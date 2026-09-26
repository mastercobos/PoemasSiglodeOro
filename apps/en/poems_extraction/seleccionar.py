#!/usr/bin/env python3
"""
seleccionar.py - build the English app's poemas.json from laurel_convert.py output.

  python3 laurel_convert.py --corpus corpus/laurel-corpus --out corpus/laurel-export   # no --max-lines
  python3 gutenberg.py                     # downloads the Gutenberg books into corpus/gutenberg
  python3 parser/extraer.py                # splits the biggest books into corpus/parser-salida
  python3 seleccionar.py --poems corpus/laurel-export/poems.jsonl \
      --asset ../assets/poemas.json --report ranking.md [--top-authors N] [--max-lines N]

Authors are ranked, best known first, and every poem of each selected author
is kept. Ranking:

  1. Tier 1 is laurel_convert.PRIORITY_POETS, the canon the gap report
     already checks. Tier 2 is everyone else.
  2. Within a tier, by English Wikipedia page views of the author's article,
     Sep 2025 - Aug 2026 (autores_vistas.json; articles were matched by search
     and the mismatches corrected by hand). Views measure fame as a person, not
     as a poet - Thoreau and Stevenson outrank Herrick - which is why the tier
     comes first.

Famous poems Laurel lacks are added from Project Gutenberg (anadidos_gutenberg.json:
author, title, text, source book and its Gutenberg URL). They are merged after
Laurel's poems, so if Laurel has the poem after all, its copy wins - unless the
addition says "reemplaza": true, which replaces Laurel's entry with the same
author and opening line (used where Laurel glued several poems into one).

The biggest books are split into poems by parser/extraer.py instead: its
output in corpus/parser-salida/ replaces Laurel's entries for those books
(--parser; run extraer.py first).

Some Laurel books are left out whole (LIBROS_EXCLUIDOS: translations, prose,
editions that are mostly notes, anthologies credited to their editor). Every
other poem goes through limpiar.py (markup, editors' notes, Latin facing texts,
"Canto I" -> "Don Juan: Canto I"). Lines that Gutenberg's text wrapped in two
are joined back using the Gutenberg file itself (gutenberg.py). Poems the
cleaner had to cut, sections it could not name and poems whose lines are still
broken are held back. limpieza.md lists it all.

Duplicates (same author, same opening line: one poem from two source editions)
are dropped, keeping the first. The app derives Poema.id from author, title and
first line and asserts they are unique, so this is required, not cosmetic.

The report names the Laurel commit the poems came from (corpus_version.json,
written by laurel_convert.py next to poems.jsonl), and lists every author with
running totals of poems, verses and bytes, so the cut can be chosen by author
rank (--top-authors) and/or length.
"""
import argparse
import json
import re
import unicodedata
from pathlib import Path

from laurel_convert import MUST_HAVE, PRIORITY_POETS, is_sonnet, split_sequences, to_roman
from limpiar import limpiar_poema, lineas_partidas, seccion_sin_obra
import gutenberg

AQUI = Path(__file__).resolve().parent

# Whole Laurel books left out: not English poems, not verse, mostly editors'
# apparatus, or crediting the poems to the wrong person. Laurel slug -> reason.
LIBROS_EXCLUIDOS = {
    "boethius-consolation": "translation, with the Latin",
    "prudentius-hymns": "translation, with the Latin",
    "persius-satires": "translation",
    "virgil-eclogues": "translation",
    "symonds-wine-women": "translation",
    "evans-welsh": "translation",
    "pushkin-poems": "translation",
    "pushkin-bakchesarian": "translation",
    "pushkin-boris-godunov": "translation",
    "schiller-third-period": "translation",
    "baudelaire-flowers-of-evil": "translation",
    "nekrasov-who-can-be-happy": "translation",
    "macpherson-ossian": "prose",
    "carroll-looking-glass": "a novel; its verses come with prose chapters",
    "darwin-loves-of-plants": "prose interludes and notes",
    "skelton-poems": "scholarly edition, mostly notes",
    "corbet-poems": "scholarly edition, mostly notes",
    "davies-poems": "scholarly edition: letters, pedigrees, notes",
    "gower-confessio": "Latin and notes",
    "poems-every-child": "anthology: every poem credited to the editor, Mary E. Burt",
    "percy-reliques": "anthology: every poem credited to the editor, Thomas Percy",
    "child-ballads": "traditional ballads credited to the collector, F. J. Child",
    "bell-ancient-poems": "traditional ballads credited to the collector, Robert Bell",
}

# Poems the cleaner cut that were then read in full and match the standard text.
VERIFICADOS = {
    ("John Milton", "Lycidas"),  # 193 lines; only the edition's headnote was cut
}

# Books by two poets that Laurel credits to one. (slug, positions) -> real author.
AUTOR_A_MANO = [
    # Denham's poems start at Cooper's Hill (Gutenberg #12322, "DENHAM'S POETICAL WORKS").
    ("waller-denham", range(122, 1000), "John Denham"),
    # Coleridge's four poems in the 1798 Lyrical Ballads: the Ancyent Marinere
    # (seven parts), The Foster-Mother's Tale, The Nightingale, The Dungeon.
    ("lyrical-ballads", [0, 1, 2, 3, 4, 5, 6, 7, 8, 16], "Samuel Taylor Coleridge"),
]


def autor_corregido(p):
    libro, pos = p["id"].split(":")[0], int(p["id"].split(":")[1].split(".")[0])
    return next((autor for l, posiciones, autor in AUTOR_A_MANO if l == libro and pos in posiciones), p["author"])


def de_romano(s):
    valores = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100}
    total = 0
    for a, b in zip(s, s[1:] + " "):
        total += -valores[a] if b != " " and valores[a] < valores[b] else valores[a]
    return total


def rangos_childe_harold(poemas):
    """Laurel titles each group of Childe Harold stanzas by its last stanza only:
    "Canto I III" holds stanzas I-III. A group starts one after the previous
    group of the same canto; checked against the stanza numbers in Gutenberg
    #5131 for all 164 groups. Two are one stanza plus a song ("Good Night")."""
    anterior = {}
    for p in poemas:
        m = re.match(r"^Canto ([IV]+) ([IVXLC]+)$", p["title"])
        if not p["id"].startswith("byron-childe-harold:") or not m:
            continue
        canto, fin = m.group(1), de_romano(m.group(2))
        inicio = anterior.get(canto, 0) + 1
        anterior[canto] = fin
        estrofas = "Stanza %s" % to_roman(fin) if inicio == fin else "Stanzas %s–%s" % (to_roman(inicio), to_roman(fin))
        p["title"] = "Childe Harold's Pilgrimage: Canto %s, %s" % (canto, estrofas)


def normalizar(s):
    s = unicodedata.normalize("NFKD", s).lower()
    s = s.replace("’", "'").replace("‘", "'").replace("'", "")
    s = re.sub(r"[^a-z0-9 ]+", " ", s)
    return re.sub(r"\s+", " ", s).strip()


def libros_propios(poemas, carpeta):
    """Replace Laurel's entries for each book parser/extraer.py split, with that book's
    sections in the same shape. Laurel's metre tag, which limpiar.py takes as a hint, is
    carried over by first line. A section Laurel doesn't have gets none, which makes the
    cleaner stricter: in annotated editions such sections are often the editor's notes
    and early versions (Tennyson's "The Eagle" in 22 lines)."""
    salidas = {f.stem: f for f in sorted(Path(carpeta).glob("*.json"))}
    plantilla, metro = {}, {}
    for p in poemas:
        libro = p["id"].split(":")[0]
        if libro in salidas:
            plantilla.setdefault(libro, p)
            metro[(libro, normalizar(p["stanzas"][0][0]))] = p["metre"]
    salida = [p for p in poemas if p["id"].split(":")[0] not in salidas]
    for libro, ruta in salidas.items():
        if libro not in plantilla:
            continue
        secciones = json.loads(ruta.read_text(encoding="utf-8"))["sections"]
        for pos, s in enumerate(x for x in secciones if not x.get("prose")):
            estrofas = [e for e in ([l.strip() for l in e if l.strip()] for e in s["stanzas"]) if e]
            if not estrofas:
                continue
            for sub, (titulo, ests) in enumerate(split_sequences(s["title"], estrofas)):
                n = sum(len(e) for e in ests)
                salida.append(dict(plantilla[libro], id="%s:%d.%d" % (libro, pos, sub), title=titulo,
                                   first_line=ests[0][0], line_count=n, stanza_count=len(ests), stanzas=ests,
                                   text="\n\n".join("\n".join(e) for e in ests),
                                   form="sonnet" if is_sonnet(ests) else "other",
                                   metre=metro.get((libro, normalizar(ests[0][0])))))
    return salida, len(salidas)


def es_canon(autor):
    return any(p.lower() in autor.lower() for p in PRIORITY_POETS)


def escribir_limpieza(ruta, libros, fuera, informe):
    """libros: {slug: poems}; fuera: {reason: [poem]}; informe: [(poem, dropped whole, cuts)]."""
    lineas = ["# Cleaning report", "",
              "Generated by `seleccionar.py` from `limpiar.py`. Check it after every rebuild.", "",
              "## Books left out", "", "| Book | Poems | Why |", "|---|---:|---|"]
    lineas += ["| %s | %d | %s |" % (b, n, LIBROS_EXCLUIDOS[b]) for b, n in sorted(libros.items())]
    for motivo, ps in fuera.items():
        lineas += ["", "## %s (%d)" % (motivo, len(ps)), ""]
        lineas += ["* %s — %s" % (p["author"], p["title"]) for p in sorted(ps, key=lambda p: (p["author"], p["title"]))]
    lineas += ["", "## What the cleaner cut", ""]
    for p, entero, descartes in sorted(informe, key=lambda x: (x[0]["author"], x[0]["title"])):
        lineas.append("### %s — %s%s" % (p["author"], p["title"], " (whole poem dropped)" if entero else ""))
        lineas.append("")
        for motivo, texto, donde in descartes:
            lineas.append("*%s, %s:* %s" % (motivo, donde, texto[:300].replace("\n", " / ")))
            lineas.append("")
    Path(ruta).write_text("\n".join(lineas), encoding="utf-8")


def es_famoso(estrofas):
    """In laurel_convert.MUST_HAVE: kept even when the cleaner had to cut it."""
    inicio = normalizar(" ".join(estrofas[0][:2]))
    return any(normalizar(v) in inicio for _, frase in MUST_HAVE for v in frase.split("|"))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--poems", required=True)
    ap.add_argument("--asset", required=True)
    ap.add_argument("--report", required=True)
    ap.add_argument("--cleaning-report", default=str(AQUI / "limpieza.md"), help="what limpiar.py dropped")
    ap.add_argument("--top-authors", type=int, default=0, help="keep only the N best-ranked authors (0 = all)")
    ap.add_argument("--max-lines", type=int, default=0, help="drop poems longer than this (0 = no cap)")
    ap.add_argument("--parser", default=str(AQUI / "corpus" / "parser-salida"),
                    help="parser/extraer.py output, used for the books it holds ('' = Laurel's split only)")
    args = ap.parse_args()

    vistas = json.loads((AQUI / "autores_vistas.json").read_text(encoding="utf-8"))
    poemas = [json.loads(l) for l in open(args.poems, encoding="utf-8")]
    if args.parser:
        if not Path(args.parser).is_dir():
            raise SystemExit("No %s: run `python3 parser/extraer.py` first (or pass --parser '')" % args.parser)
        poemas, n = libros_propios(poemas, args.parser)
        print("%d books split by parser/extraer.py" % n)
    libros = {}
    for p in poemas:
        libro = p["id"].split(":")[0]
        if libro in LIBROS_EXCLUIDOS:
            libros[libro] = libros.get(libro, 0) + 1
    poemas = [dict(p, author=autor_corregido(p)) for p in poemas if p["id"].split(":")[0] not in LIBROS_EXCLUIDOS]
    rangos_childe_harold(poemas)
    anadidos = json.loads((AQUI / "anadidos_gutenberg.json").read_text(encoding="utf-8"))
    reemplazos = {(a["autor"], normalizar(a["texto"].split("\n")[0])) for a in anadidos if a.get("reemplaza")}
    poemas = [p for p in poemas if (p["author"], normalizar(p["stanzas"][0][0])) not in reemplazos]
    for a in anadidos:
        estrofas = [e.split("\n") for e in a["texto"].split("\n\n")]
        poemas.append({"title": a["titulo"], "author": a["autor"], "text": a["texto"],
                       "stanzas": estrofas, "line_count": sum(len(e) for e in estrofas)})

    # Better to leave a poem out than to show a damaged one. Held back:
    #  * any poem the cleaner had to cut, unless it is in MUST_HAVE or was checked
    #    by hand (VERIFICADOS). Cutting a note rarely leaves the rest clean: the
    #    annotated editions leave fragments behind, or print early versions after
    #    the poem (Wordsworth's 9-line "My Heart Leaps Up" came out at 48 lines);
    #  * sections still titled only "Canto IV";
    #  * poems whose source broke long lines in two.
    # Additions from Gutenberg were checked by hand and skip all three.
    continuaciones = {libro: gutenberg.continuaciones(ebook, regla)
                      for libro, (ebook, regla) in gutenberg.LIBROS.items()}
    unidas = 0
    limpios, informe_limpieza = [], []
    fuera = {"Cut by the cleaner": [], "Section title, work unknown": [], "Lines broken in two": []}
    for p in poemas:
        anadido = "work_title" not in p
        titulo, estrofas, descartes = limpiar_poema(
            p["title"], p["stanzas"], p.get("work_title"), p.get("source_edition"),
            con_metro=anadido or bool(p.get("metre")), autor=p["author"])
        if descartes:
            informe_limpieza.append((p, estrofas is None, descartes))
        if estrofas is None:
            continue
        libro = p.get("id", ":").split(":")[0]
        if libro in continuaciones:
            antes = sum(len(e) for e in estrofas)
            estrofas = gutenberg.unir(estrofas, continuaciones[libro])
            unidas += antes - sum(len(e) for e in estrofas)
        limpio = dict(p, title=titulo, stanzas=estrofas, text="\n\n".join("\n".join(e) for e in estrofas),
                      line_count=sum(len(e) for e in estrofas))
        if not anadido:
            if descartes and not es_famoso(estrofas) and (p["author"], titulo) not in VERIFICADOS:
                fuera["Cut by the cleaner"].append(limpio)
                continue
            if seccion_sin_obra(titulo):
                fuera["Section title, work unknown"].append(limpio)
                continue
            if lineas_partidas(estrofas) >= 2:
                fuera["Lines broken in two"].append(limpio)
                continue
        limpios.append(limpio)
    poemas = limpios
    escribir_limpieza(args.cleaning_report, libros, fuera, informe_limpieza)
    print("rejoined %d lines broken in two (gutenberg.py)" % unidas)
    print("left out: %d poems in %d books; %s" % (
        sum(libros.values()), len(libros), ", ".join("%s %d" % (k.lower(), len(v)) for k, v in fuera.items())))

    vistos, unicos, duplicados = set(), [], 0
    for p in poemas:
        clave = (p["author"], normalizar(p["stanzas"][0][0]))
        if clave in vistos:
            duplicados += 1
            continue
        vistos.add(clave)
        unicos.append(p)

    por_autor = {}
    for p in unicos:
        por_autor.setdefault(p["author"], []).append(p)

    def rango(autor):
        v = vistas.get(autor, {}).get("vistas_12m", 0)
        return (0 if es_canon(autor) else 1, -max(v, 0), autor)

    orden = sorted(por_autor, key=rango)
    if args.top_authors:
        orden = orden[: args.top_authors]

    salida, filas = [], []
    total_p = total_v = total_b = 0
    for i, autor in enumerate(orden, 1):
        ps = [p for p in por_autor[autor] if not args.max_lines or p["line_count"] <= args.max_lines]
        entradas = [{"titulo": p["title"], "autor": autor, "texto": p["text"]} for p in ps]
        salida += entradas
        b = sum(len(json.dumps(e, ensure_ascii=False).encode()) for e in entradas)
        v = sum(p["line_count"] for p in ps)
        total_p += len(ps); total_v += v; total_b += b
        filas.append("| %d | %s | %s | %s | %d | %d | %d | %.2f |" % (
            i, autor, "1" if es_canon(autor) else "2",
            format(vistas.get(autor, {}).get("vistas_12m", 0), ","),
            len(ps), sum(1 for p in ps if p["line_count"] > 60), total_p, total_b / 1e6))

    Path(args.asset).write_text(json.dumps(salida, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    ruta_version = Path(args.poems).parent / "corpus_version.json"
    version = json.loads(ruta_version.read_text(encoding="utf-8")) if ruta_version.exists() else None
    if version:
        linea_version = "Laurel corpus commit `%s` (%s): %s." % (version["commit"][:7], version["date"], version["subject"])
    else:
        linea_version = "Laurel corpus version unknown (%s not found, or the corpus was not a git clone)." % ruta_version.name

    informe = [
        "# English anthology: author ranking", "",
        linea_version, "",
        "Generated by `seleccionar.py`. Tier 1 = the canon in `PRIORITY_POETS`; within a tier, "
        "Wikipedia page views (Sep 2025 - Aug 2026). Every poem of each author, "
        + ("capped at %d verses." % args.max_lines if args.max_lines else "no length cap.") ,
        "",
        "**%d poems, %d authors, %s verses, %.2f MB** (%d duplicates dropped)." % (
            total_p, len(orden), format(total_v, ","), total_b / 1e6, duplicados),
        "",
        "| # | Author | Tier | Views | Poems | Over 60 verses | Running poems | Running MB |",
        "|---:|---|:-:|---:|---:|---:|---:|---:|",
    ] + filas + [""]
    Path(args.report).write_text("\n".join(informe), encoding="utf-8")
    print("%d poems, %d authors, %.2f MB, %d duplicates dropped" % (total_p, len(orden), total_b / 1e6, duplicados))


if __name__ == "__main__":
    main()
