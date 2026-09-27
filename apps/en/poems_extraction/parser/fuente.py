"""Clean a Gutenberg text before Laurel's parser reads it, while the layout is still there."""
import re, unicodedata

def clave(s):
    s = unicodedata.normalize('NFKD', s).lower().replace('’', "'")
    return re.sub(r'[^a-z0-9]+', '', s)

def sin_notas(lines):
    """Drop footnote bodies: '[Footnote 2: ...]' up to its closing bracket, and '[238]' blocks
    (the marker, the note after it, and, when the marker stands alone, the quotation under it).

    A '[238]' or '<19.1>' block is a note only when the text has already pointed to it ("Bivar,[238]").
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
        a = re.match(r'^<(\d+\.\d+)>', s)
        if a and (i == 0 or not lines[i-1].strip()) and a.group(1) in visto:
            # Hazlitt's Lovelace: "<19.1> Dr. John Wilson was..." The parser drops the note's prose
            # but kept the verse it quotes as the end of the poem ("OR CURIOUS WILSON."). A note that
            # ends on a colon introduces quotations: the indented blocks after it that open with a
            # quotation mark go too. Not a block that is one line in capitals: that is the title of
            # a whole poem the editor reprints ("TO HIS FAIREST VALENTINE MRS. A. L."), and it stays.
            while i < n and lines[i].strip(): i += 1
            if re.search(r':\W*$', lines[i-1]):
                while True:
                    j = i
                    while j < n and not lines[j].strip(): j += 1
                    k = j
                    while k < n and lines[k].strip(): k += 1
                    bloque = lines[j:k]
                    titulo = len(bloque) == 1 and bloque[0].upper() == bloque[0]
                    tabla = any('===' in x or re.search(r'\s!\s', x) for x in bloque)   # a family tree (Sandys)
                    if bloque and bloque[0].startswith('    ') and (re.match(r'^\s*["“]', bloque[0]) or tabla) and not titulo:
                        i = k
                    else:
                        break
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
        visto.update(re.findall(r'<(\d+\.\d+)>', lines[i]))
        out.append(lines[i]); i += 1
    return out

def sin_margen(lines, minimo=10):
    """Glosses printed in the margin: Drayton's edition sets them in a left column beside the
    verse ("Pyreneus, _King     The _Phocean_ it did proue,"), and they reached the poem as the
    start of the line. The verse column is found block by block (20 in the odes, 14 in the
    elegies): the smallest indentation of at least `minimo` spaces. In such a block the text
    before that column goes when two spaces separate it from the verse; a line that is only
    gloss goes; and the asterisks in the verse that pointed to a gloss go with it. A speaker set
    in the margin ("Cho.", "Batte.": twice or more in the book) is kept in front of the line."""
    ETIQUETA = re.compile(r"^\s*_?([A-Z][a-z]{1,10}[.:])_?\s{2,}\S")   # "Batte.", "Row:"
    veces = {}
    for l in lines:
        m = ETIQUETA.match(l)
        if m: veces[m.group(1)] = veces.get(m.group(1), 0) + 1
    hablantes = {e for e, k in veces.items() if k >= 2} | {"Chorus."}   # "Batte." twice; "Zeno." (a gloss) once
    out, i, n, anterior = [], 0, len(lines), None
    while i < n:
        if not lines[i].strip():
            out.append(lines[i]); i += 1; continue
        j = i
        while j < n and lines[j].strip(): j += 1
        bloque = lines[i:j]
        sangrias = [len(l) - len(l.lstrip(' ')) for l in bloque if len(l) - len(l.lstrip(' ')) >= minimo]
        col = min(sangrias) if sangrias else None
        if col:
            # a glossed line may start its verse left of the only bare line, which is indented
            # (Thebes stanza: verse at 20, the bare line at 22)
            tras_glosa = [m.end() for m in (re.match(r'^\S.*?\s{2,}(?=\S)', l) for l in bloque)
                          if m and minimo <= m.end() <= col]
            col = min([col] + tras_glosa)
        # a stanza with a gloss on every line shows no bare verse line: then the verse starts
        # where each line resumes after the gloss and a gap of two spaces or more, and the
        # column is the leftmost of those (the Orpheus stanza of the Ode to his Rival)
        if col is None and anterior:
            inicios = [m.end() for m in (re.match(r'^\S.*?\s{2,}(?=\S)', l) for l in bloque) if m and m.end() <= anterior + 4]
            solo_glosa = [l for l in bloque if len(l.rstrip()) <= anterior and not re.search(r'\s{2,}\S', l.strip())]
            if len(inicios) >= 2 and len(inicios) + len(solo_glosa) == len(bloque):     # "Metam." alone
                col = min(inicios)
        anterior = col or anterior
        for l in bloque:
            if col and l[:col].strip():
                m = ETIQUETA.match(l)
                if m and m.group(1) in hablantes:
                    l = ' ' * col + m.group(1) + ' ' + l[col:].strip()   # a speaker in the margin stays
                elif len(l) > col and l[col - 2:col] == '  ' and l[col:].strip():
                    l = ' ' * col + l[col:]
                elif len(l.rstrip()) <= col:
                    continue                                  # gloss only
            if col:
                l = re.sub(r'\*(?=_?[A-Za-z])', '', l)
            out.append(l)
        i = j
    return out


GLOSA = re.compile(r"^  _[^_]{1,70}_")   # two spaces: the verse is indented four


def sin_glosas(lines):
    """Pollard's Herrick sets word-glosses under a poem, a block of entries like
    "  _Repullulate_, be born again." or "  _Anchus and rich Tullus._ Herrick is...",
    with indented continuations; they reached the poem as its last stanza, sometimes
    after a note ("  For an account of Alabaster
    see Notes..."). The verse is indented four spaces and the notes two: a block of
    two-space lines and their indented continuations, one of them an entry, goes."""
    out, i, n = [], 0, len(lines)
    while i < n:
        if not lines[i].strip():
            out.append(lines[i]); i += 1; continue
        j = i
        while j < n and lines[j].strip(): j += 1
        bloque = lines[i:j]
        if (re.match(r"^  \S", bloque[0]) and any(GLOSA.match(l) for l in bloque)
                and all(re.match(r"^  \S", l) or l.startswith('    ') for l in bloque)):
            i = j
            continue
        out.extend(bloque)
        i = j
    return out


def titulos_en_dos_lineas(lines):
    """A numbered heading in capitals that runs on to a second line ("336. HIS AGE,
    DEDICATED TO ... UNDER" / "THE NAME OF POSTHUMUS."): the parser took the heading
    for verse and the poem went into the one before. The two lines are joined."""
    out = list(lines)
    for k in range(len(out) - 1):
        a, b = out[k], out[k + 1]
        if (re.match(r"^\d{1,4}\. [A-Z][^a-z]{3,}$", a) and b.strip() and not b.startswith(" ")
                and b == b.upper() and re.search(r"[A-Z]{3}", b)):
            out[k], out[k + 1] = a.rstrip() + " " + b.strip(), ""
    return out


def sin_marcas_de_letra(lines):
    """Coleridge's Byron marks his notes with letters in brackets set against the word:
    "bared before thee[ri]". The parser dropped the brackets and kept the letters, so the
    app read "theeri". Only for books that mark notes this way: elsewhere a bracket against
    a word is the editor's conjecture ("Fate[s]", "C[lipseby] C[rew]")."""
    return [re.sub(r"(?<=\S)\[[a-z]{1,2}\]", "", l) for l in lines]


def sin_variantes(lines):
    """Hutchinson's Shelley follows a poem with its variant readings: "NOTES:" and then
    "_2 wert 1839; did 1824." up to the next blank line, sometimes more blocks of
    "_n" entries after it. Eight such blocks reached the app as a last stanza
    ("Love's Philosophy", "Mutability"). They go, and so do the line numbers set at
    the right margin as "_35", which the parser only knows without the underscore."""
    out, i, n = [], 0, len(lines)
    while i < n:
        if re.match(r"^NOTES?:\s*$", lines[i]):
            i += 1
            while True:
                while i < n and lines[i].strip(): i += 1
                k = i
                while k < n and not lines[k].strip(): k += 1
                if k < n and re.match(r"^_\d", lines[k]):
                    i = k
                    continue
                break
            continue
        out.append(re.sub(r"\s{2,}_\d{1,4}_?\s*$", "", lines[i]))
        i += 1
    return out


def sin_marcas(lines):
    """Transcriber's marks: Bryant's "THE MASSACRE AT SCIO. deg." (a degree sign standing for a
    note) reached the app as "The Massacre at Scio. Deg"; and emphasis set as *I* (Lanier) lost
    its closing mark to the parser and showed as "*I saw It". Blanked names ("R*k*r", "L**G")
    have letters on both sides of the asterisks and are left alone."""
    lines = [re.sub(r"(?<![\w*])\*([A-Za-z][^*\n]{0,40}?(?<=[\w.,!?']))\*(?![\w*])", r"\1", l) for l in lines]
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
