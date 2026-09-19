# Review → fix map

Every item from the original code review, and where it ended up. Useful as a
checklist when verifying on device, and as a record of why some of these files
look the way they do.

## Critical

| # | Issue | Where it was fixed |
|---|---|---|
| 1 | `Poema.id` was the JSON array index, so favourites repointed at different poems whenever the file was edited | `data/poema.dart` (stable string id, FNV-1a fallback), `data/preferencias.dart` (v1→v2 migration) |
| 2 | `AjustesProvider` stored *selections*, hiding authors added in later releases; constructor raced the load | `providers/ajustes_provider.dart` (stores exclusions, synchronous load) |
| 3 | `int.parse` on stored favourites could throw from an unawaited constructor | `data/preferencias.dart` (reads never throw), `providers/favoritos_provider.dart` |
| 4 | `PopScope(canPop: false)` left the user unable to leave the app | `screens/root_screen.dart` → `_alIntentarVolver` |
| 5 | The floating nav pill covered the last item of every list | `utils/navegacion.dart` → `espacioBarraFlotante`, applied in all four scrollables |
| 6 | `main()` awaited the asset load with no `catch`: a bad JSON was a black screen | `bootstrap.dart` + `AnthologyLoadException` |

## Performance

| # | Issue | Where |
|---|---|---|
| 7 | `autoresActivos` rebuilt a `List` per poem and did a linear `contains` | `providers/ajustes_provider.dart` returns a `Set`; `poema_del_dia_provider.dart` hoists it |
| 8 | Search lowercased the whole corpus on every keystroke | `Poema.indiceBusqueda` (built once, off-isolate) + 180 ms debounce in `busqueda_screen.dart` |
| 8b | `RichText` ignored the platform text scale | `widgets/texto_resaltado.dart` uses `Text.rich` |
| 9 | The daily selection was recomputed every build; the date was frozen in `initState` | `providers/poema_del_dia_provider.dart` (cache keyed on date + active authors, refresh on resume) |

## Architecture

| # | Issue | Where |
|---|---|---|
| 10 | A careful `ThemeData` was built and then ignored by 30 hardcoded hex values | `theme/poema_colors.dart`, `theme/poema_theme.dart`, enforced by `test/arquitectura_test.dart` |
| 11 | The fade route, the grouping helper and the poem row were each duplicated 3–5 times | `utils/navegacion.dart`, `Anthology.porAutor`, `widgets/poema_list_tile.dart` |
| 12 | ~120 lines of dead share code and a stale comment | `utils/compartir_poema.dart` — one implementation, captured with `RepaintBoundary` |
| 13 | `google_fonts` fetched fonts over the network on first launch | Bundled in each app's `pubspec.yaml`; guarded by an architecture test |
| 14 | `intl` and `flutter_localizations` were dependencies but unwired | `bootstrap.dart` delegates + `lib/l10n/*.arb` |
| 15 | Assorted: duplicated `todosLosPoemas` parameter, `_ImeWarmup`, `NavBarScope` notifying every frame, redundant `ValueListenableBuilder`, dead `tituloEsRomano`, unstable `compareTitulos` tie-break | `Provider<Anthology>`, removed, `late final` tear-off, removed, removed, `domain/orden_titulos.dart` |

## Correctness and accessibility

| # | Issue | Where |
|---|---|---|
| 16 | Stanza breaks hardcoded to `{4, 8, 11}` — a sonnet's shape on every poem | `Poema.estrofas`, from the blank lines in the source |
| 17a | Text scaling capped at 1.15 on the poem body | Unclamped; `EscalaLimitada` kept only for fixed-size rows |
| 17b | "Leer poema completo" was a disabled `TextButton` over the real tap target | Plain text inside `ExcludeSemantics` in `inicio_screen.dart` |
| 17c | `BuildContext` used across awaits in the share flow | Everything resolved before the first `await` in `compartir_poema.dart` |
| — | Author names sorted by code unit, so `Ángel` came after `Zorrilla` | `plegarParaOrden` in `domain/orden_titulos.dart` |

## Tests

Nothing existed before. Now:

* `orden_titulos_test.dart` — numerals, diacritic folding, both strategies
* `poema_test.dart` — parsing, stable ids, stanza splitting
* `seleccion_diaria_test.dart` — determinism, author variety, degenerate pools
* `planificador_avisos_test.dart` — the schedule, including that a notification names the poem the app will actually show
* `preferencias_test.dart` — the v1→v2 migration, the one step that can lose data
* `providers_test.dart` — all five providers, including revoked notification permission
* `widget_test.dart` — tab switching, per-tab stacks, back behaviour, deep links, search debounce
* `arquitectura_test.dart` — fails if anything app-specific leaks into core

## Still open

* Fonts: drop the six `.ttf` files into each app's `assets/fonts/`.
* Native notification setup per app — see `notificaciones.md`.
* A flat silhouette notification icon per app; `@mipmap/ic_launcher` renders as a white blob.
* `BusquedaScreen` sits inside a shell with `resizeToAvoidBottomInset: false`. The inner `Scaffold` should still resize for the keyboard, but check it on a real device — the original carried a comment about manual keyboard padding that no longer applied to any code.
* Golden tests for the share card would be worth having before you change its layout again.
