import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:odin_app/features/observatorio/data/geo_simplify.dart';

/// Builds a regular ring of [count] vertices around (lat, lng).
List<LatLng> _circle(int count, {double lat = -7.1, double lng = -36.6, double r = 0.2}) {
  final points = <LatLng>[];
  for (var i = 0; i < count; i++) {
    final angle = 2 * math.pi * i / count;
    points.add(LatLng(lat + r * math.sin(angle), lng + r * math.cos(angle)));
  }
  points.add(points.first);
  return points;
}

/// A staircase: DP must keep every corner, stride decimation would not.
List<LatLng> _staircase(int steps) {
  final points = <LatLng>[];
  for (var i = 0; i <= steps; i++) {
    points.add(LatLng(-7.0 - i * 0.001, -36.0 - i * 0.001));
    points.add(LatLng(-7.0 - i * 0.001, -36.0 - (i + 1) * 0.001));
  }
  final closed = <LatLng>[...points, points.first];
  return closed;
}

void main() {
  group('GeoSimplify.ring', () {
    test('respects the vertex budget', () {
      final ring = _circle(2000);

      for (final budget in [96, 320, 1100]) {
        final simplified = GeoSimplify.ring(ring, budget);
        expect(
          simplified.length,
          lessThanOrEqualTo(budget),
          reason: 'budget $budget produced ${simplified.length} vertices',
        );
        expect(simplified.length, greaterThanOrEqualTo(3));
      }
    });

    test('more budget means strictly more detail (the LoD contract)', () {
      final ring = _circle(4000);

      final low = GeoSimplify.ring(ring, 96).length;
      final medium = GeoSimplify.ring(ring, 320).length;
      final high = GeoSimplify.ring(ring, 1100).length;

      expect(low, lessThan(medium));
      expect(medium, lessThan(high));
    });

    test('preserves ring closure', () {
      final ring = _circle(1500);
      final simplified = GeoSimplify.ring(ring, 120);

      expect(simplified.first, simplified.last);
    });

    test('keeps first and last vertex of an open ring', () {
      final open = _circle(500).sublist(0, 400);
      final simplified = GeoSimplify.ring(open, 60);

      expect(simplified.first, open.first);
      expect(simplified.last, open.last);
    });

    test('returns small rings untouched', () {
      final ring = _circle(20);
      final simplified = GeoSimplify.ring(ring, 96);

      expect(simplified.length, ring.length);
    });

    test('keeps corners a stride decimation would lose', () {
      final staircase = _staircase(400);
      final simplified = GeoSimplify.ring(staircase, 900);

      // Well within budget, so nothing should be dropped.
      expect(simplified.length, staircase.length);
    });

    test('is deterministic', () {
      final ring = _circle(1234);
      final a = GeoSimplify.ring(ring, 200);
      final b = GeoSimplify.ring(ring, 200);

      expect(a, b);
    });

    test('handles degenerate input without throwing', () {
      expect(GeoSimplify.ring(const [], 96), isEmpty);
      expect(GeoSimplify.ring(const [LatLng(-7, -36)], 96), hasLength(1));
      expect(
        GeoSimplify.ring(const [LatLng(-7, -36), LatLng(-7, -36)], 96),
        isNotEmpty,
      );
    });

    test('collapses consecutive duplicates', () {
      final ring = <LatLng>[
        const LatLng(-7, -36),
        const LatLng(-7, -36),
        const LatLng(-7.1, -36),
        const LatLng(-7.1, -36.1),
        const LatLng(-7, -36),
      ];
      final simplified = GeoSimplify.ring(ring, 96);

      expect(simplified, hasLength(4));
      expect(simplified.first, simplified.last);
    });
  });
}
