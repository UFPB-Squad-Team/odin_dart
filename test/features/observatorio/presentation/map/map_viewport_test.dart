import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:odin_app/features/observatorio/domain/geo_bounds.dart';
import 'package:odin_app/features/observatorio/domain/map_resolution.dart';
import 'package:odin_app/features/observatorio/presentation/map/map_controller.dart';
import 'package:odin_app/features/observatorio/presentation/map/map_state.dart';

const _viewportBox = GeoBounds(
  south: -7.2,
  west: -36.7,
  north: -7.0,
  east: -36.5,
);

/// A whole-state box: at zoom 6 the quantisation lattice is ~1.4°, which makes
/// sub-cell pan behaviour deterministic to assert.
const _overviewBox = GeoBounds(
  south: -9.0,
  west: -39.0,
  north: -5.0,
  east: -34.0,
);

MapQuery _queryFor({
  required double zoom,
  required GeoBounds bounds,
  required LatLng center,
}) {
  return MapQuery.fromViewport(
    MapViewportState(
      zoom: zoom,
      center: center,
      bounds: bounds,
      resolution: resolutionForZoom(zoom),
      query: const MapQuery(
        detail: MapDetail.low,
        bounds: _viewportBox,
        zoomBucket: 0,
      ),
    ),
  );
}

Future<void> _settle() => Future<void>.delayed(
      MapViewportController.settleDelay + const Duration(milliseconds: 150),
    );

void main() {
  group('MapQuery.fromViewport', () {
    test('derives the detail tier from the zoom', () {
      expect(
        _queryFor(
          zoom: 6,
          bounds: _viewportBox,
          center: const LatLng(-7.1, -36.6),
        ).detail,
        MapDetail.low,
      );
      expect(
        _queryFor(
          zoom: 9,
          bounds: _viewportBox,
          center: const LatLng(-7.1, -36.6),
        ).detail,
        MapDetail.medium,
      );
      expect(
        _queryFor(
          zoom: 12,
          bounds: _viewportBox,
          center: const LatLng(-7.1, -36.6),
        ).detail,
        MapDetail.high,
      );
    });

    test('pads the box so a short pan can be served from cache', () {
      final query = _queryFor(
        zoom: 12,
        bounds: _viewportBox,
        center: const LatLng(-7.1, -36.6),
      );

      expect(query.bounds.south, lessThan(_viewportBox.south));
      expect(query.bounds.north, greaterThan(_viewportBox.north));
      expect(query.bounds.west, lessThan(_viewportBox.west));
      expect(query.bounds.east, greaterThan(_viewportBox.east));
    });

    test('snaps to a coarser lattice as zoom decreases', () {
      expect(MapQuery.gridFor(12), lessThan(MapQuery.gridFor(8)));
    });

    test('ignores the center entirely', () {
      final a = _queryFor(
        zoom: 6,
        bounds: _overviewBox,
        center: const LatLng(-7.1, -36.6),
      );
      final b = _queryFor(
        zoom: 6,
        bounds: _overviewBox,
        center: const LatLng(-6.5, -35.9),
      );

      expect(a, b);
    });

    test('absorbs a sub-cell pan', () {
      // At zoom 6 the lattice is ~1.4°, so a 0.05° inward pan (≈5 km) lands in
      // the same cells and must not change the query.
      const smaller = GeoBounds(
        south: -8.95,
        west: -38.95,
        north: -5.05,
        east: -34.05,
      );
      final a = _queryFor(
        zoom: 6,
        bounds: _overviewBox,
        center: const LatLng(-7.1, -36.6),
      );
      final b = _queryFor(
        zoom: 6,
        bounds: smaller,
        center: const LatLng(-7.1, -36.6),
      );

      expect(a, b);
    });
  });

  group('MapViewportController', () {
    late ProviderContainer container;
    late MapViewportController notifier;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
      notifier = container.read(mapViewportProvider.notifier);
    });

    test('starts in the default state at the overview tier', () {
      final state = container.read(mapViewportProvider);

      expect(state.resolution, MapResolution.overview);
      expect(state.detail, MapDetail.low);
      expect(state.query.detail, MapDetail.low);
    });

    test('updates zoom and resolution live but defers the query', () async {
      final settled = container.read(mapViewportProvider).query;

      notifier.setCamera(
        center: const LatLng(-7.1, -36.6),
        zoom: 12.5,
        bounds: _viewportBox,
      );

      final live = container.read(mapViewportProvider);
      expect(live.zoom, 12.5);
      expect(live.resolution, MapResolution.neighborhood);
      // Debounced: the network scope must not follow every camera frame.
      expect(live.query, settled);

      await _settle();

      final afterSettle = container.read(mapViewportProvider).query;
      expect(afterSettle, isNot(settled));
      expect(afterSettle.detail, MapDetail.high);
    });

    test('syncNow publishes the settled query immediately', () {
      final settled = container.read(mapViewportProvider).query;

      notifier.setCamera(
        center: const LatLng(-7.1, -36.6),
        zoom: 15,
        bounds: _viewportBox,
      );
      notifier.syncNow();

      final state = container.read(mapViewportProvider);
      expect(state.query, isNot(settled));
      expect(state.query.detail, MapDetail.high);
      expect(state.resolution, MapResolution.school);
    });

    test('a sub-cell pan never changes the query', () async {
      const smaller = GeoBounds(
        south: -8.95,
        west: -38.95,
        north: -5.05,
        east: -34.05,
      );

      notifier.setCamera(
        center: const LatLng(-7.10, -36.60),
        zoom: 6,
        bounds: _overviewBox,
      );
      notifier.syncNow();
      final before = container.read(mapViewportProvider).query;

      notifier.setCamera(
        center: const LatLng(-7.10, -36.60),
        zoom: 6,
        bounds: smaller,
      );
      await _settle();

      expect(container.read(mapViewportProvider).query, before);
    });

    test('crossing a threshold flips the resolution exactly once', () async {
      final transitions = <MapResolution>[];
      container.listen<MapResolution>(
        mapResolutionProvider,
        (previous, next) => transitions.add(next),
      );

      for (final zoom in <double>[7.9, 8.1, 10.4, 11.2]) {
        notifier.setCamera(
          center: const LatLng(-7.1, -36.6),
          zoom: zoom,
          bounds: _viewportBox,
        );
      }
      await _settle();

      // 7.9 is the initial tier, 10.4 stays inside the municipality tier.
      expect(
        transitions,
        [MapResolution.municipality, MapResolution.neighborhood],
      );
    });
  });
}
