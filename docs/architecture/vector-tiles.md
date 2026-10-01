# ADR: Camera-Driven Geospatial Pipeline & Vector-Tile Roadmap

Status: **Accepted** · Scope: `features/observatorio` map subsystem · Owner: ODIN Mobile

## 1. Context

Before this change the map was a single static render: GeoJSON was parsed once
per territory level, simplified with a fixed vertex cap
(`parseTerritoryPayload(maxPoints: 260 / 600)`), and drawn by a `PolygonLayer`.
Zooming only scaled that geometry — the same 260 vertices were displayed at zoom
5, 10 and 15. Layer switching was driven purely by user selection
(`municipio == null ? municipio : bairro`), never by the camera, and school POIs
were drawn as an unclustered `MarkerLayer`.

Two facts drove the design:

1. `flutter_map`'s `PolygonLayer` already re-simplifies in **pixel space** on
   every floored zoom (`simplificationTolerance`, default `0.3`). Therefore the
   *only* way to reveal new detail when zooming in is to change the **data**
   layer, not the renderer.
2. `MapOptions.onPositionChanged` gives a `MapCamera` with `zoom`, `center` and
   `visibleBounds`, which is everything needed to make the camera the driver.

## 2. Decision

The map is an **incremental, camera-driven subsystem** with three orthogonal
axes:

| Axis | Owner | Notes |
|---|---|---|
| Business context (`uf`, `municipio`, `module`, `indicatorId`, `showSchools`, `selectedId`) | `ObservatorioState` | Never knows about zoom |
| Camera/spatial context (`zoom`, `center`, `bounds`, `resolution`, `query`) | `MapViewportState` | Never knows about indicators |
| Geometry cache (multi-resolution, bbox-scoped, LRU) | `TerritoryGeometryStore` | Pure data, no widgets |

`MapResolution` (`overview < 8`, `municipality < 11`, `neighborhood < 14`,
`school ≥ 14`) maps zoom to a `MapDetail` tier
(`low 96` / `medium 320` / `high 1100` vertices), which is requested from the API
as `?resolution=` and enforced client-side with Douglas–Peucker as a guard rail.
`resolutionForZoom` is the single source of truth and is unit tested at every
threshold.

Indicators stay keyed to the **domain** layer (`ObservatorioState.layer`), not to
the rendered one, so zooming out never silently swaps the selected indicator;
only the *drawn* dataset follows the camera, via
`renderedTerritoryLayerProvider`.

### 2.1 Two-tier reactivity

`MapViewportController.setCamera` publishes live camera values every frame, but
`MapViewportState.query` is republished only after a 220 ms settle **and** only
if the tile-aligned, halo-padded bounding box actually changed. Consumers use
`select`, so:

* a zoom badge or cluster granularity follows the finger smoothly;
* the network scope moves at most once per settle, and never for a sub-cell pan.

This is the specific mechanism that prevents "camera-reactive" from degrading
into "request per frame".

### 2.2 Fetch regimes

| Tier | Scope | Rationale |
|---|---|---|
| `low` / `medium` municipalities | whole state, once | ~223 features in PB; bbox scoping would punch holes at the state edge and break the initial `fitCamera` |
| `high` (neighborhoods) | settled viewport `bbox` + 35 % halo | genuinely incremental; accumulates coverage, merges by feature id |

A payload that the server returns *without* honouring `bbox` is marked
`spatialParamsApplied: false` and treated as full coverage, so it is never
re-requested while panning. This is what makes the pipeline correct on a backend
that has not implemented the spatial parameters yet.

### 2.3 `GeoBounds` instead of `LatLngBounds`

`flutter_map`'s `LatLngBounds` exposes **mutable** `north/south/east/west` and
therefore cannot be `const` and can silently break value equality. State uses an
immutable `GeoBounds`; conversion happens only at the boundary
(`toLatLngBounds()`, `toBbox()`).

## 3. Consequences

**Positive**

* Zooming reveals real detail: 96 → 320 → 1100 vertices, asserted by tests.
* Panning is free inside cached coverage; geometry is LRU-capped at 24 entries.
* Business state and camera state evolve independently; the only seam is
  `renderedTerritoryLayerProvider`, a pure function of both.
* School rendering cost is bounded by the number of *visible clusters*, not the
  number of schools.
* The pipeline is testable headlessly with a stubbed `Dio` adapter and
  `ProviderContainer`.

**Negative / accepted costs**

* With spatial parameters off (the default), each tier re-downloads the same
  payload — three requests instead of one. Accepted in exchange for real LoD
  today and zero-config correctness on an unverified backend.
* `compute()` spawns an isolate per parse, and parse calls are now ~3× more
  frequent. A long-lived isolate worker is the documented fallback.
* `flutter_map_marker_cluster` pinned at `1.4.0` — the newest release compatible
  with `flutter_map ^7`. It is roughly two years old, which is a concrete
  argument for the v8 upgrade below.
* Consequence of the pixel-space ceiling: because `flutter_map` re-simplifies per
  floored zoom, the *render* tolerance and the *data* tier must move together.
  Lowering `MapDetail.maxPoints` to "save bandwidth" would silently reintroduce
  the original bug, so the caps are asserted by tests.

## 4. Phase 5 — `flutter_map` 8.x upgrade plan

The local toolchain already satisfies the requirement (Flutter 3.47.1 /
Dart 3.13.1 vs. `flutter_map 8.3.2`'s `flutter >=3.27`, `dart >=3.6`).

```yaml
environment: { sdk: ">=3.6.0 <4.0.0", flutter: ">=3.27.0" }
flutter_map: ^8.3.2
flutter_map_marker_cluster: ^8.2.2   # requires flutter_map ^8.2.2
```

Verified breaking changes that matter to us
(`docs.fleaflet.dev/getting-started/new-in-v8`):

| Change | Our exposure |
|---|---|
| `MapCamera` returns `Offset`/`Size`/`Rect` instead of `Point`/`Bounds` | **None** — we only read `center`, `zoom`, `visibleBounds` |
| `TileLayer.tileSize` → `tileDimension` (int) | **None** — not used |
| Polygon-label placement system replaced | **None** — no labels configured |
| `CancellableNetworkTileProvider` deprecated | **None** — not used |

Steps: bump `pubspec.yaml`, `flutter pub get`, `dart analyze`, run the test suite,
then adopt the free wins — v8.3.1 "`MarkerLayer` projection caching",
"`PolygonLayer` performance for polygons with holes", `PolylineLayer` culling,
and the built-in `NetworkTileProvider` cache.

## 5. Phase 6 — Vector tiles (MVT / PMTiles)

Target: parity with the web MapLibre GL implementation.

**Why this refactor is the right substrate:** vector tiles need exactly the three
things already built here — a zoom→detail mapping, viewport-scoped fetching, and
a decoupled camera state. `MapResolution` becomes the tile-zoom selector;
`MapQuery.bounds` becomes the tile request extent.

**Server contract to implement**

```sql
-- one feature per (layer, zoom, tile)
ST_AsMVTGeom(
  ST_SimplifyPreserveTopology(geom, z_tolerance),
  ST_TileEnvelope(:z, :x, :y)
)
```

* Layers: `municipio` (z0–9), `bairro` (z10–16), `escola` (z12–16, point, with
  `ideb`, `dependencia`, `alunos`).
* Endpoints: `GET /tiles/territories/{z}/{x}/{y}.mvt?layer=…` plus a
  `tileset.json` describing the pyramid and attribute schema.
* The `resolution`/`bbox` endpoints remain as the fallback path for clients that
  cannot consume MVT.

**Client options**

| Option | Trade-off |
|---|---|
| `maplibre_gl` | True parity with web (styles, sprite, MVT, PMTiles, GPU rendering). Requires a platform view, so Flutter-side hit-testing and overlays need message passing. |
| `flutter_map_vector_tiles` / `vector_map_tiles` | Stays inside the existing `FlutterMap` widget tree; overlays keep direct access to Riverpod state. Smaller feature surface than MapLibre. |

**Recommendation:** keep `flutter_map` for the next milestone — the
`MapViewportState` / `MapResolution` / `TerritoryGeometryStore` contracts are
transport-agnostic, so switching later means replacing
`TerritoryPolygonLayer` and the fetch regime in `TerritoryGeometryStore`; neither
the domain model nor the viewport controller has to change. Evaluate
`maplibre_gl` only if style parity with the web product becomes a hard
requirement.

**Acceptance criteria for the switch**

1. `MapResolution` thresholds map 1:1 onto tile zooms (no new thresholds).
2. Cluster behaviour at z8 / z11 / z14+ is unchanged for school POIs.
3. Panning issues zero requests inside already-loaded tiles.
4. Every feature carries the attributes `IndicatorCatalog` reads, at every tile
   zoom — indicator values must never depend on the tile zoom.
