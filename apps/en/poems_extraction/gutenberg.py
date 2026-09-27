#!/usr/bin/env python3
"""
gutenberg.py - rejoin verse lines that Project Gutenberg's plain text broke in two.

Gutenberg wraps its text files at about 70 characters, so a long line of verse
becomes two:

      O to draw you to me, to plant on you for the first time the lips of
          a determin'd man.

Laurel copied the text but dropped the indentation, so the second half looks
like a line of its own ("a determin'd man."). The Gutenberg file still shows
which lines are continuations, and seleccionar.py uses it to join them back.

The source files live in corpus/gutenberg/<ebook>.txt next to corpus/laurel-corpus;
`python3 gutenberg.py` downloads any that are missing.

A continuation is recognised in one of two ways, chosen per book in LIBROS
after checking its layout:

  "sangria"  the continuation is indented deeper than the line it continues,
             and starts in lower case (poets here begin every line with a
             capital). Whitman's edition also indents capitalised continuations
             exactly 6 spaces under a 2-space line ("... the valley of the /
             Mississippi"), except after a line that ends a sentence, where the
             indent is his own ("... grim and daring; / But O heart!").
  "estricta" as "sangria", but the continuation must start with a lower-case
             letter: in these books a line opening with a quotation mark or a
             bracket is a line of the poem ('"It beats!"--Away, thou dreamer!').
  "ancho-estricto"  no indent either, and poets who open lines with quotation
             marks: a line of 55 characters or more (not counting its indent) followed by one starting
             with a lower-case letter.
  "ancho"    the edition does not indent continuations, so a line that reached
             the wrap width followed by one starting in lower case is joined.
"""
import re
import sys
import unicodedata
import urllib.request
from pathlib import Path

AQUI = Path(__file__).resolve().parent
CARPETA = AQUI / "corpus" / "gutenberg"

# Laurel book -> (Gutenberg ebook, rule). Each was checked: the joins read as
# whole lines, and poems indented on purpose ("Eidolons", "O Captain!") are untouched.
LIBROS = {
    "whitman-leaves": (1322, "sangria"),
    "hopkins-poems": (22403, "sangria"),
    "swinburne-poems-ballads": (18726, "sangria"),
    "hemans-poems": (66785, "sangria"),
    "riley-farm-rhymes": (4783, "sangria"),
    "browning-selections": (28041, "sangria"),
    "hood-poems": (56712, "sangria"),
    "hood-poetical-works": (15652, "sangria"),
    "stedman-poems": (70763, "sangria"),
    "barrett-browning-poems-2": (33363, "sangria"),
    "thackeray-ballads": (2732, "sangria"),
    "lowell-amy-sword-blades": (1020, "sangria"),
    "lowell-james-russell-poems": (38520, "sangria"),
    "dowson-poems": (8497, "sangria"),
    "poe-poems": (79019, "sangria"),
    "longfellow-christus": (1365, "ancho"),
    "whittier-anti-slavery": (9580, "ancho"),
    "procter-legends-lyrics": (2304, "ancho"),
    "meredith-poems": (1381, "ancho"),
    # Checked 2026-09-27, every join inside a poem read: the stricter rules, since these
    # poets open lines with quotation marks and brackets.
    "byron-works-3": (21811, "estricta"),
    "donne-poems": (48688, "estricta"),
    "dunbar-poems": (18338, "estricta"),
    "keats-1820": (23684, "estricta"),
    "morris-defence-guenevere": (22650, "estricta"),
    "thomas-edward-poems": (22423, "estricta"),
    "seeger-poems": (617, "estricta"),
    "lowell-amy-men-women-ghosts": (841, "estricta"),
    "field-poems": (36150, "estricta"),
    "campbell-poems": (59788, "estricta"),
    "rosenberg-poems": (66889, "estricta"),
    "carleton-farm-ballads": (9500, "ancho-estricto"),
    "crawford-poems": (6815, "estricta"),
    "longfellow-poems": (1365, "ancho-estricto"),
    "tennyson-early-poems": (8601, "ancho-estricto"),
    "henley-poems": (1568, "ancho-estricto"),
    "milton-minor-poems": (397, "ancho-estricto"),
}

ANCHO = 60  # a line this long (with its indent) may have been wrapped
ANCHO_SIN_INDENTAR = 55  # "ancho-estricto": measured without the indent, which in a play is
                         # where a line shared between speakers goes ("SPIR. Care and utmost")
ANCHO_SIN_SANGRIA = 45  # Whittier's edition wraps shorter; lower case is the real signal there
FIN = re.compile(r"END OF TH[EI]S? PROJECT GUTENBERG")


def normalizar(s):
    s = re.sub(r"\s{2,}\d+\s*$", "", s)  # Browning's margin line numbers: "were       5"
    s = unicodedata.normalize("NFKD", s).lower().replace("’", "'")
    return re.sub(r"[^a-z0-9]+", "", s)


def sangria(linea):
    return len(linea) - len(linea.lstrip(" "))


def ruta(ebook):
    return CARPETA / ("%d.txt" % ebook)


def descargar(ebook):
    """Download an ebook's plain text, resuming until the end marker arrives:
    Gutenberg sometimes cuts a download short."""
    destino = ruta(ebook)
    CARPETA.mkdir(parents=True, exist_ok=True)
    url = "https://www.gutenberg.org/cache/epub/%d/pg%d.txt" % (ebook, ebook)
    for _ in range(5):
        if destino.exists() and FIN.search(destino.read_text(encoding="utf-8", errors="replace")):
            return destino
        tiene = destino.stat().st_size if destino.exists() else 0
        peticion = urllib.request.Request(url, headers={"Range": "bytes=%d-" % tiene} if tiene else {})
        with urllib.request.urlopen(peticion, timeout=90) as r, open(destino, "ab") as f:
            f.write(r.read())
    sys.exit("Could not download Gutenberg #%d completely" % ebook)


def continuaciones(ebook, regla):
    """Pairs (line, next line), normalised, where the next line continues the first."""
    if not ruta(ebook).exists():
        sys.exit("Missing %s: run `python3 gutenberg.py` to download it" % ruta(ebook))
    lineas = [l.rstrip() for l in ruta(ebook).read_text(encoding="utf-8").splitlines()]
    pares = set()
    for previa, linea in zip(lineas, lineas[1:]):
        if not previa.strip() or not linea.strip():
            continue
        if linea.strip().upper() == linea.strip():
            continue  # a line in capitals is a line of its own (Thackeray's "KILL ALL THE FRIARS!")
        inicio = linea.strip().lstrip("_")   # italics: Hemans's "_they_ seem,"
        minuscula = re.match(r"[a-z(\"'‘“\-]", inicio)
        if regla in ("estricta", "ancho-estricto"):
            minuscula = re.match(r"[a-z]", inicio)
        previa_sin_numero = re.sub(r"\s{2,}\d+$", "", previa)
        if regla in ("sangria", "estricta"):
            if sangria(linea) < sangria(previa):
                continue
            if sangria(linea) == sangria(previa):  # broken twice: "... the / continental / blood"
                ok = minuscula and sangria(linea) > 4 and len(previa_sin_numero) >= ANCHO
            else:
                ok = (minuscula and len(previa_sin_numero) >= 50) or (
                    regla == "sangria" and sangria(linea) == 6 and sangria(previa) == 2
                    and not re.search(r"[;.!?]$", previa))
        elif regla == "ancho-estricto":
            ok = minuscula and len(previa_sin_numero.strip()) >= ANCHO_SIN_INDENTAR
        else:
            ok = minuscula and len(previa_sin_numero) >= ANCHO_SIN_SANGRIA
        if ok:
            # without note marks, which the parser drops: Byron's "so fast,[ni]"
            sin_marca = lambda l: normalizar(re.sub(r"\[[^\]]{1,8}\]", "", l))
            pares.add((sin_marca(previa), sin_marca(linea)))
    return pares


# Long lines broken in two that no rule can find, each checked in its source (2026-09-27):
# Whitman's edition sets these continuations at the verse's own indent; the others are
# in books whose layout rule would join lines that are not broken, or not in our corpus.
UNIONES_A_MANO = [
    ("Here heed himself, unfold himself, (not others’ formulas heed,)", "here fill his time,"),
    ("And every day I, a curious boy, never too close, never disturbing", "them,"),
    ("To troops out of the war arising, they the tasks I have set", "promulging,"),
    ("You will not read the riddle, though you do the best you", "can do."),
    ("To form some Beauty by a new receipt, Jove sent, and found, far in a", "country scene,"),
    ("I mean, what no other mortal in the universe can boast of, your own", "spirit of pun, and own wit."),
    ("There was an Old Derry down Derry, who loved to see little folks", "merry;"),
    ("thrusting its flaming petals under and over one another like tortured", "snakes."),
    ("The waters closed—and when I shriek’d, I shriek’d below the", "foam!"),
    ("The fair starrs fill their wakefull fires, the sun him-", "self drinks day."),
]
PARES_A_MANO = {(normalizar(a), normalizar(b)) for a, b in UNIONES_A_MANO}


def unir(estrofas, pares):
    """Join each line the source shows as a continuation onto the line before.
    A line broken at a hyphen ("ever- / lastingness") joins without a space."""
    salida = []
    for estrofa in estrofas:
        nueva, ultima = [], None
        for linea in estrofa:
            clave = normalizar(linea)
            if nueva and (ultima, clave) in pares:
                sep = "" if re.search(r"[A-Za-z]-$", nueva[-1]) else " "
                nueva[-1] += sep + linea.strip()
            else:
                nueva.append(linea)
            ultima = clave
        salida.append(nueva)
    return salida


if __name__ == "__main__":
    for libro, (ebook, _) in LIBROS.items():
        print("%-28s #%-6d %s" % (libro, ebook, descargar(ebook)))
