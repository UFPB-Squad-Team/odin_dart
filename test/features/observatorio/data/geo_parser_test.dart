import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:odin_app/features/observatorio/data/geo_parser.dart';
import 'package:odin_app/features/observatorio/domain/map_resolution.dart';

/// A GeoJSON-ish payload with a single dense ring.
Map<String, Object?> _payload(int vertices) {
  final ring = <List<double>>[];
  for (var i = 0; i < vertices; i++) {
    final angle = 2 * math.pi * i / vertices;
    // GeoJSON is [lng, lat]. The parser also accepts lat-first (Brazil check).
    ring.add([-36.6 + 0.2 * math.cos(angle), -7.1 + 0.2 * math.sin(angle)]);
  }
  ring.add(ring.first);

  return <String, Object?>{
    'type': 'FeatureCollection',
    'features': [
      <String, Object?>{
        'type': 'Feature',
        'id': '2507507',
        'properties': <String, Object?>{'municipio': 'João Pessoa'},
        'geometry': <String, Object?>{
          'type': 'Polygon',
          'coordinates': [ring],
        },
      },
    ],
  };
}

void main() {
  group('parseTerritoryPayload', () {
    test('produces a feature with the parsed id, name and closure', () async {
      final features = await parseTerritoryPayload(
        _payload(500),
        detail: MapDetail.medium,
      );

      expect(features, hasLength(1));
      final feature = features.single;
      expect(feature.id, '2507507');
      expect(feature.name, 'João Pessoa');
      expect(feature.polygons, hasLength(1));
      expect(feature.detail, MapDetail.medium);
      expect(feature.hasBounds, isTrue);
      expect(feature.polygons.single.outer.first,
          feature.polygons.single.outer.last);
    });

    test('vertex count grows with detail (multi-resolution geometry)', () async {
      final low = await parseTerritoryPayload(_payload(4000), detail: MapDetail.low);
      final medium =
          await parseTerritoryPayload(_payload(4000), detail: MapDetail.medium);
      final high =
          await parseTerritoryPayload(_payload(4000), detail: MapDetail.high);

      final lowCount = low.single.vertexCount;
      final mediumCount = medium.single.vertexCount;
      final highCount = high.single.vertexCount;

      expect(lowCount, lessThanOrEqualTo(MapDetail.low.maxPoints));
      expect(mediumCount, lessThanOrEqualTo(MapDetail.medium.maxPoints));
      expect(highCount, lessThanOrEqualTo(MapDetail.high.maxPoints));

      expect(lowCount, lessThan(mediumCount));
      expect(mediumCount, lessThan(highCount));
    });

    test('low detail stays small enough for a whole-state render', () async {
      final features =
          await parseTerritoryPayload(_payload(10000), detail: MapDetail.low);

      // 96 vertices for a single ring: this is the payload win that makes the
      // overview tier cheap to ship and paint.
      expect(features.single.vertexCount, lessThanOrEqualTo(96));
    });

    test('parses a plain document list with a Point geometry', () async {
      final features = await parseTerritoryPayload(
        <Object?>[
          <String, Object?>{
            '_id': 'abc123',
            'bairro': 'Manaíra',
            'geometria': <String, Object?>{
              'type': 'Point',
              'coordinates': [-34.83, -7.09],
            },
          },
        ],
        detail: MapDetail.high,
      );

      expect(features, hasLength(1));
      expect(features.first.name, 'Manaíra');
      expect(features.first.point, isNotNull);
    });

    test('cleans ids and hit-tests parsed polygons', () async {
      final features = await parseTerritoryPayload(
        <String, Object?>{
          'type': 'FeatureCollection',
          'features': [
            <String, Object?>{
              'type': 'Feature',
              'id': '2507507.0',
              'geometry': <String, Object?>{
                'type': 'Polygon',
                'coordinates': [
                  [
                    [-35.0, -7.0],
                    [-35.0, -7.2],
                    [-34.8, -7.2],
                    [-34.8, -7.0],
                    [-35.0, -7.0],
                  ],
                ],
              },
              'properties': <String, Object?>{'municipio': 'João Pessoa'},
            },
          ],
        },
        detail: MapDetail.high,
      );

      expect(features, hasLength(1));
      expect(features.first.id, '2507507');
      expect(features.first.name, 'João Pessoa');
      expect(features.first.containsPoint(const LatLng(-7.1, -34.9)), isTrue);
      expect(features.first.containsPoint(const LatLng(-8.0, -34.9)), isFalse);
    });

    test('tolerates malformed payloads', () async {
      expect(await parseTerritoryPayload(null), isEmpty);
      expect(await parseTerritoryPayload('nope'), isEmpty);
      expect(await parseTerritoryPayload(<String, Object?>{}), isEmpty);
      expect(
        await parseTerritoryPayload(<String, Object?>{
          'features': [
            <String, Object?>{'geometry': null},
          ],
        }),
        isEmpty,
      );
    });

    test('reads a plain document list with a geometria field', () async {
      final features = await parseTerritoryPayload(
        <Object?>[
          <String, Object?>{
            '_id': 'bairro-1',
            'bairro': 'Centro',
            'geometria': <String, Object?>{
              'type': 'Polygon',
              'coordinates': [
                [
                  [-36.6, -7.1],
                  [-36.5, -7.1],
                  [-36.5, -7.2],
                  [-36.6, -7.2],
                  [-36.6, -7.1],
                ],
              ],
            },
          },
        ],
        detail: MapDetail.high,
      );

      expect(features, hasLength(1));
      expect(features.single.id, 'bairro-1');
      expect(features.single.name, 'Centro');
    });
  });
}
