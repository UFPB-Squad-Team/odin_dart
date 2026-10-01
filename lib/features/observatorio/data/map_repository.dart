import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/map_resolution.dart';
import '../domain/territory_feature.dart';
import 'observatorio_repository.dart';
import 'territory_request.dart';

/// One fetched geometry tile.
@immutable
class TerritoryEntry {
  const TerritoryEntry({
    required this.request,
    required this.features,
    required this.spatialParamsApplied,
  });

  final TerritoryRequest request;
  final List<TerritoryFeature> features;

  /// `false` means the payload is the *whole* territory level (the server
  /// ignored the spatial parameters), so it covers everything at its detail.
  final bool spatialParamsApplied;

  /// Whether this entry can answer [active] without another request.
  ///
  /// A finer tier answers a coarser request (extra vertices are harmless), but
  /// not the other way round — that is exactly the zoom-in case that must fetch.
  bool covers(TerritoryRequest active) {
    if (request.levelKey != active.levelKey) return false;
    if (request.detail.rank < active.detail.rank) return false;
    if (!spatialParamsApplied || request.bbox == null) return true;
    final bounds = active.bbox;
    if (bounds == null) return false;
    return request.bbox!.containsBounds(bounds);
  }

  /// Whether this entry contributes geometry to [active].
  bool contributesTo(TerritoryRequest active) {
    if (request.levelKey != active.levelKey) return false;
    if (request.detail.rank < active.detail.rank) return false;
    final entryBounds = request.bbox;
    final activeBounds = active.bbox;
    if (!spatialParamsApplied || entryBounds == null || activeBounds == null) {
      return true;
    }
    return entryBounds.intersects(activeBounds);
  }
}

@immutable
class TerritoryGeometryState {
  const TerritoryGeometryState({
    this.entries = const <TerritoryRequest, TerritoryEntry>{},
    this.pending = const <TerritoryRequest>{},
    this.errors = const <TerritoryRequest, Object>{},
  });

  final Map<TerritoryRequest, TerritoryEntry> entries;
  final Set<TerritoryRequest> pending;
  final Map<TerritoryRequest, Object> errors;

  bool isPending(TerritoryRequest request) => pending.contains(request);

  Object? errorFor(TerritoryRequest request) => errors[request];
}

/// Owns the multi-resolution geometry cache.
///
/// Fetches are incremental and scoped to the settled viewport
/// ([TerritoryRequest.bbox]); entries are merged by feature id on read, so
/// panning accumulates coverage instead of replacing it. A least-recently-used
/// cap keeps memory bounded no matter how far the user roams.
class TerritoryGeometryStore extends Notifier<TerritoryGeometryState> {
  /// Enough for several tiers of the current level plus recently visited ones.
  static const maxEntries = 24;

  final _order = <TerritoryRequest>[];
  bool _disposed = false;

  @override
  TerritoryGeometryState build() {
    ref.onDispose(() {
      _disposed = true;
      _order.clear();
    });
    return const TerritoryGeometryState();
  }

  /// Loads [request] unless it is already cached, covered, in flight or failed.
  ///
  /// Failure is sticky until [retry] so a flaky network cannot spam the API.
  Future<void> ensure(TerritoryRequest request) async {
    if (state.entries.containsKey(request)) return;
    if (state.pending.contains(request)) return;
    if (state.errors.containsKey(request)) return;
    if (_hasCoverage(request)) return;

    state = TerritoryGeometryState(
      entries: state.entries,
      pending: {...state.pending, request},
      errors: state.errors,
    );

    final repository = ref.read(observatorioRepositoryProvider);
    try {
      final payload = await repository.fetchTerritories(request);
      if (_disposed) return;
      _commit(
        TerritoryEntry(
          request: request,
          features: payload.features,
          spatialParamsApplied: payload.spatialParamsApplied,
        ),
      );
    } catch (error) {
      if (_disposed) return;
      state = TerritoryGeometryState(
        entries: state.entries,
        pending: {...state.pending}..remove(request),
        errors: {...state.errors, request: error},
      );
    }
  }

  /// Clears the failure for [request] and loads it again.
  Future<void> retry(TerritoryRequest request) async {
    state = TerritoryGeometryState(
      entries: {...state.entries}..remove(request),
      pending: state.pending,
      errors: {...state.errors}..remove(request),
    );
    await ensure(request);
  }

  /// Merged geometry for [active], from every cached entry that contributes.
  ///
  /// Duplicate ids keep the version with the most vertices, so a refined tier
  /// always wins over the coarser one it overlaps.
  List<TerritoryFeature> featuresFor(TerritoryRequest active) {
    final byId = <String, TerritoryFeature>{};

    for (final entry in state.entries.values) {
      if (!entry.contributesTo(active)) continue;
      for (final feature in entry.features) {
        final existing = byId[feature.id];
        if (existing == null || feature.vertexCount > existing.vertexCount) {
          byId[feature.id] = feature;
        }
      }
    }

    final features = byId.values.toList(growable: false);
    features.sort((a, b) => a.name.compareTo(b.name));
    return features;
  }

  /// The coarsest cached entry that still contributes to [active].
  ///
  /// Lets the map keep painting a previous tier while a finer one loads — the
  /// difference between "refines in place" and "blanks while zooming".
  TerritoryEntry? bestCached(TerritoryRequest active) {
    TerritoryEntry? best;
    for (final entry in state.entries.values) {
      if (!entry.contributesTo(active)) continue;
      if (best == null ||
          entry.request.detail.rank < best.request.detail.rank) {
        best = entry;
      }
    }
    return best;
  }

  bool _hasCoverage(TerritoryRequest request) {
    for (final entry in state.entries.values) {
      if (entry.covers(request)) return true;
    }
    return false;
  }

  void _commit(TerritoryEntry entry) {
    final entries = {...state.entries, entry.request: entry};
    _order
      ..remove(entry.request)
      ..add(entry.request);

    while (_order.length > maxEntries) {
      entries.remove(_order.removeAt(0));
    }

    state = TerritoryGeometryState(
      entries: entries,
      pending: {...state.pending}..remove(entry.request),
      errors: {...state.errors}..remove(entry.request),
    );
  }
}

final territoryGeometryStoreProvider =
    NotifierProvider<TerritoryGeometryStore, TerritoryGeometryState>(
  TerritoryGeometryStore.new,
);
