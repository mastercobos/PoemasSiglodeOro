#!/usr/bin/env python3
"""
laurel_convert.py - convert the Laurel corpus (TEI XML) into app-friendly data.

WHAT IT DOES
  Reads a local clone of https://github.com/laurel-corpus/laurel-corpus and writes:
    out/authors/<author-slug>.json   one JSON file per author, poems inside
    out/authors_index.json           summary of every author (counts, era, file)
    out/poems.jsonl                  every poem, one JSON object per line
    out/poems.sqlite                 SQLite database (+ full-text search if available)
    out/gap_report.md                per-poet counts and a check for famous poems

  Only the poem text and factual metadata (author, dates, work title, source URL)
  are exported. Laurel's scansion, rhyme lettering, metre labels and URNs are NOT
  exported, because they are released under CC BY-SA 4.0. The poems themselves are
  public domain. Read the corpus LICENCE before adding any of that apparatus.

USAGE
  git clone --depth 1 https://github.com/laurel-corpus/laurel-corpus.git
  python3 laurel_convert.py --corpus laurel-corpus --out out

  Common options:
    --died-before 1926     keep authors who died before this year (default 1926)
    --max-lines 60         drop poems longer than this (default: no limit)
    --min-lines 4          drop very short fragments (default 1)
    --authors Keats,Milton keep only authors whose name contains one of these
    --forms sonnet         keep only these forms (sonnet, other)
    --allow-unknown-death  also keep authors with no death date (e.g. anonymous)
    --keep-translations    keep translated works (dropped by default)

  Only the Python standard library is needed (Python 3.8+).

NOTES
  * "form" is a simple rule: 14 lines laid out as 14, 8+6, 4+4+4+2, 4+4+3+3 or 4+4+6
    = "sonnet". It is a heuristic. It misses irregular sonnets (e.g. Shakespeare's
    Sonnet 99 has 15 lines and Sonnet 126 has 12) and can tag a rare 14-line poem
    that is not a sonnet. Check before showing it to users.
  * "era" comes from the author's birth year plus a small override table. It is a
    rough tag for filtering; edit ERA_OVERRIDES and ERA_BUCKETS to taste.
  * "excerpt" is a default candidate for share cards (whole poem up to 14 lines,
    otherwise the first stanza or first 4 lines). Curate it by hand later.
  * Sequences stored as one section (e.g. Sonnets from the Portuguese) are split
    into separate sonnets when every stanza has exactly 14 lines.
"""

import argparse
import csv
import json
import re
import sqlite3
import sys
import unicodedata
from collections import defaultdict
from pathlib import Path
import xml.etree.ElementTree as ET

NS = "{http://www.tei-c.org/ns/1.0}"

# --------------------------------------------------------------------------- #
# Configuration you may want to edit
# --------------------------------------------------------------------------- #

# Birth-year buckets used when an author has no entry in ERA_OVERRIDES.
ERA_BUCKETS = [
    (1500, "Medieval"),
    (1540, "Tudor"),
    (1590, "Elizabethan"),
    (1640, "Metaphysical & Jacobean"),
    (1700, "Restoration & Augustan"),
    (1760, "Pre-Romantic"),
    (1800, "Romantic"),
    (1850, "Victorian"),
    (1900, "Modern & War poets"),
]

# Surname (lowercase) -> era, overriding the birth-year rule where it misleads.
ERA_OVERRIDES = {
    "donne": "Metaphysical & Jacobean",
    "herbert": "Metaphysical & Jacobean",
    "marvell": "Metaphysical & Jacobean",
    "herrick": "Metaphysical & Jacobean",
    "milton": "Metaphysical & Jacobean",
    "shakespeare": "Elizabethan",
    "spenser": "Elizabethan",
    "sidney": "Elizabethan",
    "wyatt": "Tudor",
    "surrey": "Tudor",
    "blake": "Romantic",
    "burns": "Romantic",
    "whitman": "American 19th century",
    "dickinson": "American 19th century",
    "poe": "American 19th century",
    "longfellow": "American 19th century",
    "emerson": "American 19th century",
    "lazarus": "American 19th century",
    "owen": "Modern & War poets",
    "brooke": "Modern & War poets",
}

# Poets to list first in the gap report (substring of the author name, case-insensitive).
PRIORITY_POETS = [
    "Shakespeare", "Spenser", "Philip Sidney", "Thomas Wyatt", "Donne", "Herbert", "Marvell", "Herrick",
    "Milton", "Blake", "Burns", "Wordsworth", "Coleridge", "Byron", "Shelley", "Keats",
    "Alfred Tennyson", "Browning", "Rossetti", "Arnold", "Hopkins", "Wilde", "Owen", "Brooke",
    "Poe", "Whitman", "Dickinson", "Longfellow", "Lazarus",
]

# Famous poems to check for in the exported set: (label, first line or distinctive phrase).
# Use "|" to give spelling variants: Laurel keeps the original spelling of some editions.
MUST_HAVE = [
    ("Shakespeare, Sonnet 18", "Shall I compare thee to a summer's day"),
    ("Shakespeare, Sonnet 116", "Let me not to the marriage of true minds"),
    ("Shakespeare, Sonnet 130", "My mistress' eyes are nothing like the sun"),
    ("Spenser, Amoretti 1", "Happy ye leaves when as those"),
    ("Sidney, Astrophel and Stella 1", "Loving in truth|Loving in trueth"),
    ("Wyatt, They flee from me", "They flee from me that sometime did me seek"),
    ("Donne, Death be not proud", "Death, be not proud, though some have called thee"),
    ("Donne, Batter my heart", "Batter my heart, three-person'd God"),
    ("Herbert, Love (III)", "Love bade me welcome"),
    ("Marvell, To His Coy Mistress", "Had we but world enough, and time"),
    ("Herrick, To the Virgins", "Gather ye rosebuds while ye may"),
    ("Milton, On His Blindness", "When I consider how my light is spent"),
    ("Blake, The Tyger", "Tyger Tyger, burning bright"),
    ("Burns, A Red, Red Rose", "O my Luve's like a red, red rose"),
    ("Wordsworth, Westminster Bridge", "Earth has not any thing to show more fair"),
    ("Wordsworth, Daffodils", "I wandered lonely as a cloud"),
    ("Coleridge, Kubla Khan", "In Xanadu did Kubla Khan"),
    ("Byron, She Walks in Beauty", "She walks in beauty, like the night"),
    ("Shelley, Ozymandias", "I met a traveller from an antique land"),
    ("Keats, Bright Star", "Bright star, would I were"),
    ("Keats, When I Have Fears", "When I have fears that I may cease to be"),
    ("Keats, Chapman's Homer", "Much have I travell'd in the realms of gold"),
    ("Keats, Ode to a Nightingale", "My heart aches, and a drowsy numbness pains"),
    ("Keats, To Autumn", "Season of mists and mellow fruitfulness"),
    ("Tennyson, Ulysses", "It little profits that an idle king"),
    ("E. B. Browning, Sonnet 43", "How do I love thee? Let me count the ways"),
    ("C. Rossetti, Remember", "Remember me when I am gone away"),
    ("Arnold, Dover Beach", "The sea is calm to-night"),
    ("Hopkins, Pied Beauty", "Glory be to God for dappled things"),
    ("Poe, The Raven", "Once upon a midnight dreary"),
    ("Whitman, O Captain!", "O Captain! my Captain! our fearful trip is done"),
    ("Dickinson, Because I could not stop", "Because I could not stop for Death"),
    ("Dickinson, Hope is the thing", "Hope is the thing with feathers"),
    ("Longfellow, Paul Revere", "Listen, my children, and you shall hear"),
    ("Lazarus, The New Colossus", "Not like the brazen giant of Greek fame"),
    ("Owen, Anthem for Doomed Youth", "What passing-bells for these who die as cattle"),
    ("Brooke, The Soldier", "If I should die, think only this of me"),
]

# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

ROMAN = [(1000, "M"), (900, "CM"), (500, "D"), (400, "CD"), (100, "C"), (90, "XC"),
         (50, "L"), (40, "XL"), (10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]


def to_roman(n):
    out = ""
    for value, symbol in ROMAN:
        while n >= value:
            out += symbol
            n -= value
    return out


def slugify(text):
    text = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode("ascii")
    text = re.sub(r"[^a-zA-Z0-9]+", "-", text).strip("-").lower()
    return text or "unknown"


def norm_text(s):
    """Lowercase, drop apostrophes, punctuation to spaces: for matching first lines."""
    s = unicodedata.normalize("NFKD", s).lower()
    s = s.replace("\u2019", "'").replace("\u2018", "'").replace("'", "")
    s = re.sub(r"[^a-z0-9 ]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def clean_line(s):
    s = unicodedata.normalize("NFC", s or "")
    return re.sub(r"\s+", " ", s).strip()


def surname(entry):
    sort_name = (entry.get("author_sort") or entry.get("author") or "").strip()
    if "," in sort_name:
        return sort_name.split(",")[0].strip().lower()
    parts = sort_name.split()
    return parts[-1].lower() if parts else "unknown"


def era_for(entry):
    sn = surname(entry)
    if sn in ERA_OVERRIDES:
        return ERA_OVERRIDES[sn]
    born = entry.get("born")
    if not isinstance(born, int) and isinstance(entry.get("died"), int):
        born = entry["died"] - 45  # rough guess when only the death year is known
    if isinstance(born, int):
        for limit, name in ERA_BUCKETS:
            if born < limit:
                return name
        return ERA_BUCKETS[-1][1]
    return "Unknown"


SONNET_LAYOUTS = {(14,), (8, 6), (4, 4, 4, 2), (4, 4, 3, 3), (4, 4, 6)}


def is_sonnet(stanzas):
    return tuple(len(x) for x in stanzas) in SONNET_LAYOUTS


def default_excerpt(stanzas, total_lines):
    """Candidate share-card excerpt: whole poem if short, else first stanza / first 4 lines."""
    if total_lines <= 14:
        return "\n\n".join("\n".join(s) for s in stanzas)
    first = stanzas[0] if stanzas else []
    if 0 < len(first) <= 8:
        return "\n".join(first)
    flat = [ln for s in stanzas for ln in s]
    return "\n".join(flat[:4])


def read_poems(tei_path):
    """Yield (head, stanzas) for every poem division in one TEI file."""
    root = ET.parse(tei_path).getroot()
    body = root.find(".//" + NS + "body")
    if body is None:
        return
    for div in body.iter(NS + "div"):
        if div.get("type") != "poem":
            continue
        head_el = div.find(NS + "head")
        head = clean_line("".join(head_el.itertext())) if head_el is not None else ""
        stanzas = []
        for lg in div.findall(NS + "lg"):
            lines = [clean_line("".join(l.itertext())) for l in lg.findall(NS + "l")]
            lines = [ln for ln in lines if ln]
            if lines:
                stanzas.append(lines)
        if stanzas:
            yield head, stanzas


def split_sequences(head, stanzas):
    """Split a section made only of 14-line stanzas (a sonnet sequence) into sonnets."""
    if len(stanzas) >= 2 and all(len(s) == 14 for s in stanzas):
        for i, s in enumerate(stanzas, 1):
            yield "%s, %s" % (head, to_roman(i)), [s]
    else:
        yield head, stanzas


# --------------------------------------------------------------------------- #
# Main conversion
# --------------------------------------------------------------------------- #

def build(args):
    corpus = Path(args.corpus)
    lib_path = corpus / "data" / "library.json"
    tei_dir = corpus / "tei"
    if not lib_path.exists() or not tei_dir.exists():
        sys.exit("Cannot find data/library.json and tei/ in %s. Did you clone the repo?" % corpus)

    library = json.loads(lib_path.read_text(encoding="utf-8"))
    wanted_authors = [a.strip().lower() for a in args.authors.split(",")] if args.authors else []
    wanted_forms = {f.strip().lower() for f in args.forms.split(",")} if args.forms else set()

    authors = {}          # key -> author dict
    poems = []
    skipped = defaultdict(int)

    for entry in library:
        name = entry.get("author") or "Unknown"
        died = entry.get("died")

        if entry.get("translator") and not args.keep_translations:
            skipped["translation"] += 1
            continue
        if entry.get("lang") not in (None, "eng", "en") and not args.keep_translations:
            skipped["non-English original"] += 1
            continue
        if isinstance(died, int):
            if died >= args.died_before:
                skipped["author died %d or later" % args.died_before] += 1
                continue
        elif not args.allow_unknown_death:
            skipped["unknown death date"] += 1
            continue
        if wanted_authors and not any(w in name.lower() for w in wanted_authors):
            skipped["not in --authors"] += 1
            continue

        tei_path = tei_dir / (entry["slug"] + ".xml")
        if not tei_path.exists():
            skipped["missing TEI file"] += 1
            continue

        key = (surname(entry), entry.get("born"), died)
        if key not in authors:
            authors[key] = {
                "name": name,
                "slug": slugify(name),
                "born": entry.get("born"),
                "died": died,
                "era": era_for(entry),
                "poems": [],
            }
        author = authors[key]

        source = entry.get("source") or {}
        for pos, (head, stanzas) in enumerate(read_poems(tei_path)):
            for sub, (title, sts) in enumerate(split_sequences(head, stanzas)):
                n_lines = sum(len(s) for s in sts)
                if n_lines < args.min_lines:
                    skipped["shorter than --min-lines"] += 1
                    continue
                if args.max_lines and n_lines > args.max_lines:
                    skipped["longer than --max-lines"] += 1
                    continue
                form = "sonnet" if is_sonnet(sts) else "other"
                if wanted_forms and form not in wanted_forms:
                    skipped["form filtered"] += 1
                    continue
                poem = {
                    "id": "%s:%d.%d" % (entry["slug"], pos, sub),
                    "title": title,
                    "first_line": sts[0][0],
                    "author": author["name"],
                    "author_slug": author["slug"],
                    "era": author["era"],
                    "work_title": entry.get("title"),
                    "published": entry.get("published"),
                    "form": form,
                    "line_count": n_lines,
                    "stanza_count": len(sts),
                    "stanzas": sts,
                    "text": "\n\n".join("\n".join(s) for s in sts),
                    "excerpt": default_excerpt(sts, n_lines),
                    "source_provider": source.get("provider"),
                    "source_url": source.get("url"),
                    "source_edition": source.get("title_as_published"),
                }
                author["poems"].append(poem)
                poems.append(poem)

    return authors, poems, skipped


def slugs_unique(authors):
    """Two different people can slugify to the same name; keep files distinct."""
    seen = defaultdict(int)
    for a in authors.values():
        seen[a["slug"]] += 1
        if seen[a["slug"]] > 1:
            a["slug"] += "-%d" % seen[a["slug"]]
            for p in a["poems"]:
                p["author_slug"] = a["slug"]


def write_outputs(out, authors, poems):
    out = Path(out)
    (out / "authors").mkdir(parents=True, exist_ok=True)

    index = []
    for a in sorted(authors.values(), key=lambda x: x["name"].lower()):
        if not a["poems"]:
            continue
        fname = "authors/%s.json" % a["slug"]
        payload = {k: a[k] for k in ("name", "born", "died", "era")}
        payload["poems"] = [{k: v for k, v in p.items() if k not in ("author", "author_slug", "era", "text")}
                            for p in a["poems"]]
        (out / fname).write_text(json.dumps(payload, ensure_ascii=False, indent=1), encoding="utf-8")
        index.append({
            "name": a["name"], "slug": a["slug"], "born": a["born"], "died": a["died"], "era": a["era"],
            "poems": len(a["poems"]),
            "sonnets": sum(1 for p in a["poems"] if p["form"] == "sonnet"),
            "file": fname,
        })
    (out / "authors_index.json").write_text(json.dumps(index, ensure_ascii=False, indent=1), encoding="utf-8")

    with open(out / "poems.jsonl", "w", encoding="utf-8") as fh:
        for p in poems:
            fh.write(json.dumps(p, ensure_ascii=False) + "\n")

    db_path = out / "poems.sqlite"
    if db_path.exists():
        db_path.unlink()
    con = sqlite3.connect(db_path)
    con.executescript("""
        CREATE TABLE authors(
            id INTEGER PRIMARY KEY, slug TEXT UNIQUE, name TEXT, born INTEGER, died INTEGER, era TEXT);
        CREATE TABLE poems(
            id TEXT PRIMARY KEY, author_id INTEGER REFERENCES authors(id),
            title TEXT, first_line TEXT, work_title TEXT, published TEXT, era TEXT, form TEXT,
            line_count INTEGER, stanza_count INTEGER, text TEXT, stanzas_json TEXT, excerpt TEXT,
            source_provider TEXT, source_url TEXT, source_edition TEXT);
        CREATE INDEX idx_poems_author ON poems(author_id);
        CREATE INDEX idx_poems_form ON poems(form);
        CREATE INDEX idx_poems_lines ON poems(line_count);
        CREATE INDEX idx_poems_era ON poems(era);
    """)
    author_ids = {}
    for a in authors.values():
        if not a["poems"]:
            continue
        cur = con.execute("INSERT INTO authors(slug,name,born,died,era) VALUES (?,?,?,?,?)",
                          (a["slug"], a["name"], a["born"], a["died"], a["era"]))
        author_ids[a["slug"]] = cur.lastrowid
    con.executemany(
        "INSERT INTO poems VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)",
        [(p["id"], author_ids[p["author_slug"]], p["title"], p["first_line"], p["work_title"],
          p["published"], p["era"], p["form"], p["line_count"], p["stanza_count"], p["text"],
          json.dumps(p["stanzas"], ensure_ascii=False), p["excerpt"],
          p["source_provider"], p["source_url"], p["source_edition"]) for p in poems])
    try:  # full-text search over title, first line and text (needs SQLite with FTS5)
        con.execute("CREATE VIRTUAL TABLE poems_fts USING fts5(title, first_line, text, content='poems', content_rowid='rowid')")
        con.execute("INSERT INTO poems_fts(rowid,title,first_line,text) SELECT rowid,title,first_line,text FROM poems")
    except sqlite3.OperationalError:
        print("Note: this SQLite build has no FTS5; skipped the full-text index.")
    con.commit()
    con.close()


def gap_report(out, authors, poems, max_lines):
    if max_lines:
        short_note = "'Short' means at most %d lines." % max_lines
    else:
        short_note = "No --max-lines was set, so 'Short' counts every poem."
    lines = ["# Gap report", "",
             "Generated from the exported set (after your filters). " + short_note, "",
             "## Priority poets", "",
             "| Poet | Poems | Sonnets (by layout) | Short |", "|---|---:|---:|---:|"]
    for key in PRIORITY_POETS:
        matches = [a for a in authors.values() if a["poems"] and key.lower() in a["name"].lower()]
        if not matches:
            lines.append("| %s | 0 | 0 | 0 |" % key)
            continue
        for a in sorted(matches, key=lambda x: x["name"]):
            n = len(a["poems"])
            son = sum(1 for p in a["poems"] if p["form"] == "sonnet")
            short = sum(1 for p in a["poems"] if not max_lines or p["line_count"] <= max_lines)
            lines.append("| %s | %d | %d | %d |" % (a["name"], n, son, short))

    lines += ["", "## Famous poems: present or missing", "", "| Poem | Status |", "|---|---|"]
    haystack = [(norm_text(p["title"] + " " + " ".join(p["stanzas"][0][:2])), p) for p in poems]
    full = None
    missing = []
    for label, phrase in MUST_HAVE:
        targets = [norm_text(x) for x in phrase.split("|")]  # "|" separates spelling variants
        hit = any(t in h for t in targets for h, _ in haystack)
        if not hit:
            if full is None:
                full = [norm_text(p["text"]) for p in poems]
            hit = any(t in txt for t in targets for txt in full)
        lines.append("| %s | %s |" % (label, "present" if hit else "**MISSING**"))
        if not hit:
            missing.append(label)
    lines += ["", "Missing poems can be added from Project Gutenberg or Wikisource "
                  "(original-language texts by authors who died over 100 years ago).", ""]
    (Path(out) / "gap_report.md").write_text("\n".join(lines), encoding="utf-8")
    return missing


def main():
    ap = argparse.ArgumentParser(description="Convert the Laurel corpus to per-author JSON, JSONL and SQLite.")
    ap.add_argument("--corpus", required=True, help="path to the cloned laurel-corpus repository")
    ap.add_argument("--out", default="out", help="output directory (default: out)")
    ap.add_argument("--died-before", type=int, default=1926, help="keep authors who died before this year")
    ap.add_argument("--max-lines", type=int, default=0, help="drop poems longer than this many lines")
    ap.add_argument("--min-lines", type=int, default=1, help="drop poems shorter than this many lines")
    ap.add_argument("--authors", default="", help="comma-separated name fragments to keep")
    ap.add_argument("--forms", default="", help="comma-separated forms to keep: sonnet, other")
    ap.add_argument("--allow-unknown-death", action="store_true", help="keep authors with no death date")
    ap.add_argument("--keep-translations", action="store_true", help="keep translated works")
    args = ap.parse_args()

    authors, poems, skipped = build(args)
    slugs_unique(authors)
    write_outputs(args.out, authors, poems)
    missing = gap_report(args.out, authors, poems, args.max_lines)

    n_auth = sum(1 for a in authors.values() if a["poems"])
    print("Wrote %d poems by %d authors to %s/" % (len(poems), n_auth, args.out))
    if skipped:
        print("Skipped:")
        for reason, n in sorted(skipped.items(), key=lambda x: -x[1]):
            print("  %6d  %s" % (n, reason))
    print("Famous poems missing from this set: %d of %d (see gap_report.md)" % (len(missing), len(MUST_HAVE)))


if __name__ == "__main__":
    main()
