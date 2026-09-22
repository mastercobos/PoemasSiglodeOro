# Logs

Chronology of the changes made in each prompt, newest last.
Format: date and time (local, UTC+8), the request, what changed.

Times for entries 1–3 were not recorded when they happened, so they show the
date only. From entry 4 on, times are taken from the system clock.

## Before this log

- 2026-09-19 12:31 — commit `bf70cf6` "wip: pre test-fixing": restructure into `packages/poemario_core` + `apps/es` + `apps/en`, add `CLAUDE.md`.
- 2026-09-19 19:07 — commit `d4ae544`: platform folders and notification setup for the English app.

## Session 2026-09-20

### 1. 2026-09-20 — Explain the state of changes and commits
- Read-only. Explained the branches (`main`, `monorepo`, `multipoemario`), the commit chain, and the 63 uncommitted files.
- Flagged: tracked `build/` directories, modified `poemas.json`, nothing pushed.

### 2. 2026-09-20 — "Let's do all of them"
- `.gitignore`: added `**/build/`; untracked `apps/es/build` and `packages/poemario_core/build`.
- Checked the `poemas.json` diff: four poems got explicit ids (derived id + `-2`). Verified the first copies keep their derived ids, so favourites are safe (rule 1).
- Commits: `f760ac1` stop tracking build output, `e934d6c` English app icons/splash/assets, `14a5c2e` core + Spanish app (tips feature, l10n, test fixes).
- Pushed `monorepo` to `origin/monorepo`.

### 3. 2026-09-20 — Run `flutter analyze` and `flutter test`
- `flutter analyze` in `packages/poemario_core`: no issues.
- `flutter test`: all 104 tests pass. The `widget_test.dart` hang from `CLAUDE.md` no longer occurs. `CLAUDE.md` "Known open items" is now out of date.
- Only the core package was checked, not `apps/es` or `apps/en`.

### 4. 2026-09-20 11:51 — Create this log file
- Created `logs.md` with the entries above. Not committed yet.

### 5. 2026-09-20 13:22 — How do notifications work / avoiding spam
- Read-only. Explained `PlanificadorAvisos`, `NotificacionesProvider` and `ServicioAvisos`: at most one notification per day at one chosen hour, opt-in, rescheduled in place.

### 6. 2026-09-20 13:24 — Performance test
- Added `packages/poemario_core/benchmark/rendimiento_test.dart` (not part of `flutter test`; run it by path). It times the real 5,071-poem anthology.
- Results (desktop VM): full load ~300 ms, planner/14-day series ~15 ms, single day pick ~1 ms. The cost is in `Poema.fromJson` (~137 ms), mostly the search index built by `plegarParaOrden`.
- No production code changed. Not committed.

### 7. 2026-09-20 13:31 — Optimise `plegarParaOrden`
- Rewrote `plegarParaOrden` (`lib/domain/orden_titulos.dart`) to scan code units and copy unchanged runs in bulk, instead of allocating a String per rune. Lowercasing is still done first, so output is meant to be identical.
- Added an equivalence test in `test/orden_titulos_test.dart` against a copy of the old implementation: every BMP code unit plus mixed strings (emoji, `İ`, `ẞ`).
- `flutter analyze` clean, all 106 tests pass (104 + 2 new).
- Benchmark: `fromJson` 138 → 31 ms, full load 301 → 120 ms, title folding 7.3 → 0.8 ms.
- Not committed.

### 8. 2026-09-20 13:41 — App icon instead of the book glyph on poems and share card
- `AppConfig`: new optional `assetOrnamento` (rule 6: the icon is app-specific, so it lives in config, not core).
- `Ornamento` (used above/below the poem and on the share card) draws that image as a small rounded badge (1.7× the old glyph size), falling back to the book glyph when unset or if the asset fails to load.
- `CompartirPoema` pre-caches the image before capturing, otherwise it would not be decoded in time and would be missing from the shared PNG.
- `apps/es` uses `gafas_bigote_splash_mini.png`, `apps/en` uses `quill_icon.png`; both declared in each pubspec.
- New `test/ornamento_test.dart` (3 tests). Core: analyze clean, 109 tests pass. Both apps analyze clean; `apps/es` web debug build succeeds.
- Not checked visually or on a device, and the share PNG was not inspected. Not committed.

### 9. 2026-09-20 14:04 — Format of the share card, and render one
- Explained the card: PNG, 800 logical px wide at pixel ratio 3 (2400 px), height follows the poem, opaque `fondoCompartir` background.
- Added `packages/poemario_core/benchmark/render_tarjeta_test.dart`, which renders `TarjetaCompartir` with the Spanish app's real fonts, icon and a Quevedo sonnet to `$SALIDA` (default `build/tarjeta`). Rendered light and dark to the session scratchpad (2400x2568 each).
- Correction to my previous answer: the card follows the reader's *current* theme (`Theme.of(context)` in `compartir`), so dark-mode readers get the dark card. I had said it always used the light palette.
- The first dark render was identical to the light one: harness bug (theme animation not advanced), not an app bug. Fixed in the test.
- Not committed.

### 10. 2026-09-20 14:13 — How the repository works; what is left for the English app
- Read-only. Explained the architecture and audited `apps/en`. Findings are in the reply; nothing changed.

### 11. 2026-09-20 14:17 — Notification channel and default hour common to all apps
- Removed `canalNotificaciones` and `horaNotificacionPorDefecto` from `AppConfig` and from both apps' `main.dart`.
- `ServicioAvisos.canalId` is now a constant `'poema_diario'` and `NotificacionesProvider.horaPorDefecto` a constant 09:00. The channel *name* shown to users still comes from the app name.
- Safe for the live app: notifications were first added in the restructure commit (`bf70cf6`), so 1.0.7 has no channel to orphan. English default hour changes 08:00 → 09:00.
- Core analyze clean, tests pass; both apps analyze clean. Not committed.

### 12. 2026-09-20 14:23 — Why Play fonts differ from Chrome
- Read-only investigation. Play 1.0.7+9 uses `google_fonts` (runtime download); the current code bundles fonts. Bundled Lato is v2.015 (latofonts.com) and Playfair Display is v1.203 variable. Explained in the reply; nothing changed.

### 13. 2026-09-20 14:28 — Existing users see no font difference
- Extracted the exact font files `google_fonts` 8.0.2 downloaded in release 1.0.7 (URLs and SHA-256 from the package's own tables; all 12 downloads verified) and bundled them in `apps/es/assets/fonts`: Lato Regular/Italic/Bold (Lato 1.x) and Playfair Display Regular/SemiBold/Bold (static). Removed the Lato 2.015 files and the Playfair variable font.
- `apps/es/pubspec.yaml`: explicit weights (600, 700) and a comment saying not to swap them.
- Coverage check: all 99 characters in the anthology and UI strings are in the fonts.
- Moved the card renderer to `apps/es/benchmark/` (loads the new fonts); it still renders correctly.
- Only fonts were addressed, not spacing or sizes elsewhere. Not checked on a device. Not committed.

### 14. 2026-09-20 14:46 — Fonts still look different in Chrome: spacing candidates
- Read-only. Compared the old `AppTextStyles` (7f46d97) with the new `PoemaTextStyles`. Verse style is identical; nav label is 11 → 10 px, small app-bar title has 18 and 17 px variants in the old code but only 17 now. Nothing changed. Told the user to fully restart (hot reload does not reload font assets).

## Session 2026-09-22

### 15. 2026-09-22 20:12 — `flutter build appbundle --release` failing with NPE in `signReleaseBundle`
- Diagnosed: `apps/es/android/app/build.gradle.kts` reads `rootProject.file("key.properties")`, but `key.properties` was sitting in `apps/es/android/app/`, not `apps/es/android/` (the Gradle root project, since `app` is an included subproject). File never found → signing config resolved to all-null → Gradle threw a bare NPE in `FinalizeBundleTask` while signing. The Gradle/AGP/Kotlin upgrade warnings in the output were unrelated noise.
- Fix: moved `apps/es/android/app/key.properties` → `apps/es/android/key.properties`. It's gitignored (both root and `apps/es/android/.gitignore`) and was never tracked, so this was a plain filesystem move, not a git change.
- Verified: `flutter build appbundle --release` now succeeds (`app-release.aab`, 57.4MB); `keytool -printcert` confirms it's signed with the expected `CN=Manuel Cobos` cert from `/home/manu/mi-clave.jks`.
- Committed `logs.md` at the user's request (this entry).

### 16. 2026-09-22 20:27 — Test the release build on device: app hung on the splash screen
- `flutter build apk --release` + `adb install`. The device already had v1.0.4 installed via Aurora Store, signed with a different key; asked the user, who chose to uninstall and install fresh (loses that copy's local favourites/settings — expected, and means this run doesn't exercise the v1→v2 migration).
- App hung forever on the native splash screen. `adb logcat` showed an unhandled `PlatformException(invalid_icon, ...)` from `ServicioAvisos.iniciar` → `bootstrap()`: `flutter_local_notifications` couldn't find the `ic_notification` drawable, so `bootstrap()` never completed and no UI ever built.
- Root cause: `ic_notification` is looked up by string name at runtime (`AndroidInitializationSettings('ic_notification')` in `servicio_avisos.dart:53`), so Flutter's default release R8 resource shrinker (on by default even with no `isMinifyEnabled`/`isShrinkResources` lines in `build.gradle.kts` — confirmed via `minifyReleaseWithR8`/`shrunk_resources_*` build outputs) sees no static reference and strips the drawable. This is a real bug that would have shipped completely broken; unrelated to the `key.properties` fix above.
- Fix: added `res/raw/keep.xml` with `tools:keep="@drawable/ic_notification"` (the standard Android fix for resources only reached by dynamic lookup) in both `apps/es/android/app/src/main/res/raw/keep.xml` and `apps/en/android/app/src/main/res/raw/keep.xml` — `apps/en` has the same `ic_notification.xml` and would hit the same crash later, even though `CLAUDE.md` says it has no `android/` folder yet (stale, like other "Known open items").
- Verified: rebuilt, `aapt2 dump resources` shows `ic_notification` retained, reinstalled over the same signing key, app now shows "Poemas del día" for 2026-09-22 with two poems (Lope de Vega *CVIII*, López de Mendoza *XLII*) — screenshot checked, no errors in logcat.
- Committed both fixes (this entry).
