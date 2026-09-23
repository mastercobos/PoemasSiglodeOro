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
- Ran the extraction with no filter at the user's direction (all 13,020 poems), wrote `apps/en/assets/poemas.json` (31.87 MB), and measured real load cost with a new `apps/en/benchmark/rendimiento_test.dart` (mirroring core's own, kept app-side per rule 6): `jsonDecode` 172.78 ms, `Poema.fromJson` 455.82 ms median — about 15x the Spanish app's ~31 ms despite only 2.6x the poem count, since Laurel's pool skews toward much longer poems. Not committed at that point — flagged the size/speed numbers before treating it as final.

### 22. 2026-09-23 00:36 — Making the extraction lighter and faster; curated to ≤60 verses
- User asked whether it could be made lighter/faster before committing to it. Investigated rather than guessed: format (indent vs compact JSON) is a dead end — indentation is only ~0.6% of the 31MB, the rest is real poem text. Profiled `Poema.fromJson` by splitting it into its two real costs: stanza-splitting (~156–159 ms) and folding the full poem body into `indiceBusqueda` for search (~132 ms, vs ~3.5 ms for title+author alone).
- Checked `busqueda_screen.dart` before proposing to cut the search-index cost: full-text search (matching inside poem bodies, with a ~40-character excerpt around the hit) is a deliberate, documented feature, not incidental cost — so didn't propose narrowing it without flagging the trade-off explicitly.
- Tested a hypothesis before claiming it as a fix: guessed the `RegExp(r'\n[ \t]*\n')` in `_dividirEnEstrofas` being reconstructed on every one of 13,020 calls (not hoisted to a constant) was costing real time. Benchmarked it directly — hoisting made no measurable difference (158.90 ms vs 158.69 ms). Reported the corrected finding rather than the wrong guess; the real cost is the actual line-by-line allocation work, not regex recompilation, and a genuine fix would need a single-pass rewrite equivalence-tested like `plegarParaOrden` was, not a one-liner.
- Checked gzip compression too: 31 MB raw → ~12.6 MB gzipped, relevant to real download size (app packages are compressed archives) but irrelevant to parse-time cost, which needs the full decompressed content in memory regardless.
- User chose to start with the lever that helps every dimension at once: cut poems over 60 verses. Re-generated `apps/en/assets/poemas.json` from the already-cloned corpus (no re-clone needed) with that filter: **10,366 poems, 260 authors, 9.12 MB** (was 13,020 / 277 / 31.87 MB) — dropped exactly the poems in the "61+" bucket measured earlier, confirming the filter behaved as expected.
- Re-benchmarked: `jsonDecode` 56.83 ms, `Poema.fromJson` 130.13 ms — a **3.4–3.5x speedup** from cutting only ~20% of poems, because the cut poems were disproportionately expensive to parse, not just disproportionately large. `flutter analyze` clean.
- Committed as `8850b31`.

### 23. 2026-09-23 00:44 — English fonts, first real device test, and a duplicate-id bug in the extracted data
- Downloaded EBGaramond (Regular/Bold) and SourceSans3 (Regular/Italic/Bold) — 5 files — using the same methodology as the Spanish app's earlier Lato/Playfair extraction: read the exact SHA256 hashes and byte lengths out of the cached `google_fonts` package's own generated source (`google_fonts-8.0.2/lib/src/google_fonts_parts/part_e.dart` and `part_s.dart`), downloaded each from `fonts.gstatic.com/s/a/<hash>.ttf`, verified all 5 against the expected size. Uncommented the `fonts:` block in `apps/en/pubspec.yaml` (was `# TEMP-FONTS (font files missing)` on every line).
- First real test of the extracted anthology in a running app (`flutter run -d chrome`, port 8766): it crashed on load. `PoemaRepository` asserts on duplicate derived ids, and two poems — same author, same opening line, body text differing by only 3 characters — collided. Traced it to the corpus, not the app: it's the same well-known Coleridge poem extracted twice from two different source editions.
- Checked the real scope before patching the one collision: grouped the full 13,020-poem pool by (author, normalized opening line) — **115 duplicate groups, 145 extra poems (~1.1%)**, not a one-off.
- Fix at the data layer, not the id-generation code: `Poema.id`'s derivation logic (rule 1) is shared, tested, correct behaviour — the actual problem was duplicate source material. Deduplicated the full pool first, then re-applied the 60-verse cap: **10,289 poems, 260 authors, 9.04 MB** (barely different from the pre-dedup 10,366/9.12MB, since only 77 of the 145 duplicates were also ≤60 verses). Verified zero remaining collisions by replicating `_idDerivado`'s exact key (lowercased author+title+first line) in Python before re-testing.
- Re-ran in Chrome: loads clean now, no assertion, no other errors — only an expected, already-handled `MissingPluginException` from `path_provider` not being implemented on Flutter Web (existing `CompartirPoema` catch block, not a new issue, would happen on the Spanish app's own web build too).
- Committed fonts + pubspec + deduplicated data together.

### 24. 2026-09-23 00:52 — Shakespeare's sonnets weren't in numeric order
- User noticed Shakespeare's sonnets (all 154, now in the extracted anthology) weren't ordered "I, II, III…" and recalled the Spanish app solving the same class of problem before. Checked rather than assumed the existing fix (`EstrategiaOrden.romanosPrimero`) would cover it: its regex (`_formatoGuiones`) requires the title to *start* with a dash (`"- N -"`, the Spanish source's convention) — `"Sonnet I"` never matches it, so even switching the English app to that strategy would have changed nothing; every sonnet would still fall through to plain alphabetical, where `"Sonnet IX"` sorts before `"Sonnet V"` because "I" < "V" lexically.
- Checked the real scope before designing a fix: **1,055 poems across ~200 distinct title prefixes** carry an inline numeral — not just Shakespeare's sonnets. Found genuinely nested cases too: `"Canto IV III"` (a canto number and a stanza number, no comma) and `"Sonnet II, I"` (my own `split_sequences`, when a numbered entry turned out to itself be a run of 14-line stanzas).
- Added a new strategy, `EstrategiaOrden.numeralesNaturales`, to the shared `orden_titulos.dart` rather than a Shakespeare-specific patch: tokenizes a title into alternating text/numeral runs (a numeral only counts at a whole-word boundary, so "Maud" and "Vivian" are never misread) and compares token by token — text folds and compares as text, numerals compare by value, and a title that's a prefix of another (`"Part I"` vs `"Part I, Section I"`) sorts first. Left `romanosPrimero` and the Spanish app completely untouched — this is a new, opt-in third option, not a change to existing behaviour.
- `apps/en/lib/main.dart` now picks `numeralesNaturales` instead of `alfabetico`.
- Added 6 new tests to `orden_titulos_test.dart` (inline numeral order, grouped-by-prefix, nested numerals, prefix-vs-longer-title, word-that-looks-like-a-numeral, and confirmed it also handles the Spanish `"- N -"` shape correctly as a bonus). All 115 tests pass (109 + 6), both packages analyze clean.
- Re-ran in Chrome: loads clean, no errors at all this time (not even the earlier harmless `MissingPluginException`, since nothing triggered a share this run).

### 25. 2026-09-23 01:04 — Committed the Spanish app's fonts; stopped tracking build output
- Session resumed after a closed session. Found the font work from the 2026-09-20 session (exact google_fonts 8.0.2 Lato 1.x + static Playfair Display files, pubspec pointing at them) plus `.gitignore` keystore patterns still uncommitted. Re-verified all six font files against the SHA-256 hashes in google_fonts 8.0.2's own tables; `flutter analyze` clean on `apps/es`.
- Why it mattered: HEAD's pubspec referenced `PlayfairDisplay-Variable.ttf`, which was never tracked, and the new Playfair files were untracked, so a build from the repo (e.g. Codemagic) would not have matched the tested `1.1.0+10` device build.
- Committed fonts + pubspec + `.gitignore`. Separately ran `git rm -r --cached` on the 30 `build/` files tracked under `apps/es/build` and `packages/poemario_core/build` despite `**/build/` being ignored (files stay on disk).

### 26. 2026-09-23 01:06 — First on-device run of the English app
- Ran `flutter run --debug` for `apps/en` on the Pixel 9a (installs as `com.manucobos.englishverse`, alongside the Spanish app). Built in ~69 s, installed and launched with no errors or assertions in the log.
- Screenshot confirmed the full anthology loaded on-device: "English Verse" title, Poems of the day (Skelton, Burns), with the bundled EBGaramond/SourceSans3 fonts rendering and the 4-line preview on the home cards. Only build warning: `flutter_timezone` still applies the Kotlin Gradle Plugin (a deprecation warning for now, not an error).
- Left `flutter run` attached in the background for hot reload while the user tests. No source changes, nothing committed.

### 27. 2026-09-23 01:17 — Share card: fixed 4:5 frame, fills with verses instead of cutting to 4
- User asked for a fixed-size share card (Instagram proportions) and, for long poems, to show up to a sonnet's worth or whatever fills the card instead of the old 4-verse cut. The old card was 800 px wide with a height that grew with the poem; >14 verses fell back to the first stanza (≤8) or the first 4 verses.
- `TarjetaCompartir` is now a fixed 800×1000 (4:5, Instagram's tallest feed portrait; still exported at 3×). The verse area is an `Expanded` + `LayoutBuilder` that measures each verse with `TextPainter` at the real width, so wrapped long lines count:
  - ≤14 verses: always shown whole; `FittedBox(scaleDown)` shrinks it slightly if a long title steals room (checked against the 271-char Cervantes title: fits whole).
  - >14 verses: new `seleccionarVersos` fills as many verses as fit, then "…". Cuts at a stanza break if that keeps ≥¾ of what would fit, else mid-stanza. ½ was tried first and left Coleridge's card at 8 of ~14 verses.
- Tightened spacing to fit a sonnet (verse line height 2.0→1.65, stanza gap 18→16, smaller vertical gaps). Title capped at 3 lines, author at 1, both with ellipsis.
- Rendered real cards with the bundled Playfair/Lato (a scratch test, since deleted) for a short sonnet, the longest-title sonnet, the 21-verse Quevedo, and English 60-verse, long-line, and 4-verse poems. All fit with no overflow.
- New `test/tarjeta_compartir_test.dart` (3 widget + 5 unit tests). 123 tests pass; analyze clean on core, es, en. Not committed.

### 28. 2026-09-23 01:25 — Roadmap: four new items in the Store Launch Tracker
- User asked for roadmap items only, no app changes. Added to the tracker (live artifact + `docs/store-launch-tracker.html`):
  - Spanish Android group: restore stanza breaks, marked **before the update**. The Spanish `poemas.json` has no blank lines, so the core shows each sonnet as one 14-line block. 1.0.7 hard-coded breaks after lines 4/8/11, so 1.1.0 would regress.
  - Spanish Android group: test the new 4:5 share card on a device; add an author search bar in Índice.
  - English content group: rework the selection so the best-known authors come first with all their poems, no length cap. Then count the total, decide what to cut, and check performance.
- Found the live tracker unstyled: its checkbox self-save used `querySelector("style")`, which picked up the host's injected style tag instead of the page's own. Rebuilt from the local file, kept the live-only checked state (`ei2`, Codemagic re-pointed), and gave the page's style tag an id so the self-save grabs the right one. Now 38 items, 10 done. Not committed.

### 29. 2026-09-23 21:40 — Committed the share card and tracker changes
- Re-ran analyze (clean) and the core suite (123 pass) first.
- `3b3de99` Share card: fixed 4:5 frame that fills with verses (`compartir_poema.dart` + new `tarjeta_compartir_test.dart`).
- Tracker commit: four roadmap items + the self-save style fix (`docs/store-launch-tracker.html`, plus this log). Not pushed.

### 30. 2026-09-23 22:09 — Task list: daily-poem mismatch, stanza breaks, author search, English ranking, one notification a day
- **Notification named other poems than the app showed (Spanish).** `registrarVisto` added today's authors to the stored history; every reschedule after that (each resume, switching reminders on) recomputed *today* while avoiding today's own authors, so every following day diverged. The stored history is now the one in force at the *start* of the day (`historial_base` + `historial_base_fecha`), and days the app wasn't opened are replayed from the date (`SeleccionDiariaService.historialPara`). Migration v2→v3 in `Preferencias.migrar` rewinds 1.1.0's stored history (drops its leading day). Also fixed: `serie` stepped days with `Duration(days: 1)`, which repeats 25 October (25-hour day). v1→v2 migration untouched (a `dart format` rewrap of it was reverted).
- **Stanza breaks (Spanish).** Data, not code: `apps/es/tools/insertar_estrofas.py` adds blank lines to `poemas.json` — 4-4-3-3 for the 5,045 sonnets, estrambotes as their own stanza, six odd poems by rhyme. Verified only blank lines changed (order, titles, authors, every verse identical), so ids and favourites are safe. Source is missing a verse in Garcilaso VIII, Figueroa "Bendito seas, Amor" and Litala XV.
- **Share card on device:** no phone or emulator connected. Rendered real cards with the new stanzas instead: sonnets still fit whole, even under the longest title. Device test still pending.
- **Author search in Índice** (core, so both apps, Android and iOS): accent- and case-insensitive filter; new shared `CampoBusqueda` used by Índice and Buscar (Buscar now also gets the gold rule under its app bar).
- **English selection:** re-cloned Laurel, new `apps/en/poems_extraction/seleccionar.py`: tier 1 = `PRIORITY_POETS`, then Wikipedia page views (`autores_vistas.json`, article matches corrected by hand), every poem, no cap, duplicates dropped. `assets/poemas.json` is now 12,846 poems / 277 authors / 31 MB (~620 ms parse on desktop); `ranking.md` has running totals to choose the cut. First Wikimedia request sent the user's email in the User-Agent by mistake; later requests didn't.
- **Notifications:** one per day — title "Hoy hay poemas nuevos"/"New poems today", one body line per poem (title — author: first verse), tap opens Home (`SolicitudDePoema.inicio`). The two-a-day cause: the "repeat daily from day 15" backstop fires from the next occurrence of the time, ignoring the date. Replaced by 16 one-shot generic days; old slot 999 still cancelled. Old poem-id payloads still open the poem.
- 131 tests pass; analyze clean on core, es, en. Tracker artifact updated (v7). Nothing committed.

### 31. 2026-09-23 23:36 — Committed the task list, one commit per task
- User confirmed each notification line uses the poem's *first* verse, which is what was built.
- Commits on `monorepo`: `7a41646` daily-poem/notification mismatch (+ DST day stepping), `328c28e` Spanish stanza breaks, author search in Índice, `2dd7112` one notification a day, then the English ranking and this docs commit. Files that mixed tasks (ARB strings, generated l10n, widget tests) were staged as in-between versions; each code commit was checked alone with a stash (analyze clean; 128, 129, 131 tests). Not pushed.
