#!/usr/bin/env python3
"""
extraer.py - split the anthology's biggest books into poems ourselves.

Laurel's poems.jsonl is Gutenberg text cut into poems by Laurel's parser, and
almost every serious fault in it (poems glued together, footnotes at the end of
a poem, drama scenes with the speakers stripped) comes from that cutting. The
layout that shows where a poem or a note begins is gone by the time the text
reaches seleccionar.py. So for the books in LIBROS we run Laurel's own parser
(it ships in corpus/laurel-corpus/pipeline) and fix the causes before it reads
the text (fuente.py). The test that led here is in prueba_top10.md.

  python3 parser/extraer.py                 # every book in LIBROS
  python3 parser/extraer.py burns-poems     # some of them
  python3 parser/extraer.py --laurel ...    # Laurel's parser alone, as a control

Writes corpus/parser-salida/<book>.json, which seleccionar.py uses in place of
Laurel's entries for that book, and parser/informe.md (what was fixed, what is
still open). corpus/parser-trabajo/ holds the copy of Laurel's pipeline it runs,
rebuilt whenever the Laurel clone changes commit.

Per book:
  1. the Gutenberg text (corpus/gutenberg/, downloaded if missing), cleaned by
     fuente.py: note marks off headings, footnote bodies out, titles named in
     the book's own contents raised so the parser reads them as titles;
  2. Laurel's parse_gutenberg with Laurel's per-book hints, plus PISTAS below;
  3. Laurel's hand fixes (segmentation-findings.json). They name sections by
     ids made from titles and stanzas by position in Laurel's split, so they
     are replayed on Laurel's split (in passes, as Laurel ran them) and each is
     moved onto ours by content: the section that opens with the same line,
     the stanzas with the same first lines. A fix our split already does is
     skipped; one that can't be moved is listed in informe.md;
  4. titles: a section that opens (and ends) like one of Laurel's takes
     Laurel's title; our rules move boundaries, not names;
  5. our own fixes, correcciones.json: Laurel's format keyed to our split, plus
     "anadir" (a poem taken straight from the source), "unir" (parts of one
     poem split apart), "quitar" (stray lines) and "resuelto" (Laurel fixes checked and closed, with the reason);
  6. speaker tags put back in dialogue poems, epigraphs from other writers
     dropped (fuente.con_hablantes, fuente.sin_epigrafes).

Tools: buscar.py (which section holds a line), probar_reglas.py (which source
rule changes the split around a line), comparar.py / detalle.py (two runs).
"""
import argparse
import copy
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent
LAUREL = RAIZ / "corpus" / "laurel-corpus"
TRABAJO = RAIZ / "corpus" / "parser-trabajo"   # a copy of Laurel's pipeline/, rebuilt when Laurel changes
SALIDA = RAIZ / "corpus" / "parser-salida"
sys.path.insert(0, str(RAIZ))
sys.path.insert(0, str(AQUI))
import gutenberg  # noqa: E402
import fuente     # noqa: E402

# The books that give the most poems to the asset, best first. Left to Laurel:
# Shakespeare's sonnets and In Memoriam (parsed by hand in Laurel's ingest.py);
# Lear's nonsense (Laurel's published split is not what its parser makes: 2
# sections against 113); Tennyson's early poems (Collins's edition is more notes
# than verse, and Laurel's hand fixes for it don't carry over: poems glued, the
# notes' early versions read as poems).
LIBROS = [
    "herrick-hesperides", "hemans-poems", "burns-poems", "dickinson-poems", "longfellow-poems",
    "dunbar-poems", "macdonald-poems", "barnes-dorset", "whitman-leaves", "swift-poems",
    "hood-poems", "emerson-poems", "shelley-later-poems", "lowell-james-russell-poems", "donne-poems",
    "byron-childe-harold", "swift-poems-vol1", "drayton-minor-poems", "rossetti-goblin-market", "byron-works-3",
    "cawein-poems", "bowles-sonnets", "henley-poems", "hood-poetical-works", "whittier-anti-slavery",
    "bryant-poems", "seward-sonnets", "kirke-white-poems", "sidney-astrophel", "lovelace-lucasta",
    "waller-denham", "arnold-poems", "harper-poems", "thackeray-ballads",
    "stedman-poems", "wordsworth-vol2", "lanier-poems", "spenser-amoretti",
    "patmore-angel", "coolidge-few-more-verses", "meredith-poems", "praed-poems", "rossetti-house-of-life",
    "timrod-poems", "coleridge-poems", "johnson-lionel-poems",
]

# Our hints, on top of Laurel's catalog.SLUG_META. Lists are added to Laurel's.
PISTAS = {
    # Longfellow's two plays, taken out like Laurel takes out Christus: an act is not a poem.
    # Capital lines that fuente.hablantes takes for speaker tags and are not: "no_hablantes".
    "hemans-poems": {"no_hablantes": ["FROM A PAINTING BY WILLIAMS."]},
    "barnes-dorset": {"no_hablantes": ["THE RAILROAD."]},
    "seward-sonnets": {"no_hablantes": ["SUBJECT CONTINUED."]},
    # Collins's critical introduction quotes Tennyson line by line with the poem named under
    # each quotation, and the parser made those poems ("The Eagle" in 22 lines). The poems
    # begin at the second "To the Queen" (the first is in the contents; any case, since
    # fuente.titulos_del_indice may have raised it).
    "tennyson-early-poems": {"start_at": r"(?i)^to the queen$", "start_occurrence": 2, "start_inclusive": True},
    "longfellow-poems": {"drop_range": [(r"^THE SPANISH STUDENT$", r"^THE BELFRY OF BRUGES AND OTHER POEMS$"),
                                        (r"^THE MASQUE OF PANDORA$", r"^THE HANGING OF THE CRANE$")]},
}

CORRECCIONES = AQUI / "correcciones.json"


def commit_laurel():
    return subprocess.run(["git", "-C", str(LAUREL), "rev-parse", "HEAD"],
                          capture_output=True, text=True, check=True).stdout.strip()


def preparar(libros_gutenberg):
    """The working copy of Laurel's pipeline, with the books where its parser looks for them."""
    sello = TRABAJO / "laurel_commit"
    commit = commit_laurel()
    if not sello.exists() or sello.read_text() != commit:
        shutil.rmtree(TRABAJO, ignore_errors=True)
        shutil.copytree(LAUREL / "pipeline", TRABAJO / "pipeline")
        (TRABAJO / "site" / "data" / "works").mkdir(parents=True)   # the parser writes commentary there
        sello.write_text(commit)
    fuentes = TRABAJO / "pipeline" / "sources"
    fuentes.mkdir(exist_ok=True)
    for ebook in libros_gutenberg:
        enlace = fuentes / ("pg%d.txt" % ebook)
        if not enlace.exists():
            enlace.symlink_to(gutenberg.descargar(ebook))
    sys.path.insert(0, str(TRABAJO / "pipeline"))


def ya_hecho(r, viejo, secciones):
    """Our split already does what this Laurel fix is for: the poem it splits off starts a
    section of ours, the text it drops starts none, the title it gives is the one we have.
    Content, not position, so it holds however the two splits number their stanzas."""
    fix, sid = r.get("fix") or {}, r["section"]
    old = viejo.get(sid)
    if not fix or not old or "missed" in fix or "retitle_after_previous" in fix or "append_from_next" in fix:
        return False
    inicio = {fuente.clave(s["stanzas"][0][0]): s for s in secciones if s["stanzas"] and s["stanzas"][0]}
    vista = [old[n] for n in fix["keep_stanzas"] if 0 <= n < len(old)] if "keep_stanzas" in fix else old
    anterior = {}                                            # first line of a section -> the section before it
    for a, b in zip(secciones, secciones[1:]):
        if b["stanzas"] and b["stanzas"][0]:
            anterior[fuente.clave(b["stanzas"][0][0])] = a

    def abre(n):
        """Stanza n opens a section of ours, and the stanza before it ends the section before
        (not just any section: Donne's edition prints the Psalms poem twice)."""
        if not (0 < n < len(vista) and vista[n] and vista[n - 1]):
            return False
        antes = anterior.get(fuente.clave(vista[n][0]))
        return bool(antes) and any(fuente.clave(vista[n - 1][0]) == fuente.clave(st[0]) for st in antes["stanzas"] if st)
    pruebas = []
    if "drop" in fix:
        pruebas.append(fuente.clave(old[0][0]) not in inicio)
    if "split_at_stanza" in fix:
        pruebas.append(abre(fix["split_at_stanza"]))
    if "split_many" in fix:
        pruebas += [abre(n) for n, _ in fix["split_many"]]
    if "retitle" in fix:
        s = inicio.get(fuente.clave(vista[0][0])) if vista and vista[0] else None
        pruebas.append(bool(s) and s["title"] == fix["retitle"])
    if "keep_stanzas" in fix:
        fuera = {fuente.clave(st[0]) for k, st in enumerate(old) if k not in fix["keep_stanzas"] and st}
        dentro = {fuente.clave(l) for s in secciones for st in s["stanzas"] for l in st[:1]}
        pruebas.append(not (fuera & dentro))
    return bool(pruebas) and all(pruebas)


def reanclar(r, viejo, ahora, log):
    """A Laurel hand fix, written against Laurel's split, moved onto ours: each stanza it
    names is found again by its first line. None, and logged, when that can't be done."""
    fix, sid = r.get("fix") or {}, r["section"]
    if sid == "*" or (sid in ahora and ahora[sid] == viejo.get(sid)):
        return r
    # The target is found by what it says, not by its id: ids come from titles, and the same
    # id can name a different text in the two splits (Laurel's "the-prairies" is a stray note
    # it drops; ours is Bryant's poem). The section of ours that opens as Laurel's did: the one
    # with the same id if it does, else the only one that does.
    destino = None
    if viejo.get(sid) and viejo[sid][0]:
        abre = viejo[sid][0][0]
        iguales = [i for i, st in ahora.items() if st and st[0] and st[0][0] == abre]
        destino = sid if sid in iguales else (iguales[0] if len(iguales) == 1 else None)
        if destino is None:
            # its opening stanza may be one our rules took out (Burns's prose note over
            # Halloween): the only section of ours holding one of its first two stanzas near its top
            primeras = {st[0] for st in viejo[sid][:2] if st}
            cerca = [i for i, st in ahora.items() if any(e and e[0] in primeras for e in st[:3])]
            destino = sid if sid in cerca else (cerca[0] if len(cerca) == 1 else None)
    if destino is None:
        log.append("not moved: `%s` %s" % (sid, "/".join(fix) or "missed"))
        return None
    old, new = viejo[sid], ahora[destino]
    r = copy.deepcopy(r)
    r["section"] = destino
    f = r["fix"]
    primeras = {st[0]: k for k, st in enumerate(new) if st}
    mover = lambda n: primeras.get(old[n][0]) if 0 <= n < len(old) and old[n] else None
    # split and join numbers count the stanzas left after keep_stanzas, in both splits
    vista_old = [old[n] for n in f["keep_stanzas"] if 0 <= n < len(old)] if "keep_stanzas" in f else old
    if "keep_stanzas" in f:
        f["keep_stanzas"] = [k for k in (mover(n) for n in f["keep_stanzas"]) if k is not None]
        vista_new = [new[k] for k in f["keep_stanzas"]]
    else:
        vista_new = new
    pos = {st[0]: k for k, st in enumerate(vista_new) if st}
    m2 = lambda n: pos.get(vista_old[n][0]) if 0 <= n < len(vista_old) and vista_old[n] else None
    ok = not ("keep_stanzas" in f and not f["keep_stanzas"])
    if "split_at_stanza" in f:
        f["split_at_stanza"] = m2(f["split_at_stanza"])
        ok = ok and bool(f["split_at_stanza"])
    if "split_many" in f:
        f["split_many"] = [[m2(n), t] for n, t in f["split_many"]]
        ok = ok and all(n for n, _ in f["split_many"])
    if "join_stanzas" in f:
        f["join_stanzas"] = [[m2(a), m2(b)] for a, b in f["join_stanzas"]
                             if m2(a) is not None and m2(b) is not None]
    if not ok:
        log.append("not moved: `%s` %s" % (sid, "/".join(fix)))
        return None
    return r


def seccion_de_nota(nota):
    """The section a log line is about: ours read "not moved: `id` ...", segfix's
    read "  <book>: <id> ..." """
    import re
    m = re.search(r"`([^`]+)`", nota) or re.match(r"\s*[\w-]+: ([\w-]+)", nota)
    return m.group(1) if m else None


def anadir(w, r, ingest, log):
    """A poem the parser missed, taken straight from the source: the lines after the one
    matching `desde` (searched from the line matching `tras`, if given) up to the one
    matching `hasta`. `sin_numeros` drops lines that are only a roman numeral."""
    import re
    a = r["anadir"]
    lineas = ingest.load(a["ebook"])
    t = next((k for k, l in enumerate(lineas) if re.match(a["tras"], l.strip())), None) if a.get("tras") else 0
    i = next((k for k in range(t, len(lineas)) if re.match(a["desde"], lineas[k].strip())), None) if t is not None else None
    j = next((k for k in range(i + 1, len(lineas)) if re.match(a["hasta"], lineas[k].strip())), None) if i is not None else None
    if i is None or j is None:
        log.append("not added: %s (start or end not found)" % a["title"])
        return
    estrofas, actual = [], []
    for l in lineas[i + 1:j]:
        l = ingest.clean(l)
        if a.get("sin_numeros") and re.match(r"^[IVXLC]+\.?$", l):
            l = ""
        if l:
            actual.append(l)
        elif actual:
            estrofas.append(actual)
            actual = []
    if actual:
        estrofas.append(actual)
    ids = [s["id"] for s in w["sections"]]
    pos = ids.index(a["despues_de"]) + 1 if a.get("despues_de") in ids else len(ids)
    w["sections"].insert(pos, {"id": r["section"], "title": a["title"], "short": a["title"][:18], "stanzas": estrofas})


def extraer(slug, lib, consultas, hallazgos, propias, reglas, informe):
    import catalog
    import generic
    import ingest
    import segfix
    b, q = lib[slug], consultas[slug]
    meta = {"title": q[2], "title_as_published": b["source"].get("title_as_published"), "author": b["author"],
            "author_sort": b["author_sort"], "born": b["born"], "died": b["died"], "circa": b.get("circa", ""),
            "published": q[4], "blurb": q[3], "form": None, "scheme": None,
            "meter": q[5] if q[5] in ("blank verse", "heroic couplets", "free verse", "trochaic tetrameter", "dactylic hexameter") else None}
    meta.update(copy.deepcopy(catalog.SLUG_META.get(slug, {})))
    meta_laurel = copy.deepcopy(meta)
    for k, v in PISTAS.get(slug, {}).items():
        meta[k] = meta.get(k, []) + v if isinstance(v, list) else v
    ebook = b["source"]["ebook"]

    # Laurel's split, made exactly as Laurel made it: its hand fixes name sections by ids
    # derived from titles ("song-2"), which shift as soon as anything before them changes
    generic.load = ingest.load
    laurel = generic.parse_gutenberg(ebook, slug, meta_laurel)
    if not reglas:
        meta = meta_laurel
    if reglas:
        generic.load = lambda gid: fuente.titulos_del_indice(fuente.sin_notas(fuente.sin_marcas(ingest.load(gid))))[0]
        w = generic.parse_gutenberg(ebook, slug, meta)
    else:
        w = laurel
    w = catalog.mark_prose(w, meta)
    w = ingest.apply_corrections(w)
    log = []

    orden = {"drop": 0, "keep_stanzas": 0, "split_at_stanza": 1, "split_many": 1, "append_from_next": 2, "retitle": 3, "missed": 4}
    clave = lambda r: orden.get(next(iter(r["fix"])) if r.get("fix") else "missed", 9)
    rs = sorted([r for r in hallazgos if r["work"] == slug], key=clave)
    if reglas:
        # Each Laurel fix was written against Laurel's split as it stood when the fix ran, after
        # the fixes before it (Seward's "sonnet-ii" only exists once the "sonnet" fix has split it
        # off). So Laurel's fixes are replayed on Laurel's split, keeping what each one saw.
        # segfix applies drops and keeps before splits, so a fix on a section another fix creates
        # only takes on a second run, which is how Laurel ran it: replayed here in passes.
        # A fix that fails (its section not there yet, or too short until another fix has joined
        # onto it: Donne's "A Litanie" is appended to, then split) is tried again next pass.
        repeticion, antes, orden_real, pendientes = copy.deepcopy(laurel), {}, [], list(rs)
        for _ in range(4):
            ids = {s["id"] for s in repeticion["sections"]}
            listos = [r for r in pendientes if r["section"] == "*" or r["section"] in ids]
            aplicados = []
            for r in listos:
                foto = {s["id"]: copy.deepcopy(s["stanzas"]) for s in repeticion["sections"]}
                fallos = []
                segfix.apply(repeticion, [r], fallos)
                if not fallos:
                    antes[id(r)] = foto
                    aplicados.append(r)
            if not aplicados:
                break
            orden_real += aplicados
            pendientes = [r for r in pendientes if r not in aplicados]
        for r in pendientes:
            antes[id(r)] = {s["id"]: s["stanzas"] for s in repeticion["sections"]}
        # and on ours in the same order, one at a time, since they build on each other here too
        hechos = []
        for r in orden_real + pendientes:
            if ya_hecho(r, antes[id(r)], w["sections"]):
                hechos.append(r)
                continue
            ahora = {s["id"]: s["stanzas"] for s in w["sections"]}
            movido = reanclar(r, antes[id(r)], ahora, log)
            if movido:
                segfix.apply(w, [movido], log)
        if hechos:
            log.append("already done by our split: " + ", ".join("`%s`" % r["section"] for r in hechos))
        # Our rules move where poems begin and end, not what they are called. Laurel's titling
        # is tuned book by book, and raising a heading to capitals changes how the parser cases
        # it ("Break, Break, Break"): a section that opens like one of Laurel's takes its title.
        # Matched on first and last line: Burns prints songs in two versions that open alike,
        # and Hemans heads two poems with the same epigraph. On the first line alone only
        # where it opens a single section.
        primera = lambda s: fuente.clave(s["stanzas"][0][0])
        ultima = lambda s: fuente.clave(s["stanzas"][-1][-1])
        suyas = [s for s in repeticion["sections"] if s["stanzas"] and s["stanzas"][0]]
        cuantas, ambas = {}, {}
        for s in suyas:
            cuantas[primera(s)] = cuantas.get(primera(s), 0) + 1
            ambas[(primera(s), ultima(s))] = ambas.get((primera(s), ultima(s)), 0) + 1
        # Burns's two versions of a song can open and close alike: then only the same id decides
        por_ambas = {(primera(s), ultima(s)): s["title"] for s in suyas if ambas[(primera(s), ultima(s))] == 1}
        por_id = {s["id"]: (primera(s), s["title"]) for s in suyas}
        # On the first line alone the two must also be about the same length: Timrod's whole
        # "A Vision of Poesy: Part I" opens like Laurel's 27-line fragment of it.
        lineas = lambda s: sum(len(st) for st in s["stanzas"])
        por_primera = {primera(s): (s["title"], lineas(s)) for s in suyas if cuantas[primera(s)] == 1}
        for s in w["sections"]:
            if s["stanzas"] and s["stanzas"][0]:
                mismo = por_id.get(s["id"])
                titulo = mismo[1] if mismo and mismo[0] == primera(s) else por_ambas.get((primera(s), ultima(s)))
                if not titulo and primera(s) in por_primera:
                    suyo, n = por_primera[primera(s)]
                    titulo = suyo if 0.7 <= lineas(s) / max(n, 1) <= 1.4 else None
                if titulo:
                    s["title"] = titulo
    else:
        segfix.apply(w, rs, log)

    epigrafes = voces = 0
    if reglas:
        # our fixes count stanzas as the parser left them, so they come before speakers and epigraphs
        nuestras = [r for r in propias if r["work"] == slug]
        for r in nuestras:
            if "anadir" in r:
                anadir(w, r, ingest, log)
        segfix.apply(w, sorted([r for r in nuestras if "fix" in r], key=clave), log)
        for r in nuestras:
            if "unir" in r:                                 # one poem the source numbers in parts
                ids = [s["id"] for s in w["sections"]]
                if r["section"] in ids and all(i in ids for i in r["unir"]):
                    base = w["sections"][ids.index(r["section"])]
                    for i in r["unir"]:
                        parte = next(s for s in w["sections"] if s["id"] == i)
                        base["stanzas"] += parte["stanzas"]
                        w["sections"].remove(parte)
                    base["title"] = r.get("title", base["title"])
                else:
                    log.append("not joined: `%s` (a part is missing)" % r["section"])
            if "quitar" in r:                               # stray lines: a subtitle left in the verse
                for s in w["sections"]:
                    if s["id"] == r["section"]:
                        s["stanzas"] = [st for st in ([l for l in st if l.strip() not in r["quitar"]] for st in s["stanzas"]) if st]
        mapa = {k: v for k, v in fuente.hablantes(ingest.load(ebook)).items() if v not in meta.get("no_hablantes", [])}
        for s in w["sections"]:
            s["stanzas"], n = fuente.con_hablantes(s["stanzas"], mapa)
            voces += n
        for s in w["sections"]:
            s["stanzas"], n = fuente.sin_epigrafes(s["stanzas"])
            epigrafes += n
        w["sections"] = [s for s in w["sections"] if s["stanzas"]]

    # Laurel fixes we have checked and closed (correcciones.json "resuelto") leave the list of open ones
    resueltos = {i: r["note"] for r in propias if r["work"] == slug for i in r.get("resuelto", [])} if reglas else {}
    log = [n for n in log if seccion_de_nota(n) not in resueltos]

    SALIDA.mkdir(parents=True, exist_ok=True)
    (SALIDA / (slug + ".json")).write_text(json.dumps(w, ensure_ascii=False), encoding="utf-8")
    informe.append((slug, len(laurel["sections"]), len(w["sections"]), b["stats"]["sections"], voces, epigrafes, log))
    print("%-28s Laurel's split %4d, ours %4d (published %4d), speakers %4d, epigraphs dropped %3d%s" % (
        slug, len(laurel["sections"]), len(w["sections"]), b["stats"]["sections"], voces, epigrafes,
        "  [%d notes]" % len(log) if log else ""))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("libros", nargs="*", help="books to run (default: all of LIBROS)")
    ap.add_argument("--laurel", action="store_true", help="Laurel's parser and hand fixes alone, no rules of ours")
    ap.add_argument("--salida", help="write the books here instead of corpus/parser-salida (for comparisons)")
    args = ap.parse_args()
    if args.salida:
        global SALIDA
        SALIDA = Path(args.salida)
    lib = {b["slug"]: b for b in json.loads((LAUREL / "data" / "library.json").read_text(encoding="utf-8"))}
    libros = args.libros or LIBROS
    preparar([lib[s]["source"]["ebook"] for s in libros])
    import catalog
    import segfix
    consultas = {q[0]: q for q in catalog.QUERIES}
    hallazgos = [r for r in json.load(open(segfix.FINDINGS, encoding="utf-8")) if "issue" in r]
    propias = json.loads(CORRECCIONES.read_text(encoding="utf-8")) if CORRECCIONES.exists() else []
    informe = []
    for slug in libros:
        extraer(slug, lib, consultas, hallazgos, propias, not args.laurel, informe)
    if not args.libros and not args.laurel:
        escribir_informe(informe)


def escribir_informe(informe):
    filas = ["# Parser report", "",
             "Generated by `parser/extraer.py`. Sections: as Laurel's parser splits the book, as ours does after",
             "all fixes, and as Laurel published it (its published count includes hand work its code can't redo).", "",
             "| Book | Laurel's split | Ours | Published | Speaker tags restored | Epigraphs dropped |", "|---|---:|---:|---:|---:|---:|"]
    notas, hechos = [], []
    for slug, a, b, c, v, e, log in informe:
        filas.append("| %s | %d | %d | %d | %d | %d |" % (slug, a, b, c, v, e))
        notas += ["* %s: %s" % (slug, n.strip()) for n in log if not n.startswith("already done")]
        hechos += ["* %s: %s" % (slug, n[len("already done by our split: "):]) for n in log if n.startswith("already done")]
    filas += ["", "## Fixes not applied", "",
              "Laurel's own notes for fixes its code can't apply, and hand fixes that could not be moved onto our split.", ""]
    filas += notas or ["None."]
    filas += ["", "## Laurel fixes our split already does", "",
              "Checked by content: the poem the fix splits off starts one of our sections, the text it drops", "starts none, the title it gives is ours.", ""]
    filas += hechos or ["None."]
    (AQUI / "informe.md").write_text("\n".join(filas) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
