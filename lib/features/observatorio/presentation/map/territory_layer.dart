import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../../../../core/theme/odin_colors.dart';
import '../../domain/map_resolution.dart';
import '../../domain/territory_feature.dart';
import 'map_providers.dart';

/// Draws territory polygons with a pixel tolerance matched to the camera's
/// level of detail.
///
/// `flutter_map` already re-simplifies in *pixel* space on every floored zoom,
/// so this tolerance only decides how aggressively a given tier is thinned:
/// coarse tiers can afford to be cheap and blurry, fine tiers must stay crisp
/// because they were fetched precisely to be looked at closely.
class TerritoryPolygonLayer extends StatelessWidget {
  const TerritoryPolygonLayer({
    super.key,
    required this.features,
    required this.choropleth,
    required this.detail,
    this.selectedId,
  });

  final List<TerritoryFeature> features;
  final ChoroplethData? choropleth;
  final MapDetail detail;
  final String? selectedId;

  /// Logical pixels of tolerated error, per tier.
  double get _tolerance {
    switch (detail) {
      case MapDetail.low:
        return 0.55;
      case MapDetail.medium:
        return 0.40;
      case MapDetail.high:
        return 0.22;
    }
  }

  List<Polygon> _build({required Color noData, required Color border}) {
    final base = <Polygon>[];
    final selected = <Polygon>[];

    for (final feature in features) {
      final color = choropleth?.colors[feature.id] ?? noData;
      final isSelected = feature.id == selectedId;

      for (final polygon in feature.polygons) {
        final built = Polygon(
          points: polygon.outer,
          holePointsList: polygon.holes.isEmpty ? null : polygon.holes,
          color: color.withAlpha(isSelected ? 235 : 191),
          borderColor: isSelected ? OdinColors.selection : border,
          borderStrokeWidth: isSelected ? 3 : 0.6,
        );
        (isSelected ? selected : base).add(built);
      }
    }

    // Selected last so it paints above its neighbours.
    return [...base, ...selected];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PolygonLayer(
      polygons: _build(
        noData: isDark ? OdinColors.zinc700 : OdinColors.zinc300,
        border: isDark ? OdinColors.zinc950 : OdinColors.white,
      ),
      simplificationTolerance: _tolerance,
      polygonCulling: true,
    );
  }
}
