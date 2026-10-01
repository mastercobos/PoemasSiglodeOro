"""
The authors and collections wikisource.py crawls.

Each author: display name, Wikisource author page (its Wikidata item gives the
death date), and the collections to take. Each collection is a Wikisource
page: its table of contents is followed to the poems. Optional keys:

  titre      the collection's name in the output (default: the page name)
  edition    the printed edition Wikisource transcribes, for the record
  exclure    regexes on page titles to skip (prefaces, notes, prose)
  prefixe    follow the table of contents' links under this prefix instead
             of the page's own subpages; '*' follows every article it links
  titre_premier  on a page of several headed poems, the first one takes the
                 collection's name (the Testament, whose ballades follow it)
  garder_sections  keep verse found on section pages (epigraphs, dedications)
  complement  only poems the author does not already have (by title): a
              second edition that fills in what the first lacks
  titres_centres   a centred bold line is a poem title (no heading markup)
  separer_blocs    an empty paragraph between verse blocks separates two
                   untitled poems (titled by their first line)
  reprise_numerotee  a centred stanza numeral returns to the page's main poem
  sequences  regexes of pages holding a whole sequence (L'Olive's 115
             sonnets): split at headings like a collection's own page
  exclure_titres  regexes on the titles of poems inside such a page
  titres_simples  any centred line outside the verse is a poem title
                  (Guiffrey's Marot); "(De la Suyte)" notes are dropped
  vers_par_paragraphe  one verse per paragraph, a numbered heading and a
                       title paragraph above each poem (the Adolescence);
                       'sans_titre' when the poems have no title

Editions: the one Wikisource has proofread, and among those the last the poet
saw through the press. Spelling stays as that edition prints it.

Left out on purpose, per author, in the comment above each one: book-length
narrative poems (they read badly on a phone and would crowd out everything
else in the daily selection), prose poems, and translations.
"""

AUTEURS = [
    # The ballades and complaintes of d'Héricault's edition (1874), whose
    # rondeaux volume Wikisource does not have: the best-known rondeau is
    # taken from its own page. Out: the Latin and English poems.
    {'nom': 'Charles d’Orléans', 'wikisource': 'Auteur:Charles d’Orléans', 'recueils': [
        {'page': "Poésies complètes (Charles d'Orléans)", 'titre': 'Poésies', 'prefixe': '*',
         'exclure': [r'/Vie de Charles', r'/Glossaire$', r'^Poésies attribués']},  # attributed, not his
        {'page': 'Le temps a laissié son manteau'},  # a rondeau
    ]},
    # The Testament, the Lais and the separate ballades. The La Monnoye
    # edition's notes are on separate pages and never followed.
    {'nom': 'François Villon', 'wikisource': 'Auteur:François Villon', 'recueils': [
        {'page': 'Le Lais', 'titre': 'Le Lais'},
        {'page': 'Le Grand Testament', 'titre': 'Le Grand Testament', 'titre_premier': True, 'reprise_numerotee': True},
        {'page': 'Épître à Marie d’Orléans'},
        {'page': 'Ballade du concours de Blois'},
        {'page': 'Ballade des Menus Propos'},
        {'page': 'Ballade des Proverbes'},
        {'page': 'Ballade de bon conseil'},
        {'page': 'Ballade des pendus'},
    ]},
    # L'Adolescence clémentine and its Suite. Out: the eclogue and the Temple
    # de Cupido (long allegories), his Virgil and Ovid translations, the
    # Psalms.
    # Two layouts: the Adolescence's short poems one verse per paragraph under
    # numbered headings (vers_par_paragraphe), the Suite's under plain
    # centred titles (titres_simples).
    {'nom': 'Clément Marot', 'wikisource': 'Auteur:Clément Marot', 'recueils': [
        {'page': 'L’Adolescence Clémentine', 'exclure': [r'/La première eglogue', r'/Le Temple de Cupido',
                                                          r'/Le jugement de Minos', r'/Les tristes vers',
                                                          r'/(Rondeaux|Ballades|Chansons)$',
                                                          r'/Epitaphes$']},  # a layout not read yet
    ] + [
        {'page': f'L’Adolescence Clémentine/{s}', 'titre': 'L’Adolescence Clémentine', 'vers_par_paragraphe': v}
        for s, v in (('Ballades', True), ('Rondeaux', True), ('Chansons', 'sans_titre'))
    ] + [
        {'page': 'La Suite de l’Adolescence Clémentine', 'titres_simples': True, 'sequences': [r'.'],
         'exclure': [r'/L’Eglogue sur le trepas'],  # a long pastoral elegy
         'exclure_titres': [r'^Perdiderat']},  # Lucian's Amour fugitif, translated
    ]},
    # Élégies and Sonnets; the Débat de Folie et d'Amour is prose, and the
    # Escriz de divers poëtes are other poets' tributes to her.
    {'nom': 'Louise Labé', 'wikisource': 'Auteur:Louise Labé', 'recueils': [
        {'page': 'Œuvres de Louise Labé, édition Boy, 1887/I/04', 'titre': 'Élégies', 'edition': 'éd. Boy, 1887'},
        {'page': 'Œuvres de Louise Labé, édition Boy, 1887/I/05', 'titre': 'Sonnets', 'edition': 'éd. Boy, 1887'},
    ]},
    # Out: La Franciade (unfinished epic), the Abrégé de l'art poétique (prose).
    {'nom': 'Pierre de Ronsard', 'wikisource': 'Auteur:Pierre de Ronsard', 'recueils': [
        {'page': 'Les Amours (1553)', 'titre': 'Les Amours'},
        # Most of the 1553 scans are not proofread yet; the 1862 selection
        # (Didot, ed. Auguste Noël) is, and fills in part of the gap.
        {'page': 'Le premier livre des Amours, édition 1862', 'titre': 'Les Amours', 'edition': 'Didot, 1862'},
        {'page': 'Continuation des Amours (1555)', 'titre': 'Continuation des Amours', 'separer_blocs': True},
        {'page': 'Nouvelle Continuation des Amours (1556)', 'titre': 'Nouvelle Continuation des Amours', 'separer_blocs': True},
        {'page': 'Sur la mort de Marie (1578)', 'titre': 'Sur la mort de Marie', 'separer_blocs': True},
        {'page': 'Sonnets et Madrigals pour Astrée', 'separer_blocs': True},
        {'page': 'Le premier livre des Sonnets pour Hélène', 'titre': 'Sonnets pour Hélène, I'},
        {'page': 'Le second livre des Sonnets pour Hélène', 'titre': 'Sonnets pour Hélène, II'},
        {'page': 'Les Amours diverses', 'prefixe': '*'},
        {'page': 'Les Odes (Ronsard)', 'titre': 'Les Odes', 'exclure': [r'^Odes$', r'Avantentrée']},
        {'page': 'Le Bocage', 'prefixe': '*'},
        {'page': 'Les Meslanges', 'prefixe': '*'},
        {'page': 'Derniers Vers - Pierre de Ronsard', 'titre': 'Derniers Vers', 'prefixe': '*'},
        {'page': '« Soit que son or se crêpe lentement »'},
        {'page': 'Contre les bucherons de la forest de Gastine'},
        {'page': 'Hinne à la Nuit'},
        {'page': 'Hymne de la Mort (Ronsard)', 'titre': 'Hymne de la Mort'},
    ]},
    # Out: the Deffence (prose manifesto).
    {'nom': 'Joachim du Bellay', 'wikisource': 'Auteur:Joachim du Bellay', 'recueils': [
        {'page': 'L’Olive', 'sequences': [r'^L’Olive/L’Olive$'], 'titres_centres': True,
         'exclure': [r'/Dédicaces$', r'/Ioannes Auratus', r'/Salmonii Macrini']},  # Latin tributes by others
        {'page': 'Vers lyriques'},
        {'page': 'Œuvres de l’Invention de l’auteur', 'prefixe': '*'},
        {'page': 'Les Regrets (du Bellay)', 'titre': 'Les Regrets'},
        {'page': 'Les Antiquités de Rome'},
    ]},
    # Out: Les Larmes de saint Pierre (a long early poem, translated from
    # Tansillo).
    {'nom': 'François de Malherbe', 'wikisource': 'Auteur:François de Malherbe', 'recueils': [
        {'page': 'Poésies de François Malherbe', 'titre': 'Poésies', 'exclure': [r'/Les Larmes de Saint Pierre$']},
    ]},
    # Jannet's edition (1856). Its prose (letters, the Fragments d'une
    # histoire comique, the trial papers) holds no verse and is skipped.
    {'nom': 'Théophile de Viau', 'wikisource': 'Auteur:Théophile de Viau', 'recueils': [
        {'page': 'Œuvres complètes de Théophile', 'titre': 'Œuvres poétiques', 'edition': 'Jannet, 1856',
         'prefixe': 'Œuvres complètes de Theophile (Jannet)/'},
    ]},
    # The Fables: books I-VI from the original edition (Barbin, 1668, the
    # only one Wikisource has), books VII-XII from the complete 1874 one.
    # Out: the Contes (long bawdy verse tales) and the theatre.
    {'nom': 'Jean de La Fontaine', 'wikisource': 'Auteur:Jean de La Fontaine', 'recueils': [
        {'page': 'Fables de La Fontaine (éd. Barbin)', 'titre': 'Fables', 'edition': 'Barbin, 1668'},
        {'page': 'Fables de La Fontaine (éd. 1874)', 'titre': 'Fables', 'edition': 'Hachette, 1874',
         'complement': True},
    ]},
    # Almost nothing was printed in his lifetime; Derocquigny's selection
    # (1907) gives the Bucoliques, Élégies and Iambes from the manuscripts.
    {'nom': 'André Chénier', 'wikisource': 'Auteur:André Chénier', 'recueils': [
        {'page': 'Poésies choisies de André Chénier/Derocquigny, 1907', 'titre': 'Poésies', 'edition': 'Derocquigny, 1907'},
    ]},
    # Out: Jocelyn and La Chute d'un ange (book-length), La Mort de Socrate,
    # the Dernier Chant du pèlerinage d'Harold (long single poems).
    {'nom': 'Alphonse de Lamartine', 'wikisource': 'Auteur:Alphonse de Lamartine', 'recueils': [
        {'page': 'Méditations poétiques/Édition de 1860', 'titre': 'Méditations poétiques', 'edition': 'Œuvres complètes, 1860',
         'prefixe': 'Œuvres complètes de Lamartine (1860)/Tome 1/',
         'exclure': [r'/L’apparition de l’ombre de Samuël$']},  # a scene from his tragedy Saül
        {'page': 'Nouvelles Méditations poétiques/Édition de 1849', 'titre': 'Nouvelles Méditations poétiques',
         'edition': '1849', 'prefixe': '*',
         'exclure': [r'/L’apparition de l’ombre de Samuël$']},  # a scene from his tragedy Saül
        {'page': 'Harmonies poétiques et religieuses', 'edition': '1860', 'prefixe': '*',
         'exclure': [r'^Œuvres complètes de Lamartine \(1860\)$']},
        {'page': 'Recueillements poétiques'},
        {'page': 'Troisièmes Méditations poétiques/Édition de 1849', 'titre': 'Troisièmes Méditations poétiques',
         'edition': '1849', 'prefixe': '*'},
    ]},
    # Out: the Livre dramatique of Les Quatre Vents (two plays), manuscript
    # variants, La Fin de Satan, Dieu, Le Pape, La Pitié suprême, Religions et
    # religion, L'Âne (each one long poem); Océan vers and Le Verso de la page
    # (posthumous fragments, published 1942 and 1960).
    {'nom': 'Victor Hugo', 'wikisource': 'Auteur:Victor Hugo', 'recueils': [
        {'page': 'Odes et Ballades'},
        {'page': 'Les Orientales'},
        {'page': 'Les Feuilles d’automne'},
        {'page': 'Les Chants du crépuscule'},
        {'page': 'Les Voix intérieures'},
        {'page': 'Les Rayons et les Ombres'},
        # Half the poems of Les Châtiments have pages of their own, outside
        # the collection's subpages: every link is followed.
        {'page': 'Les Châtiments', 'prefixe': '*'},
        {'page': 'Les Contemplations'},
        {'page': 'La Légende des siècles', 'prefixe': '*',
         'exclure': [r'/Welf, Castellan d’Osbor$']},  # Welf: a play
        # The first series (1859) is a section page whose poems are not its
        # subpages. After the collective edition, so its text is the one kept.
        {'page': 'La Légende des siècles/1e série, 1859', 'titre': 'La Légende des siècles',
         'prefixe': 'La Légende des siècles/'},
        {'page': 'Les Chansons des rues et des bois', 'prefixe': '*'},
        {'page': 'L’Année terrible'},
        {'page': 'L’Art d’être grand-père', 'prefixe': '*'},
        {'page': 'Les Quatre Vents de l’esprit', 'exclure': [r'/Le Livre dramatique', r'/Manuscrit', r'/Illustrations']},
        {'page': 'Toute la lyre', 'exclure': [r'/Les manuscrits', r'/Variantes', r'/Historique']},
        {'page': 'Les Années funestes'},
        {'page': 'Dernière Gerbe'},
    ]},
    # Out: Héléna (long single poem). Éloa is part of Poèmes antiques et
    # modernes and stays with it; Estève's introduction and notes do not.
    {'nom': 'Alfred de Vigny', 'wikisource': 'Auteur:Alfred de Vigny', 'recueils': [
        {'page': 'Poèmes antiques et modernes/éd. Estève 1914', 'titre': 'Poèmes antiques et modernes',
         'edition': 'éd. Estève, 1914', 'prefixe': 'Poèmes antiques et modernes/'},
        {'page': 'Les Destinées (recueil)', 'titre': 'Les Destinées', 'edition': 'Lévy, 1864'},
    ]},
    # The Contes d'Espagne et d'Italie are inside the Premières Poésies. Out:
    # the three verse plays in it (La Coupe et les Lèvres, À quoi rêvent les
    # jeunes filles, Les Marrons du feu).
    {'nom': 'Alfred de Musset', 'wikisource': 'Auteur:Alfred de Musset', 'recueils': [
        {'page': 'Premières Poésies (Musset, éd. 1863)', 'titre': 'Premières Poésies', 'edition': 'Charpentier, 1863',
         'exclure': [r'/La Coupe et les Lèvres', r'/À quoi rêvent les jeunes filles', r'/Les Marrons du feu']},
        {'page': 'Poésies nouvelles (1836-1852)', 'titre': 'Poésies nouvelles'},
        {'page': 'Poésies posthumes (Musset)', 'titre': 'Poésies posthumes',
         # scenes from unfinished plays, the last two in prose
         'exclure': [r'/Le songe d’Auguste$', r'/La servante du roi$', r'/Faustine', r'/L’Âne et le Ruisseau$']},
    ]},
    # Out: the Élégies nationales (juvenilia) and his translations of Goethe.
    # Petits Châteaux de Bohême mixes prose and verse; only the verse is kept.
    {'nom': 'Gérard de Nerval', 'wikisource': 'Auteur:Gérard de Nerval', 'recueils': [
        {'page': 'Les Chimères'},
        # The odelettes (Fantaisie, Avril...) have pages of their own.
        {'page': 'Petits châteaux de Bohême (Didier, 1853)', 'titre': 'Petits Châteaux de Bohême', 'prefixe': '*',
         'exclure': [r'/Corilla$']},  # a play in prose
        {'page': 'Choix de poésies de Nerval', 'titre': 'Poésies diverses', 'edition': 'éd. Séché, 1907'},
    ]},
    # Out: Albertus and La Comédie de la Mort's title poem (long narratives),
    # the prose.
    {'nom': 'Théophile Gautier', 'wikisource': 'Auteur:Théophile Gautier', 'recueils': [
        {'page': 'Premières Poésies (Gautier)', 'titre': 'Premières Poésies', 'prefixe': '*',
         'exclure': [r'Albertus', r'Préface']},
        {'page': 'La Comédie de la Mort', 'titre': 'La Comédie de la Mort',
         'exclure': [r'/Portail$', r'/La Vie dans la Mort$', r'/La Mort dans la Vie$']},
        {'page': 'Œuvres de Théophile Gautier/Lemerre, 1890/España', 'titre': 'España', 'edition': 'Lemerre, 1890'},
        {'page': 'Émaux et Camées'},
    ]},
    {'nom': 'Marceline Desbordes-Valmore', 'wikisource': 'Auteur:Marceline Desbordes-Valmore', 'recueils': [
        {'page': 'Poésies (Desbordes-Valmore, 1830)/Idylles', 'titre': 'Idylles', 'edition': 'Boulland, 1830',
         'prefixe': 'Poésies (Desbordes-Valmore, 1830)/'},
        {'page': 'Poésies (Desbordes-Valmore, 1830)/Élégies', 'titre': 'Élégies', 'edition': 'Boulland, 1830',
         'prefixe': 'Poésies (Desbordes-Valmore, 1830)/'},
        {'page': 'Poésies (Desbordes-Valmore, 1830)/Romances', 'titre': 'Romances', 'edition': 'Boulland, 1830',
         'prefixe': '*', 'exclure': [r'^Romances \(Marceline Desbordes-Valmore\)$']},  # another edition's index
        {'page': 'Les Pleurs'},
        {'page': 'Pauvres fleurs (éd. Dumont 1839)', 'titre': 'Pauvres fleurs', 'edition': 'Dumont, 1839',
         'prefixe': 'Pauvres fleurs/'},
        {'page': 'Bouquets et prières'},
        {'page': 'Poésies inédites (Desbordes-Valmore, 1860)', 'titre': 'Poésies inédites', 'edition': 'Fick, 1860',
         'prefixe': 'Poésies inédites (Marceline Desbordes-Valmore)/'},
        # Not in Wikisource's copy of the 1860 book; transcribed from Lemerre's.
        {'page': 'Les Séparés', 'edition': 'Lemerre'},
    ]},
    # The 1868 Fleurs du mal (the last text Baudelaire prepared) plus Les
    # Épaves, which holds the six poems condemned in 1857. Out: the Petits
    # Poèmes en prose (prose poems).
    {'nom': 'Charles Baudelaire', 'wikisource': 'Auteur:Charles Baudelaire', 'recueils': [
        {'page': 'Les Fleurs du mal (1868)', 'titre': 'Les Fleurs du mal', 'edition': 'Michel Lévy, 1868',
         'exclure': [r'/Appendice']},
        {'page': 'Les Épaves (Baudelaire)', 'titre': 'Les Épaves', 'edition': '1866'},
    ]},
    # Out: the two plays, Les Érinnyes and L'Apollonide. The dialogue poems
    # (Hélène, Niobé) stay, with their speakers' names.
    {'nom': 'Leconte de Lisle', 'wikisource': 'Auteur:Leconte de Lisle', 'recueils': [
        {'page': 'Poèmes antiques', 'edition': 'Lemerre, 1891'},
        {'page': 'Poèmes barbares', 'edition': 'Lemerre', 'prefixe': '*'},
        {'page': 'Poèmes tragiques', 'edition': 'Lemerre, 1886', 'prefixe': '*',
         'exclure': [r'/Les Érinnyes']},  # a tragedy, staged in 1873
        {'page': 'Derniers Poèmes', 'edition': 'Lemerre, 1895',
         'exclure': [r'/L’Apollonide$']},  # a lyric drama in scenes
    ]},
    # The main books of verse. Out: the plays (Gringoire and the rest), the
    # prose.
    {'nom': 'Théodore de Banville', 'wikisource': 'Auteur:Théodore de Banville', 'recueils': [
        {'page': 'Les Cariatides (Théodore de Banville)', 'titre': 'Les Cariatides'},
        {'page': 'Les Stalactites (Banville)', 'titre': 'Les Stalactites'},
        {'page': 'Odelettes (Banville)', 'titre': 'Odelettes'},
        {'page': 'Odes funambulesques/1874', 'titre': 'Odes funambulesques', 'edition': 'Lemerre, 1874'},
        {'page': 'Les Exilés (Banville)', 'titre': 'Les Exilés'},
        {'page': 'Trente-six Ballades joyeuses', 'exclure': [r'/Histoire de la Ballade']},  # Asselineau's essay
        {'page': 'Rondels composés à la manière de Charles d’Orléans', 'titre': 'Rondels'},
    ]},
    # José-Maria de Heredia was on the list; Wikidata gives his death as
    # 1905, after the cut-off, so he is refused (kept here so the report says
    # so rather than silently leaving him out).
    {'nom': 'José-Maria de Heredia', 'wikisource': 'Auteur:José-Maria de Heredia', 'recueils': [
        {'page': 'Les Trophées'},
    ]},
    # Out: Les Amies, Femmes, Hombres (erotica), the Sonnet du Trou du Cul.
    {'nom': 'Paul Verlaine', 'wikisource': 'Auteur:Paul Verlaine', 'recueils': [
        {'page': 'Poèmes saturniens (1866)', 'titre': 'Poèmes saturniens', 'edition': 'Lemerre, 1866'},
        {'page': 'Fêtes galantes (1891)', 'titre': 'Fêtes galantes', 'edition': 'Vanier, 1891'},
        {'page': 'La Bonne Chanson (1891)', 'titre': 'La Bonne Chanson', 'edition': 'Vanier, 1891'},
        {'page': 'Romances sans paroles (1891)', 'titre': 'Romances sans paroles', 'edition': 'Vanier, 1891'},
        {'page': 'Sagesse (1893)', 'titre': 'Sagesse', 'edition': 'Vanier, 1893'},
        {'page': 'Jadis et naguère (1884)', 'titre': 'Jadis et naguère', 'edition': 'Vanier, 1884'},
        {'page': 'Amour (Verlaine)', 'titre': 'Amour'},
        {'page': 'Parallèlement'},
        {'page': 'Bonheur (Verlaine)', 'titre': 'Bonheur'},
        {'page': 'Chansons pour elle'},
        {'page': 'Liturgies intimes'},
        {'page': 'Odes en son honneur'},
        {'page': 'Élégies (Verlaine)', 'titre': 'Élégies', 'prefixe': '*',
         'exclure': [r'^Élégies$', r'^Œuvres complètes de Paul Verlaine']},
        {'page': 'Dans les limbes'},
        {'page': 'Épigrammes (Verlaine)', 'titre': 'Épigrammes', 'prefixe': 'Épigrammes/'},
        {'page': 'Chair'},
        {'page': 'Invectives'},
        {'page': 'Dédicaces'},
    ]},
    # Out: the monologues and saynètes (prose and comic sketches for the
    # stage), the science.
    {'nom': 'Charles Cros', 'wikisource': 'Auteur:Charles Cros', 'recueils': [
        {'page': 'Le Coffret de santal (éd. 1879)', 'titre': 'Le Coffret de santal', 'edition': 'Tresse, 1879'},
        {'page': 'Le Collier de griffes'},
    ]},
    # Les Amours jaunes, his one book (1873).
    {'nom': 'Tristan Corbière', 'wikisource': 'Auteur:Tristan Corbière', 'recueils': [
        {'page': 'Les Amours jaunes', 'prefixe': '*'},
    ]},
    # The Poésies and the 1872 verse. Out: Une saison en enfer and the
    # Illuminations (prose poems), Les Stupra and the Album zutique (obscene parodies).
    {'nom': 'Arthur Rimbaud', 'wikisource': 'Auteur:Arthur Rimbaud', 'recueils': [
        {'page': 'Poésies (Rimbaud)/éd. Vanier, 1895', 'titre': 'Poésies', 'edition': 'Vanier, 1895'},
        # The verse of 1872 (L'Éternité, Ô saisons, ô châteaux), first printed
        # at the end of the 1886 Illuminations; the prose poems around it hold
        # no verse and are skipped.
        {'page': 'Illuminations (éd. 1886)', 'titre': 'Derniers vers', 'edition': 'La Vogue, 1886'},
    ]},
    # Out: Le Concile féerique (a verse play), the Moralités légendaires
    # (prose).
    {'nom': 'Jules Laforgue', 'wikisource': 'Auteur:Jules Laforgue', 'recueils': [
        {'page': 'Poésies complètes de Jules Laforgue', 'titre': 'Poésies', 'exclure': [r'/Le Concile féerique']},
        {'page': 'Des Fleurs de bonne volonté'},
    ]},
    # The 1899 Deman edition, the one Mallarmé prepared. Out: the Poe
    # translations, Igitur and the Divagations (prose), Vers de circonstance.
    {'nom': 'Stéphane Mallarmé', 'wikisource': 'Auteur:Stéphane Mallarmé', 'recueils': [
        {'page': 'Poésies (Mallarmé)/Édition 1899', 'titre': 'Poésies', 'edition': 'Deman, 1899',
         'titres_centres': True, 'separer_blocs': True},
    ]},
]


# Hand corrections to single poems, (author, title) -> [(regex, replacement)],
# applied to the finished text. Each regex must match exactly once, so a
# correction that no longer applies (the source was fixed) stops the build.
CORRECTIONS = {
    # Dante's Italian lines and their French prose translation, printed as
    # the epigraph: not Hugo's verse. The poem opens at "Murs, ville,".
    ('Victor Hugo', 'Les Djinns'): [(r'(?s)\A.*?\n\n(?=Murs, ville,)', '')],
    # Two alexandrines run together on one line.
    ('Alphonse de Lamartine', 'Épitaphe des prisonniers français'): [
        (r'rêve\. (?=Patience)', 'rêve.\n')],
}


# Poems whose Wikisource scans are not proofread yet (so wikisource.py sets
# them aside), let in after reading them against the scan by hand: (author,
# start of the first verse) -> the file in verifies/ holding the text as the
# scan prints it (the OCR with every error found corrected). An entry that
# matches nothing stops the build: the poem was proofread since (drop the
# entry and its file) or its first line changed.
#
# Checked and refused: Ronsard's « Ciel, air et vents » (Les Amours, 1553),
# whose Wikisource text is the later revised version, not the 1553 scan it
# sits on; Marot's Adolescence clémentine, typed from another edition than
# its 1547 scans (other spelling and punctuation throughout).
VERIFIES = {
    ('Pierre de Ronsard', 'Quand vous serez bien vieille'): 'ronsard-quand-vous-serez-bien-vieille.txt',
    ('Pierre de Ronsard', 'Comme on voit sur la branche'): 'ronsard-comme-on-voit-sur-la-branche.txt',
    ('Pierre de Ronsard', 'Je vous envoye un bouquet'): 'ronsard-je-vous-envoye-un-bouquet.txt',
    ('Pierre de Ronsard', 'Je n’ay plus que les os'): 'ronsard-je-n-ay-plus-que-les-os.txt',
    ('Pierre de Ronsard', 'O Fontaine Bellerie'): 'ronsard-o-fontaine-bellerie.txt',
    ('Pierre de Ronsard', 'Quand je suis vingt ou trente mois'): 'ronsard-quand-je-suis-vingt-ou-trente-mois.txt',
    ('Victor Hugo', 'Oh ! combien de marins'): 'hugo-oceano-nox.txt',
    ('Victor Hugo', 'Puisque j’ai mis ma lèvre'): 'hugo-puisque-j-ai-mis-ma-levre.txt',
    ('Victor Hugo', 'L’été, lorsque le jour'): 'hugo-nuits-de-juin.txt',
    ('Victor Hugo', 'Dans les vieilles forêts'): 'hugo-a-albert-durer.txt',
}
