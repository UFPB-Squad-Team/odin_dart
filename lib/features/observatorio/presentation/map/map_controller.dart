import 'dart:async';

import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/geo_bounds.dart';
import '../../domain/map_resolution.dart';
import 'map_state.dart';

/// The raw `flutter_map` controller.
///
/// Lives with the map subsystem, not with the business context — moving it out
/// of `observatorio_controller.dart` is what lets the viewport evolve without
/// touching domain state.
final mapControllerProvider = Provider<MapController>((ref) {
  final controller = MapController();
  ref.onDispose(controller.dispose);
  return controller;
});

/// Owns [MapViewportState] and nothing else.
///
/// Two-tier reactivity:
///  * `setCamera` publishes the live camera immediately (cheap, filtered by
///    `select` at every consumer), so a zoom badge or cluster granularity can
///    follow the finger smoothly.
///  * [MapViewportState.query] is republished only after [settleDelay] of
///    camera stillness, so network scoping ignores intermediate frames.
class MapViewportController extends Notifier<MapViewportState> {
  /// How long the camera must stay still before the network scope may change.
  static const settleDelay = Duration(milliseconds: 220);

  Timer? _settle;
  bool _disposed = false;

  @override
  MapViewportState build() {
    ref.onDispose(() {
      _disposed = true;
      _settle?.cancel();
      _settle = null;
    });
    return MapViewportState.initial();
  }

  /// Publishes a camera position. Bind this to `MapOptions.onPositionChanged`.
  void setCamera({
    required LatLng center,
    required double zoom,
    GeoBounds? bounds,
    bool gestureDriven = false,
  }) {
    state = MapViewportState(
      zoom: zoom,
      center: center,
      bounds: bounds ?? state.bounds,
      resolution: resolutionForZoom(zoom),
      // Carried over untouched: the settled query is what triggers fetches.
      query: state.query,
      gestureDriven: gestureDriven,
    );
    _scheduleSettle();
  }

  /// Matches `MapOptions.onPositionChanged`'s `PositionCallback` typedef.
  void onCameraChanged(MapCamera camera, bool hasGesture) {
    setCamera(
      center: camera.center,
      zoom: camera.zoom,
      bounds: geoBoundsFrom(camera.visibleBounds),
      gestureDriven: hasGesture,
    );
  }

  /// Publishes the settled query right away.
  ///
  /// Used after the initial `onMapReady` and after programmatic moves, where
  /// waiting for the debounce would just delay the first real fetch.
  void syncNow() {
    _settle?.cancel();
    _settle = null;
    _settleNow();
  }

  void _scheduleSettle() {
    _settle?.cancel();
    _settle = Timer(settleDelay, _settleNow);
  }

  void _settleNow() {
    _settle = null;
    if (_disposed) return;
    final candidate = MapQuery.fromViewport(state);
    if (candidate == state.query) return;
    state = state.copyWith(query: candidate);
  }
}

/// The camera/spatial context. Independent from `observatorioProvider`.
final mapViewportProvider =
    NotifierProvider<MapViewportController, MapViewportState>(
  MapViewportController.new,
);

/// Current level of detail. Rebuilds only when a zoom threshold is crossed.
final mapResolutionProvider = Provider<MapResolution>(
  (ref) => ref.watch(mapViewportProvider.select((state) => state.resolution)),
);

/// Settled network scope. Rebuilds only when the scope actually changes.
final mapQueryProvider = Provider<MapQuery>(
  (ref) => ref.watch(mapViewportProvider.select((state) => state.query)),
);

/// Geometry tier required by the current camera.
final mapDetailProvider = Provider<MapDetail>(
  (ref) => detailForResolution(ref.watch(mapResolutionProvider)),
);
