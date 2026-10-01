import 'package:latlong2/latlong.dart';

import 'map_resolution.dart';

class GeoPolygon {
  const GeoPolygon({required this.outer, this.holes = const []});

  final List<LatLng> outer;
  final List<List<LatLng>> holes;

  bool contains(LatLng point) {
    if (!_ringContains(outer, point)) return false;
    for (final hole in holes) {
      if (_ringContains(hole, point)) return false;
    }
    return true;
  }
}

bool _ringContains(List<LatLng> ring, LatLng point) {
  var inside = false;
  for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
    final xi = ring[i].longitude;
    final yi = ring[i].latitude;
    final xj = ring[j].longitude;
    final yj = ring[j].latitude;
    final crosses = (yi > point.latitude) != (yj > point.latitude) &&
        point.longitude < (xj - xi) * (point.latitude - yi) / (yj - yi) + xi;
    if (crosses) inside = !inside;
  }
  return inside;
}

class TerritoryFeature {
  TerritoryFeature._({
    required this.id,
    required this.name,
    required this.properties,
    required this.polygons,
    required this.point,
    required this.detail,
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  factory TerritoryFeature.create({
    required String id,
    required String name,
    required Map<String, dynamic> properties,
    required List<GeoPolygon> polygons,
    LatLng? point,
    MapDetail detail = MapDetail.high,
  }) {
    double? south;
    double? west;
    double? north;
    double? east;

    void extend(LatLng p) {
      south = south == null || p.latitude < south! ? p.latitude : south;
      north = north == null || p.latitude > north! ? p.latitude : north;
      west = west == null || p.longitude < west! ? p.longitude : west;
      east = east == null || p.longitude > east! ? p.longitude : east;
    }

    for (final polygon in polygons) {
      polygon.outer.forEach(extend);
    }
    if (point != null) extend(point);

    return TerritoryFeature._(
      id: id,
      name: name,
      properties: properties,
      polygons: polygons,
      point: point,
      detail: detail,
      south: south,
      west: west,
      north: north,
      east: east,
    );
  }

  final String id;
  final String name;
  final Map<String, dynamic> properties;
  final List<GeoPolygon> polygons;
  final LatLng? point;

  /// Geometry precision tier this feature was parsed at. Lets the rendering
  /// layer report/verify the current level of detail.
  final MapDetail detail;

  final double? south;
  final double? west;
  final double? north;
  final double? east;

  /// Total number of vertices across every ring, holes included.
  ///
  /// Diagnostic only — used to prove that higher resolutions really do carry
  /// more geometry than lower ones.
  int get vertexCount {
    var total = 0;
    for (final polygon in polygons) {
      total += polygon.outer.length;
      for (final hole in polygon.holes) {
        total += hole.length;
      }
    }
    return total;
  }

  bool get hasBounds =>
      south != null && west != null && north != null && east != null;

  LatLng? get center {
    if (point != null) return point;
    if (!hasBounds) return null;
    return LatLng((south! + north!) / 2, (west! + east!) / 2);
  }

  String? get uf {
    final value = properties['sg_uf'] ?? properties['uf'];
    return value?.toString();
  }

  bool containsPoint(LatLng target) {
    if (!hasBounds || polygons.isEmpty) return false;
    if (target.latitude < south! ||
        target.latitude > north! ||
        target.longitude < west! ||
        target.longitude > east!) {
      return false;
    }
    for (final polygon in polygons) {
      if (polygon.contains(target)) return true;
    }
    return false;
  }
}
