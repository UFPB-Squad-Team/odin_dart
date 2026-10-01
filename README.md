# ODIN App

**ODIN — Northeast Integrated Data Observatory** (*Observatório de Dados Integrados do Nordeste*)
Flutter mobile client · Beta `0.1.0` · UFPB / LEMA extension project

ODIN brings scattered, hard-to-read public datasets onto a single interactive map of
Brazil's nine Northeast states, giving civil society and public authorities clear
evidence for urban, educational and social planning. This repository contains the
Flutter app, which consumes the same API as the ODIN web version.

---

## Features

- **Choropleth map of the Northeast** — all 9 states (AL, BA, CE, MA, PB, PE, PI, RN, SE),
  with drill-down from state → municipality → neighborhood → school.
- **Two indicator modules**, switchable from the control panel:
  - **Education** — School Census (*Censo Escolar INEP*): IDEB, infrastructure, approval /
    dropout rates, age-grade distortion, enrollment totals, and more.
  - **Socioeconomic** — IBGE 2022 Population Census: race, literacy, sanitation,
    population, housing, and more.
  - ~40 indicators in total, each with its own color scale, unit, decimals and
    "higher-is-better" direction. Indicators unavailable at the neighborhood level fall
    back automatically.
- **Camera-driven level of detail** — zooming genuinely reveals new geometry
  (96 → 320 → 1,100 vertices per feature) instead of scaling a single static outline;
  see [the architecture ADR](docs/architecture/vector-tiles.md).
- **Vector basemap with raster fallback** — CARTO Positron / Dark Matter styles rendered
  through `vector_map_tiles`, falling back to OpenStreetMap raster tiles; follows the
  system light/dark theme.
- **Schools** — clustered POIs from zoom 14+, a paginated school list with fuzzy search
  and filters (administrative dependency, urban/rural location), and a school detail page.
- **Universal search** — find municipalities, neighborhoods, schools, streets and CEPs;
  the camera flies to the result at an appropriate zoom.
- **PDF dossiers** — generate and open a municipality or state dossier (*dossiê*) straight
  from the app.
- **Territory summaries** — key figures for the selected state, municipality or
  neighborhood in the detail sheet.
- **About page** — project description, extension team and map credits.

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter `>=3.24` (Dart `>=3.5.0 <4.0.0`) |
| State management | Riverpod (`flutter_riverpod` — `Notifier`/`Provider`) |
| Routing | `go_router` |
| HTTP | `dio` |
| Mapping | `flutter_map` 7, `flutter_map_marker_cluster`, `vector_map_tiles`, `latlong2` |
| PDF handling | `path_provider` + `open_filex` |
| Formatting | `intl` |
| Lints | `flutter_lints` (+ `prefer_const`, `prefer_final_locals`, `avoid_print`) |
| Icons / splash | `flutter_launcher_icons`, `flutter_native_splash` |

## Getting started

### Prerequisites

- Flutter SDK `>= 3.24` (`flutter --version`)
- A platform toolchain: Android SDK (and/or Xcode for iOS)
- On Windows, a Bash environment for the setup script (Git Bash, WSL or MSYS)

### Setup

```bash
./tool/setup.sh
flutter run
```

`tool/setup.sh`:

1. generates the `android/` and `ios/` folders with
   `flutter create . --org br.ufpb.lema --project-name odin_app --platforms android,ios`
   (the platform folders are intentionally not committed);
2. adds the `android.permission.INTERNET` permission to the Android manifest (idempotent);
3. runs `flutter pub get`;
4. generates the launcher icon and the native splash screen (logo on a white background).

## Configuration

The API base URL and the spatial-API switch are compile-time `--dart-define`s
(see `lib/core/config/env.dart`):

| Define | Default | Description |
|---|---|---|
| `ODIN_API_BASE_URL` | `https://odin-backend-xdfx.onrender.com/api/v1` | Backend base URL |
| `ODIN_SPATIAL_API` | `false` | Ask the API for viewport-scoped, resolution-aware geometry (`?bbox=…&resolution=…`). Always safe to enable: if the backend answers with a 4xx, the repository downgrades itself for the rest of the session and falls back to whole-territory payloads. |

```bash
# Point at a local backend (10.0.2.2 = host loopback as seen from the Android emulator)
flutter run --dart-define=ODIN_API_BASE_URL=http://10.0.2.2:8000/api/v1

# Enable spatial parameters
flutter run --dart-define=ODIN_SPATIAL_API=true
```

> **Note:** the free-tier Render instance sleeps when idle, so the first request after a
> period of inactivity may take about a minute.

## Architecture

```
lib/
  main.dart / app.dart        ProviderScope, MaterialApp.router, light/dark theme
  core/
    config/                   Env (dart-defines)
    network/                  Dio provider (60s connect / 90s receive timeouts)
    router/                   go_router routes
    territory/                the 9 Northeast states (center + zoom)
    theme/                    ODIN colors and Material theme
    utils/                    number/date formatters
  features/
    splash/
    about/
    observatorio/
      domain/                 models, IndicatorCatalog, MapResolution/MapDetail, GeoBounds
      data/                   repositories, GeoJSON parser (isolate), Douglas–Peucker
                              simplifier, multi-resolution geometry store (LRU cache)
      presentation/           Riverpod controller, page, map/ (layers, viewport state),
                              schools/, widgets/ (control panel, sheets, search bar, dossier)
  test/                       unit & widget tests mirroring lib/
```

### State design: three orthogonal axes

The map subsystem keeps business context, camera context and geometry fully decoupled
(full rationale in [`docs/architecture/vector-tiles.md`](docs/architecture/vector-tiles.md)):

| Axis | Owner | Knows about |
|---|---|---|
| Business context (`uf`, `municipio`, `module`, `indicatorId`, `showSchools`, `selectedId`) | `ObservatorioState` | Never the zoom |
| Camera/spatial context (`zoom`, `center`, `bounds`, `resolution`, `query`) | `MapViewportState` | Never the indicators |
| Geometry cache (multi-resolution, bbox-scoped, LRU of 24 entries) | `TerritoryGeometryStore` | Pure data, no widgets |

The only seam between them is `renderedTerritoryLayerProvider`, a pure function of both —
indicators stay keyed to the *domain* layer, so zooming never silently swaps the selected
indicator.

### Level of detail

`resolutionForZoom` is the single source of truth (unit-tested at every threshold):

| Zoom | `MapResolution` | `MapDetail` (vertex budget) |
|---|---|---|
| `< 8` | `overview` (state view) | `low` — 96 |
| `< 11` | `municipality` | `medium` — 320 |
| `< 14` | `neighborhood` | `high` — 1,100 |
| `≥ 14` | `school` (+ school POIs) | `high` — 1,100 |

Geometry is parsed in a background isolate and simplified client-side with
Douglas–Peucker as a guard rail; the API `resolution` parameter is the primary lever.
Network requests only re-issue after the camera settles (220 ms) and the padded,
tile-aligned bounding box actually changes, so camera-reactivity never degrades into
request-per-frame.

### App routes

| Path | Page |
|---|---|
| `/` | Splash |
| `/observatorio` | Observatory (map, control panel, detail sheet) |
| `/sobre` | About |
| `/municipio/:id/escolas` | School list (with `?nome=`) |
| `/escola/:inep` | School detail |

## API endpoints used

All requests are relative to `ODIN_API_BASE_URL`:

| Endpoint | Purpose |
|---|---|
| `GET /aggregations/cities` | Municipality geometries + indicator aggregates |
| `GET /aggregations/neighborhoods` | Neighborhood geometries for a municipality |
| `GET /estados/{uf}/resumo` | State summary |
| `GET /municipios/{id}/resumo` | Municipality summary |
| `GET /bairros/{id}/resumo` | Neighborhood summary |
| `GET /municipios/{id}/dossie` | Municipality PDF dossier |
| `GET /estados/{uf}/dossie` | State PDF dossier |
| `GET /escolas/geojson/paraiba` | School POIs for a municipality |
| `GET /schools` | Paginated school list (`search`, `fuzzy_search`, `dependencia_adm`, `tipo_localizacao`) |
| `GET /{inep}` | School detail |
| `GET /busca/universal` | Universal search (`q`, `sg_uf`, `limit`) |

Optional query parameters sent when `ODIN_SPATIAL_API=true`:
`?resolution=overview|medium|detail` and `?bbox=minLon,minLat,maxLon,maxLat`.

## Testing

```bash
flutter test        # run the whole suite
dart analyze        # lints (flutter_lints + project rules)
```

The suite covers the parts most likely to regress:

| Test | What it asserts |
|---|---|
| `test/indicator_test.dart` | Indicator value reading (nested/flat/string) and bairro fallback |
| `test/.../domain/map_resolution_test.dart` | Zoom → resolution thresholds and monotonicity |
| `test/.../domain/geo_bounds_test.dart` | Immutable bounds math (pad, quantize, containment) |
| `test/.../domain/school_models_test.dart` | School list/detail JSON parsing |
| `test/.../data/geo_parser_test.dart` | GeoJSON parsing and vertex budgets |
| `test/.../data/geo_simplify_test.dart` | Douglas–Peucker simplification |
| `test/.../data/territory_geometry_store_test.dart` | Cache coverage, merging and LRU eviction |
| `test/.../presentation/map/map_viewport_test.dart` | Settled/quantized viewport queries |

## Documentation

- [`docs/architecture/vector-tiles.md`](docs/architecture/vector-tiles.md) — ADR:
  *Camera-Driven Geospatial Pipeline & Vector-Tile Roadmap*, covering the fetch regimes,
  the `GeoBounds` decision, the `flutter_map` 8.x upgrade plan and the MVT/PMTiles
  (vector tiles) phase.

## Repository

```
https://github.com/UFPB-Squad-Team/odin_dart.git   (branch: main)
```

## Credits

- **Project:** extension project of Universidade Federal da Paraíba (UFPB) — LEMA.
- **Extension team:** Samuel Colaço Lira Carvalho, Brenno Henrique Alves da Silva Costa,
  Deivyson Henrique Gomes Ribeiro, Felipe Emidio de Medeiros Neto, Gustavo Henrique Rocha
  Oliveira, Ítalo Oliveira de Sousa.
- **Coordination:** Jorge Henrique Norões Viana, Alessio Tony Cavalcanti.
- **Data sources:** INEP School Census · IBGE 2022 Population Census.
- **Map credits:** © OpenStreetMap contributors · © CARTO.
