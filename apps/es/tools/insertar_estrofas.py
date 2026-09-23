"""Insert stanza breaks into the Spanish anthology.

1.0.7 drew breaks after verses 4, 8 and 11 of every poem at render time; the
core now takes stanzas from blank lines in the data, and this file had none.
Idempotent: existing blank lines are removed first.
"""
import json, sys

RUTA = sys.argv[1]
# Poems whose shape isn't a plain sonnet (+ estrambote), keyed by
# (author, first verse) -> verse numbers after which a stanza ends. Worked out from
# the rhymes; see logs.md, 2026-09-23.
EXCEPCIONES = {
    # 13 verses, one missing from the second quatrain (4/3/3/3).
    ('Garcilaso de La Vega', 'De aquella vista pura y excelente'): [4, 7, 10],
    ('Francisco de Figueroa', 'Bendito seas, Amor, perpetuamente,'): [4, 7, 10],
    # A four-verse copla introducing the sonnet.
    ('Luis de Ulloa y Pereira', 'Científico Apolo nuestro'): [4, 8, 12, 15],
    # Estrambote in two parts.
    ('Baltasar del Alcázar', 'Haz un soneto que levante el vuelo'): [4, 8, 11, 14, 17],
    ('Juan de Salinas', 'Ciego rapaz de las doradas hebras,'): [4, 8, 11, 14, 17],
    ('Quevedo', 'Quien quisiere ser culto en sólo un día'): [4, 8, 11, 14, 18],
}

def cortes(n):
    if n >= 14: return [4, 8, 11, 14]
    if n >= 12: return [4, 8, 11]  # sonnet missing its last verse(s)
    if n >= 9: return [4, 8]       # two quatrains and one tercet
    return [4]

d = json.load(open(RUTA, encoding='utf-8'))
usadas = set()
for p in d:
    versos = [l for l in p['texto'].split('\n') if l.strip()]
    clave = (p['autor'], versos[0].strip() if versos else '')
    if clave in EXCEPCIONES:
        usadas.add(clave)
    c = set(EXCEPCIONES.get(clave) or cortes(len(versos)))
    salida = []
    for i, v in enumerate(versos, 1):
        salida.append(v)
        if i in c and i < len(versos):
            salida.append('')
    p['texto'] = '\n'.join(salida)
faltan = set(EXCEPCIONES) - usadas
assert not faltan, faltan
open(RUTA, 'w', encoding='utf-8').write(json.dumps(d, indent=2, ensure_ascii=False) + '\n')
