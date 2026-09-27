# French anthology: poem extraction

```bash
python3 gutenberg.py                   # Gutenberg texts for the gaps (gutenberg_fr.json)
python3 wikisource.py                  # crawl every collection in recueils.py
python3 wikisource.py --auteur Hugo    # one author
python3 wikisource.py --page "Les Fleurs du mal (1868)/Allégorie"   # debug one page
python3 sonde.py "Some Wikisource page"    # what the crawler would see there
```

Stdlib only. API responses are cached in `corpus/` (gitignored), so a rerun
is offline and quick; delete the cache to pick up Wikisource corrections.

## Sources and rules

* **French Wikisource, through the MediaWiki API** (`action=parse`,
  `action=query`). Wikimedia throttles anonymous parse calls (429 with
  `Retry-After` ≈ 36 s), so poem pages are rendered ~20 per call and cut
  apart again; see `precharger()`.
* **Authors**: `recueils.py`. Each author's death year is read from Wikidata
  through their Wikisource author page, and anyone who died in 1900 or later is
  refused. `auteurs_verifies.json` records what Wikidata said. José-Maria de
  Heredia (d. 1905) is refused by this rule.
* **Only proofread text**: every scanned page a poem comes from must be at
  least "proofread" (level 3) on Wikisource. Below that it is raw OCR, and
  the poem is set aside (listed per collection in the report).
* **Project Gutenberg fills gaps**: a set-aside poem is replaced by the same
  poem from a Gutenberg plain-text book when `gutenberg.py` has one (same
  author, collection and first line or title). The transcribers' `_italics_`
  and flattened ligatures (coeur → cœur, from a fixed word list) are undone.
  Gallica is not used.
* **Only the verse**: headers, page numbers, footnote calls and footnotes,
  prefaces, notices, commentaries and other apparatus are dropped. Pages with
  no verse are listed in the report, never guessed at.
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
| `relu` | `true`: every scanned page proofread; `null`: no scan to check (typed-in page, or Gutenberg) |

`informe_wikisource.md` lists poems per author and collection, what was
replaced from Gutenberg, what was set aside (not proofread, second copies,
fragments), pages without verse and missing pages. Check it after every
rebuild.
