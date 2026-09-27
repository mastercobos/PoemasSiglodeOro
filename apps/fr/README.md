# app_fr

Poésie française — the French anthology, built on `packages/poemario_core`.

Not yet released. What exists so far:

* `lib/main.dart` — the whole app: locale `fr`, name, palette, fonts.
* Android / iOS / web shells copied from `apps/en` (notification setup,
  desugaring and the `keep.xml` shrinker rule included), bundle id
  `com.manucobos.poesiefrancaise`.
* UI strings in `packages/poemario_core/lib/l10n/app_fr.arb`.

Still to do:

* The corpus. `assets/poemas/` expects the split format the English app uses:
  `indice.json` plus `textos/<n>.json` chunks (see `TextosPoemas` in core).
  Until it exists the app opens on the "couldn't load" screen.
* An icon of its own. `assets/icon/quill_icon.png` is the English quill as a
  placeholder; replace it, then `dart run flutter_launcher_icons` and
  `dart run flutter_native_splash:create`.
