import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../domain/map_resolution.dart';
import '../domain/territory_feature.dart';
import 'geo_simplify.dart';

class ParseRequest {
  const ParseRequest(this.payload, this.detail);

  final Object? payload;
  final MapDetail detail;
}

/// Parses a GeoJSON payload inside a background isolate, simplifying geometry to
/// the vertex budget of [detail].
///
/// The budget grows with zoom (`MapDetail.maxPoints`), which is the whole point
/// of the multi-resolution pipeline: a coarse tier is cheap to ship and paint,
/// while a detail tier genuinely contains more vertices instead of a frozen
/// once-only simplification.
Future<List<TerritoryFeature>> parseTerritoryPayload(
  Object? payload, {
  MapDetail detail = MapDetail.high,
}) {
  return compute(parseTerritorySync, ParseRequest(payload, detail));
}

List<TerritoryFeature> parseTerritorySync(ParseRequest request) {
  final payload = request.payload;
  final result = <TerritoryFeature>[];

  if (payload is Map && payload['features'] is List) {
    for (final item in payload['features'] as List) {
      if (item is! Map) continue;
      final feature = _fromFeature(item, request.detail);
      if (feature != null) result.add(feature);
    }
  } else if (payload is List) {
    for (final item in payload) {
      if (item is! Map) continue;
      final feature = _fromDocument(item, request.detail);
      if (feature != null) result.add(feature);
    }
  }

  return result;
}

TerritoryFeature? _fromFeature(Map raw, MapDetail detail) {
  final props = _stringKeyed(raw['properties']);
  final id = _cleanId(
    raw['id'] ??
        props['municipioIdIbge'] ??
        props['municipio_id_ibge'] ??
        props['co_municipio'] ??
        props['id'] ??
        props['_id'],
  );
  if (id.isEmpty) return null;

  return _build(
    id: id,
    name: _name(props, id),
    props: props,
    geometry: raw['geometry'],
    detail: detail,
  );
}

TerritoryFeature? _fromDocument(Map raw, MapDetail detail) {
  final props = _stringKeyed(raw);
  final id = _cleanId(
    props['_id'] ??
        props['cd_bairro_ibge'] ??
        props['cd_setor'] ??
        props['id'],
  );
  if (id.isEmpty) return null;

  return _build(
    id: id,
    name: _name(props, id),
    props: props,
    geometry: props['geometria'] ?? props['geometry'],
    detail: detail,
  );
}

TerritoryFeature? _build({
  required String id,
  required String name,
  required Map<String, dynamic> props,
  required Object? geometry,
  required MapDetail detail,
}) {
  if (geometry is! Map) return null;
  final type = geometry['type'];
  final coordinates = geometry['coordinates'];
  if (coordinates is! List) return null;

  final polygons = <GeoPolygon>[];
  LatLng? point;

  if (type == 'Point') {
    point = _point(coordinates);
  } else if (type == 'Polygon') {
    final polygon = _polygon(coordinates, detail);
    if (polygon != null) polygons.add(polygon);
  } else if (type == 'MultiPolygon') {
    for (final part in coordinates) {
      if (part is! List) continue;
      final polygon = _polygon(part, detail);
      if (polygon != null) polygons.add(polygon);
    }
  }

  if (polygons.isEmpty && point == null) return null;

  return TerritoryFeature.create(
    id: id,
    name: name,
    properties: props,
    polygons: polygons,
    point: point,
    detail: detail,
  );
}

GeoPolygon? _polygon(List rings, MapDetail detail) {
  final parsed = <List<LatLng>>[];
  for (final ring in rings) {
    if (ring is! List) continue;
    final points = _ring(ring, detail);
    if (points.length >= 3) parsed.add(points);
  }
  if (parsed.isEmpty) return null;
  return GeoPolygon(outer: parsed.first, holes: parsed.sublist(1));
}

/// Parse one linear ring and reduce it to the vertex budget of [detail].
///
/// Douglas–Peucker (inside [GeoSimplify]) replaces the previous index-stride
/// decimation: same budget, far more faithful outline, and the budget itself is
/// now a function of zoom rather than a one-off `maxPoints: 260/600`.
List<LatLng> _ring(List ring, MapDetail detail) {
  final points = <LatLng>[];
  for (final raw in ring) {
    final point = _point(raw);
    if (point != null) points.add(point);
  }
  if (points.length <= detail.maxPoints) return points;
  return GeoSimplify.ring(points, detail.maxPoints);
}

bool _inBrazil(double lng, double lat) {
  return lng >= -75 && lng <= -30 && lat >= -35 && lat <= 6;
}

LatLng? _point(Object? raw) {
  if (raw is! List || raw.length < 2) return null;
  final x = raw[0];
  final y = raw[1];
  if (x is! num || y is! num) return null;
  final a = x.toDouble();
  final b = y.toDouble();
  if (!a.isFinite || !b.isFinite) return null;

  if (_inBrazil(a, b)) return LatLng(b, a);
  if (_inBrazil(b, a)) return LatLng(a, b);
  return LatLng(b, a);
}

Map<String, dynamic> _stringKeyed(Object? value) {
  if (value is Map) {
    return value.map((key, val) => MapEntry(key.toString(), val));
  }
  return <String, dynamic>{};
}

String _cleanId(Object? value) {
  if (value == null) return '';
  if (value is Map) {
    return _cleanId(value[r'$oid'] ?? value['oid']);
  }
  return value.toString().replaceAll(RegExp(r'\.0$'), '').trim();
}

String _name(Map<String, dynamic> props, String fallback) {
  final value = props['municipio'] ??
      props['nome'] ??
      props['name'] ??
      props['bairro'] ??
      props['nm_bairro'] ??
      props['nome_area'] ??
      fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}
