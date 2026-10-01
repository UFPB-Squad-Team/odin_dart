/// Level-of-detail semantics driven purely by the map camera.
///
/// The map is an incremental, camera-driven subsystem: the camera decides both
/// which dataset is meaningful to draw and how many vertices are worth having.
/// Nothing in this file knows about the business context (state, municipality,
/// indicator) — see `ObservatorioState` for that.
enum MapResolution {
  /// Zoom 3–7: whole-state view, coarse municipality outlines.
  overview(label: 'Visão geral', minZoom: 3),

  /// Zoom 8–10: municipality outlines at full useful precision.
  municipality(label: 'Municípios', minZoom: 8),

  /// Zoom 11–13: neighborhoods of the drilled-down municipality.
  neighborhood(label: 'Bairros', minZoom: 11),

  /// Zoom 14+: neighborhoods plus individual school POIs.
  school(label: 'Escolas', minZoom: 14);

  const MapResolution({required this.label, required this.minZoom});

  /// Human readable name, safe to surface in UI/debug overlays.
  final String label;

  /// Lowest zoom at which this resolution applies.
  final double minZoom;

  /// Whether neighborhood geometries are meaningful at this resolution.
  bool get showsNeighborhoods => index >= MapResolution.neighborhood.index;

  /// Whether individual school POIs are meaningful at this resolution.
  bool get showsSchools => index >= MapResolution.school.index;
}

/// Maps a raw camera zoom to the [MapResolution] it belongs to.
///
/// Thresholds are contractual: `<8 overview`, `<11 municipality`,
/// `<14 neighborhood`, otherwise `school`.
MapResolution resolutionForZoom(double zoom) {
  if (zoom < 8) return MapResolution.overview;
  if (zoom < 11) return MapResolution.municipality;
  if (zoom < 14) return MapResolution.neighborhood;
  return MapResolution.school;
}

/// Geometry precision tier requested from the API and enforced on the client.
///
/// This replaces the old fixed `maxPoints: 260 / 600` strategy. The API value is
/// the primary lever (server-side `ST_SimplifyPreserveTopology`); [maxPoints]
/// is a client-side guard rail so a backend that ignores the parameter still
/// yields real, zoom-increasing detail instead of one frozen simplification.
enum MapDetail {
  low(apiValue: 'overview', maxPoints: 96),
  medium(apiValue: 'medium', maxPoints: 320),
  high(apiValue: 'detail', maxPoints: 1100);

  const MapDetail({required this.apiValue, required this.maxPoints});

  /// Sent as the `resolution` query parameter.
  final String apiValue;

  /// Douglas–Peucker output cap applied inside the parsing isolate.
  final int maxPoints;
}

/// Which detail tier a resolution needs from the geometry pipeline.
MapDetail detailForResolution(MapResolution resolution) {
  switch (resolution) {
    case MapResolution.overview:
      return MapDetail.low;
    case MapResolution.municipality:
      return MapDetail.medium;
    case MapResolution.neighborhood:
    case MapResolution.school:
      return MapDetail.high;
  }
}

extension MapDetailOrdering on MapDetail {
  /// Index-comparable rank, so "best cached geometry" lookups are cheap.
  int get rank => index;
}
