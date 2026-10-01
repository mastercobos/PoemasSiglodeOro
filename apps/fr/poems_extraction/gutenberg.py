#!/usr/bin/env python3
"""
gutenberg.py - poems from Project Gutenberg plain-text books, for what
Wikisource cannot give yet (collections whose scans are not proofread).

  python3 gutenberg.py        # downloads into corpus/gutenberg/, writes gutenberg_fr.json

wikisource.py reads gutenberg_fr.json and merges it after its own poems of the
same collection; a poem it already has (same author and first line) keeps the
Wikisource copy, so these only fill gaps.

Each book: the Gutenberg header and footer are stripped, then the stretch
between two markers is split into poems by one of two layouts:

  majuscules  a poem starts at a title line in capitals ("LA CONSCIENCE");
              a capitals line straight after another, or after a numeral, is
              a section heading above it; a numeral inside a poem is a part
              number and stays. Hugo's Hetzel-Quantin edition.
  numeros     untitled poems, each under an indented numeral (Sagesse).

The transcribers' conventions are undone: _italics_ markers, and the oe/ae
ligature they flattened, restored only in words where French always writes
it (coeur -> cœur). Spelling is otherwise left as the file has it.
"""
import json
import re
import time
import urllib.request
from pathlib import Path

AQUI = Path(__file__).resolve().parent
DOSSIER = AQUI / 'corpus' / 'gutenberg'
UA = {'User-Agent': 'PoemarioFR/0.1 (poetry anthology corpus builder; python urllib)'}

LIVRES = [
    {'id': 15112, 'autor': 'Paul Verlaine', 'recueil': 'Sagesse', 'edition': 'Vanier (Gutenberg #15112)',
     'debut': r'^SAGESSE$', 'fin': r'^JADIS ET NAGUÈRE$', 'mise_en_page': 'numeros'},
] + [
    {'id': n, 'autor': 'Victor Hugo', 'recueil': 'La Légende des siècles',
     'edition': f'Hetzel-Quantin, édition définitive, tome {t} (Gutenberg #{n})',
     'debut': r'^\s*A LA FRANCE$' if t == 'I' else r'^\s*LA LÉGENDE DES SIÈCLES$',
     'fin': r'^\s*(NOTES?|TABLE|TABLE DES MATIÈRES)\s*$', 'mise_en_page': 'majuscules'}
    for n, t in ((72885, 'I'), (76396, 'II'), (76638, 'III'), (76907, 'IV'))
]

LIGATURES = {
    'coeur': 'cœur', 'coeurs': 'cœurs', 'soeur': 'sœur', 'soeurs': 'sœurs', 'oeil': 'œil',
    'oeillet': 'œillet', 'oeillets': 'œillets', 'oeuvre': 'œuvre', 'oeuvres': 'œuvres',
    'voeu': 'vœu', 'voeux': 'vœux', 'noeud': 'nœud', 'noeuds': 'nœuds', 'boeuf': 'bœuf',
    'boeufs': 'bœufs', 'moeurs': 'mœurs', 'oeuf': 'œuf', 'oeufs': 'œufs', 'choeur': 'chœur',
    'choeurs': 'chœurs', 'manoeuvre': 'manœuvre', 'rancoeur': 'rancœur', 'oedipe': 'Œdipe',
}


def telecharger(n):
    fichier = DOSSIER / f'pg{n}.txt'
    if not fichier.exists():
        DOSSIER.mkdir(parents=True, exist_ok=True)
        req = urllib.request.Request(f'https://www.gutenberg.org/cache/epub/{n}/pg{n}.txt', headers=UA)
        fichier.write_bytes(urllib.request.urlopen(req, timeout=300).read())
        time.sleep(2)
    return fichier.read_text(encoding='utf-8')


def corps(texte):
    """The book without Gutenberg's header and licence."""
    debut = re.search(r'^\*\*\* ?START OF.*$', texte, re.M)
    fin = re.search(r'^\*\*\* ?END OF.*$', texte, re.M)
    return texte[debut.end() if debut else 0:fin.start() if fin else len(texte)]


def ligatures(ligne):
    def rempl(m):
        w = m.group(0)
        r = LIGATURES.get(w.lower())
        if not r:
            return w
        return r[0].upper() + r[1:] if w[0].isupper() else r
    return re.sub(r"[A-Za-z]+", rempl, ligne)


def nettoyer(lignes):
    sortie = []
    for l in lignes:
        l = re.sub(r'_([^_]+)_', r'\1', l).replace('_', '')
        l = re.sub(r'\[Illustration[^\]]*\]', '', l)
        if re.fullmatch(r'\s*--.*\bVoir\b.*--\s*', l):
            continue  # the editor's cross-reference, "--_Voir page 7._--"
        sortie.append(ligatures(l.strip()))
    texte = re.sub(r'\n{3,}', '\n\n', '\n'.join(sortie)).strip('\n')
    return texte


NUMERAL = re.compile(r'\s*[IVXLC]+\.?\s*')


def est_majuscules(l):
    l = l.strip()
    return (len(l) > 2 and any(c.isalpha() for c in l) and l == l.upper()
            and not NUMERAL.fullmatch(l) and not l.startswith('['))


def decouper_majuscules(lignes):
    """[(title, lines)]: see the module docstring."""
    poemes = []
    titre, courant = None, []
    precedent = None  # the last non-blank line's kind: 'titre', 'numero', 'vers'
    for l in lignes:
        s = l.strip()
        if not s:
            if courant:
                courant.append('')
            continue
        if est_majuscules(s) and s.startswith('(') and precedent == 'titre':
            continue  # a subtitle: "(GARDE IMPÉRIALE SUISSE)"
        if est_majuscules(s) and s.endswith('.') and titre:
            # Who speaks next in a dialogue ("LE CHŒUR.", "L'HOMME."): titles
            # in this edition have no full stop. Its own stanza.
            courant += ['', s, '']
            precedent = 'vers'
            continue
        if est_majuscules(s):
            if precedent in ('titre', 'numero') and not any(x for x in courant if x and not NUMERAL.fullmatch(x)):
                titre, courant = s, []  # the line above was a section heading
            else:
                if titre and courant:
                    poemes.append((titre, courant))
                titre, courant = s, []
            precedent = 'titre'
            continue
        if NUMERAL.fullmatch(s):
            precedent = 'numero'
            if titre and any(x and not NUMERAL.fullmatch(x) for x in courant):
                courant.append(s)  # a part of the current poem
            continue
        courant.append(s)
        precedent = 'vers'
    if titre and courant:
        poemes.append((titre, courant))
    return poemes


def decouper_numeros(lignes):
    """[(None, lines)] for untitled poems each under an indented numeral."""
    poemes, courant = [], []
    for l in lignes:
        if NUMERAL.fullmatch(l) and l.startswith('    '):
            if any(x.strip() for x in courant):
                poemes.append((None, courant))
            courant = []
            continue
        courant.append(l)
    if any(x.strip() for x in courant):
        poemes.append((None, courant))
    return poemes


def livre(l):
    texte = corps(telecharger(l['id'])).replace('\r', '')
    lignes = texte.split('\n')
    debut = next(i for i, x in enumerate(lignes) if re.match(l['debut'], x.strip() if l['mise_en_page'] == 'numeros' else x))
    fin = next((i for i, x in enumerate(lignes[debut + 1:], debut + 1) if re.match(l['fin'], x)), len(lignes))
    lignes = lignes[debut + 1:fin]
    decoupe = decouper_numeros(lignes) if l['mise_en_page'] == 'numeros' else decouper_majuscules(lignes)
    poemes = []
    for titre, vers in decoupe:
        texte = nettoyer(vers)
        if sum(1 for x in texte.split('\n') if x.strip()) < 3:
            continue
        poemes.append({
            'autor': l['autor'],
            'titulo': titre or '',  # untitled: wikisource.finaliser names it by its first line
            'recueil': l['recueil'],
            'sections': [],
            'texto': texte,
            'fuente': 'gutenberg',
            'edition': l['edition'],
            'url': f"https://www.gutenberg.org/ebooks/{l['id']}",
        })
    return poemes


def main():
    tous = []
    for l in LIVRES:
        p = livre(l)
        print(f"{l['autor']} - {l['recueil']} #{l['id']}: {len(p)}")
        tous += p
    (AQUI / 'gutenberg_fr.json').write_text(json.dumps(tous, ensure_ascii=False, indent=1) + '\n')


if __name__ == '__main__':
    main()
