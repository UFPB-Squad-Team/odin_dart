import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/map_repository.dart';
import '../../data/territory_request.dart';
import '../../domain/map_resolution.dart';
import '../../domain/territory_feature.dart';
import '../../domain/territory_layer.dart';
import 'map_controller.dart';
import '../observatorio_controller.dart';

/// Which dataset is actually drawn: a pure function of
/// (domain drill-down, camera resolution).
///
/// This is the seam that turns the old click-only layer switch into a
/// camera-driven one: neighborhoods appear as soon as the camera is close
/// enough *and* a municipality has been selected, and disappear again when the
/// user zooms back out — while the domain selection itself is untouched.
final renderedTerritoryLayerProvider = Provider<TerritoryLayer>((ref) {
  final hasMunicipio =
      ref.watch(observatorioProvider.select((s) => s.municipio != null));
  final resolution = ref.watch(mapResolutionProvider);
  final wantsNeighborhoods = hasMunicipio && resolution.showsNeighborhoods;
  return wantsNeighborhoods ? TerritoryLayer.bairro : TerritoryLayer.municipio;
});

/// The single request the map currently needs.
///
/// Aggregate tiers (overview/medium municipalities) are always whole-state:
/// they are small, and bounding-box scoping there would punch holes at the state
/// edges and break the initial `fitCamera`. Detail tiers carry the settled
/// viewport box so fetching becomes incremental.
///
/// The box is attached even when the API is not known to support it — the
/// repository decides whether to *send* it, and degrades to whole-territory
/// payloads that (correctly) report themselves as covering everything.
final territoryRequestProvider = Provider<TerritoryRequest>((ref) {
  final uf = ref.watch(observatorioProvider.select((s) => s.uf));
  final municipioId =
      ref.watch(observatorioProvider.select((s) => s.municipio?.id));
  final layer = ref.watch(renderedTerritoryLayerProvider);
  final detail = ref.watch(mapDetailProvider);
  final query = ref.watch(mapQueryProvider);

  return TerritoryRequest(
    uf: uf,
    municipioId: layer == TerritoryLayer.bairro ? municipioId : null,
    layer: layer,
    detail: detail,
    bbox: detail.rank >= MapDetail.high.rank ? query.bounds : null,
  );
});

/// Everything the rendering layer needs to know about the current geometry.
@immutable
class TerritoryView {
  const TerritoryView({
    required this.request,
    required this.features,
    required this.isLoading,
    required this.isRefining,
    required this.isWholeTerritory,
    this.error,
  });

  final TerritoryRequest request;

  /// Merged geometry to draw right now (may be a previous tier while a finer
  /// one loads).
  final List<TerritoryFeature> features;

  /// Nothing at all to draw: show the blocking loader.
  final bool isLoading;

  /// Drawing something, fetching something better: show a quiet indicator.
  final bool isRefining;

  /// Whether the payload covers the whole level rather than a viewport tile.
  final bool isWholeTerritory;

  final Object? error;

  bool get isEmpty => features.isEmpty;
}

final territoryViewProvider = Provider<TerritoryView>((ref) {
  final request = ref.watch(territoryRequestProvider);
  final state = ref.watch(territoryGeometryStoreProvider);
  final store = ref.watch(territoryGeometryStoreProvider.notifier);

  final features = store.featuresFor(request);
  final pending = state.isPending(request);
  final error = state.errorFor(request);

  return TerritoryView(
    request: request,
    features: features,
    isLoading: features.isEmpty && pending && error == null,
    isRefining: pending && features.isNotEmpty,
    isWholeTerritory: !(state.entries[request]?.spatialParamsApplied ?? false),
    error: error,
  );
});

/// The single "the map is working" signal the loading overlay binds to.
///
/// True while the camera is under a gesture (instant feedback) or while the
/// current request is in flight and geometry is still on screen (refinement).
///
/// Deliberately excludes [TerritoryView.isLoading]: an empty map already gets
/// its own centred placeholder in `observatorio_page.dart`, so the canvas never
/// shows two indicators for the same wait.
final mapBusyProvider = Provider<bool>((ref) {
  if (ref.watch(viewportActivityProvider)) return true;
  return ref.watch(territoryViewProvider).isRefining;
});

/// Features currently painted, used to derive the choropleth.
final renderedFeaturesProvider = Provider<List<TerritoryFeature>>(
  (ref) => ref.watch(territoryViewProvider).features,
);

/// Whether the school POI layer is drawn: the user's toggle inside a
/// drilled-down municipality. Clustering keeps it cheap at any zoom.
final schoolClusterEnabledProvider = Provider<bool>((ref) {
  final showSchools =
      ref.watch(observatorioProvider.select((s) => s.showSchools));
  final hasMunicipio =
      ref.watch(observatorioProvider.select((s) => s.municipio != null));
  return showSchools && hasMunicipio;
});

@immutable
class ChoroplethData {
  const ChoroplethData({
    required this.colors,
    required this.values,
    required this.min,
    required this.max,
  });

  final Map<String, Color> colors;
  final Map<String, double> values;
  final double min;
  final double max;

  int get count => values.length;
}

/// Colour scale for the features currently on screen.
///
/// Derived from the *rendered* geometry, so switching detail tier does not
/// change the values — the same features come back with the same properties,
/// only with more vertices.
final choroplethProvider = Provider<ChoroplethData?>((ref) {
  final features = ref.watch(renderedFeaturesProvider);
  final indicator = ref.watch(activeIndicatorProvider);
  if (features.isEmpty) return null;

  final values = <String, double>{};
  var min = double.infinity;
  var max = double.negativeInfinity;

  for (final feature in features) {
    final value = indicator.read(feature.properties);
    if (value == null) continue;
    values[feature.id] = value;
    if (value < min) min = value;
    if (value > max) max = value;
  }

  if (values.isEmpty) return null;

  final range = max - min;
  final colors = <String, Color>{
    for (final entry in values.entries)
      entry.key:
          indicator.colorAt(range == 0 ? 0.5 : (entry.value - min) / range),
  };

  return ChoroplethData(colors: colors, values: values, min: min, max: max);
});

