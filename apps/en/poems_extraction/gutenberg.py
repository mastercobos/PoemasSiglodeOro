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
}

ANCHO = 60  # a line this long (with its indent) may have been wrapped
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
        minuscula = re.match(r"[a-z(\"'‘“\-]", linea.strip())
        previa_sin_numero = re.sub(r"\s{2,}\d+$", "", previa)
        if regla == "sangria":
            if sangria(linea) < sangria(previa):
                continue
            if sangria(linea) == sangria(previa):  # broken twice: "... the / continental / blood"
                ok = minuscula and sangria(linea) > 4 and len(previa_sin_numero) >= ANCHO
            else:
                ok = (minuscula and len(previa_sin_numero) >= 50) or (
                    sangria(linea) == 6 and sangria(previa) == 2 and not re.search(r"[;.!?]$", previa))
        else:
            ok = minuscula and len(previa_sin_numero) >= ANCHO_SIN_SANGRIA
        if ok:
            pares.add((normalizar(previa), normalizar(linea)))
    return pares


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
