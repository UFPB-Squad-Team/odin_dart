import 'package:flutter/foundation.dart';

import '../domain/geo_bounds.dart';
import '../domain/map_resolution.dart';
import '../domain/territory_layer.dart';

/// Cache key for one geometry tier of one territory level.
///
/// Keying by [detail] is what makes zoom-driven LoD cheap: every tier is cached
/// independently, so zooming in and back out reuses already-parsed geometry
/// instead of re-requesting and re-parsing it.
///
/// [bbox] is only populated when viewport-scoped fetching is active, so a `null`
/// bbox means "the whole territory level in one request".
@immutable
class TerritoryRequest {
  const TerritoryRequest({
    required this.uf,
    required this.municipioId,
    required this.layer,
    required this.detail,
    this.bbox,
  });

  /// State abbreviation, always upper case.
  final String uf;

  /// Municipality id — only meaningful when [layer] is [TerritoryLayer.bairro].
  final String? municipioId;

  /// Which dataset is being drawn.
  final TerritoryLayer layer;

  /// Geometry precision tier.
  final MapDetail detail;

  /// Viewport scope, or `null` for a whole-territory fetch.
  final GeoBounds? bbox;

  /// Whether a specific municipality must be resolved before fetching.
  bool get isBairro => layer == TerritoryLayer.bairro;

  /// Identity of the territory *level*, ignoring precision and scope.
  ///
  /// This is what decides when the camera is allowed to `fitCamera`: a domain
  /// change may move the camera, a detail/scope change must not.
  (String, TerritoryLayer, String?) get levelKey => (uf, layer, municipioId);

  /// The same level at a different precision.
  TerritoryRequest withDetail(MapDetail detail) => TerritoryRequest(
        uf: uf,
        municipioId: municipioId,
        layer: layer,
        detail: detail,
        bbox: bbox,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TerritoryRequest &&
          other.uf == uf &&
          other.municipioId == municipioId &&
          other.layer == layer &&
          other.detail == detail &&
          other.bbox == bbox);

  @override
  int get hashCode => Object.hash(uf, municipioId, layer, detail, bbox);

  @override
  String toString() => 'TerritoryRequest($uf, ${layer.name}, '
      'municipio: $municipioId, detail: ${detail.name}, '
      'bbox: ${bbox?.toBbox() ?? 'all'})';
}

