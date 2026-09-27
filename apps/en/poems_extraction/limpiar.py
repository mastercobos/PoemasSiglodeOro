#!/usr/bin/env python3
"""
limpiar.py - clean poems coming out of laurel_convert.py before they reach the app.

Laurel transcribes Project Gutenberg editions faithfully, and with them the
editions' clutter. seleccionar.py runs every poem through limpiar_poema():

  1. Transcriber markup, line by line: "--" for an em dash, _italic_, +bold+,
     |small caps|, drop capitals written "$E$ nuy", footnote markers (@, *, <1>,
     [L116], the letters Byron's edition glues on: "shrine,gj"), the braces that bracket triplets, William Barnes's [=o] for ō,
     page references "(p. 87)". Lines left with no letters are dropped.
  2. Stanzas that are not English verse: editors' notes and prefaces printed
     between poems (Pope's Canto I notes, Tennyson's "In 1830 and in 1842 edd."),
     Latin and Greek facing texts (Prudentius, Boethius), prose passages.
  3. Whole poems whose title says they are apparatus (Introduction, Notes...),
     or that lose most of their lines in steps 1-2.

It also fixes titles: "207. To Carnations" loses its number, and a bare section
title gets its work: "Canto I" becomes "Don Juan: Canto I" when the book is one
work, or is looked up in OBRA_A_MANO when the book is a collection.

seleccionar.py decides what to do with what this reports: it drops cut poems,
sections whose work is still unknown and poems with lines broken in two.

Heuristics, so check limpieza.md after a rebuild: it lists what was dropped.
"""
import re

# ---- 1. line markup ------------------------------------------------------- #

MACRON = {"a": "ā", "e": "ē", "i": "ī", "o": "ō", "u": "ū", "A": "Ā", "E": "Ē", "I": "Ī", "O": "Ō", "U": "Ū"}

PALABRAS_CORTAS = set("a i o ah am an as at be by do go he if in is it lo me my no of oh on or so to up us we ye".split())

SUSTITUCIONES = [
    (re.compile(r"\$(\w)\$ ?"), r"\1"),                        # $E$ nuy -> Enuy
    (re.compile(r"\[=([aeiouAEIOU])\]"), lambda m: MACRON[m.group(1)]),
    (re.compile(r"\[[A-Z]?\d+(:\d+)?\]"), ""),                 # [L116], [12], [8:2]
    (re.compile(r"<\d+>|(?<=\w)\(\d\)"), ""),                    # <1>, hero(1)
    (re.compile(r"\s*\(pp?\. ?\d+[;.]?\)"), ""),                # (p. 87)
    (re.compile(r"(?<![\w_])_([^_\n]+)_(?![\w_])"), r"\1"),     # _italic_
    (re.compile(r"(?<![\w+])\+([A-Za-z][^+\n]*)\+(?![\w+])"), r"\1"),  # +bold+
    (re.compile(r"\s*\|\s*\d+\s*$"), ""),                        # "| 120": line number
    (re.compile(r"\|([^|\n]+)\|"), r"\1"),                       # |Small Caps|
    (re.compile(r"[<>=]"), ""),                                 # <italic>, =bold=
    (re.compile(r"~"), ""),                                     # ~transliterated Greek~
    (re.compile(r"(?<=[\w,.;:!?'’”])@+|\$(?!\d)"), ""),         # footnote markers, $Vertue
    (re.compile(r"(?<=[A-Za-z,.;:!?'’”)])\*+(?=[\s,.;:!?)]|$)"), ""),  # dight** (not "Colonel *****")
    (re.compile(r"(?<=[A-Za-z][,.;:!?)])[A-Z]?[a-z]{1,2}$"), ""),   # footnote letters: "shrine,gj"
    (re.compile(r"(?<=[A-Za-z][,.;:!?)])[a-z]{1,2}(?=\s)"), ""),     # mid-line: "not.f In that"
    (re.compile(r"([A-Za-z][,.;:!?)](?:—|--))([a-z]{1,2})$"),     # after a dash only if not a word:
     lambda m: m.group(0) if m.group(2) in PALABRAS_CORTAS else m.group(1)),  # "shrine,—fs", not "—no"
    (re.compile(r"\s*[{}]+\s*$"), ""),                          # triplet braces
    (re.compile(r"[{}]"), ""),
    (re.compile(r"\s*\|\s*$"), ""),                             # stray | at line end
    (re.compile(r"-{2,}"), "—"),                                # -- is an em dash
    (re.compile(r"[ \t]{2,}"), " "),
]


def limpiar_linea(linea):
    for patron, reemplazo in SUSTITUCIONES:
        linea = patron.sub(reemplazo, linea)
    return linea.strip()


# ---- 2. stanzas that are not English verse ---------------------------------- #

LATIN = set("et est non quae ad cum sed qui nec ut per quod atque quam tibi mihi sunt nunc iam "
            "haec hic ille enim neque vel ubi quid inter sub te se tu ego deus".split())
INGLES = set("the and of to a is that with his he her my thy thou i it for".split())

APARATO = re.compile(
    r"\b(pp?\. ?\d|edd?\.(?!\w)|editions?\b|MSS?\b|[Cc]f\.|Compare\b|[Vv]ols?\. ?\d|[Ii]bid|"
    r"ll?\. ?\d|st\. ?\d|stanzas? \d|lines? \d|written in \d{4}|first (printed|published)|"
    r"reprinted|footnote|[Tt]ranslat(ed|ion) (of|from)|title-page|imprint|4to|8vo|12mo|fol\.|"
    r"See [A-Z]|^NOTES?\b|\bNo\. \d|\bv\. \d|[,—]p\. \d|\bi{1,3}\. \d|\b1[5-9]\d\d\b|present (reading|version|text)|Transcriber)")


def es_latin(lineas):
    palabras = re.findall(r"[a-zæœ]+", " ".join(lineas).lower())
    if len(palabras) < 6:
        return False
    lat = sum(p in LATIN or p.endswith(("orum", "arum", "ibus", "ntur")) for p in palabras)
    ing = sum(p in INGLES for p in palabras)
    return (lat >= 4 and lat > 1.5 * ing) or (lat >= 1 and ing == 0 and len(palabras) >= 10)


def es_griego(lineas):
    texto = " ".join(lineas)
    griego = len(re.findall(r"[Ͱ-Ͽἀ-῿]", texto))
    return griego > 0.3 * max(1, len(re.findall(r"\w", texto)))


def puntuacion_prosa(lineas):
    """Higher = more like prose wrapped at a fixed width, or an editor's note."""
    n = len(lineas)
    if n < 2:
        return 4 if APARATO.search(lineas[0]) else 1.5 if len(lineas[0]) > 90 else 0
    media = sum(len(l) for l in lineas) / n
    minuscula = sum(1 for l in lineas[1:] if re.match(r"[\"'‘“(\[]*[a-z]", l)) / (n - 1)
    sin_final = sum(1 for l in lineas[:-1] if not re.search(r"[.,;:!?)\"'’”\-—]$", l)) / (n - 1)
    aparato = sum(1 for l in lineas if APARATO.search(l)) / n
    digitos = sum(1 for l in lineas if re.search(r"\d", l)) / n
    corta = 1.5 if n <= 3 and aparato else 0  # "Reprinted without alteration in 1872."
    return (media > 58) + (media > 68) + 2 * minuscula + 1.5 * sin_final + 3 * aparato + digitos + corta


UMBRAL_PROSA = 3.5
UMBRAL_NOTA_SIN_METRO = 2.8  # no metre found and a citation in it: almost always a note


def motivo_estrofa(lineas, con_metro=True):
    if es_latin(lineas):
        return "latin"
    if es_griego(lineas):
        return "greek"
    cita = any(APARATO.search(l) for l in lineas)
    if puntuacion_prosa(lineas) >= (UMBRAL_NOTA_SIN_METRO if cita and not con_metro else UMBRAL_PROSA):
        return "prose"
    return None


# ---- 3. whole poems, and titles ------------------------------------------------ #

TITULO_APARATO = re.compile(
    r"(?i)^(introductory note|notes?|notices?\b|preface|prefatory|memoir|appendix|"
    r"glossary|index|contents|errata|observations on|biographical|bibliograph|editor'?s)")

SECCION = re.compile(
    r"(?i)^(canto|book|part|act|scene|chapter|fytte|fitt?|duan|epistle|eclogue|prologue|epilogue|"
    r"interlude|proem|argument|conclusion|dedication|introduction)\b[\s.,:ivxlcdm\d]*$|"
    r"^(the )?(first|second|third|fourth|fifth|sixth|seventh|eighth|ninth|tenth|eleventh|twelfth|last) "
    r"(canto|book|part)$")

COLECCION = re.compile(r"(?i)\b(poems|poetical works|works|ballads|lyrics|verses|songs|collected|selected|"
                       r"miscellan|hesperides|leaves of grass)\b")


# Sections of long poems in books that hold several works, so Laurel's work title
# can't name them. Each was confirmed against the heading printed above it in the
# Gutenberg source. (author, Laurel title, cleaned first line[:30]) -> title.
OBRA_A_MANO = {
    ('W. S. Gilbert', 'Part I', 'AT a pleasant evening party I '): 'Ferdinando and Elvira: Part I',
    ('W. S. Gilbert', 'Part II', '“Tell me, HENRY WADSWORTH, ALF'): 'Ferdinando and Elvira: Part II',
    ('Francis James Child', 'Part II', 'Sir Lancelott, & Sir Steven, b'): 'The Marriage of Sir Gawaine: Part II',
    ('Joanna Baillie', 'Part I', '"The wild winds bellow o\'er my'): 'Night Scenes of Other Times: Part I',
    ('Joanna Baillie', 'Part II', 'Loud roars the wind that shake'): 'Night Scenes of Other Times: Part II',
    ('Joanna Baillie', 'Part III', '"No rest nor comfort can I fin'): 'Night Scenes of Other Times: Part III',
    ('Henry Kirke White', 'Part I', "Pictured in memory's mellowing"): 'Childhood: Part I',
    ('Henry Kirke White', 'Part II', 'There are who think that Child'): 'Childhood: Part II',
    ('Isabella Valancy Crawford', 'Part I', "Max plac'd a ring on little Ka"): "Malcolm's Katie: Part I",
    ('Isabella Valancy Crawford', 'Part II', 'The South Wind laid his moccas'): "Malcolm's Katie: Part II",
    ('Isabella Valancy Crawford', 'Part III', 'The great farm house of Malcol'): "Malcolm's Katie: Part III",
    ('Isabella Valancy Crawford', 'Part IV', 'From his far wigwam sprang the'): "Malcolm's Katie: Part IV",
    ('Isabella Valancy Crawford', 'Part V', 'Said the high hill, in the mor'): "Malcolm's Katie: Part V",
    ('Isabella Valancy Crawford', 'Part VI', '"Who curseth Sorrow knows her '): "Malcolm's Katie: Part VI",
    ('Isabella Valancy Crawford', 'Part VII', 'Again rang out the music of th'): "Malcolm's Katie: Part VII",
    ('Isabella Valancy Crawford', 'Part II', 'From harpings and sagas and mi'): 'Gisli the Chieftain: Part II',
    ('Isabella Valancy Crawford', 'Part III', 'The shouting of Gisli, the chi'): 'Gisli the Chieftain: Part III',
    ('Isabella Valancy Crawford', 'Part IV', 'A ghost along the Hell-way spe'): 'Gisli the Chieftain: Part IV',
    ('John Addington Symonds', 'Part I', 'In the spring-time, when the s'): 'Flora and Phyllis: Part I',
    ('John Addington Symonds', 'Part III', 'On their steeds the ladies rid'): 'Flora and Phyllis: Part III',
    ('James Russell Lowell', 'Part III', 'Many a speculating wight'): 'The Unhappy Lot of Mr. Knott: Part III',
    ('Alexander Pope', 'Canto I', "What dire offence from am'rous"): 'The Rape of the Lock: Canto I',
    ('Alexander Pope', 'Canto II', "Not with more glories, in th' "): 'The Rape of the Lock: Canto II',
    ('Alexander Pope', 'Canto III', 'Close by those meads, for ever'): 'The Rape of the Lock: Canto III',
    ('Alexander Pope', 'Canto IV', 'But anxious cares the pensive '): 'The Rape of the Lock: Canto IV',
    ('Alexander Pope', 'Canto V', 'She said: the pitying audience'): 'The Rape of the Lock: Canto V',
    ('Felicia Hemans', 'Canto III', '“Fermossi al fin il cor che ba'): 'The Abencerrage: Canto III',
    ('Felicia Hemans', 'Part II', 'Hast thou a scene that is not '): 'The Widow of Crescentius: Part II',
    ('Felicia Hemans', 'Part II', 'Sweet is the gloom of forest s'): 'A Tale of the Secret Tribunal: Part II',
    ('Felicia Hemans', 'Part II', 'Wie diese treue liebe seele'): 'The Forest Sanctuary: Part II',
    # the same two, opening on the verse once parser/extraer.py has dropped their epigraphs
    ('Felicia Hemans', 'Canto III', 'Heroes of elder days! untaught'): 'The Abencerrage: Canto III',
    ('Felicia Hemans', 'Part II', 'Bring me the sounding of the t'): 'The Forest Sanctuary: Part II',
    ('Gerard Manley Hopkins', 'Part I', 'Thou mastering me'): 'The Wreck of the Deutschland: Part I',
    ('Gerard Manley Hopkins', 'Part II', "'Some find me a sword; some"): 'The Wreck of the Deutschland: Part II',
    ('Samuel Taylor Coleridge', 'Part I', "'Tis the middle of night by th"): 'Christabel: Part I',
    ('Samuel Taylor Coleridge', 'Part II', 'Each matin bell, the Baron sai'): 'Christabel: Part II',
    ('Samuel Taylor Coleridge', 'Part II', 'To see a man tread over graves'): 'The Three Graves: Part II',
    ('Thomas Percy', 'Part II', "Lowe lay'd by my sorrow, begot"): 'Willow, Willow, Willow: Part II',
    ('Thomas Percy', 'Part I', 'In Venice towne not long agoe'): 'Gernutus, the Jew of Venice: Part I',
    ('Thomas Percy', 'Part II', '"Of the Jews crueltie; setting'): 'Gernutus, the Jew of Venice: Part II',
    ('James Beattie', 'Book I', 'Ah! who can tell how hard it i'): 'The Minstrel: Book I',
    ('James Beattie', 'Book II', 'Of chance or change, O let not'): 'The Minstrel: Book II',
    ('Samuel Rogers', 'Canto I', 'Say who first pass’d the porta'): 'The Voyage of Columbus: Canto I',
    ('Samuel Rogers', 'Canto II', '“What vast foundations in the '): 'The Voyage of Columbus: Canto II',
    ('Samuel Rogers', 'Canto IV', '“Ah, why look back, tho’ all i'): 'The Voyage of Columbus: Canto IV',
    ('Samuel Rogers', 'Canto V', 'Yet who but He undaunted could'): 'The Voyage of Columbus: Canto V',
    ('Samuel Rogers', 'Canto VI', 'War and the Great in War let o'): 'The Voyage of Columbus: Canto VI',
    ('Samuel Rogers', 'Canto VII', 'What tho’ Despondence reign’d,'): 'The Voyage of Columbus: Canto VII',
    ('Samuel Rogers', 'Canto VIII', 'Twice in the zenith blaz’d the'): 'The Voyage of Columbus: Canto VIII',
    ('Samuel Rogers', 'Canto X', '—Then CORA came, the youngest '): 'The Voyage of Columbus: Canto X',
    ('Samuel Rogers', 'Canto XI', 'Her leaves at length the consc'): 'The Voyage of Columbus: Canto XI',
    ('Helen Maria Williams', 'Canto I', 'Where the pacific deep in sile'): 'Peru: Canto I',
    ('Helen Maria Williams', 'Canto II', "Flush'd with impatient hope, t"): 'Peru: Canto II',
    ('Helen Maria Williams', 'Canto III', 'Now stern Pizarro seeks the di'): 'Peru: Canto III',
    ('Helen Maria Williams', 'Canto IV', 'Now the stern partner of Pizar'): 'Peru: Canto IV',
    ('Helen Maria Williams', 'Canto V', 'In this sweet scene, to all th'): 'Peru: Canto V',
    ('Helen Maria Williams', 'Canto VI', 'At length Almagro, and Alphons'): 'Peru: Canto VI',
    ('William Makepeace Thackeray', 'Part I', 'At Paris, hard by the Maine ba'): 'The Chronicle of the Drum: Part I',
    ('William Makepeace Thackeray', 'Part II', '"The glorious days of Septembe'): 'The Chronicle of the Drum: Part II',
    ('Lord Byron', 'Canto I', '"—nessun maggior dolore,'): 'The Corsair: Canto I',
    ('Thomas Campbell', 'Part I', 'I’ll bid the hyacinth to blow,'): 'Caroline: Part I',
    ('Thomas Hood', 'Part II', 'The Scene is changed! No green'): 'The Elm Tree: Part II',
    ('Thomas Hood', 'Part III', 'The deed is done: the Tree is '): 'The Elm Tree: Part III',
    ('Thomas Hood', 'Part I', 'Some dreams we have are nothin'): 'The Haunted House: Part I',
    ('Thomas Hood', 'Part II', 'O, very gloomy is the House of'): 'The Haunted House: Part II',
    ('Thomas Hood', 'Part III', "'Tis hard for human actions to"): 'The Haunted House: Part III',
    ('Thomas Hood', 'Part I', 'Like a dead man gone to his sh'): 'The Forge: Part I',
    ('Thomas Hood', 'Part II', 'Idly watching the Furnace-flam'): 'The Forge: Part II',
    ('Percy Bysshe Shelley', 'Part II', 'There was a Power in this swee'): 'The Sensitive Plant: Part II',
    ('Percy Bysshe Shelley', 'Part III', 'Three days the flowers of the '): 'The Sensitive Plant: Part III',
    ('Percy Bysshe Shelley', 'Part II', 'O happy Earth! reality of Heav'): 'The Daemon of the World: Part II',
    ('Percy Bysshe Shelley', 'Canto I', 'When the last hope of trampled'): 'The Revolt of Islam: Canto I',
    ('Percy Bysshe Shelley', 'Canto II', 'The starlight smile of childre'): 'The Revolt of Islam: Canto II',
    ('Percy Bysshe Shelley', 'Canto III', "What thoughts had sway o'er Cy"): 'The Revolt of Islam: Canto III',
    ('Percy Bysshe Shelley', 'Canto IV', 'The old man took the oars, and'): 'The Revolt of Islam: Canto IV',
    ('Percy Bysshe Shelley', 'Canto V', 'Over the utmost hill at length'): 'The Revolt of Islam: Canto V',
    ('Percy Bysshe Shelley', 'Canto VI', 'Beside the dimness of the glim'): 'The Revolt of Islam: Canto VI',
    ('Percy Bysshe Shelley', 'Canto VII', 'So we sate joyous as the morni'): 'The Revolt of Islam: Canto VII',
    ('Percy Bysshe Shelley', 'Canto VIII', "'I sate beside the Steersman t"): 'The Revolt of Islam: Canto VIII',
    ('Percy Bysshe Shelley', 'Canto IX', "'That night we anchored in a w"): 'The Revolt of Islam: Canto IX',
    ('Percy Bysshe Shelley', 'Canto X', 'Was there a human spirit in th'): 'The Revolt of Islam: Canto X',
    ('Percy Bysshe Shelley', 'Canto XI', 'She saw me not—she heard me no'): 'The Revolt of Islam: Canto XI',
    ('Percy Bysshe Shelley', 'Canto XII', 'The transport of a fierce and '): 'The Revolt of Islam: Canto XII',
    ('Edgar Allan Poe', 'Part I', 'O! nothing earthly save the ra'): 'Al Aaraaf: Part I',
    ('Edgar Allan Poe', 'Part II', 'High on a mountain of enamelle'): 'Al Aaraaf: Part II',
    ('Edward Young', 'Book I', 'From lofty themes, from though'): 'The Force of Religion; or, Vanquished Love: Book I',
    ('Edward Young', 'Book II', 'Her Guilford clasps her, beaut'): 'The Force of Religion; or, Vanquished Love: Book II',
    ('Edward Young', 'Part I', 'The days how few, how short th'): 'Resignation: Part I',
    ('Edward Young', 'Part II', 'But what in either sex, beyond'): 'Resignation: Part II',
    ('Charles Churchill', 'Book I', "The clock struck twelve; o'er "): 'The Duellist: Book I',
    ('Charles Churchill', 'Book II', 'Deep in the bosom of a wood,'): 'The Duellist: Book II',
    ('Charles Churchill', 'Book III', 'Ah me! what mighty perils wait'): 'The Duellist: Book III',
    ('Charles Churchill', 'Book I', 'Far off (no matter whether eas'): 'Gotham: Book I',
    ('Charles Churchill', 'Book II', 'How much mistaken are the men '): 'Gotham: Book II',
    ('Charles Churchill', 'Book III', 'Can the fond mother from herse'): 'Gotham: Book III',
    ('Charles Churchill', 'Book I', 'With eager search to dart the '): 'The Ghost: Book I',
    ('Charles Churchill', 'Book II', 'A sacred standard rule we find'): 'The Ghost: Book II',
    ('Charles Churchill', 'Book III', 'It was the hour, when housewif'): 'The Ghost: Book III',
    ('Charles Churchill', 'Book IV', 'Coxcombs, who vainly make pret'): 'The Ghost: Book IV',
    ('William Lisle Bowles', 'Book I', 'Awake a louder and a loftier s'): 'The Spirit of Discovery by Sea: Book I',
    ('William Lisle Bowles', 'Book II', 'Oh for a view, as from that cl'): 'The Spirit of Discovery by Sea: Book II',
    ('William Lisle Bowles', 'Book III', 'My heart has sighed in secret,'): 'The Spirit of Discovery by Sea: Book III',
    ('William Lisle Bowles', 'Book IV', 'Stand on the gleaming Pharos, '): 'The Spirit of Discovery by Sea: Book IV',
    ('William Lisle Bowles', 'Book V', 'Such are thy views, DISCOVERY!'): 'The Spirit of Discovery by Sea: Book V',
    ('Mark Akenside', 'Book I', 'With what attractive charms th'): 'The Pleasures of Imagination: Book I',
    ('Mark Akenside', 'Book II', 'When shall the laurel and the '): 'The Pleasures of Imagination: Book II',
    ('Mark Akenside', 'Book III', 'What wonder therefore, since t'): 'The Pleasures of Imagination: Book III',
    ('Mark Akenside', 'Book I: 1757', "With what enchantment Nature's"): 'The Pleasures of Imagination (1757 revision): Book I',
    ('Mark Akenside', 'Book II: 1765', 'Thus far of Beauty and the ple'): 'The Pleasures of Imagination (1757 revision): Book II: 1765',
    ('Mark Akenside', 'Book III: 1770', 'What tongue then may explain t'): 'The Pleasures of Imagination (1757 revision): Book III: 1770',
}

# Byron's Giaour volume titles each stanza of two long poems with a mangled
# heading: "Canto II: Ge XII" (The Bride of Abydos, Canto II, stanza XII) and
# "Canto II: Canto II IV" (The Corsair). Checked against each canto's opening line.
TITULOS_A_MANO = [
    ("Lord Byron", re.compile(r"^Canto ([IVX]+): Ge ([IVXLC]+)$"), r"The Bride of Abydos: Canto \1, Stanza \2"),
    ("Lord Byron", re.compile(r"^Canto ([IVX]+): Canto \1 ([IVXLC]+)$"), r"The Corsair: Canto \1, Stanza \2"),
]

NUMERACION = re.compile(r"^\d+\.\s+(?=\S)")  # "207. To Carnations" (Herrick's Hesperides)


def titulo_completo(titulo, obra, edicion=None, autor=None, primera=""):
    """Laurel's work title can name only the first work in a book: Pope's is
    "The Rape of the Lock", but the edition is "..., and Other Poems" and also
    holds the Essay on Man's epistles. So both must look like a single work;
    otherwise the section is looked up in OBRA_A_MANO."""
    t = limpiar_linea(NUMERACION.sub("", titulo.strip()))
    for a, patron, nuevo in TITULOS_A_MANO:
        if a == autor and patron.match(t):
            return patron.sub(nuevo, t)
    if not SECCION.match(t):
        return t
    if obra and not COLECCION.search(obra) and not COLECCION.search(edicion or "") and obra.lower() not in t.lower():
        return "%s: %s" % (obra.strip(), t)
    return OBRA_A_MANO.get((autor, titulo.strip(), primera[:30]), t)


def seccion_sin_obra(titulo):
    """A title that is still only "Canto IV": nobody could tell which poem it belongs to."""
    return bool(re.match(r"(?i)(canto|book|part)\b[\s.,:ivxlcdm\d]*$", titulo))


def lineas_partidas(estrofas):
    """How many verse lines the source edition broke in two: a long line with no
    closing punctuation, then a short run-on starting in lower case."""
    n = 0
    for e in estrofas:
        for previa, linea in zip(e, e[1:]):
            if (len(previa) > 45 and not re.search(r"[.,;:!?)\"'’”\-—]$", previa)
                    and len(linea) < 25 and re.match(r"[a-z]", linea)):
                n += 1
    return n


# Lines corrected by hand, (author, line as cleaned) -> line. Checked against Gutenberg
# (2026-09-26). Two kinds only; nothing here modernises the text:
#  * the editions' footnote marks, pointing to notes the app doesn't show (Wheatley, Spenser,
#    Lazarus, Whittier, Harper, Barnes). Wheatley's mark on "Niobe" said the verse from there
#    to the end "is the Work of another Hand";
#  * Gutenberg's own slips in Tennyson's Maud, an asterisk typed for an apostrophe.
LINEAS_A_MANO = {
    ('Alfred Tennyson', 'I play*d with the girl when a child; she promised then to be fair.'): "I play'd with the girl when a child; she promised then to be fair.",
    ('Alfred Tennyson', "The red rose cries, *She is near, she is near;'"): "The red rose cries, 'She is near, she is near;'",
    ('Edmund Spenser', 'And steel-hed speare, and morion * on her hedd,'): 'And steel-hed speare, and morion on her hedd,',
    ('Edmund Spenser', 'And Iacob staffe ** in hand devoutly crost,'): 'And Iacob staffe in hand devoutly crost,',
    ('Emma Lazarus', 'Half of his immortality."* He needs'): 'Half of his immortality." He needs',
    ('Phillis Wheatley', '* "The queen of all her family bereft,'): '"The queen of all her family bereft,',
    ('Phillis Wheatley', "Who ere escap'd thee, but the saint * of old"): "Who ere escap'd thee, but the saint of old",
    ('Phillis Wheatley', "When loss to loss * ensu'd, and woe to woe,"): "When loss to loss ensu'd, and woe to woe,",
    ('John Greenleaf Whittier', "Our eyes to Pillow's ghastly stain. **"): "Our eyes to Pillow's ghastly stain.",
    ('Frances Ellen Watkins Harper', 'The Loyal Legion * band.'): 'The Loyal Legion band.',
    ('William Barnes', 'J. L., *T. D., at Meldonley.'): 'J. L., T. D., at Meldonley.',
}


# Found by hand; the heuristics above miss them. (author, title, opening words).
DESCARTAR_A_MANO = {
    # Biographies and a contents page, printed as verse because they quote it.
    ("Mark Akenside", "The Life of Akenside", "\"Led"),
    ("Robert Browning", "The Life of Browning", "And I myself went with the tale"),
    ("James Beattie", "The Life of Robert Blair", "O great maneater"),
    ("John Wilmot Rochester", "The Contents", "A Letter from Artemisa"),
    # Notes pages in the Rape of the Lock edition, each note too short to look like prose.
    ("Alexander Pope", "Canto V", "Painting the face was"),
    ("Alexander Pope", "Introduction", "2) learning, culture"),
    ("Alexander Pope", "Epistle", "An imaginary portrait of a mad poet"),
}
LINEAS_ESPURIAS = {
    ("John Donne", "one page which shall paste"),  # a marginal gloss printed inside Coryat's verses
}


def es_indice(estrofas):
    """A contents list: most lines are "IV Picture-Books in Winter" or "3. In Port"."""
    lineas = [l for e in estrofas for l in e]
    numeradas = sum(1 for l in lineas if re.match(r"^([IVXLC]+\.?|\d+\.)\s+[A-Z]", l))
    return len(lineas) >= 4 and numeradas > 0.6 * len(lineas)


def limpiar_poema(titulo, estrofas, obra=None, edicion=None, con_metro=True, autor=None):
    """Return (title, stanzas, dropped) where dropped is [(reason, text, where)],
    where being "start", "end" or "middle" of the poem.

    stanzas is None when the whole poem should go. con_metro=False (Laurel
    found no metre) makes the test stricter for stanzas that cite something."""
    if any(a == autor and t == titulo and estrofas[0][0].startswith(c) for a, t, c in DESCARTAR_A_MANO):
        return titulo, None, [("by hand", "\n".join(estrofas[0]), "start")]
    if es_indice(estrofas):
        return titulo, None, [("contents list", "\n".join(estrofas[0]), "start")]
    if TITULO_APARATO.match(titulo.strip()):
        return titulo, None, [("apparatus title", "\n".join(estrofas[0]), "start")]
    total = 0  # lines in English: a Latin original beside its translation is not a loss
    limpias, guardadas, cortes = [], [], []
    for i, e in enumerate(estrofas):
        lineas = [limpiar_linea(l) for l in e]
        lineas = [l for l in lineas if re.search(r"[^\W\d_]", l) and (autor, l) not in LINEAS_ESPURIAS]
        lineas = [LINEAS_A_MANO.get((autor, l), l) for l in lineas]
        if not lineas:
            continue
        motivo = motivo_estrofa(lineas, con_metro)
        if motivo not in ("latin", "greek"):
            total += len(lineas)
        if motivo:
            cortes.append((i, motivo, "\n".join(lineas)))
            continue
        limpias.append(lineas)
        guardadas.append(i)
    quedan = sum(len(e) for e in limpias)
    if not limpias or quedan < 0.5 * total:
        return titulo, None, [(m, t, "middle") for _, m, t in cortes]
    descartes = [(m, t, "start" if i < guardadas[0] else "end" if i > guardadas[-1] else "middle")
                 for i, m, t in cortes]
    return titulo_completo(titulo, obra, edicion, autor, limpias[0][0]), limpias, descartes

