"""Which source rule changes a book's split around a line: python3 parser/probar_reglas.py <book> <text>"""
import copy, json, sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import extraer, fuente
extraer.preparar([])
import catalog, generic, ingest
slug, texto = sys.argv[1], sys.argv[2]
b = {x["slug"]: x for x in json.loads((extraer.LAUREL / "data" / "library.json").read_text())}[slug]
q = {x[0]: x for x in catalog.QUERIES}[slug]
meta = {"title": q[2], "author": b["author"], "author_sort": b["author_sort"], "born": b["born"], "died": b["died"],
        "published": q[4], "blurb": q[3], "form": None, "scheme": None, "meter": None}
meta.update(copy.deepcopy(catalog.SLUG_META.get(slug, {})))
reglas = {
    "none": lambda L: L,
    "marcas": fuente.sin_marcas,
    "notas": fuente.sin_notas,
    "indice": lambda L: fuente.titulos_del_indice(L)[0],
    "all": lambda L: fuente.titulos_del_indice(fuente.sin_notas(fuente.sin_marcas(L)))[0],
}
for nombre, f in reglas.items():
    generic.load = lambda gid, f=f: f(ingest.load(gid))
    w = generic.parse_gutenberg(b["source"]["ebook"], slug, copy.deepcopy(meta))
    for s in w["sections"]:
        for k, st in enumerate(s["stanzas"]):
            if any(texto in l for l in st):
                print("%-7s %-40s stanza %d of %d" % (nombre, s["title"][:40], k, len(s["stanzas"])))
