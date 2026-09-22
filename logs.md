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

### 17. 2026-09-22 20:49 — Check notifications and the favourites migration on device
- Notifications: enabled the daily reminder via Ajustes (accidentally, while fumbling tap coordinates — flagged to the user), then deliberately set the hour ~1 minute ahead to force a real firing instead of waiting a day. Confirmed via `dumpsys alarm` that `PlanificadorAvisos` had scheduled a real 14-day `AlarmManager` series (today, tomorrow, day after, all at the chosen hour). The near-term alarm fired on schedule (target 20:35:00, detected 20:35:53) with the correct content — "Poema del día - CVIII - — Lope de Vega", matching the in-app daily poem — and no crash, confirming the `ic_notification` fix from entry 16 holds under real delivery, not just at resource-compile time.
- Favourites migration: built the actual pre-restructure app (commit `400ecf7`, before the monorepo split) in a worktree at `/tmp/poemario-old-v1` (now removed), signed with the same keystore so it could upgrade in place. Installed it fresh, favourited two real poems through its UI (Jacinto Polo de Medina's *A una hermosura que murió de repente con un reloj en la mano*, Quevedo's *Descubre quién lleva los premios de las victorias marciales*), then `adb install -r`'d the current `1.1.0+10` build over it without uninstalling. Logcat showed `Migrados 2/2 favoritos a ids estables`, and the Favoritos screen showed both poems correctly after the upgrade — the v1→v2 migration (rule 2) works correctly against real data, not just in the test suite.
- Also confirmed rule 1 empirically as a side effect: since ids weren't touched, the migrated favourites still resolved to the right poems.
- Left the device as-is afterward at the user's request: daily reminder still on with hour set to ~20:35, and the two test favourites still saved. Not committed (no source changes this entry).

### 18. 2026-09-22 20:58 — Author names hard to read in Índice/Ajustes
- `autorTarjeta` (`packages/poemario_core/lib/theme/poema_theme.dart`) used the bold display serif (Playfair Display) at 17px — fine as a one-off heading, but hard to read repeated down a scrolling list. Switched its `fontFamily` from `display` to `body` (Lato), kept bold weight and size. Single shared style, so Índice, Ajustes and Favoritos all picked up the fix at once (all three already used `autorTarjeta`).
- `flutter analyze` clean, all 109 tests pass (the `widget_test.dart` hang `CLAUDE.md` still lists as a known open item did not reproduce here either — second confirmation this doc entry is stale).
- Verified visually: ran `flutter run -d chrome` on port 8765, user checked Índice/Ajustes themselves in the opened Chrome window and confirmed it reads better. No screenshot tooling was available in this environment to verify it myself (no browser-automation tool wired up despite being listed, no CDP/websocket client, no screenshot utility).
- Committed as `7fc31af` at the user's request.

### 19. 2026-09-22 22:51 — Launch roadmap for both apps/both stores; iOS AppDelegate fix for the Spanish app
- Audited both apps directly (not from `CLAUDE.md`'s "Known open items", which had already been shown stale twice this session) and built a checklist artifact, [Store Launch Tracker](https://claude.ai/artifact/STCanLphD2DzSm9SFFdoN9) (also saved at `docs/store-launch-tracker.html`, self-publishing via the `artifact` capability so checked state persists).
- Findings that shaped it: both apps have real `ios/` folders (contradicts the stale doc); `apps/es/ios/Runner/AppDelegate.swift` was missing the `UNUserNotificationCenter` delegate registration that `apps/en`'s already has; `apps/en/assets/poemas.json` has only 8 placeholder poems (Shakespeare, Blake, Dickinson, Wordsworth) against the Spanish app's ~25k-line anthology; `apps/en`'s fonts (EBGaramond, SourceSans3) were never bundled — the pubspec font block is entirely commented out as `# TEMP-FONTS (font files missing)`; no release keystore exists yet for `com.manucobos.englishverse`; no `DEVELOPMENT_TEAM` is committed in either app's Xcode project, on either side of the restructure.
- User said they'd already had iOS signing working and uploads going out before the monorepo restructure, and asked whether to pull in the pre-restructure `ios/` folder. Checked instead of assuming: diffed `400ecf7`'s `ios/` (the commit right before the restructure, same one used for the Android migration test in entry 17) against `apps/es/ios/` — `CODE_SIGN_STYLE`, bundle id and `Info.plist` are identical, and neither side ever committed `DEVELOPMENT_TEAM` (that's local Xcode/Apple-ID state, keyed to the bundle id, not the folder). Concluded no swap was needed — reusing the older Flutter-tooling-vintage project would have been the riskier move — and said so.
- Fix: added the missing delegate registration to `apps/es/ios/Runner/AppDelegate.swift`, matching the working `apps/en` version and the exact snippet in `docs/notificaciones.md`. Not compiled or verified — no Xcode/macOS available in this environment; needs a real build on a Mac to confirm.
- Committed as `769639f` at the user's request (this session — see entry 20 for the exact hash).

### 20. 2026-09-22 23:09 — Codemagic clarification, real build error, docs/codemagic.md
- User clarified iOS updates go through Codemagic (web dashboard, no committed config file — confirmed via git history), with Xcode only ever needed for one-time initial signing. Revised the guidance: the real fix needed is re-pointing Codemagic's workflow working directory at `apps/es` (moved there by the restructure), not "get a Mac" or "set up signing from scratch" as the tracker previously said.
- Wrote `docs/codemagic.md`: how to push an update, where signing lives (Codemagic/Apple-Developer account level, independent of repo layout), the monorepo working-directory gotcha, and a known-gotcha section for the agreement error below.
- Mid-turn, the user pasted a real Codemagic build log: `fetch-signing-files` failed with `403 A required agreement is missing or has expired`. Diagnosed as Apple blocking all App Store Connect API access account-wide until the Account Holder re-accepts a pending agreement (likely Paid Applications, given the app has IAP tips) directly in the App Store Connect web UI — no API workaround exists by design. Confirmed unrelated to the monorepo restructure: Codemagic had already correctly resolved the bundle id and reached Apple's API before hitting it, so the working-directory fix looks fine on its own.
- Also mid-edit, the live tracker artifact got a conflicting publish from the user's own open tab (they checked "Enrol in the Apple Developer Program" while I was editing) — routine `artifact` capability conflict, not an error; merged by re-applying that same checkbox state locally before republishing.
- Updated the tracker: corrected the Spanish-app-iOS group's badge from "new" to "update" (it's already live — I'd mis-stated this originally), rewrote its steps around Codemagic instead of generic Xcode setup, and added the Apple-agreement item to the shared prerequisites group.
- Committed `docs/codemagic.md` and the tracker update alongside the AppDelegate.swift fix from entry 19, in `769639f`.

### 21. 2026-09-23 00:20 — English anthology extraction: designing the data, and a share-card gap it surfaced
- User pointed at `apps/en/poems_extraction/laurel_convert.py`, an already-written (not by me this session) converter for the [Laurel corpus](https://github.com/laurel-corpus/laurel-corpus) — TEI XML poetry, only the text and factual metadata exported (title, author, dates, source), Laurel's own CC BY-SA apparatus (scansion, rhyme lettering, metre) deliberately excluded. Confirmed via the corpus's own `LICENCE`: poem texts are public domain (pre-1931, sourced from Project Gutenberg).
- Cloned the real corpus and ran the script (default filter: author died before 1926) to get current numbers instead of trusting the stale `gap_report.md` already sitting in that folder: **13,020 poems across 277 authors** — comfortably more than the Spanish app's 5,071.
- Found a real shape mismatch worth designing around: the Spanish anthology is almost entirely 9–14 line poems (5,050 of 5,071); Laurel's pool spans much wider, with over 5,000 poems past 30 lines and a single author (Herrick) alone accounting for ~11% of the pool.
- Asked the user to choose a length cap / author cap / target scale via AskUserQuestion; they rejected the framing and asked to clarify instead — said to test with the full pool, but raised a real concern: the share-card widget (`TarjetaCompartir`) had no height cap at all, and every poem the shipping Spanish app has ever had is ≤14 lines, so long-poem sharing was untested territory.
- Discussed two fixes: (1) fall back to plain-text share above a threshold, using the already-existing error-recovery path: rejected — user pointed out people can already copy text, and a plain-text dump is a worse teaser than a card. (2) Preview the card itself (first stanza or first 4 lines + "…") for long poems, same idea `poema.versos.take(4)` already uses on the home screen's preview cards: **chosen**, on the condition that the app's own signature stays visibly on the card so it reads as an invitation, not a cut-off.
- Fix: `TarjetaCompartir` now shows the whole poem under 14 verses (matching production's proven range) and previews above it (first stanza if ≤8 lines, else first 4 verses, plus a "…" mark in the accent colour) — computed live from `poema.estrofas`, not baked into extracted data, so it also protects the Spanish app against any future long addition. `firma` (already carries the app's name/tagline on every card) is untouched by the change, so it stays visible either way.
- Verified visually, not just by test: extended `apps/es/benchmark/render_tarjeta_test.dart` with a second, synthetic 30-line poem (invented filler text, not real content — only there to exercise the >14-line path) rendered alongside the existing real Quevedo sonnet. Screenshotted both: the sonnet renders whole and unchanged; the long one previews to 4 lines + "…" + the signature, exactly as designed. `flutter analyze` clean on both `poemario_core` and `apps/es`, all 109 tests still pass.
- Not committed yet. Extraction itself (deciding the final pool and writing `apps/en/assets/poemas.json`) is still in progress as of this entry.
