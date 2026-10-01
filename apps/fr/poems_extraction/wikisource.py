#!/usr/bin/env python3
"""
wikisource.py - collect the French anthology's poems from fr.wikisource.org.

  python3 wikisource.py                 # crawl every collection in recueils.py
  python3 wikisource.py --auteur Baudelaire      # one author (substring match)
  python3 wikisource.py --page "Les Fleurs du mal (1868)/Allégorie"   # debug one page

Everything goes through the MediaWiki API (action=parse, action=query); the
rendered HTML it returns is read with a small stdlib DOM, no scraping of the
website. Responses are cached in corpus/cache/, so a rerun costs nothing and
the output can be rebuilt offline.

Authors come from recueils.AUTEURS. Each one's death date is checked on
Wikidata (via the author's Wikisource page, so the date and the texts belong
to the same person) and anyone who died in 1926 or later is refused - see
auteurs_verifies.json for what Wikidata said.

A collection is a Wikisource page. Its table of contents is followed to its
subpages, recursively through section pages, until a page holds verse
(div.poem). A page with several headed poems (Villon's Testament and its
ballades) is split at its headings. Only the verse is kept: headers, page
numbers, footnote markers, footnotes, editors' notes and prose are dropped.
Pages that hold no verse are listed in the report, never guessed at.

Spelling is kept exactly as the edition prints it (old spelling included).
Only the markup is normalised: one line per verse, a blank line between
stanzas, no trailing spaces, non-breaking spaces before ; : ! ? kept.

Output: poemas_fr.json (see README.md for the fields) and informe_wikisource.md.
"""
import argparse
import hashlib
import json
import re
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser
from pathlib import Path

from recueils import AUTEURS, CORRECTIONS, VERIFIES

AQUI = Path(__file__).resolve().parent
CACHE = AQUI / 'corpus' / 'cache'
API = 'https://fr.wikisource.org/w/api.php'
WIKIDATA = 'https://www.wikidata.org/w/api.php'
UA = {'User-Agent': 'PoemarioFR/0.1 (poetry anthology corpus builder; python urllib)'}
# Copyright. In France and the EU a work is free 70 years after its author's
# death, 100 for one "mort pour la France" (Apollinaire, Péguy): anyone who
# died in 1925 or earlier is free in 2026 either way. In the US what counts
# is publication: before 1931 is free, so a collection is taken only from an
# edition dated before 1931 (EDITION_LIMITE, read from Wikisource's header),
# unless recueils.py marks it as a later reprint of a text printed before
# then ('reimpression', with the reason). A modern edition of an old text
# (a critical edition, which establishes the text) is refused.
ANNEE_LIMITE = 1926
EDITION_LIMITE = 1931
# Wikisource proofreading level every scanned page of a poem must reach:
# 3 = proofread once, 4 = validated by a second person. Below that the text
# is raw OCR ("hélas 1" for "hélas !", line numbers glued to verses).
QUALITE_MINIMALE = 3


# --- API ---------------------------------------------------------------------

def _requete(url, params, post=False):
    """One API call. On 429/5xx waits as long as the server's Retry-After asks
    (Wikimedia throttles anonymous parse calls hard) and tries again."""
    for essai in range(12):
        try:
            donnees = urllib.parse.urlencode(params).encode() if post else None
            cible = url if post else url + '?' + urllib.parse.urlencode(params)
            req = urllib.request.Request(cible, data=donnees, headers=UA)
            reponse = json.load(urllib.request.urlopen(req, timeout=120))
            time.sleep(0.5)
            return reponse
        except urllib.error.HTTPError as e:
            if e.code in (429, 500, 502, 503, 504):
                attente = e.headers.get('Retry-After')
                time.sleep(int(attente) + 1 if attente and attente.isdigit() else min(60, 5 * (essai + 1)))
                continue
            raise
        except (urllib.error.URLError, TimeoutError):
            time.sleep(10)
    raise RuntimeError(f'API unreachable: {params.get("action")} {params.get("page", "")}')


def _fichier_cache(url, params):
    cle = hashlib.sha1((url + json.dumps(params, sort_keys=True)).encode()).hexdigest()
    return CACHE / f'{cle}.json'


def _get(url, params):
    """GET with an on-disk cache."""
    fichier = _fichier_cache(url, params)
    if fichier.exists():
        return json.loads(fichier.read_text())
    donnees = _requete(url, params)
    CACHE.mkdir(parents=True, exist_ok=True)
    fichier.write_text(json.dumps(donnees, ensure_ascii=False))
    return donnees


def _params_page(titre):
    return dict(action='parse', page=titre, prop='text', format='json', formatversion=2, redirects=1)


def page_html(titre):
    """(resolved title, rendered HTML) or (None, None) if the page is missing."""
    d = _get(API, _params_page(titre))
    if 'error' in d:
        return None, None
    return d['parse']['title'], d['parse']['text']


LOT = 20
MARQUE = 'ws-lot-poemario'


def precharger(titres):
    """Renders pages in batches and caches each as page_html() would.

    Throttling makes one call per poem take hours, so ~20 poem pages are
    transcluded into one parse call ({{:Title}} between marker divs) and the
    result is cut back apart. Titles are resolved first (redirects, missing
    pages), 50 per query. A transcluded page renders its relative links
    against the wrong page, so only pages with verse are cached this way:
    anything else (a section's table of contents, prose) is left for
    page_html() to fetch on its own.
    """
    a_faire = [t for t in dict.fromkeys(titres) if not _fichier_cache(API, _params_page(t)).exists()]
    resolus = {}
    for i in range(0, len(a_faire), 50):
        lot = a_faire[i:i + 50]
        d = _get(API, dict(action='query', titles='|'.join(lot), redirects=1, format='json', formatversion=2))
        q = d.get('query', {})
        renvois = {r['from']: r['to'] for r in q.get('normalized', []) + q.get('redirects', [])}
        manquants = {p['title'] for p in q.get('pages', []) if p.get('missing') or p.get('invalid')}
        for t in lot:
            fin = t
            while fin in renvois:
                fin = renvois[fin]
            if fin not in manquants:
                resolus[t] = fin
    elements = list(resolus.items())
    for i in range(0, len(elements), LOT):
        lot = elements[i:i + LOT]
        texte = '\n'.join(f'<div class="{MARQUE}" id="{MARQUE}-{j}"></div>\n{{{{:{fin}}}}}\n'
                           for j, (_, fin) in enumerate(lot))
        texte += f'<div class="{MARQUE}" id="{MARQUE}-fin"></div>'
        d = _requete(API, dict(action='parse', text=texte, prop='text', contentmodel='wikitext',
                               format='json', formatversion=2), post=True)
        html = d['parse']['text']
        morceaux = re.split(rf'<div class="{MARQUE}" id="{MARQUE}-(?:\d+|fin)"></div>', html)[1:]
        if len(morceaux) != len(lot) + 1:
            continue  # the markers did not survive; page_html() will fetch these one by one
        for (demande, fin), morceau in zip(lot, morceaux):
            if 'class="poem' not in morceau:
                continue
            CACHE.mkdir(parents=True, exist_ok=True)
            reponse = json.dumps({'parse': {'title': fin, 'text': morceau}}, ensure_ascii=False)
            _fichier_cache(API, _params_page(demande)).write_text(reponse)
            if fin != demande:
                _fichier_cache(API, _params_page(fin)).write_text(reponse)


QUALITES = CACHE / 'qualites.json'


def _qualites_en_cache():
    """Levels already known, per page: the file qualite_des_pages keeps, plus
    any proofread query cached before it existed. Batches are cached by their
    exact titles, so one poem more or less shifts every later batch; a cache
    per page keeps a rebuild offline."""
    if QUALITES.exists():
        return json.loads(QUALITES.read_text())
    connues = {}
    for f in CACHE.glob('*.json'):
        texte = f.read_text()
        if '"proofread"' not in texte[:20000]:
            continue
        q = json.loads(texte).get('query', {})
        noms = {n['to']: n['from'] for n in q.get('normalized', [])}
        for pg in q.get('pages', []):
            niveau = pg.get('proofread', {}).get('quality')
            if niveau is not None:
                connues[noms.get(pg['title'], pg['title'])] = niveau
                connues[pg['title']] = niveau
    return connues


def qualite_des_pages(pages):
    """Proofreading level of scanned pages, 50 per query: 0 without text,
    1 not proofread, 2 problematic, 3 proofread, 4 validated. Delete
    corpus/cache/qualites.json to pick up new proofreading."""
    qualite = _qualites_en_cache()
    pages = sorted(set(pages) - set(qualite))
    for i in range(0, len(pages), 50):
        d = _requete(API, dict(action='query', prop='proofread', titles='|'.join(pages[i:i + 50]),
                               format='json', formatversion=2), post=True)  # long titles: no GET
        q = d.get('query', {})
        noms = {n['to']: n['from'] for n in q.get('normalized', [])}
        for pg in q.get('pages', []):
            niveau = pg.get('proofread', {}).get('quality')
            if niveau is not None:
                qualite[noms.get(pg['title'], pg['title'])] = niveau
                qualite[pg['title']] = niveau
    CACHE.mkdir(parents=True, exist_ok=True)
    QUALITES.write_text(json.dumps(qualite, ensure_ascii=False))
    return qualite


def date_de_deces(page_auteur):
    """(Wikidata id, death year) of the person whose Wikisource page this is."""
    d = _get(WIKIDATA, dict(action='wbgetentities', sites='frwikisource', titles=page_auteur,
                            props='claims', format='json'))
    (qid, entite), = d['entities'].items()
    if 'missing' in entite:
        return None, None
    annees = []
    for c in entite['claims'].get('P570', []):
        t = c['mainsnak'].get('datavalue', {}).get('value', {}).get('time')
        if t:
            annees.append(int(t[1:5]) * (-1 if t[0] == '-' else 1))
    # Several claims (sources disagree on the day) - take the latest year, the
    # conservative choice for a copyright cut-off.
    return qid, max(annees) if annees else None


# --- a minimal DOM -------------------------------------------------------------

VIDES = {'br', 'img', 'hr', 'meta', 'link', 'input', 'wbr', 'source', 'col', 'area'}


class Noeud:
    __slots__ = ('tag', 'attrs', 'enfants', 'parent')

    def __init__(self, tag, attrs=None, parent=None):
        self.tag, self.attrs, self.enfants, self.parent = tag, dict(attrs or {}), [], parent

    @property
    def classes(self):
        return set((self.attrs.get('class') or '').split())

    def iter(self):
        yield self
        for e in self.enfants:
            if isinstance(e, Noeud):
                yield from e.iter()

    def texte(self):
        return ''.join(e if isinstance(e, str) else e.texte() for e in self.enfants)


class _Constructeur(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.racine = self.courant = Noeud('racine')

    def handle_starttag(self, tag, attrs):
        n = Noeud(tag, attrs, self.courant)
        self.courant.enfants.append(n)
        if tag not in VIDES:
            self.courant = n

    def handle_startendtag(self, tag, attrs):
        self.courant.enfants.append(Noeud(tag, attrs, self.courant))

    def handle_endtag(self, tag):
        n = self.courant
        while n is not None and n.tag != tag:
            n = n.parent
        if n is not None and n.parent is not None:
            self.courant = n.parent

    def handle_data(self, data):
        self.courant.enfants.append(data)


def dom(html):
    c = _Constructeur()
    c.feed(html)
    return c.racine


# --- cleaning ------------------------------------------------------------------

def _a_jeter(n):
    """Apparatus that is never part of a poem's text."""
    cl = n.classes
    if cl & {'ws-noexport', 'reference', 'references', 'mw-references-wrap',
             'mw-editsection', 'noprint', 'mw-cite-backlink', 'lettrine-texte-alt'}:
        return True
    if n.tag in ('style', 'script', 'sup'):
        return True  # a sup is a note call
    if 'visibility:hidden' in (n.attrs.get('style') or '').replace(' ', ''):
        # A verse split between two speakers: the first half repeated,
        # invisible, only to indent the second.
        return True
    if n.tag == 'table' and not any('poem' in e.classes for e in n.iter()):
        # Tables are navigation and tables of contents - except the
        # blockcenter layout, which wraps a poem in one.
        return True
    if n.attrs.get('id') in ('headertemplate', 'subheader', 'ws-data', 'toc'):
        return True
    return False


def _elaguer(n):
    n.enfants = [e for e in n.enfants if isinstance(e, str) or not _a_jeter(e)]
    for e in n.enfants:
        if isinstance(e, Noeud):
            _elaguer(e)


def _lignes_de(n, sauts_bruts=False):
    """Text of a poem block, with <br> as newlines and <p> as stanza breaks.
    With sauts_bruts, raw newlines in the text are line breaks too (verse
    transcribed without <poem>, where the HTML keeps the wikitext's lines)."""
    morceaux = []

    def visite(x):
        if isinstance(x, str):
            morceaux.append(x if sauts_bruts else x.replace('\n', ' '))
            return
        if x.tag == 'br':
            morceaux.append('\n')
            return
        if x.classes & {'pagenum', 'ws-pagenum'}:
            return
        bloc = x.tag in ('p', 'div', 'dd', 'dl', 'li', 'blockquote', 'center')
        if bloc:
            morceaux.append('\n\n')
        for e in x.enfants:
            visite(e)
        if bloc:
            morceaux.append('\n\n')

    visite(n)
    return ''.join(morceaux)


ESPACES = re.compile(r'[ \t         ]+')


def normaliser(texte):
    """One verse per line, one blank line between stanzas, spelling untouched."""
    texte = texte.replace('\r', '').replace('​', '').replace('﻿', '')
    lignes = []
    for l in texte.split('\n'):
        l = ESPACES.sub(' ', l)
        # Leading non-breaking spaces are indentation, meaningless once the app
        # lays the text out. Those inside a line (before ; : ! ?) are French
        # typography and stay.
        l = l.strip('   ')
        lignes.append(l)
    t = '\n'.join(lignes)
    t = re.sub(r'\n{3,}', '\n\n', t).strip('\n')
    return t


# --- extraction ----------------------------------------------------------------

TITRES = ('h1', 'h2', 'h3', 'h4', 'h5', 'h6')


def _titre_propre(t):
    t = normaliser(t if isinstance(t, str) else _lignes_de(t)).replace('\n', ' ')
    return re.sub(r'\s+', ' ', t).strip(' .')


SAUT = '\x0c'  # a page break of the printed edition, between two poem blocks


def recoudre(blocs):
    """Joins poem blocks, mending stanzas the printed page split in two.

    Each scanned page is its own poem block, so a stanza running over a page
    comes out as two stanzas. Nothing in the markup says so; the evidence is
    arithmetic: two fragments either side of a page break, each shorter than
    the poem's usual stanza, that add up to exactly that length (a huitain
    split 6 + 2). Anything else is left as printed.
    """
    strophes, sauts, noms = [], set(), set()
    for b in blocs:
        if b.startswith(SAUT):
            if strophes:
                sauts.add(len(strophes) - 1)
            continue
        if b.startswith(RUBRIQUE):
            noms.add(len(strophes))
            strophes.append([b[1:]])
            continue
        for st in normaliser(b).split('\n\n'):
            if st.strip():
                strophes.append(st.split('\n'))
    if not strophes:
        return ''
    if all(i in noms for i in range(len(strophes))):
        return ''  # a name with no verse
    tailles = [len(st) for i, st in enumerate(strophes) if i not in noms]
    if len(tailles) >= 3 and sauts:
        from collections import Counter
        mode, freq = Counter(tailles).most_common(1)[0]
        if mode > 1 and freq >= 2:
            sortie = []
            i = 0
            while i < len(strophes):
                st = strophes[i]
                if (i in sauts and i + 1 < len(strophes) and not {i, i + 1} & noms and len(st) < mode
                        and len(strophes[i + 1]) < mode and len(st) + len(strophes[i + 1]) == mode):
                    sortie.append(st + strophes[i + 1])
                    i += 2
                    continue
                sortie.append(st)
                i += 1
            strophes = sortie
    return '\n\n'.join('\n'.join(st) for st in strophes)


def _numero_centre(n):
    """The numeral of a centred block holding only a roman numeral."""
    if n.tag not in ('div', 'p') or 'poem' in n.classes:
        return None
    if 'text-align:center' not in (n.attrs.get('style') or '').replace(' ', ''):
        return None
    m = re.fullmatch(r'\s*([IVXLCDM]+)\.?\s*', n.texte())
    return m.group(1) if m else None


def _ancre_de_titre(n):
    """A centred title block carrying an anchor, the other way Wikisource
    heads a poem inside a longer page (the ballades of Villon's Testament).
    The anchor, not the printed capitals, gives the title."""
    if n.tag not in ('div', 'p') or 'poem' in n.classes:
        return None
    if 'text-align:center' not in (n.attrs.get('style') or '').replace(' ', ''):
        return None
    for e in n.enfants:
        if isinstance(e, Noeud) and e.tag == 'span' and e.attrs.get('id') and not e.texte().strip():
            titre = e.attrs['id'].replace('_', ' ').strip()
            if re.search(r'[a-zà-ÿ]{3}', titre):
                return titre[0].upper() + titre[1:]
    return None


def _titre_centre(n):
    """A centred block with bold or enlarged text: a printed poem title where
    the transcription used no heading (Mallarmé's 1899 Poésies)."""
    if n.tag not in ('div', 'p') or 'poem' in n.classes:
        return None
    if 'text-align:center' not in (n.attrs.get('style') or '').replace(' ', ''):
        return None
    if not any(isinstance(e, Noeud) and e.tag in ('b', 'big', 'strong') for e in n.iter() if e is not n):
        return None
    t = _titre_propre(n)
    return t if re.search(r'[^\W\d_]{2}', t) else None


RUBRIQUE = '\x0b'  # marks a speaker's name, a stanza of its own in the finished text


def _personnage(n):
    """The name of who speaks next in a dialogue poem, in capitals, as
    Wikisource's personnage template sets it above their verse (« LA SŒUR. »).
    Kept as a one-line stanza; the app draws it like a section numeral."""
    if n.tag not in ('div', 'p') or 'poem' in n.classes:
        return None
    if not any('personnage' in e.classes for e in n.iter()) or any('poem' in e.classes for e in n.iter()):
        return None
    t = re.sub(r'\s+', ' ', normaliser(_lignes_de(n))).strip()
    return t.upper() if re.search(r'[^\W\d_]{2}', t) else None


def _titre_simple(n):
    """A centred line outside the verse, in the plain layout of Guiffrey's
    Marot: a poem's title; "(De la Suyte)", the book it came from, is None;
    "Envoy" is returned as it is, for the caller to keep inside the poem."""
    if n.tag not in ('div', 'p') or 'poem' in n.classes or any('poem' in e.classes for e in n.iter()):
        return None
    if 'text-align:center' not in (n.attrs.get('style') or '').replace(' ', ''):
        return None
    t = _titre_propre(n)
    if not re.search(r'[^\W\d_]{2}', t) or re.fullmatch(r'[({].*[)}]', t):
        return None
    return t


def _vers_par_paragraphe(racine, avec_titre=True):
    """Verse set one line per paragraph, an empty paragraph between stanzas
    (Marot's Adolescence clémentine on Wikisource). Each heading (a numeral)
    starts a poem, and the paragraph under it is the poem's title, unless
    avec_titre is False (the Chansons, untitled)."""
    segs, page = [], [None]

    def visite(n):
        if isinstance(n, str):
            return
        if n.classes & {'pagenum', 'ws-pagenum'}:
            page[0] = n.attrs.get('title')
            return
        if n.tag in TITRES:
            segs.append([None, [], set()])
            return
        if n.tag == 'p' and segs:
            for e in n.iter():
                if e.classes & {'pagenum', 'ws-pagenum'} and e.attrs.get('title'):
                    page[0] = e.attrs['title']
            t = re.sub(r'\s+', ' ', normaliser(_lignes_de(n)).replace('\n', ' ')).strip()
            seg = segs[-1]
            if not t:
                if seg[1] and seg[1][-1]:
                    seg[1].append('')
            elif seg[0] is None and avec_titre and not seg[1]:
                seg[0] = t.strip(' .')
            else:
                seg[1].append(t)
                if page[0]:
                    seg[2].add(page[0])
            return
        for e in n.enfants:
            visite(e)

    visite(racine)
    return [(titre, '\n'.join(lignes).strip('\n'), sorted(pages))
            for titre, lignes, pages in segs if any(lignes)]


def _separateur(n):
    """An empty paragraph (only line breaks): the gap an edition leaves
    between two untitled poems. A page break has none."""
    return (n.tag == 'p' and not n.texte().strip()
            and any(isinstance(e, Noeud) and e.tag == 'br' for e in n.enfants))


def segments(racine, titres_centres=False, separer_blocs=False, reprise_numerotee=False,
             titres_simples=False, vers_par_paragraphe=False):
    """Headed segments of a page: [(heading or None, verse, scanned pages)].

    The scanned pages ("Page:….djvu/12") a segment's verse came from are
    recorded so its proofreading status can be checked (qualite_des_pages).

    With separer_blocs, an empty paragraph between poem blocks starts a new
    untitled segment; with titres_centres, a centred bold line is a heading
    and a centred numeral the next poem of a sequence; with reprise_numerotee,
    a centred numeral returns to the page's main poem (Villon's Testament);
    with titres_simples, any centred line is a heading (_titre_simple); with
    vers_par_paragraphe, see _vers_par_paragraphe.
    """
    _elaguer(racine)
    if vers_par_paragraphe:
        return _vers_par_paragraphe(racine, avec_titre=vers_par_paragraphe != 'sans_titre')
    segs = [[None, [], set()]]
    courant = [0]
    page = [None]

    def a_du_vers(i):
        return any(not x.startswith(SAUT) for x in segs[i][1])

    def nouveau(titre):
        segs.append([titre, [], set()])
        courant[0] = len(segs) - 1

    def visite(n):
        if isinstance(n, str):
            return
        if separer_blocs and _separateur(n):
            if a_du_vers(courant[0]):
                nouveau(None)
            return
        if titres_simples and n.tag in ('div', 'p') and 'poem' not in n.classes \
                and 'text-align:center' in (n.attrs.get('style') or '').replace(' ', '') \
                and not any('poem' in e.classes for e in n.iter()):
            t = _titre_simple(n)
            if t and re.fullmatch(r'Envo[yi]e?\.?', t, re.IGNORECASE):
                segs[courant[0]][1].append(RUBRIQUE + t.upper())
            elif t:
                nouveau(t)
            return
        if titres_centres:
            t = _titre_centre(n)
            if t:
                nouveau(t)
                return
        if n.classes & {'pagenum', 'ws-pagenum'}:
            page[0] = n.attrs.get('title')
            segs[courant[0]][1].append(SAUT)
            return
        if n.tag in TITRES:
            nouveau(_titre_propre(n))
            return
        qui = _personnage(n)
        if qui:
            segs[courant[0]][1].append(RUBRIQUE + qui)
            return
        ancre = _ancre_de_titre(n)
        if ancre:
            nouveau(ancre)
            return
        num = _numero_centre(n)
        if num and reprise_numerotee:
            # A numbered stanza after an inserted piece: the main poem, the
            # first segment with verse, resumes (the Testament's huitains
            # after one of its ballades).
            principal = next((i for i in range(len(segs)) if a_du_vers(i)), None)
            if principal is not None and principal < courant[0] and a_du_vers(courant[0]):
                courant[0] = principal
            return
        if num and titres_centres:
            # A numbered poem. Right after a title ("Chansons bas", I, II...) it
            # opens or continues that sequence; after a finished poem, it is
            # an untitled poem of a numbered group, named by its first line.
            actuel = segs[courant[0]][0]
            if actuel and not a_du_vers(courant[0]):
                segs[courant[0]][0] = f'{actuel}, {num}'
            else:
                suite = re.fullmatch(r'(.*), [IVXLCDM]+', actuel or '')
                nouveau(f'{suite.group(1)}, {num}' if suite else None)
            return
        if 'poem' in n.classes:
            seg = segs[courant[0]]
            seg[1].append(_lignes_de(n))
            if page[0]:
                seg[2].add(page[0])
            for e in n.iter():  # page breaks inside the block
                if e.classes & {'pagenum', 'ws-pagenum'} and e.attrs.get('title'):
                    page[0] = e.attrs['title']
                    seg[2].add(page[0])
            return
        for e in n.enfants:
            visite(e)

    visite(racine)
    if not any(a_du_vers(i) for i in range(len(segs))):
        segs = _vers_sans_balise(racine)
    sortie = []
    for titre, blocs, pages in segs:
        texte = recoudre(blocs)
        if not texte:
            continue
        pages = sorted(pages)
        sonnets = _sonnets_colles(texte) if separer_blocs else None
        if sonnets is None:
            sortie.append((titre, texte, pages))
        elif titre:
            sortie += [(f'{titre}, {_ordre_romain(str(i + 1))}', t, pages) for i, t in enumerate(sonnets)]
        else:
            sortie += [(None, t, pages) for t in sonnets]
    return sortie


def _vers_probables(lignes):
    """French verse of the period capitalises every line; prose wrapped at
    the printed line mostly continues in lower case. A paragraph in capitals
    is a printed title."""
    lettres = [re.sub(r'^[^\w]+', '', l)[:1] for l in lignes]
    lettres = [c for c in lettres if c.isalpha()]
    if not lettres or all(l.upper() == l for l in lignes):
        return False
    return sum(c.isupper() for c in lettres) >= 0.8 * len(lettres)


def _vers_sans_balise(racine):
    """Verse transcribed as plain paragraphs, one line per wikitext line,
    on a page with no poem block at all. A paragraph counts as a stanza only
    with two or more lines averaging under 70 characters; prose paragraphs
    are one long line and never qualify, nor do running heads."""
    segs = [[None, [], set()]]
    page = [None]

    def visite(n):
        if isinstance(n, str):
            return
        if n.classes & {'pagenum', 'ws-pagenum'}:
            page[0] = n.attrs.get('title')
            segs[-1][1].append(SAUT)
            return
        if n.tag in TITRES:
            segs.append([_titre_propre(n), [], set()])
            return
        if n.tag == 'p':
            lignes = [l.strip() for l in normaliser(_lignes_de(n, sauts_bruts=True)).split('\n') if l.strip()]
            if len(lignes) >= 2 and sum(map(len, lignes)) / len(lignes) < 70 and _vers_probables(lignes):
                segs[-1][1].append('\n'.join(lignes))
                if page[0]:
                    segs[-1][2].add(page[0])
            elif len(lignes) == 1 and re.fullmatch(r'[IVXLCDM]+\.?', lignes[0]):
                segs.append([lignes[0], [], set()])  # a part number set as a paragraph
            return
        for e in n.enfants:
            visite(e)

    visite(racine)
    return segs


def _sonnets_colles(texte):
    """Several sonnets run together with no gap between them: the stanza
    pattern 4-4-3-3 repeated exactly, twice or more. Anything less regular is
    left whole."""
    strophes = texte.split('\n\n')
    if len(strophes) < 8 or len(strophes) % 4:
        return None
    tailles = [len(st.split('\n')) for st in strophes]
    if tailles != [4, 4, 3, 3] * (len(strophes) // 4):
        return None
    return ['\n\n'.join(strophes[i:i + 4]) for i in range(0, len(strophes), 4)]


NAVIGATION = {'headertemplate', 'subheader', 'ws-data', 'footertemplate'}


def liens(html, prefixe=None):
    """Article titles linked from a page's body, in document order, deduplicated.

    The header and footer (previous/next navigation, the collection link) are
    dropped first, so a poem page never leads to its siblings. With a prefix,
    only titles under it; without, every main-namespace article.
    """
    racine = dom(html)

    def elaguer(n):
        n.enfants = [e for e in n.enfants if isinstance(e, str) or not (
            e.attrs.get('id') in NAVIGATION or e.classes & NAVIGATION)]
        for e in n.enfants:
            if isinstance(e, Noeud):
                elaguer(e)

    elaguer(racine)
    vus, sortie = set(), []
    for n in racine.iter():
        href = n.attrs.get('href') or '' if n.tag == 'a' else ''
        if not href.startswith('/wiki/') or 'redlink' in href:
            continue
        titre = urllib.parse.unquote(href[6:].split('#')[0]).replace('_', ' ')
        if ':' in titre.split('/')[0]:
            continue  # Auteur:, Catégorie:, Fichier:, Page:, Livre: ...
        if prefixe is not None and not titre.startswith(prefixe):
            continue
        if titre not in vus:
            vus.add(titre)
            sortie.append(titre)
    return sortie


# Pages that are never poems, by the last part of their title: an edition's
# apparatus, and the "whole text" page that repeats every poem of a book.
APPAREIL = re.compile(
    r'(Texte entier|Préface.*|Avant-propos|Avertissement.*|Avis.*|Notice.*|Introduction|Commentaires?|'
    r'Notes?( .*)?|Tables?( .*)?|Portrait|Titre|Errata|Achevé d.imprimer|Bibliographie|'
    r'Appendice|Variantes|Index|Lettre à .*|Entretien avec le lecteur|Des Méditations|'
    r'Préface générale|Des Destinées de la Poésie)',
    re.IGNORECASE)


def _nom_de_page(titre):
    """Last path component, without the disambiguator Wikisource appends."""
    nom = titre.rsplit('/', 1)[-1]
    return re.sub(r'\s*\((?:[^()]*\d{4}[^()]*|[A-ZÉ][^()]*)\)$', '', nom).strip()


def _ordre_romain(nom):
    """'12' -> 'XII' for sonnets numbered only by their subpage."""
    if not nom.isdigit():
        return nom
    n, r = int(nom), ''
    for v, s in ((1000, 'M'), (900, 'CM'), (500, 'D'), (400, 'CD'), (100, 'C'), (90, 'XC'),
                 (50, 'L'), (40, 'XL'), (10, 'X'), (9, 'IX'), (5, 'V'), (4, 'IV'), (1, 'I')):
        while n >= v:
            r += s
            n -= v
    return r


# --- crawl -----------------------------------------------------------------------

def _cle_titre(t):
    t = unicodedata.normalize('NFKD', t.lower().replace('œ', 'oe').replace('æ', 'ae'))
    return re.sub(r'[^a-z0-9]', '', ''.join(c for c in t if not unicodedata.combining(c)))


def premier_vers(texte):
    """The first line of verse, past any part number ("I") or speaker's name
    ("LA SŒUR.") set above it."""
    for ligne in texte.split('\n'):
        l = ligne.strip()
        if re.search(r'[^\W\d_]', l) and not re.fullmatch(r'[IVXLCDM]+\.?', l) and not rubrique(l):
            return l  # past part numbers, names and ornaments ("*")
    return texte.split('\n', 1)[0].strip()


def rubrique(ligne):
    """A line with two letters or more and none in lower case: a speaker's
    name or a heading. Same test as asset.py and esMarcaDeSeccion in
    poemario_core."""
    return sum(c.isalpha() for c in ligne) >= 2 and not any(c.islower() for c in ligne)


def incipit(texte):
    premiere = premier_vers(texte)
    premiere = re.sub(r'[\s,;:.\u00a0—–-]+$', '', premiere)
    return f'« {premiere} »'


NUMERO = re.compile(r'(?:(?:Poème|Sonnet|Ode|Chanson|Pièce)\s+)?([0-9]+|[IVXLCDM]+)\.?', re.IGNORECASE)


class Collecte:
    def __init__(self):
        self.poemes = []
        self.sans_vers = []      # (collection, page) with no verse at all
        self.manquantes = []     # (collection, page) that does not exist
        self.vues = set()
        self.trop_courts = []
        self.non_relus = []
        self.remplaces = 0
        self.editions = []       # (author, collection, year printed in the header, taken)

    def recueil(self, auteur, rec):
        titre, html = page_html(rec['page'])
        if html is None:
            self.manquantes.append((rec['page'], rec['page']))
            return
        m = re.search(r'class="ws-year">\D*(\d{4})', html)
        annee = int(m.group(1)) if m else None
        pris = annee is None or annee < EDITION_LIMITE or bool(rec.get('reimpression'))
        self.editions.append((auteur['nom'], rec['page'], annee, pris, rec.get('reimpression')))
        if not pris:
            return
        self.vues.add(titre)
        segs = self._segments(rec, html)
        prefixe = rec.get('prefixe', titre + '/')
        enfants = liens(html, None if prefixe == '*' else prefixe)
        if not enfants:
            # The collection is one page: its headed poems, or a single poem.
            if segs:
                self._ajouter(auteur, rec, titre, segs, [], racine=True)
            else:
                self.sans_vers.append((rec['page'], titre))
            return
        precharger(enfants)
        for e in enfants:
            self._suivre(auteur, rec, e, profondeur=1, sections=[])

    def _suivre(self, auteur, rec, titre, profondeur, sections):
        if titre in self.vues:
            return
        self.vues.add(titre)
        nom = titre.rsplit('/', 1)[-1]
        if rec.get('complement') and _cle_titre(_nom_de_page(titre)) in {
                _cle_titre(p['titulo']) for p in self.poemes if p['autor'] == auteur['nom']}:
            return
        if APPAREIL.fullmatch(nom) or any(re.search(m, titre) for m in rec.get('exclure', [])):
            return
        titre, html = page_html(titre)
        if html is None:
            self.manquantes.append((rec['page'], titre))
            return
        # Again under the title the link resolved to (a redirect).
        if any(re.search(m, titre) for m in rec.get('exclure', [])):
            return
        self.vues.add(titre)
        enfants = liens(html, titre + '/')
        segs = self._segments(rec, html)
        # A section page (a table of contents of its own subpages) is followed.
        # Verse on it is an epigraph or dedication, kept as its own poem only
        # when the collection asks for it.
        if enfants and profondeur < 5:
            if segs and rec.get('garder_sections'):
                self._ajouter(auteur, rec, titre, segs, sections)
            precharger(enfants)
            for e in enfants:
                self._suivre(auteur, rec, e, profondeur + 1, sections + [_nom_de_page(titre)])
            return
        if not segs:
            self.sans_vers.append((rec['page'], titre))
            return
        sequence = any(re.search(m, titre) for m in rec.get('sequences', []))
        self._ajouter(auteur, rec, titre, segs, sections, racine=sequence)

    @staticmethod
    def _segments(rec, html):
        return segments(dom(html), titres_centres=rec.get('titres_centres', False),
                        separer_blocs=rec.get('separer_blocs', False),
                        reprise_numerotee=rec.get('reprise_numerotee', False),
                        titres_simples=rec.get('titres_simples', False),
                        vers_par_paragraphe=rec.get('vers_par_paragraphe', False))

    def _titre(self, nom, texte):
        """A poem's title from its page name or heading. A bare number
        ("Poème 12", "XXXIV") names nothing a reader knows: the first line
        does. A number glued to a title ("VI ANAGRAMME") loses the number."""
        if NUMERO.fullmatch(nom):
            return incipit(texte)
        m = re.fullmatch(r'[IVXLCDM]+\.?\s+(\S.*)', nom)
        return m.group(1) if m else nom

    def _ajouter(self, auteur, rec, titre_page, segs, sections, racine=False):
        url = 'https://fr.wikisource.org/wiki/' + urllib.parse.quote(titre_page.replace(' ', '_'))
        if not racine:
            # A poem's own page: its headings are the printed title (the first,
            # dropped: the page name is cleaner) and its numbered or named
            # parts ("Le Voyage", I to VIII), kept as a line of their own.
            # A lone numeral atop the page is the poem's number in its
            # sequence; it is a part number only if more parts follow.
            numeros = [t for t, _, _ in segs if t and re.fullmatch(r'[IVXLCDM]+', t)]
            morceaux, pages = [], sorted({pg for _, _, ps in segs for pg in ps})
            for i, (t, texte, _) in enumerate(segs):
                if t and (i > 0 or (re.fullmatch(r'[IVXLCDM]+', t) and len(numeros) > 1)):
                    morceaux.append(t)
                morceaux.append(texte)
            texte = '\n\n'.join(morceaux)
            titre = self._titre(_nom_de_page(titre_page), texte)
            self.poemes.append(self._poeme(auteur, rec, titre, texte, url, sections, pages))
            return
        nom = (rec.get('titre') if titre_page == page_html(rec['page'])[0] else None) or _nom_de_page(titre_page)
        if len(segs) == 1:
            # One poem: its own page's name, even when the collection is
            # given another ('titre', the book a single poem belongs to).
            nom = _nom_de_page(titre_page)
            self.poemes.append(self._poeme(auteur, rec, self._titre(nom, segs[0][1]), segs[0][1], url, sections, segs[0][2]))
            return
        # A collection printed on one page (Villon's Testament, the Regrets):
        # one poem per heading. The first takes the collection's name with
        # 'titre_premier'; untitled ones their first line.
        for i, (t, texte, pages) in enumerate(segs):
            if t and re.fullmatch(r'(Bibliographie|Table( des matières)?|Notes?)', t, re.IGNORECASE):
                continue
            if t and any(re.search(m, t) for m in rec.get('exclure_titres', [])):
                continue
            if i == 0 and rec.get('titre_premier'):
                titre = nom
            elif t:
                titre = self._titre(t, texte)
            else:
                titre = incipit(texte)
            self.poemes.append(self._poeme(auteur, rec, titre, texte, f'{url}#{i}', sections, pages))

    def _poeme(self, auteur, rec, titre, texte, url, sections, pages):
        return {
            'autor': auteur['nom'],
            'titulo': titre,
            'recueil': rec.get('titre') or _nom_de_page(rec['page']),
            'sections': sections,
            'texto': texte,
            'fuente': 'wikisource',
            'edition': rec.get('edition', ''),
            'url': url,
            'pages': pages,
        }


MOT = re.compile(r"[^\W\d_]+(?:[’'-][^\W\d_]+)*")
ROMAIN = re.compile(r'M{0,4}(CM|CD|D?C{0,3})(XC|XL|L?X{0,3})(IX|IV|V?I{0,3})')
MOTS_ROMAINS = {'MI', 'DI', 'LI', 'CI', 'DIX', 'MIL'}  # French words spelt like numerals


def noms_propres(poemes):
    """Words the corpus capitalises inside a line more often than not:
    names, and the poets' personifications (Dieu, Amour, la Mort)."""
    from collections import Counter
    haut, bas = Counter(), Counter()
    for p in poemes:
        for ligne in p['texto'].split('\n'):
            for m in list(MOT.finditer(ligne))[1:]:
                avant = ligne[:m.start()].rstrip()
                if avant.endswith(('.', '!', '?', '«', '—', ':')):
                    continue  # a sentence or quotation starts here
                mot = m.group(0)
                (haut if mot[0].isupper() else bas)[mot.lower()] += 1
    return {m for m, n in haut.items() if n >= 2 and n > bas[m]}


def casse_de_titre(titre, propres):
    """'À VICTOR HUGO' -> 'À Victor Hugo', 'CHANSON' -> 'Chanson': sentence
    case for a title printed in capitals, proper nouns kept, numerals too."""
    def mot(m):
        w = m.group(0)
        if ROMAIN.fullmatch(w) and w not in MOTS_ROMAINS:
            return w
        bas = w.lower()
        # D’ARTAGNAN -> d’Artagnan: elided article, then the word itself
        if re.match(r"[a-zà-ÿ][’']", bas):
            reste = bas[2:]
            return bas[:2] + (reste[:1].upper() + reste[1:] if reste in propres else reste)
        return bas[:1].upper() + bas[1:] if bas in propres else bas
    t = MOT.sub(mot, titre)
    i = next((k for k, ch in enumerate(t) if ch.isalpha()), None)
    return t if i is None else t[:i] + t[i].upper() + t[i + 1:]


def typographie(texte):
    """Undoes printing conventions that are not spelling: the long s (ſ, in
    the Barbin La Fontaine) and the capitals of a drop-cap opening word
    ("LE Roy des animaux", "VOuloir tromper"). Spelling stays as printed."""
    texte = texte.replace('ſ', 's')
    m = re.match(r'([^\w]*)([^\W\d_]+)(?=[\s’\',;:.!?])', texte)
    if m and not rubrique(texte.split('\n', 1)[0]) and len(m.group(2)) > 1 and any(c.isupper() for c in m.group(2)[1:]) \
            and not ROMAIN.fullmatch(m.group(2)) and '\n' in texte[:200]:
        mot = m.group(2)
        texte = texte[:m.start(2)] + mot[0] + mot[1:].lower() + texte[m.end(2):]
    return texte


def _plier(t):
    return _cle_titre(t.replace('&', 'et'))


def _semblables(a, b):
    """Same title, allowing for old spelling ("l'Asne" for "l'Âne")."""
    from difflib import SequenceMatcher
    a, b = _plier(a), _plier(b.strip('«» '))
    return bool(a) and SequenceMatcher(None, a, b).ratio() >= 0.8


def sans_entete(texte, titre):
    """Drops a poem's number and title where the edition set them inside the
    verse (the Barbin Fables: "XIX." / "Le Lion & l'Asne chassant.")."""
    strophes = texte.split('\n\n')
    numero = re.compile(r'[IVXLCDM]+\.?')
    parties = sum(1 for st in strophes if numero.fullmatch(st.strip()))
    while len(strophes) > 1 and '\n' not in strophes[0] and (
            (numero.fullmatch(strophes[0].strip()) and parties == 1)
            or _semblables(strophes[0], titre)):
        strophes.pop(0)
    return '\n\n'.join(strophes)


# Longer poems are left out: a poem of the day is read on a phone. 300 is
# already long (Le Lac has 64 verses, La Mort du loup 88).
VERS_MAX = 300


def nombre_de_vers(texte):
    """Verses, not counting part numerals, ornaments or speakers' names."""
    return sum(1 for l in texte.split('\n')
               if l.strip() and not rubrique(l) and not re.fullmatch(r'\s*([IVXLCDM]+\.?|\d+\.?|[*∗⁂ ]+)\s*', l))


SOURCE = re.compile(r'\n\n(\((?:Tiré|Imité|Traduit|Trad\.) d[’\'e][^)]*\)\.?)\s*\Z')


def finaliser(poemes):
    """Typography normalised and printed headers dropped; titles printed in
    capitals set in sentence case; fragments of fewer than three lines
    ("etc." stubs, stray prose) and second copies of a poem (same author and
    first line: Ronsard moved sonnets between books) set aside for the
    report, the first copy kept."""
    propres = noms_propres(poemes)
    gardes, courts, vus = [], [], set()
    for p in poemes:
        p['titulo'] = typographie(p['titulo'])
        p['texto'] = typographie(sans_entete(typographie(p['texto']), p['titulo']))
        for motif, remplacement in CORRECTIONS.get((p['autor'], p['titulo']), []):
            p['texto'], n = re.subn(motif, remplacement, p['texto'])
            if n != 1:
                sys.exit(f"Correction for {p['titulo']} matched {n} times: {motif}")
        note = SOURCE.search(p['texto'])
        if note:
            # The editor's note of what the poem renders (Derocquigny's
            # Chénier): a translation is set aside, an imitation kept
            # without the note.
            if re.match(r'\((Trad|Traduit)', note.group(1)):
                p['traduction'] = True
                courts.append(p)
                continue
            p['texto'] = p['texto'][:note.start()].rstrip('\n')
        if sum(1 for l in p['texto'].split('\n') if l.strip()) < 3:
            courts.append(p)
            continue
        if nombre_de_vers(p['texto']) > VERS_MAX:
            p['trop_long'] = True
            courts.append(p)
            continue
        if p['titulo'].startswith('«'):
            p['titulo'] = incipit(p['texto'])  # again, now the drop cap is undone
        premiere = (p['autor'], _plier(premier_vers(p['texto'])))
        if premiere in vus:
            p['doublon'] = True
            courts.append(p)
            continue
        vus.add(premiere)
        if re.search(r'[A-ZÀ-Ý]{3}', p['titulo']) and not re.search(r'[a-zà-ÿ]', p['titulo'].strip('«» ')[:1] + ''.join(
                ch for ch in p['titulo'] if ch.isalpha() and ch.islower())):
            p['titulo'] = casse_de_titre(p['titulo'], propres)
        gardes.append(p)
    return gardes, courts


def remplacer_par_gutenberg(poemes):
    """Gives a poem whose scans are not proofread the text of the same poem
    from Project Gutenberg (gutenberg_fr.json, see gutenberg.py), when it has
    one: same author and collection, and the same first line or title. The
    Wikisource title, section and place in the book are kept. Returns the
    number replaced."""
    fichier = AQUI / 'gutenberg_fr.json'
    if not fichier.exists():
        return 0
    from collections import defaultdict
    from difflib import SequenceMatcher
    par_recueil = defaultdict(list)
    for g in json.loads(fichier.read_text()):
        par_recueil[(g['autor'], g['recueil'])].append(g)
    n = 0
    for p in poemes:
        if p['relu'] is not False:
            continue
        candidats = par_recueil.get((p['autor'], p['recueil']), [])
        vers = _plier(premier_vers(typographie(p['texto'])))
        titre = _plier(p['titulo'])
        for g in candidats:
            if (_plier(premier_vers(g['texto'])) == vers
                    or (g['titulo'] and SequenceMatcher(None, _plier(g['titulo']), titre).ratio() >= 0.9)):
                p.update(texto=g['texto'], fuente='gutenberg', edition=g['edition'], url=g['url'], relu=None)
                candidats.remove(g)
                n += 1
                break
    return n


def verifies_a_la_main(poemes):
    """Lets in the unproofread poems recueils.VERIFIES lists: their text is
    replaced by the file in verifies/, the OCR corrected by hand against the
    scan, and `relu` becomes "verifie". An entry that matches nothing (the
    poem was proofread on Wikisource since, or its first line changed) stops
    the build. Returns how many were let in."""
    auteurs = {p['autor'] for p in poemes}  # only those crawled (--auteur)
    restants = {cle: v for cle, v in VERIFIES.items() if cle[0] in auteurs}
    n = 0
    for p in poemes:
        if p['relu'] is not False:
            continue
        vers = _plier(premier_vers(typographie(p['texto'])))
        for cle in list(restants):
            auteur, debut = cle
            if p['autor'] == auteur and vers.startswith(_plier(debut)):
                p['texto'] = (AQUI / 'verifies' / restants.pop(cle)).read_text().strip('\n')
                p['relu'] = 'verifie'
                n += 1
                break
    if restants:
        sys.exit(f'VERIFIES entries matching no set-aside poem: {list(restants)}')
    return n


def verifier_auteurs(filtre):
    verifies = {}
    for a in AUTEURS:
        if filtre and filtre.lower() not in a['nom'].lower():
            continue
        qid, annee = date_de_deces(a['wikisource'])
        ok = annee is not None and annee < ANNEE_LIMITE
        verifies[a['nom']] = {'wikidata': qid, 'deces': annee, 'retenu': ok}
        print(f"{a['nom']:32} {qid or '?':10} died {annee}  {'ok' if ok else 'REFUSED'}", file=sys.stderr)
    return verifies


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--auteur')
    ap.add_argument('--page')
    ap.add_argument('--out', default=str(AQUI / 'poemas_fr.json'))
    ap.add_argument('--rapport', default=str(AQUI / 'informe_wikisource.md'))
    args = ap.parse_args()

    if args.page:
        t, h = page_html(args.page)
        arbre = dom(h)
        print('subpages:', liens(h, t + '/')[:40])
        for titre, texte, _ in segments(arbre, titres_centres=True):
            print(f'--- [{titre}]\n{texte}\n')
        return

    verifies = verifier_auteurs(args.auteur)
    (AQUI / 'auteurs_verifies.json').write_text(json.dumps(verifies, ensure_ascii=False, indent=1) + '\n')
    c = Collecte()
    for a in AUTEURS:
        if a['nom'] not in verifies or not verifies[a['nom']]['retenu']:
            continue
        for rec in a['recueils']:
            avant = len(c.poemes)
            c.recueil(a, rec)
            print(f"  {a['nom']} - {rec['page']}: {len(c.poemes) - avant}", file=sys.stderr)

    qualite = qualite_des_pages(pg for p in c.poemes for pg in p['pages'])
    for p in c.poemes:
        pages = p.pop('pages')
        niveaux = [qualite.get(pg, 0) for pg in pages]
        p['relu'] = min(niveaux) >= QUALITE_MINIMALE if niveaux else None
        if p['relu'] is False:
            p['scans'] = pages  # for checking by hand; not in the output
    c.remplaces = remplacer_par_gutenberg(c.poemes)
    c.verifies = verifies_a_la_main(c.poemes)
    c.non_relus = [p for p in c.poemes if p['relu'] is False]
    c.poemes = [p for p in c.poemes if p['relu'] is not False]
    for p in c.poemes:
        p.pop('scans', None)
    c.poemes, c.trop_courts = finaliser(c.poemes)
    corriges = {(p['autor'], p['titulo']) for p in c.poemes}
    if oublies := {k for k in CORRECTIONS if k[0] in {a for a, _ in corriges}} - corriges:
        sys.exit(f'Corrections for poems not in the corpus: {oublies}')
    Path(args.out).write_text(json.dumps(c.poemes, ensure_ascii=False, indent=1) + '\n')
    # What was set aside as unproofread, for choosing hand-checked poems (VERIFIES).
    (CACHE / 'non_relus.json').write_text(json.dumps(c.non_relus, ensure_ascii=False, indent=1))
    rapport(c, verifies, Path(args.rapport))


def rapport(c, verifies, chemin):
    from collections import Counter
    l = ['# Wikisource crawl report', '', 'Generated by `wikisource.py`. Check it after every rebuild.', '',
         '## Authors (death year from Wikidata)', '', '| Author | Wikidata | Died | Kept | Poems |', '|---|---|---:|---|---:|']
    par_auteur = Counter(p['autor'] for p in c.poemes)
    for nom, v in verifies.items():
        l.append(f"| {nom} | {v['wikidata']} | {v['deces']} | {'yes' if v['retenu'] else '**no**'} | {par_auteur.get(nom, 0)} |")
    l += ['', '## Poems per collection', '', '| Author | Collection | Poems |', '|---|---|---:|']
    for (a, r), n in Counter((p['autor'], p['recueil']) for p in c.poemes).items():
        l.append(f'| {a} | {r} | {n} |')
    l += ['', '## Editions (year in the Wikisource header)', '',
          f'Taken only if dated before {EDITION_LIMITE}, or a later reprint of a text printed before then.',
          'No year: check by hand.', '', '| Author | Collection | Year | Taken |', '|---|---|---:|---|']
    l += [f"| {a} | {r} | {y or '?'} | {'yes' if ok else '**no**'}{' (reprint: ' + why + ')' if why else ''} |"
          for a, r, y, ok, why in c.editions]
    l += ['', f'## Pages with no verse ({len(c.sans_vers)})', '',
          'Prose, notes, prefaces, or verse Wikisource does not mark as a poem. Not guessed at.', '']
    l += [f'* {r} → {p}' for r, p in c.sans_vers]
    from collections import Counter as _C
    nr = _C((p['autor'], p['recueil']) for p in c.non_relus)
    sans_scan = _C((p['autor'], p['recueil']) for p in c.poemes if p['relu'] is None)
    l += ['', f'## Replaced from Project Gutenberg ({c.remplaces})', '',
          'Poems whose Wikisource scans are not proofread, taken instead from a Gutenberg text of the',
          'same book (gutenberg.py): `fuente` is "gutenberg".']
    verifies = [p for p in c.poemes if p['relu'] == 'verifie']
    l += ['', f'## Checked by hand against the scan ({len(verifies)})', '',
          'Not proofread on Wikisource; let in by recueils.VERIFIES with the text read off the scan',
          '(verifies/). `relu` is "verifie".', '']
    l += [f"* {p['autor']} — {p['recueil']} — {p['titulo']}" for p in verifies]
    l += ['', f'## Set aside: not proofread on Wikisource ({len(c.non_relus)})', '',
          f'Some scanned page is below level {QUALITE_MINIMALE} (raw OCR). Proofreading them on Wikisource and',
          'rerunning brings them in.', '', '| Author | Collection | Poems |', '|---|---|---:|']
    l += [f'| {a} | {r} | {n} |' for (a, r), n in nr.most_common()]
    l += ['', f"## Kept without a scan to check ({sum(sans_scan.values())})", '',
          'Typed in from another source, not transcluded from scanned pages, so Wikisource has no',
          'proofreading level for them. `relu` is null in the JSON.', '', '| Author | Collection | Poems |', '|---|---|---:|']
    l += [f'| {a} | {r} | {n} |' for (a, r), n in sans_scan.most_common()]
    doublons = [p for p in c.trop_courts if p.get('doublon')]
    traductions = [p for p in c.trop_courts if p.get('traduction')]
    longs = [p for p in c.trop_courts if p.get('trop_long')]
    courts = [p for p in c.trop_courts if not (p.get('doublon') or p.get('traduction') or p.get('trop_long'))]
    l += ['', f'## Set aside: longer than {VERS_MAX} verses ({len(longs)})', '']
    l += [f"* {p['autor']} — {p['recueil']} — {p['titulo']} ({nombre_de_vers(p['texto'])})" for p in longs]
    l += ['', f'## Set aside: translations ({len(traductions)})', '',
          'The edition notes the poem is translated from another poet.', '']
    l += [f"* {p['autor']} — {p['recueil']} — {p['titulo']}" for p in traductions]
    l += ['', f'## Set aside: second copies ({len(doublons)})', '',
          'Same author and first line as a poem kept earlier (Ronsard moved sonnets between books).', '']
    l += [f"* {p['autor']} — {p['recueil']} — {p['titulo']}" for p in doublons]
    l += ['', f'## Set aside: fewer than three lines ({len(courts)})', '']
    l += [f"* {p['autor']} — {p['recueil']} — {p['titulo']}: {p['texto'][:60]!r}" for p in courts]
    l += ['', f'## Missing pages ({len(c.manquantes)})', '']
    l += [f'* {r} → {p}' for r, p in c.manquantes]
    chemin.write_text('\n'.join(l) + '\n')


if __name__ == '__main__':
    main()
