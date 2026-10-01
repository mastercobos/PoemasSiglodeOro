# French anthology: poem extraction

```bash
python3 gutenberg.py                   # Gutenberg texts for the gaps (gutenberg_fr.json)
python3 wikisource.py                  # crawl every collection in recueils.py
python3 wikisource.py --auteur Hugo    # one author
python3 wikisource.py --page "Les Fleurs du mal (1868)/Allégorie"   # debug one page
python3 sonde.py "Some Wikisource page"    # what the crawler would see there
python3 asset.py                       # poemas_fr.json -> ../assets/poemas (indice.json + textos/)
```

Stdlib only. API responses are cached in `corpus/` (gitignored), so a rerun
is offline and quick (~3 min); delete the cache to pick up Wikisource
corrections. Proofreading levels are cached per scanned page in
`corpus/cache/qualites.json`: delete it alone to pick up new proofreading.
The poems set aside as unproofread, with their scan pages, are dumped to
`corpus/cache/non_relus.json` for choosing hand checks (`VERIFIES`).

## Sources and rules

* **French Wikisource, through the MediaWiki API** (`action=parse`,
  `action=query`). Wikimedia throttles anonymous parse calls (429 with
  `Retry-After` ≈ 36 s), so poem pages are rendered ~20 per call and cut
  apart again; see `precharger()`.
* **Authors**: `recueils.py`. Each author's death year is read from Wikidata
  through their Wikisource author page, and anyone who died in 1926 or later is
  refused: free in France and the EU in 2026 even with the 30 extra years of
  a "mort pour la France". `auteurs_verifies.json` records what Wikidata said.
* **Editions dated before 1931** (free in the US), read from each collection's
  Wikisource header; a later reprint of a text printed before then is taken
  only when `recueils.py` says so (`reimpression`), a modern critical edition
  never. The report lists every collection's edition year.
* **Only proofread text**: every scanned page a poem comes from must be at
  least "proofread" (level 3) on Wikisource. Below that it is raw OCR, and
  the poem is set aside (listed per collection in the report).
* **Hand-checked exceptions**: a set-aside poem listed in
  `recueils.VERIFIES` comes in with the text in `verifies/`, which is its OCR
  with every error found against the scan corrected (punctuation, accents,
  a stanza split by a page break). A page whose text is not the edition on
  its scan (typed from another source) cannot be checked and stays out; the
  refusals are noted above `VERIFIES`.
* **Project Gutenberg fills gaps**: a set-aside poem is replaced by the same
  poem from a Gutenberg plain-text book when `gutenberg.py` has one (same
  author, collection and first line or title). The transcribers' `_italics_`
  and flattened ligatures (coeur → cœur, from a fixed word list) are undone.
  Gallica is not used.
* **Only the verse**: headers, page numbers, footnote calls and footnotes,
  prefaces, notices, commentaries and other apparatus are dropped, and so
  are an editor's note of the poem's source ("(Tiré de Thomson.)"). Pages
  with no verse are listed in the report, never guessed at.
* **Out**: verse plays and scenes from plays, prose poems, book-length
  narratives, poems of more than 300 verses (`VERS_MAX`; a few classics let in
  by name in `LONGS_PERMIS`), and translations (also when only the editor's note says so,
  "(Traduit de Gessner.)"). Per author, in the comment in `recueils.py`.
* **Dialogue poems keep their speakers**: a name Wikisource sets with the
  `personnage` template ("LA MUSE.") is a one-line stanza in capitals, which
  the app draws like a section numeral. A verse split between two speakers,
  whose first half Wikisource repeats invisibly to indent the second, is
  given once.
* **Spelling as printed**: old spelling (Villon, Ronsard, the Barbin La
  Fontaine) is kept, `&` included. Only layout and typography are normalised:
  one verse per line, a blank line between stanzas, French non-breaking
  spaces before `; : ! ?` kept, the long s (ſ) printed as s, a drop-cap
  opening word ("LE Roy") in normal case, titles printed in capitals set in
  sentence case (proper nouns kept, judged by how the corpus capitalises them).
* **One copy of each poem**: a poem already taken (same author and first
  line) is not taken again from another collection or edition.
* **Editions**: the one Wikisource has proofread, preferring the last the poet
  saw through the press. Each collection's choice is in `recueils.py`.

## Output: `poemas_fr.json`

A list of poems in reading order:

| Field | |
|---|---|
| `autor` | Author, as displayed |
| `titulo` | Title. Untitled or only numbered poems take their first line in « »; parts of a titled sequence are "Plusieurs sonnets, II" |
| `recueil` | Collection |
| `sections` | Section path inside the collection, e.g. `["Spleen et Idéal"]` |
| `texto` | The poem |
| `fuente` | `wikisource` or `gutenberg` |
| `edition` | Printed edition transcribed |
| `url` | Wikisource page (with `#n` when several poems share one page), or Gutenberg ebook |
| `relu` | `true`: every scanned page proofread; `null`: no scan to check (typed-in page, or Gutenberg); `"verifie"`: checked by hand against the scan (`VERIFIES`) |

`informe_wikisource.md` lists poems per author and collection, what was
replaced from Gutenberg, what was checked by hand, what was set aside (not
proofread, translations, second copies, fragments), pages without verse and
missing pages. Check it after every
rebuild.
