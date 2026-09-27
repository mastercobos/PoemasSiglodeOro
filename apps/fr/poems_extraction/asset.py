"""Turns poemas_fr.json into the split anthology the app loads.

    python3 asset.py                      # writes ../assets/poemas/
    python3 asset.py --asset some/folder

Same layout and chunking as the English pipeline (apps/en/poems_extraction/
seleccionar.py, escribir_dividido): indice.json holds the title, author number
and first line of every poem, and the texts go in chunks of about TROZO bytes
in textos/<n>.json. Only the index is read at startup.

The app derives each poem's id from author, title and the first verse given
here (Poema._idDerivado; see primera_linea). Once the app ships, favourites
and notifications persist those ids: changing a title or a first verse then
orphans them.
"""

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

AQUI = Path(__file__).parent
TROZO = 150_000  # bytes of text per chunk: opening a poem decodes one chunk


# A stanza that is only a section mark: numeral, asterism or row of dots.
# Same pattern as esMarcaDeSeccion in poemario_core (versos_sangrados.dart).
MARCA = re.compile(r"^\s*([IVXLCDM]+\.?|\d+\.?|[*∗⁂](\s*[*∗])*|[-—–_.\s]{3,})\s*$")


def primera_linea(texto):
    """The first verse, untrimmed: the first line with something on it,
    skipping a leading stanza that is only a section mark ("I" before part
    one of a poem). The app trims it to derive the poem's id and shows it as
    the first verse, so once the app ships this must not change."""
    for estrofa in re.split(r"\n\s*\n", texto):
        lineas = [l for l in estrofa.split("\n") if l.strip()]
        if not lineas or (len(lineas) == 1 and MARCA.match(lineas[0])):
            continue
        return lineas[0]
    return next((l for l in texto.split("\n") if l.strip()), "")


def comprobar(poemas):
    """Refuses what the app would choke on: empty texts, and poems whose
    (author, title, first line) repeat, since they would share an id."""
    vacios = [p["titulo"] for p in poemas if not p["texto"].strip()]
    if vacios:
        sys.exit("Poems with no text: %s" % vacios[:10])
    claves = Counter((p["autor"].lower(), p["titulo"].lower(),
                      primera_linea(p["texto"]).strip().lower()) for p in poemas)
    repetidos = [k for k, n in claves.items() if n > 1]
    if repetidos:
        sys.exit("Poems that would share an id: %s" % repetidos[:10])


def escribir_dividido(poemas, carpeta):
    carpeta.mkdir(parents=True, exist_ok=True)
    textos = carpeta / "textos"
    textos.mkdir(exist_ok=True)
    for viejo in textos.glob("*.json"):
        viejo.unlink()
    autores, filas, inicios, trozo, tam = [], [], [], [], 0
    numero = {}
    def cerrar():
        (textos / ("%d.json" % (len(inicios) - 1))).write_text(
            json.dumps(trozo, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    for i, p in enumerate(poemas):
        if p["autor"] not in numero:
            numero[p["autor"]] = len(autores)
            autores.append(p["autor"])
        filas.append([p["titulo"], numero[p["autor"]], primera_linea(p["texto"])])
        if not inicios or tam >= TROZO:
            if inicios:
                cerrar()
            inicios.append(i)
            trozo, tam = [], 0
        trozo.append(p["texto"])
        tam += len(p["texto"].encode("utf-8"))
    cerrar()
    (carpeta / "indice.json").write_text(json.dumps(
        {"textos": "textos", "inicios": inicios, "autores": autores, "poemas": filas},
        ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    return len(inicios)


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--entrada", default=AQUI / "poemas_fr.json", type=Path)
    ap.add_argument("--asset", default=AQUI.parent / "assets" / "poemas", type=Path)
    args = ap.parse_args()
    poemas = json.loads(args.entrada.read_text(encoding="utf-8"))
    comprobar(poemas)
    trozos = escribir_dividido(poemas, args.asset)
    print("%d poems, %d authors, %d chunks -> %s" % (
        len(poemas), len({p["autor"] for p in poemas}), trozos, args.asset))


if __name__ == "__main__":
    main()
