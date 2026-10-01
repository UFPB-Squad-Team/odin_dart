import 'package:flutter_test/flutter_test.dart';
import 'package:odin_app/features/observatorio/domain/map_resolution.dart';

void main() {
  group('resolutionForZoom', () {
    test('maps the contractual thresholds exactly', () {
      expect(resolutionForZoom(3), MapResolution.overview);
      expect(resolutionForZoom(7.0), MapResolution.overview);
      expect(resolutionForZoom(7.99), MapResolution.overview);

      expect(resolutionForZoom(8.0), MapResolution.municipality);
      expect(resolutionForZoom(10.0), MapResolution.municipality);
      expect(resolutionForZoom(10.99), MapResolution.municipality);

      expect(resolutionForZoom(11.0), MapResolution.neighborhood);
      expect(resolutionForZoom(13.0), MapResolution.neighborhood);
      expect(resolutionForZoom(13.99), MapResolution.neighborhood);

      expect(resolutionForZoom(14.0), MapResolution.school);
      expect(resolutionForZoom(18.0), MapResolution.school);
    });

    test('is monotonic in zoom', () {
      var previous = resolutionForZoom(3);
      for (var zoom = 3.0; zoom <= 18.0; zoom += 0.1) {
        final current = resolutionForZoom(zoom);
        expect(current.index, greaterThanOrEqualTo(previous.index));
        previous = current;
      }
    });

    test('minZoom of each resolution round-trips through the mapper', () {
      for (final resolution in MapResolution.values) {
        expect(resolutionForZoom(resolution.minZoom), resolution);
      }

      // Everything above the lowest tier must be reachable only from its own
      // threshold upwards.
      for (final resolution in MapResolution.values.skip(1)) {
        expect(
          resolutionForZoom(resolution.minZoom - 0.01).index,
          lessThan(resolution.index),
        );
      }
    });
  });

  group('MapResolution flags', () {
    test('neighborhoods and schools only appear from their threshold up', () {
      expect(MapResolution.overview.showsNeighborhoods, isFalse);
      expect(MapResolution.municipality.showsNeighborhoods, isFalse);
      expect(MapResolution.neighborhood.showsNeighborhoods, isTrue);
      expect(MapResolution.school.showsNeighborhoods, isTrue);

      expect(MapResolution.overview.showsSchools, isFalse);
      expect(MapResolution.municipality.showsSchools, isFalse);
      expect(MapResolution.neighborhood.showsSchools, isFalse);
      expect(MapResolution.school.showsSchools, isTrue);
    });
  });

  group('detailForResolution', () {
    test('increases detail strictly with resolution', () {
      final ranks = MapResolution.values
          .map((r) => detailForResolution(r).rank)
          .toList(growable: false);

      for (var i = 1; i < ranks.length; i++) {
        expect(ranks[i], greaterThanOrEqualTo(ranks[i - 1]));
      }
      expect(ranks.first, lessThan(ranks.last));
    });

    test('caps grow with detail (no more frozen simplification)', () {
      expect(MapDetail.low.maxPoints, lessThan(MapDetail.medium.maxPoints));
      expect(MapDetail.medium.maxPoints, lessThan(MapDetail.high.maxPoints));
    });
  });
}
