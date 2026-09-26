"""Find sections of an extraer.py book by a line they contain: python3 parser/buscar.py <book> <text> [...]"""
import json, sys
from pathlib import Path
w = json.loads((Path(__file__).resolve().parent.parent / "corpus" / "parser-salida" / (sys.argv[1] + ".json")).read_text())["sections"]
for texto in sys.argv[2:]:
    for i, s in enumerate(w):
        for k, st in enumerate(s["stanzas"]):
            if any(texto.lower() in l.lower() for l in st):
                print("[%d] %s | %r | stanza %d of %d | first: %s | last: %s" % (i, s["id"], s["title"], k, len(s["stanzas"]), s["stanzas"][0][0][:40], s["stanzas"][-1][-1][:40]))
    print("--", texto)
