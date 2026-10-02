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
    // The camera is done, so nothing can still be moving. This doubles as the
    // safety net for the activity signal below: a dropped end-event can never
    // latch the loading overlay on forever.
    ref.read(viewportActivityProvider.notifier).onCameraSettled();
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

/// Whether the camera is being moved *right now*: drag, pinch, fling inertia,
/// double-tap zoom or scroll wheel.
///
/// This is the instant half of the visual feedback. It flips on the first
/// movement event, long before the settle debounce can publish a query and
/// long before any request exists — while [TerritoryView.isRefining] (in
/// `map_providers.dart`) covers the second half, once the fetch really starts.
///
/// Deliberately *not* a field of [MapViewportState]: that class's value equality
/// is the network-scoping trigger asserted by `map_viewport_test.dart`, and an
/// ephemeral UI flag must never take part in it.
class ViewportActivityController extends Notifier<bool> {
  @override
  bool build() => false;

  /// Bind to `MapOptions.onMapEvent`.
  void onMapEvent(MapEvent event) {
    switch (event) {
      case MapEventMoveStart():
      case MapEventFlingAnimationStart():
      case MapEventDoubleTapZoomStart():
      case MapEventScrollWheelZoom():
        _set(true);
      case MapEventMoveEnd():
      case MapEventFlingAnimationEnd():
      case MapEventFlingAnimationNotStarted():
      case MapEventDoubleTapZoomEnd():
        _set(false);
      default:
        break;
    }
  }

  /// The camera settled. Whatever the event stream last reported, no movement
  /// can still be in flight.
  ///
  /// Scroll-wheel zoom in particular emits a start with no end, so the settle
  /// is the only reliable place that clears it.
  void onCameraSettled() => _set(false);

  void _set(bool value) {
    if (state == value) return;
    state = value;
  }
}

/// The activity signal feeding the map's lightweight loading indicator.
final viewportActivityProvider =
    NotifierProvider<ViewportActivityController, bool>(
  ViewportActivityController.new,
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
