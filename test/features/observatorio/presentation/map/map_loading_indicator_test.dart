import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:odin_app/features/observatorio/data/map_repository.dart';
import 'package:odin_app/features/observatorio/data/observatorio_repository.dart';
import 'package:odin_app/features/observatorio/data/territory_request.dart';
import 'package:odin_app/features/observatorio/domain/geo_bounds.dart';
import 'package:odin_app/features/observatorio/presentation/map/map_controller.dart';
import 'package:odin_app/features/observatorio/presentation/map/map_loading_indicator.dart';
import 'package:odin_app/features/observatorio/presentation/map/map_providers.dart';

const _viewportBox = GeoBounds(
  south: -7.2,
  west: -36.7,
  north: -7.0,
  east: -36.5,
);

MapCamera _camera() => MapCamera(
      crs: const Epsg3857(),
      center: const LatLng(-7.1, -36.6),
      zoom: 6,
      rotation: 0,
      nonRotatedSize: const math.Point<double>(360, 640),
    );

/// Dio adapter whose reply is awaited by the test, so "pending" and "data
/// emitted" are two moments the test controls by hand.
class _AsyncStubAdapter implements HttpClientAdapter {
  _AsyncStubAdapter(this.handler);

  final Future<(int, Object)> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final (status, body) = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, Object?> _featureJson(String id) => <String, Object?>{
      'type': 'Feature',
      'id': id,
      'properties': <String, Object?>{'municipio': id},
      'geometry': <String, Object?>{
        'type': 'Polygon',
        'coordinates': [
          <List<double>>[
            [-36.70, -7.20],
            [-36.50, -7.20],
            [-36.50, -7.00],
            [-36.70, -7.00],
            [-36.70, -7.20],
          ],
        ],
      },
    };

Map<String, Object?> _collection(List<Map<String, Object?>> features) =>
    <String, Object?>{'type': 'FeatureCollection', 'features': features};

ProviderContainer _container(_AsyncStubAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://stub.test/api/v1'))
    ..httpClientAdapter = adapter;

  final container = ProviderContainer(
    overrides: [
      observatorioRepositoryProvider.overrideWith(
        (ref) => ObservatorioRepository(dio, spatialEnabled: true),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ViewportActivityController', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
      addTearDown(container.dispose);
    });

    test('drag start/end toggles the activity signal', () {
      final notifier = container.read(viewportActivityProvider.notifier);
      final camera = _camera();

      expect(container.read(viewportActivityProvider), isFalse);

      notifier.onMapEvent(
        MapEventMoveStart(source: MapEventSource.dragStart, camera: camera),
      );
      expect(container.read(viewportActivityProvider), isTrue);

      notifier.onMapEvent(
        MapEventMoveEnd(source: MapEventSource.dragEnd, camera: camera),
      );
      expect(container.read(viewportActivityProvider), isFalse);
    });

    test('a dropped end-event cannot latch the signal on', () {
      final notifier = container.read(viewportActivityProvider.notifier);

      notifier.onMapEvent(
        MapEventFlingAnimationStart(
          source: MapEventSource.flingAnimationController,
          camera: _camera(),
        ),
      );
      expect(container.read(viewportActivityProvider), isTrue);

      // This is exactly what `MapViewportController._settleNow()` now does.
      notifier.onCameraSettled();
      expect(container.read(viewportActivityProvider), isFalse);
    });
  });

  group('mapBusyProvider', () {
    test(
        'is true while a viewport-scoped fetch is pending and false once the '
        'data lands', () async {
      final gate = Completer<void>();
      late final String activeBbox;

      final adapter = _AsyncStubAdapter((options) async {
        if (options.queryParameters['bbox'] == activeBbox) await gate.future;
        return (200, _collection([_featureJson('seed')]));
      });
      final container = _container(adapter);

      // Drive the camera onto the bbox-scoped detail tier.
      container.read(mapViewportProvider.notifier)
        ..setCamera(
          center: const LatLng(-7.1, -36.6),
          zoom: 12.5,
          bounds: _viewportBox,
        )
        ..syncNow();

      final active = container.read(territoryRequestProvider);
      expect(active.bbox, isNotNull);
      activeBbox = active.bbox!.toBbox();

      // A strictly smaller box: it *contributes* geometry to `active` but does
      // not *cover* it, so `active` still has to go to the network.
      final box = active.bbox!;
      final seed = TerritoryRequest(
        uf: active.uf,
        municipioId: active.municipioId,
        layer: active.layer,
        detail: active.detail,
        bbox: GeoBounds(
          south: box.south + box.latSpan * 0.25,
          west: box.west + box.lngSpan * 0.25,
          north: box.north - box.latSpan * 0.25,
          east: box.east - box.lngSpan * 0.25,
        ),
      );
      expect(seed.bbox!.isValid, isTrue);

      final store = container.read(territoryGeometryStoreProvider.notifier);
      await store.ensure(seed);
      expect(container.read(mapBusyProvider), isFalse);

      final inflight = store.ensure(active);
      expect(
        container.read(mapBusyProvider),
        isTrue,
        reason: 'pending request while geometry is still on screen = refining',
      );

      gate.complete();
      await inflight;

      expect(container.read(mapBusyProvider), isFalse, reason: 'data emitted');
    });
  });

  group('MapLoadingIndicator (widget)', () {
    Widget harness(ProviderContainer container, {required VoidCallback onTap}) {
      return UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Stack(
              fit: StackFit.expand,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: const ColoredBox(color: Colors.white),
                ),
                const MapLoadingIndicator(),
              ],
            ),
          ),
        ),
      );
    }

    Finder bar() => find.descendant(
          of: find.byType(MapActivityLatch),
          matching: find.byType(LinearProgressIndicator),
        );

    testWidgets(
        'shows feedback while the viewport is busy and drops it once the '
        'camera settles', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(harness(container, onTap: () {}));

      expect(bar(), findsNothing);

      final notifier = container.read(viewportActivityProvider.notifier);
      final camera = _camera();
      notifier.onMapEvent(
        MapEventMoveStart(source: MapEventSource.dragStart, camera: camera),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(bar(), findsOneWidget);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find.descendant(
                of: find.byType(MapActivityLatch),
                matching: find.byType(AnimatedOpacity),
              ),
            )
            .opacity,
        1,
        reason: 'the fade-in must have finished',
      );

      notifier.onMapEvent(
        MapEventMoveEnd(source: MapEventSource.dragEnd, camera: camera),
      );

      // Still inside the minimum window: a short gesture must not blink it.
      await tester.pump(const Duration(milliseconds: 300));
      expect(bar(), findsOneWidget);

      // Minimum elapsed, trailing grace not yet over: still up.
      await tester.pump(const Duration(milliseconds: 420));
      expect(bar(), findsOneWidget);

      // Grace over, fade-out finished: the child is out of the tree, so no
      // indeterminate animation keeps ticking while idle.
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();
      expect(bar(), findsNothing);
    });

    testWidgets('never swallows a tap meant for the map', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      var taps = 0;
      await tester.pumpWidget(harness(container, onTap: () => taps++));

      container.read(viewportActivityProvider.notifier).onMapEvent(
            MapEventMoveStart(
              source: MapEventSource.dragStart,
              camera: _camera(),
            ),
          );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(bar(), findsOneWidget);
      expect(
        tester
            .widget<IgnorePointer>(
              find.descendant(
                of: find.byType(MapActivityLatch),
                matching: find.byType(IgnorePointer),
              ),
            )
            .ignoring,
        isTrue,
        reason: 'the indicator must never intercept pointer events',
      );

      // Tap dead-centre on the bar: the gesture has to reach the map below.
      await tester.tapAt(tester.getCenter(bar()));
      await tester.pump();

      expect(taps, 1);
    });
  });
}
