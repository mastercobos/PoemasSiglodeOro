"""Clean a Gutenberg text before Laurel's parser reads it, while the layout is still there."""
import re, unicodedata

def clave(s):
    s = unicodedata.normalize('NFKD', s).lower().replace('’', "'")
    return re.sub(r'[^a-z0-9]+', '', s)

def sin_notas(lines):
    """Drop footnote bodies: '[Footnote 2: ...]' up to its closing bracket, and '[238]' blocks
    (the marker, the note after it, and, when the marker stands alone, the quotation under it).

    A '[238]' block is a note only when the text has already pointed to it ("Bivar,[238]").
    Knight's Wordsworth sets a bare '[21]' above the stanza a note refers to: that one is the
    reference itself, and the stanza under it is verse."""
    visto = set()                                             # note numbers referred to so far
    out, i, n = [], 0, len(lines)
    while i < n:
        s = lines[i].strip()
        if s.startswith('[Footnote'):
            while i < n:                                      # up to the line that closes it
                fin = re.search(r'\][.,;:)]*$', lines[i].rstrip()) is not None
                i += 1
                if fin: break
            continue
        m = re.match(r'^\[(\d+)\](\s|$)', s)
        if m and (i == 0 or not lines[i-1].strip()) and m.group(1) in visto:   # a note body opens a block
            solo = re.fullmatch(r'\[\d+\]', s)
            while i < n and lines[i].strip(): i += 1          # the note itself
            if solo:                                          # the quotation printed under a bare marker
                while i < n and not lines[i].strip(): i += 1
                while i < n and lines[i].strip(): i += 1
            continue
        visto.update(re.findall(r'\[(\d+)\]', lines[i]))
        out.append(lines[i]); i += 1
    return out

def sin_marcas(lines):
    """Transcriber's note markers left on headings: Bryant's "THE MASSACRE AT SCIO. deg."
    (a degree sign standing for a note) reached the app as "The Massacre at Scio. Deg"."""
    return [re.sub(r"\s*\(?\s*\bdeg\.\)?\s*$", "", l) if re.search(r"[A-Za-z.]\s+\(?\s*deg\.\)?\s*$", l) else l
            for l in lines]


def titulos_del_indice(lines):
    """A line standing alone that the book's own contents list names is a title: set it in
    capitals so the parser cannot take it for verse."""
    bloques, ini = [], None
    for k, l in enumerate(lines + ['']):
        if l.strip() and ini is None: ini = k
        if not l.strip() and ini is not None: bloques.append((ini, k)); ini = None
    # the contents: the first run of 8+ consecutive short lines, taken before the body begins
    indice = set()
    for a, b in bloques[:60]:
        filas = [re.sub(r'\s{2,}\d+\s*$', '', l).strip() for l in lines[a:b]]
        if len(filas) >= 8 and all(len(f) < 90 for f in filas):
            indice |= {clave(f) for f in filas if len(clave(f)) > 3}
    if not indice: return lines, 0
    fin_indice = max(b for a, b in bloques[:60] if b - a >= 8)
    out, n = list(lines), 0
    for a, b in bloques:
        if a <= fin_indice or b - a != 1: continue
        t = lines[a].strip()
        k = clave(t)
        nombrado = k in indice or any(len(e) >= 8 and k.startswith(e) for e in indice)   # "To A Mouse, On Turning Her Up..."
        numeral = re.fullmatch(r"[IVXLCl]{1,6}\.?", t)          # also as scanned: "Ill" for III
        if nombrado and not numeral and len(t) < 120 and t != t.upper() and a >= 2 and not lines[a-1].strip():
            out[a] = lines[a].upper(); n += 1
    return out, n


HABLANTE = re.compile(r"^[A-Z][A-Z .'\u2019-]{1,28}\.$")
# headings set like speaker tags: a song or sonnet inside a longer piece is not a speaker,
# nor is a dedication ("TO GENEVRA.", twice in a row in Byron)
NO_ES_HABLANTE = re.compile(r"^(TO|ON|UPON|LINES|WRITTEN|FROM|IN|AT|FOR)\b|^(A |THE )?(SONG|SONNET|FRAGMENT|ODE|HYMN|EPIGRAM|ELEGY|STANZAS|BALLAD|DIRGE|EPITAPH|"
                            r"INSCRIPTION|AIR|DUET|TRIO|RECITATIVE|MADRIGAL|CANZONET|GLEE|ROUND|CATCH|L'ENVOI|ENVOY|"
                            r"PROLOGUE|EPILOGUE|ARGUMENT|DEDICATION|INTRODUCTION|CONCLUSION|NOTE|NOTES|POSTSCRIPT)\b")


def hablantes(lines):
    """{first line of a speech: speaker tag} for the dialogue poems in a book.

    Laurel's parser strips speaker tags ("SIMON.", "JOHN.") from every stanza,
    which leaves a Barnes eclogue as one voice arguing with itself. A tag is a
    line in capitals ending in a stop, with the speech on the next non-blank
    line. Titles are set the same way ("THE WIND.", "INTERLUDE."); what marks a
    dialogue is that the same tag comes back within CERCA lines and another
    tag stands near it."""
    CERCA = 120
    donde = {}
    for k, l in enumerate(lines):
        e = l.strip()
        if HABLANTE.match(e) and not NO_ES_HABLANTE.match(e) and not re.match(r"^([IVXLC]+|(PART|BOOK|CANTO|SECTION)\b.*)\.$", e):
            donde.setdefault(e, []).append(k)
    todas = sorted((k, e) for e, ks in donde.items() for k in ks)
    mapa = {}
    for k, e in todas:
        vuelve = any(0 < abs(j - k) <= CERCA for j in donde[e])
        otra = any(abs(j - k) <= CERCA and f != e for j, f in todas)
        if not (vuelve and otra):
            continue
        siguiente = next((x for x in lines[k + 1:k + 4] if x.strip()), "")
        if siguiente and not HABLANTE.match(siguiente.strip()) and siguiente.strip() != siguiente.strip().upper():
            mapa.setdefault(clave(siguiente), e)
    return mapa


def con_hablantes(estrofas, mapa):
    """Put each speaker's tag back above the stanza that opens the speech: (stanzas, how many).
    Not above the first stanza: the app shows a poem's first line in lists and notifications
    («JOHN.» would say nothing), and an eclogue's title names its speakers. A stanza that is
    only a tag (the source sets a blank line under it) joins the speech below it."""
    unidas = []
    for st in estrofas:
        if unidas and len(unidas[-1]) == 1 and HABLANTE.match(unidas[-1][0]):
            unidas[-1] = unidas[-1] + st
        else:
            unidas.append(list(st))
    salida, n = [], 0
    for st in unidas:
        if not salida and HABLANTE.match(st[0]) and len(st) > 1:
            st = st[1:]                                   # the opening speaker, set in the source
        e = mapa.get(clave(st[0])) if st else None
        if e and salida and not HABLANTE.match(st[0]):
            st = [e] + st
            n += 1
        salida.append(st)
    return salida, n


PEQUENAS = {"of", "the", "de", "da", "di", "del", "von", "van", "and", "on", "in", "to", "a", "la", "le", "by", "&"}
CITA_Y_AUTOR = re.compile(r"[”\"’'.!?]\s*(—|--)\s*_?[A-Z][\w’'. ,&-]{1,50}\.?_?\s*$")
CIERRA_CITA_Y_AUTOR = re.compile(r"[”\"’]\s*(—|--)\s*_?[A-Z][\w’'. ,&-]{1,50}\.?_?\s*$")


def como_nombre(texto):
    """Reads like a name or a reference: every word capitalised but the small ones and the
    numerals ("Joanna Baillie", "OVID, Fastorum, Lib. vi"). "A woman's grave" does not."""
    palabras = re.findall(r"[\w’'&-]+", texto)
    return 0 < len(palabras) <= 8 and all(
        w[0].isupper() or w.lower() in PEQUENAS or re.fullmatch(r"[ivxlc]+|\d+", w) for w in palabras)


def solo_autor(linea):
    """A line that is nothing but a name or a book title: "Wordsworth.", "Hippolito Pindemonte.",
    "Poem of the Cid.", "Sir Philip Sidney's Arcadia." Every word but the small ones is capitalised."""
    l = re.sub(r"^(—|--)\s*", "", linea.strip()).strip("_ ")
    if not l.endswith(".") or len(l) > 60:
        return False
    palabras = re.findall(r"[\w’'&-]+", l)
    return 0 < len(palabras) <= 6 and all(w[0].isupper() or w.lower() in PEQUENAS for w in palabras)


def cierra_con_autor(estrofa, resto):
    """The stanza ends on an attribution, and not on a refrain the poem repeats ("Mandy Lou.",
    "Iram, coram, dago.") nor on the poet's own initials ("--R. B.")."""
    ultima = estrofa[-1].strip()
    m = CITA_Y_AUTOR.search(ultima)
    if m:
        autor = re.sub(r"^.*?(—|--)\s*", "", m.group(0)).strip("_ .")
        cita = True
    elif len(estrofa) > 1 and solo_autor(ultima) and re.match(r"^[“\"‘']", estrofa[0].strip()):
        autor, cita = ultima, True
    else:
        return False
    if re.fullmatch(r"([A-Z]\.\s?){1,3}", autor + ".") or not como_nombre(autor):
        return False
    return not any(clave(autor) in clave(l) for e in resto for l in e)


def sin_epigrafes(estrofas):
    """Drop epigraphs quoted from other writers, with their attribution: (stanzas, how many).

    Hemans heads most poems with a few lines of Wordsworth or Schiller and the
    poet's name under them, and the parser keeps them as the poem's first stanza,
    so the app showed "Wordsworth." as a line of Hemans. At the start of a poem:
    a stanza of up to 12 lines closing on "quote, dash, name", or a quotation
    whose last line is only a name; or a quotation followed by a stanza that is
    only the name. At the end, only a closing quotation mark, dash, name: the
    epigraph of the next poem, glued on (not Byron's "so hid?--A woman's grave.")."""
    n = 0
    while len(estrofas) > 1:
        a = estrofas[0]
        if len(a) <= 12 and cierra_con_autor(a, estrofas[1:]):
            estrofas = estrofas[1:]; n += 1
        elif (len(estrofas) > 2 and len(a) <= 12 and len(estrofas[1]) == 1 and solo_autor(estrofas[1][0])
              and re.match(r"^[“\"‘']", a[0].strip())):
            estrofas = estrofas[2:]; n += 1
        else:
            break
    if (len(estrofas) > 1 and len(estrofas[-1]) <= 12 and CIERRA_CITA_Y_AUTOR.search(estrofas[-1][-1])
            and cierra_con_autor(estrofas[-1], estrofas[:-1])):
        estrofas = estrofas[:-1]; n += 1
    return estrofas, n
