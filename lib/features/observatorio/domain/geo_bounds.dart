import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Immutable south/west/north/east bounding box.
///
/// [`flutter_map`'s `LatLngBounds`] exposes **mutable** `north`/`south`/`east`/
/// `west` fields, which makes it unsafe as Riverpod state: it cannot be `const`,
/// and any callee could silently break equality. This value object is the
/// state-safe equivalent; conversion to `LatLngBounds` happens only at the
/// rendering/controller boundary (see the `GeoBoundsX` extension in
/// `presentation/map/map_state.dart`).
@immutable
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  /// Bounding box that encloses every provided point.
  ///
  /// Returns `null` for an empty input.
  static GeoBounds? fromPoints(Iterable<LatLng> points) {
    var hasAny = false;
    var south = double.infinity;
    var west = double.infinity;
    var north = double.negativeInfinity;
    var east = double.negativeInfinity;

    for (final point in points) {
      final lat = point.latitude;
      final lng = point.longitude;
      if (!lat.isFinite || !lng.isFinite) continue;
      hasAny = true;
      if (lat < south) south = lat;
      if (lat > north) north = lat;
      if (lng < west) west = lng;
      if (lng > east) east = lng;
    }

    if (!hasAny) return null;
    return GeoBounds(south: south, west: west, north: north, east: east);
  }

  /// The latitude of the southern edge.
  final double south;

  /// The longitude of the western edge.
  final double west;

  /// The latitude of the northern edge.
  final double north;

  /// The longitude of the eastern edge.
  final double east;

  static const double _minLatitude = -90;
  static const double _maxLatitude = 90;
  static const double _minLongitude = -180;
  static const double _maxLongitude = 180;

  /// Latitude extent in degrees.
  double get latSpan => north - south;

  /// Longitude extent in degrees.
  double get lngSpan => east - west;

  bool get isValid =>
      south <= north && west <= east && latSpan.isFinite && lngSpan.isFinite;

  /// `minLon,minLat,maxLon,maxLat` — the GeoJSON/OGC `bbox` wire format.
  String toBbox() => '$west,$south,$east,$north';

  /// Grow by [fraction] of each span (pre-fetch halo), clamped to WGS84.
  ///
  /// A halo means a short pan does not immediately invalidate the coverage the
  /// client already holds.
  GeoBounds padded(double fraction) {
    final padLat = latSpan * fraction;
    final padLng = lngSpan * fraction;
    return GeoBounds(
      south: math.max(_minLatitude, south - padLat),
      west: math.max(_minLongitude, west - padLng),
      north: math.min(_maxLatitude, north + padLat),
      east: math.min(_maxLongitude, east + padLng),
    );
  }

  /// Snap every edge outward onto a [grid]-degree lattice.
  ///
  /// Rounding *outward* guarantees the quantized box still contains the real
  /// viewport, while making sub-tile pans produce an identical value — which is
  /// what stops a pan from triggering a network request.
  GeoBounds quantized(double grid) {
    if (grid <= 0 || !grid.isFinite) return this;
    if (latSpan >= 180 || lngSpan >= 360) return this;
    return GeoBounds(
      south: math.max(_minLatitude, (south / grid).floorToDouble() * grid),
      west: math.max(_minLongitude, (west / grid).floorToDouble() * grid),
      north: math.min(_maxLatitude, (north / grid).ceilToDouble() * grid),
      east: math.min(_maxLongitude, (east / grid).ceilToDouble() * grid),
    );
  }

  /// Whether [point] lies inside the box (edges inclusive).
  bool contains(LatLng point) =>
      point.latitude >= south &&
      point.latitude <= north &&
      point.longitude >= west &&
      point.longitude <= east;

  /// Whether [other] is fully inside this box.
  bool containsBounds(GeoBounds other) =>
      other.south >= south &&
      other.north <= north &&
      other.west >= west &&
      other.east <= east;

  /// Whether the two boxes share any area.
  bool intersects(GeoBounds other) =>
      !(south > other.north ||
          north < other.south ||
          east < other.west ||
          west > other.east);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GeoBounds &&
          other.south == south &&
          other.west == west &&
          other.north == north &&
          other.east == east);

  @override
  int get hashCode => Object.hash(south, west, north, east);

  @override
  String toString() =>
      'GeoBounds(south: $south, west: $west, north: $north, east: $east)';
}
