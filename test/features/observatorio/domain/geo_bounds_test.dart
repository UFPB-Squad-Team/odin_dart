import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:odin_app/features/observatorio/domain/geo_bounds.dart';

void main() {
  const box = GeoBounds(south: -8, west: -37, north: -7, east: -36);

  group('fromPoints', () {
    test('encloses every point', () {
      final bounds = GeoBounds.fromPoints(const [
        LatLng(-7.5, -36.5),
        LatLng(-7.1, -36.9),
        LatLng(-7.9, -36.2),
      ]);

      expect(bounds, isNotNull);
      expect(bounds!.south, -7.9);
      expect(bounds.north, -7.1);
      expect(bounds.west, -36.9);
      expect(bounds.east, -36.2);
    });

    test('returns null when empty', () {
      expect(GeoBounds.fromPoints(const []), isNull);
    });
  });

  group('toBbox', () {
    test('emits minLon,minLat,maxLon,maxLat', () {
      expect(box.toBbox(), '-37.0,-8.0,-36.0,-7.0');
    });
  });

  group('padded', () {
    test('grows by the given fraction of each span', () {
      final padded = box.padded(0.5);

      // 0.5 of the span on each side, so the span doubles.
      expect(padded.latSpan, closeTo(2.0, 1e-9));
      expect(padded.lngSpan, closeTo(2.0, 1e-9));
      expect(padded.south, closeTo(-8.5, 1e-9));
      expect(padded.north, closeTo(-6.5, 1e-9));
      expect(padded.west, closeTo(-37.5, 1e-9));
      expect(padded.east, closeTo(-35.5, 1e-9));
    });

    test('is clamped to WGS84 limits', () {
      const wide = GeoBounds(south: -89, west: -179, north: 89, east: 179);
      final padded = wide.padded(1.0);

      expect(padded.south, greaterThanOrEqualTo(-90));
      expect(padded.north, lessThanOrEqualTo(90));
      expect(padded.west, greaterThanOrEqualTo(-180));
      expect(padded.east, lessThanOrEqualTo(180));
    });
  });

  group('quantized', () {
    test('rounds outward so the real viewport stays covered', () {
      final quantized = box.quantized(0.5);

      expect(quantized.south, lessThanOrEqualTo(box.south));
      expect(quantized.north, greaterThanOrEqualTo(box.north));
      expect(quantized.west, lessThanOrEqualTo(box.west));
      expect(quantized.east, greaterThanOrEqualTo(box.east));
    });

    test('absorbs inward sub-grid pans (identical value => no refetch)', () {
      final a = box.quantized(0.05);
      // A pan that stays inside the same lattice cell must quantize identically.
      const inward = GeoBounds(south: -7.99, west: -36.99, north: -7.01, east: -36.01);
      final b = inward.quantized(0.05);

      expect(a, b);
    });

    test('grows the box when a pan crosses a lattice step', () {
      final a = box.quantized(0.05);
      const outward = GeoBounds(south: -8.01, west: -37.01, north: -7, east: -36);
      final b = outward.quantized(0.05);

      expect(b.south, lessThan(a.south));
      expect(b.west, lessThan(a.west));
    });

    test('is a no-op for non-positive grids', () {
      expect(box.quantized(0), box);
      expect(box.quantized(-1), box);
    });
  });

  group('relations', () {
    test('contains honours the edges', () {
      expect(box.contains(const LatLng(-8, -37)), isTrue);
      expect(box.contains(const LatLng(-7, -36)), isTrue);
      expect(box.contains(const LatLng(-6.99, -36)), isFalse);
    });

    test('containsBounds / intersects', () {
      const inner = GeoBounds(south: -7.6, west: -36.6, north: -7.4, east: -36.4);
      const outside = GeoBounds(south: -6.6, west: -35.6, north: -6.4, east: -35.4);

      expect(box.containsBounds(inner), isTrue);
      expect(box.containsBounds(outside), isFalse);
      expect(box.intersects(inner), isTrue);
      expect(box.intersects(outside), isFalse);
    });
  });

  test('equality and hashCode are value based', () {
    const same = GeoBounds(south: -8, west: -37, north: -7, east: -36);

    expect(box, same);
    expect(box.hashCode, same.hashCode);
    expect(box == const GeoBounds(south: -8, west: -37, north: -7, east: -36.5),
        isFalse);
  });
}
