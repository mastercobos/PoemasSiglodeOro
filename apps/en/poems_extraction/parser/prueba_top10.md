# Parser test: the top 10 books through Laurel's own parser

> Record of the one-session test (2026-09-26) that led to `extraer.py`. The
> scripts it names (`correr.py`, `a_jsonl.py`, `muestra.py`...) became
> `extraer.py` and `seleccionar.libros_propios`; the numbers below are the
> test's, not the current build's (see `informe.md`).

A one-session test (2026-09-26) of "option 3": run Laurel's Gutenberg parser
ourselves and fix problems where the layout is still visible, instead of
patching Laurel's output afterwards.

The 10 books that give the most poems to the English asset (34% of it):
Herrick, Hemans, Burns, Dickinson, Longfellow, Dunbar, MacDonald, Barnes,
Whitman, Swift. Their Gutenberg files are in `../corpus/gutenberg/`.

## Files

| file | what it does |
|---|---|
| `correr.py` | runs Laurel's `parse_gutenberg` on chosen books with its per-book hints (`catalog.SLUG_META`), text corrections and hand fixes (`segmentation-findings.json`). With `FUENTE=1`, cleans the source first (`fuente.py`) and moves each hand fix onto the new split by the first lines of the stanzas it names; `NOSEG=1` skips the hand fixes |
| `fuente.py` | the two source-level rules: drop footnote bodies (`[Footnote n: ...]`, `[238] ...`), and raise to capitals any line standing alone that the book's own contents list names, so it is read as a title |
| `a_jsonl.py` | puts a run's books into a copy of `poems.jsonl` in place of Laurel's, for `seleccionar.py` |
| `muestra.py`, `banderas.py` | 20-poem sample per book from an asset; scan for suspicious lines |
| `comparar.py`, `detalle.py`, `porlibro.py` | compare two runs or two assets |

## Running it

`correr.py` and `fuente.py` must sit inside a copy of Laurel's `pipeline/`
folder, with the books in `sources/pg<n>.txt` and an empty `../site/data/works/`
beside it (the parser writes commentary there):

```
W=/some/work/dir
cp -r ../corpus/laurel-corpus/pipeline $W/lp && cp correr.py fuente.py $W/lp/
mkdir -p $W/lp/sources $W/site/data/works
for f in ../corpus/gutenberg/*.txt; do ln -s $(realpath $f) $W/lp/sources/pg$(basename $f); done
cd $W/lp && FUENTE=1 python3 correr.py ../../<path>/corpus/laurel-corpus/data/library.json $W/nuevo herrick-hesperides hemans-poems ...
python3 a_jsonl.py corpus/laurel-export/poems.jsonl $W/nuevo $W/B/poems.jsonl      # from poems_extraction/
python3 seleccionar.py --poems $W/B/poems.jsonl --asset $W/B/poemas.json --report $W/B/ranking.md --cleaning-report $W/B/limpieza.md
```

## What it found

* Laurel's parser, run here without changes, reproduces its published split
  (section counts equal or within 1-3). The asset built from it matches the
  current one to within 3 poems a book. The conversion is faithful.
* The two source rules changed 4 of the 10 books (Burns, Hemans, Swift,
  Barnes); the other 6 came out identical.
* Burns: 17 poems that the current asset has glued inside others come out on
  their own, among them "To a Louse" (inside "To Mr. M'Adam"), "The Auld
  Farmer's New-Year Morning Salutation" (inside "Scotch Drink"), "Lament of
  Mary, Queen of Scots" (inside the Burnet elegy); "To a Mouse" is 48 lines
  again (55 in the current asset).
* Hemans: about 25 poems lose trailing footnotes; "The Voice of Spring" comes
  out of "The Meeting of the Bards"; "Metastasio" splits into its 3 poems.
* Swift: about 15 poems lose trailing footnotes; the Sheridan exchange splits
  into its replies.
* Asset: 14,836 poems (current 14,797); Hemans +16, Burns +16.

Costs seen:

* Laurel's 688 hand fixes are keyed to its own split. 13 of the 90 for the
  changed books no longer matched; moving them by stanza first lines saved 7.
  Left to redo by hand: Hemans retitles `constantine-the-sleeper-of-marathon`,
  `wallenstein-the-revellers`, `true-hearted-an-hour-of-romance`; Burns
  `lassie-wi-the-lint-white-locks`; Swift `on-the-same-2`, `twelve-articles-xii`
  (Twelve Articles merges into the poem before it until this is done).
* Laurel's published output has poems its author added by hand that the shipped
  pipeline can't make: Barnes "Eclogue: The Times" and "Eclogue: The Veairies"
  are missing from our run.
* Poems the cleaner used to hold back can now get in with notes it doesn't
  catch (Hemans "The Last Constantine" ends in a prose note).
* Laurel's metre tag, used by `limpiar.py` as a hint, is copied by first line;
  poems new to our split take their book's default.
* Two bugs in the first version of the footnote rule (an unmatched bracket, and
  Swift's `[3]Appearances` markers at the start of verse lines) cut poems short.
  Both were caught by diffing the two runs; each rule needs that check.

Not tried: the other problems in the sample (Longfellow drama scenes with the
speakers stripped, "Poem III"-style titles, epigraphs with attribution lines,
"Upon Brock. Epig" truncations).
