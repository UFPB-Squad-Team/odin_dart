import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odin_app/features/observatorio/data/map_repository.dart';
import 'package:odin_app/features/observatorio/data/observatorio_repository.dart';
import 'package:odin_app/features/observatorio/data/territory_request.dart';
import 'package:odin_app/features/observatorio/domain/geo_bounds.dart';
import 'package:odin_app/features/observatorio/domain/map_resolution.dart';
import 'package:odin_app/features/observatorio/domain/territory_layer.dart';

/// Records every outgoing request and replies with a canned GeoJSON payload.
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final (int status, Object body) Function(RequestOptions options) handler;
  final requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final (status, body) = handler(options);
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

Dio _dio(_StubAdapter adapter) =>
    Dio(BaseOptions(baseUrl: 'https://stub.test/api/v1'))
      ..httpClientAdapter = adapter;

/// A closed ring with [vertices] + 1 points, so `vertexCount` is predictable.
Map<String, Object?> _featureJson(String id, String name, int vertices) {
  final ring = <List<double>>[];
  for (var i = 0; i < vertices; i++) {
    final angle = 2 * math.pi * i / vertices;
    ring.add([-36.6 + 0.05 * math.cos(angle), -7.1 + 0.05 * math.sin(angle)]);
  }
  ring.add(ring.first);
  return <String, Object?>{
    'type': 'Feature',
    'id': id,
    'properties': <String, Object?>{'municipio': name},
    'geometry': <String, Object?>{'type': 'Polygon', 'coordinates': [ring]},
  };
}

Map<String, Object?> _collection(List<Map<String, Object?>> features) =>
    <String, Object?>{'type': 'FeatureCollection', 'features': features};

const _uf = 'PB';
const _municipioId = '2507507';

TerritoryRequest _request({
  MapDetail detail = MapDetail.high,
  GeoBounds? bbox,
  TerritoryLayer layer = TerritoryLayer.bairro,
}) =>
    TerritoryRequest(
      uf: _uf,
      municipioId: layer == TerritoryLayer.bairro ? _municipioId : null,
      layer: layer,
      detail: detail,
      bbox: bbox,
    );

const _west = GeoBounds(south: -7.2, west: -36.7, north: -7.0, east: -36.6);
const _east = GeoBounds(south: -7.2, west: -36.6, north: -7.0, east: -36.5);
const _all = GeoBounds(south: -7.2, west: -36.7, north: -7.0, east: -36.5);

void main() {
  ProviderContainer containerWith(_StubAdapter adapter, {required bool spatial}) {
    final container = ProviderContainer(
      overrides: [
        observatorioRepositoryProvider.overrideWith(
          (ref) =>
              ObservatorioRepository(_dio(adapter), spatialEnabled: spatial),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('spatial parameters disabled (default, unverified backend)', () {
    test('fetches once per level and never sends resolution or bbox', () async {
      final adapter = _StubAdapter(
        (_) => (200, _collection([_featureJson('a', 'A', 3)])),
      );
      final container = containerWith(adapter, spatial: false);
      final store = container.read(territoryGeometryStoreProvider.notifier);

      await store.ensure(_request(bbox: _west));

      expect(adapter.requests, hasLength(1));
      expect(
        adapter.requests.single.queryParameters,
        isNot(contains('resolution')),
      );
      expect(adapter.requests.single.queryParameters, isNot(contains('bbox')));

      // Re-asking for the same tier is free.
      await store.ensure(_request(bbox: _west));
      expect(adapter.requests, hasLength(1));

      // A whole-territory payload covers every viewport at that tier, so panning
      // must not trigger another request.
      await store.ensure(_request(bbox: _east));
      expect(adapter.requests, hasLength(1));

      final state = container.read(territoryGeometryStoreProvider);
      expect(state.pending, isEmpty);
      expect(state.errors, isEmpty);
      expect(state.entries.values.single.spatialParamsApplied, isFalse);
    });

    test('a separate tier fetches separately', () async {
      final adapter = _StubAdapter(
        (_) => (200, _collection([_featureJson('a', 'A', 3)])),
      );
      final container = containerWith(adapter, spatial: false);
      final store = container.read(territoryGeometryStoreProvider.notifier);

      await store.ensure(_request(detail: MapDetail.high));
      await store.ensure(_request(detail: MapDetail.medium));

      expect(adapter.requests, hasLength(2));
    });
  });

  group('spatial parameters enabled', () {
    test('sends resolution and the viewport bbox', () async {
      final adapter = _StubAdapter(
        (_) => (200, _collection([_featureJson('a', 'A', 3)])),
      );
      final container = containerWith(adapter, spatial: true);
      final store = container.read(territoryGeometryStoreProvider.notifier);

      await store.ensure(_request(bbox: _west));

      final params = adapter.requests.single.queryParameters;
      expect(params['resolution'], MapDetail.high.apiValue);
      expect(params['bbox'], _west.toBbox());
      expect(params['municipio_id'], _municipioId);
      expect(
        container
            .read(territoryGeometryStoreProvider)
            .entries
            .values
            .single
            .spatialParamsApplied,
        isTrue,
      );
    });

    test('downgrades after a 4xx and stops sending the parameters', () async {
      final adapter = _StubAdapter(
        (options) => options.queryParameters.containsKey('resolution')
            ? (422, <String, Object?>{'detail': 'unknown query parameter'})
            : (200, _collection([_featureJson('a', 'A', 3)])),
      );
      final container = containerWith(adapter, spatial: true);
      final store = container.read(territoryGeometryStoreProvider.notifier);

      await store.ensure(_request(bbox: _west));

      // The first attempt carried the parameters and was rejected; the retry
      // did not.
      expect(adapter.requests, hasLength(2));
      expect(adapter.requests.first.queryParameters, contains('resolution'));
      expect(
        adapter.requests.last.queryParameters,
        isNot(contains('resolution')),
      );

      final state = container.read(territoryGeometryStoreProvider);
      expect(state.errors, isEmpty, reason: 'the retry succeeded');
      expect(state.entries.values.single.features, hasLength(1));
      expect(state.entries.values.single.spatialParamsApplied, isFalse);
    });

    test('a 5xx failure is recorded and not retried automatically', () async {
      final adapter = _StubAdapter(
        (_) => (500, <String, Object?>{'error': 'boom'}),
      );
      final container = containerWith(adapter, spatial: false);
      final store = container.read(territoryGeometryStoreProvider.notifier);

      await store.ensure(_request());

      expect(adapter.requests, hasLength(1));
      expect(
        container.read(territoryGeometryStoreProvider).errors,
        hasLength(1),
      );

      // Sticky failure: re-asking must not hammer the API.
      await store.ensure(_request());
      expect(adapter.requests, hasLength(1));

      // An explicit retry clears it and fetches again.
      await store.retry(_request());
      expect(adapter.requests, hasLength(2));
      expect(container.read(territoryGeometryStoreProvider).errors, isEmpty);
    });
  });

  group('merging', () {
    test('accumulates tiles and keeps the most detailed copy of an id', () async {
      final adapter = _StubAdapter((options) {
        final bbox = options.queryParameters['bbox'] as String?;
        if (bbox != null && bbox.startsWith('-36.7,')) {
          return (
            200,
            _collection([
              _featureJson('only-west', 'West', 3),
              _featureJson('shared', 'Shared', 3),
            ])
          );
        }
        return (
          200,
          _collection([
            _featureJson('shared', 'Shared', 7),
            _featureJson('only-east', 'East', 3),
          ])
        );
      });
      final container = containerWith(adapter, spatial: true);
      final store = container.read(territoryGeometryStoreProvider.notifier);

      await store.ensure(_request(bbox: _west));
      await store.ensure(_request(bbox: _east));

      expect(adapter.requests, hasLength(2));

      final features = store.featuresFor(_request(bbox: _all));
      expect(
        features.map((feature) => feature.id).toSet(),
        {'only-west', 'shared', 'only-east'},
      );

      final shared = features.firstWhere((feature) => feature.id == 'shared');
      expect(shared.vertexCount, 8, reason: 'the finer copy must win');
    });

    test('does not reuse a coarser tier for a finer request', () async {
      final adapter = _StubAdapter(
        (_) => (200, _collection([_featureJson('a', 'A', 3)])),
      );
      final container = containerWith(adapter, spatial: true);
      final store = container.read(territoryGeometryStoreProvider.notifier);

      await store.ensure(_request(detail: MapDetail.medium, bbox: _all));

      // The camera zoomed in: a detail tier must be fetched, not silently
      // served by the coarser geometry (that is the whole point of LoD).
      await store.ensure(_request(detail: MapDetail.high, bbox: _all));

      expect(adapter.requests, hasLength(2));
    });
  });
}
