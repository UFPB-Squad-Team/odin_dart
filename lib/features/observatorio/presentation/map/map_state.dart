import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/territory/estados_nordeste.dart';
import '../../domain/geo_bounds.dart';
import '../../domain/map_resolution.dart';

/// Conversion helpers between the immutable [GeoBounds] used as state and the
/// mutable [`LatLngBounds`] that `flutter_map` requires.
extension GeoBoundsX on GeoBounds {
  LatLngBounds toLatLngBounds() =>
      LatLngBounds.unsafe(north: north, south: south, east: east, west: west);
}

/// Reads a `LatLngBounds` (from `MapCamera.visibleBounds`) into state-safe form.
GeoBounds geoBoundsFrom(LatLngBounds bounds) => GeoBounds(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
    );

/// The network-scoping view of the camera.
///
/// Deliberately *quieter* than [MapViewportState]: it changes only after the
/// camera settles and only past a tile-aligned lattice, so panning does not
/// hammer the API. Everything that fetches should depend on this, never on the
/// raw zoom/center.
@immutable
class MapQuery {
  const MapQuery({
    required this.detail,
    required this.bounds,
    required this.zoomBucket,
  });

  /// Builds a scoped query from a live viewport.
  factory MapQuery.fromViewport(MapViewportState viewport) {
    final bucket = viewport.zoom.floor();
    return MapQuery(
      detail: detailForResolution(viewport.resolution),
      bounds: viewport.bounds.padded(prefetchHalo).quantized(gridFor(bucket)),
      zoomBucket: bucket,
    );
  }

  /// Fraction of each span added around the viewport so a short pan can be
  /// served from geometry the client already holds.
  static const double prefetchHalo = 0.35;

  /// Lattice step in degrees: a quarter of a tile at [zoomBucket].
  static double gridFor(int zoomBucket) =>
      360 / math.pow(2, zoomBucket + 2).toDouble();

  /// Geometry precision tier this query needs.
  final MapDetail detail;

  /// Padded, quantized area the client should hold geometry for.
  final GeoBounds bounds;

  /// Integer zoom this query was derived at.
  final int zoomBucket;

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      (other is MapQuery &&
          other.detail == detail &&
          other.bounds == bounds &&
          other.zoomBucket == zoomBucket);

  @override
  int get hashCode => Object.hash(detail, bounds, zoomBucket);

  @override
  String toString() =>
      'MapQuery(detail: ${detail.name}, zoom: $zoomBucket, bbox: ${bounds.toBbox()})';
}

/// Camera/spatial context, fully decoupled from the business context.
///
/// [zoom]/[center]/[bounds]/[resolution] are live (they change on every camera
/// frame so the UI can react), while [query] only settles. Consumers should
/// watch this through a `select` so a frame-by-frame assignment does not cause
/// frame-by-frame rebuilds.
@immutable
class MapViewportState {
  const MapViewportState({
    required this.zoom,
    required this.center,
    required this.bounds,
    required this.resolution,
    required this.query,
    this.gestureDriven = false,
  });

  /// Sensible starting camera for the default state, before the map reports its
  /// real camera through `onMapReady`.
  factory MapViewportState.initial() {
    final estado = Nordeste.bySigla(Nordeste.defaultUf);
    final pad = 360 / math.pow(2, estado.zoom).toDouble();
    final bounds = GeoBounds(
      south: estado.latitude - pad,
      west: estado.longitude - pad,
      north: estado.latitude + pad,
      east: estado.longitude + pad,
    );
    final viewport = MapViewportState(
      zoom: estado.zoom,
      center: estado.center,
      bounds: bounds,
      resolution: resolutionForZoom(estado.zoom),
      query: MapQuery(
        detail: detailForResolution(resolutionForZoom(estado.zoom)),
        bounds: bounds,
        zoomBucket: estado.zoom.floor(),
      ),
    );
    return viewport.copyWith(query: MapQuery.fromViewport(viewport));
  }

  /// Live camera zoom.
  final double zoom;

  /// Live camera center.
  final LatLng center;

  /// Live visible bounds.
  final GeoBounds bounds;

  /// Level of detail implied by [zoom].
  final MapResolution resolution;

  /// Settled, quantized query used for network scoping.
  final MapQuery query;

  /// Whether the camera reached this state through a user gesture.
  final bool gestureDriven;

  /// Detail tier implied by [resolution].
  MapDetail get detail => detailForResolution(resolution);

  MapViewportState copyWith({
    double? zoom,
    LatLng? center,
    GeoBounds? bounds,
    MapResolution? resolution,
    MapQuery? query,
    bool? gestureDriven,
  }) =>
      MapViewportState(
        zoom: zoom ?? this.zoom,
        center: center ?? this.center,
        bounds: bounds ?? this.bounds,
        resolution: resolution ?? this.resolution,
        query: query ?? this.query,
        gestureDriven: gestureDriven ?? this.gestureDriven,
      );

  @override
  bool operator ==(Object other) =>
      identical(other, this) ||
      (other is MapViewportState &&
          other.zoom == zoom &&
          other.center == center &&
          other.bounds == bounds &&
          other.resolution == resolution &&
          other.query == query &&
          other.gestureDriven == gestureDriven);

  @override
  int get hashCode =>
      Object.hash(zoom, center, bounds, resolution, query, gestureDriven);

  @override
  String toString() => 'MapViewportState(zoom: $zoom, res: ${resolution.name}, '
      'query: $query)';
}
