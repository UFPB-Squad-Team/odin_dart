import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/territory/estados_nordeste.dart';
import '../../../../core/theme/odin_colors.dart';
import '../../data/map_repository.dart';
import '../../data/territory_request.dart';
import '../../domain/geo_bounds.dart';
import '../../domain/map_resolution.dart';
import '../../domain/observatorio_models.dart';
import '../../domain/territory_feature.dart';
import '../../domain/territory_layer.dart';
import '../observatorio_controller.dart';
import 'basemap_layer.dart';
import 'map_controller.dart';
import 'map_loading_indicator.dart';
import 'map_providers.dart';
import 'map_state.dart';
import 'school_layer.dart';
import 'territory_layer.dart';

/// The camera-driven map.
///
/// Responsibilities kept deliberately narrow:
///  * publish every camera change to `mapViewportProvider`;
///  * request exactly one geometry tier for the settled viewport;
///  * move the camera *only* when the business context changes.
///
/// It never owns domain state, and zooming never re-fits the camera.
class TerritoryMap extends ConsumerStatefulWidget {
  const TerritoryMap({
    super.key,
    required this.onFeatureTap,
    required this.onSchoolTap,
  });

  final ValueChanged<TerritoryFeature> onFeatureTap;
  final ValueChanged<SchoolPoint> onSchoolTap;

  @override
  ConsumerState<TerritoryMap> createState() => _TerritoryMapState();
}

class _TerritoryMapState extends ConsumerState<TerritoryMap> {
  bool _ready = false;
  LatLngBounds? _pendingFit;
  double? _pendingMinZoom;
  ProviderSubscription<TerritoryRequest>? _requestSubscription;

  static const _fitPadding = EdgeInsets.fromLTRB(24, 150, 24, 24);

  @override
  void initState() {
    super.initState();
    // Kick off the very first fetch as soon as the request is known, and keep
    // the geometry store in step with the settled viewport from then on.
    _requestSubscription = ref.listenManual<TerritoryRequest>(
      territoryRequestProvider,
      (previous, next) =>
          ref.read(territoryGeometryStoreProvider.notifier).ensure(next),
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _requestSubscription?.close();
    super.dispose();
  }

  LatLngBounds? _boundsOf(List<TerritoryFeature> features) {
    double? south;
    double? west;
    double? north;
    double? east;

    for (final feature in features) {
      if (!feature.hasBounds) continue;
      south = south == null || feature.south! < south ? feature.south : south;
      north = north == null || feature.north! > north ? feature.north : north;
      west = west == null || feature.west! < west ? feature.west : west;
      east = east == null || feature.east! > east ? feature.east : east;
    }

    if (south == null || west == null || north == null || east == null) {
      return null;
    }
    return GeoBounds(south: south, west: west, north: north, east: east)
        .toLatLngBounds();
  }

  /// Fits the camera to [features].
  ///
  /// [minZoom] lets a deliberate drill-down guarantee at least the resolution it
  /// asked for, even when the territory is large enough that a plain bounds fit
  /// would land below the neighborhood threshold.
  void _fit(List<TerritoryFeature> features, {double? minZoom}) {
    final bounds = _boundsOf(features);
    if (bounds == null) return;

    if (!_ready) {
      _pendingFit = bounds;
      _pendingMinZoom = minZoom;
      return;
    }

    final controller = ref.read(mapControllerProvider);
    controller.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: _fitPadding),
    );
    if (minZoom != null && controller.camera.zoom < minZoom) {
      controller.move(controller.camera.center, minZoom);
    }
  }

  void _handleTap(LatLng point) {
    final features = ref.read(territoryViewProvider).features;
    for (final feature in features.reversed) {
      if (feature.containsPoint(point)) {
        widget.onFeatureTap(feature);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(mapControllerProvider);
    final view = ref.watch(territoryViewProvider);
    final choropleth = ref.watch(choroplethProvider);
    final state = ref.watch(observatorioProvider);
    final showSchools = ref.watch(schoolClusterEnabledProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Re-fit only when the business context changes. A detail/tier change while
    // zooming must never move the camera — that was the main regression risk of
    // making geometry resolution-driven.
    ref.listen<(String, TerritoryLayer, String?)>(
      territoryRequestProvider.select((request) => request.levelKey),
      (previous, next) {
        if (previous == null || previous == next) return;
        final features = ref.read(territoryViewProvider).features;
        if (features.isEmpty) return;
        _fit(
          features,
          minZoom: next.$2 == TerritoryLayer.bairro
              ? MapResolution.neighborhood.minZoom
              : null,
        );
      },
    );

    final estado = Nordeste.bySigla(state.uf);
    final municipio = state.municipio;

    return FlutterMap(
      mapController: controller,
      options: MapOptions(
        initialCenter: estado.center,
        initialZoom: estado.zoom,
        minZoom: 3,
        maxZoom: 18,
        backgroundColor: isDark ? OdinColors.zinc950 : OdinColors.zinc100,
        interactionOptions: const InteractionOptions(
          flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
        ),
        // The camera is the driver of the whole geospatial pipeline.
        onPositionChanged:
            ref.read(mapViewportProvider.notifier).onCameraChanged,
        // Instant, gesture-level half of the visual feedback: flips on the
        // first movement event, well before the settle debounce can fetch.
        onMapEvent: ref.read(viewportActivityProvider.notifier).onMapEvent,
        onTap: (tapPosition, point) => _handleTap(point),
        onMapReady: () {
          _ready = true;
          // Publish the real camera (constraints may have adjusted it) and let
          // the settled query go out immediately.
          ref.read(mapViewportProvider.notifier).syncNow();

          final pending = _pendingFit;
          final minZoom = _pendingMinZoom;
          _pendingFit = null;
          _pendingMinZoom = null;

          if (pending != null) {
            controller.fitCamera(
              CameraFit.bounds(bounds: pending, padding: _fitPadding),
            );
            if (minZoom != null && controller.camera.zoom < minZoom) {
              controller.move(controller.camera.center, minZoom);
            }
          } else if (view.features.isNotEmpty) {
            _fit(view.features);
          }
        },
      ),
      children: [
        BasemapLayer(dark: isDark),
        TerritoryPolygonLayer(
          features: view.features,
          choropleth: choropleth,
          detail: view.request.detail,
          selectedId: state.selectedId,
        ),
        if (showSchools && municipio != null)
          SchoolClusterLayer(
            municipalityId: municipio.id,
            onSchoolTap: widget.onSchoolTap,
          ),
        const RichAttributionWidget(
          alignment: AttributionAlignment.bottomLeft,
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
            TextSourceAttribution('CARTO'),
          ],
        ),
        // Non-blocking activity feedback. `FlutterMap` renders non-mobile
        // children in a static stack, so this stays pinned to the canvas while
        // the camera moves, and it ignores pointers so pan/zoom never stall.
        const MapLoadingIndicator(),
      ],
    );
  }
}
