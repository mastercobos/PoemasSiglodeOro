# CLAUDE.md

Context for Claude Code working in this repo.

## What this is

A white-label Flutter poetry anthology, published as one app per language from
a shared core.

```
packages/poemario_core/   All logic, screens, widgets. Zero branding.
apps/es/                  Antología Poética (Spanish) — the shipping app
apps/en/                  English anthology — not yet released
```

The Spanish app is live on Play at 1.0.7+9. The repo was just restructured from
a single Flutter project into this layout, and the code has never been run
against a compiler before now, so syntax slips and wrong test expectations are
expected. Real users' data is at stake — see "Rules" below.

Identifiers are Spanish (`Poema`, `autor`, `favoritos`), comments are English.
Keep it that way; do not rename things to English.

## Commands

```bash
cd packages/poemario_core && flutter analyze     # all errors in one pass
cd packages/poemario_core && flutter test        # the suite
cd apps/es && flutter run -d chrome              # quick visual check
```

Melos is configured but optional. Fonts are bundled in `apps/*/assets/fonts/`;
`google_fonts` was deliberately removed.

## Architecture

* `config/app_config.dart` — **the injection point.** Everything that differs
  between published apps: colours, fonts, app name, locale, sort strategy,
  notification channel. Each app's `main.dart` builds one and calls
  `bootstrap()`.
* `data/` — loading and persistence. `PoemaRepository` parses the asset off the
  UI isolate and returns an immutable `Anthology` (pre-grouped by author,
  pre-sorted, indexed by id). `Preferencias` wraps SharedPreferences and owns
  schema migrations.
* `domain/` — pure functions, no Flutter. `SeleccionDiariaService` picks the
  poems of the day deterministically; `PlanificadorAvisos` turns that into a
  notification schedule; `orden_titulos` handles sorting and diacritic folding.
* `providers/` — ChangeNotifiers over the above. No async work in constructors.
* `screens/`, `widgets/` — drawing only.
* `notifications/` — `AgendaAvisos` is the interface the provider talks to;
  `ServicioAvisos` is the plugin implementation.

## Rules

These are not style preferences. Breaking any of them ships a bug to real
users or breaks the multi-app split.

1. **Never change `Poema.id` generation** without a migration in
   `Preferencias.migrar`. Favourites and notification payloads persist these
   ids. The previous version used the JSON array index, which silently
   repointed saved favourites whenever the file was edited.
2. **Never touch the v1→v2 migration** except to fix a bug in it. It runs once
   per install and maps old integer favourites through each poem's position in
   `poemas.json`. It is the only code here that can destroy user data.
3. **No colour literals, `Colors.*` constants, font family names or Spanish
   strings in `lib/screens` or `lib/widgets`.** Colours come from
   `context.colores`, text styles from `context.tipos`, strings from
   `lib/l10n/*.arb`. `test/arquitectura_test.dart` enforces this.
4. **`domain/` stays pure.** No `BuildContext`, no Flutter imports beyond
   `foundation` and `TimeOfDay`. The notification scheduler calls this code
   with no UI running and for future dates.
5. **`SeleccionDiariaService` must stay deterministic.** Same pool, date and
   history → same poems, on any device, forever. Notifications scheduled two
   weeks ahead name the poem the app will show that morning; that only works
   because of this.
6. **Never add anything app-specific to `poemario_core`.** If the Spanish and
   English apps would want different values, it belongs in `AppConfig`.

## When a test fails

Assume the **test expectation** is wrong before assuming the production code
is, *except* for anything covered by rules 1–6, where the code is more likely
at fault and the consequences are worse. Never delete or skip a test to make
the suite green — if you believe a test is wrong, fix its expectation and say
why in your summary.

`test/support/harness.dart` builds fixtures and the provider stack;
`asset_falso.dart` mocks the asset bundle so the real repository runs under
test. `rootBundle` caches by asset key, so fixtures must clear it.

## Known open items

* `test/widget_test.dart` hangs: `pumpAndSettle` never settles, probably the
  nav pill's `AnimatedBuilder` in `root_screen.dart` or a provider notifying in
  a loop. Diagnose before changing anything else.
* `apps/en` has no `android/` or `ios/` folder yet.
* Native notification setup (manifest receivers, Gradle desugaring) is
  documented in `docs/notificaciones.md` and not yet applied.
* The notification small icon still points at `@mipmap/ic_launcher`, which
  Android renders as a white blob.

`docs/revision.md` maps every issue from the original code review to the file
that fixed it. Read it before concluding something looks odd for no reason.
