import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/indicator.dart';
import '../../domain/map_resolution.dart';
import '../../domain/observatorio_models.dart';
import '../observatorio_controller.dart';

/// School POIs, clustered.
///
/// At state scale every school of the municipality collapses into a single
/// counted bubble; approaching the neighborhood threshold the bubbles break into
/// sub-clusters; at [MapResolution.school] the clusters dissolve entirely and
/// individual schools become tappable. Rendering a few dozen bubble widgets
/// instead of hundreds of markers is what keeps the map smooth, while the tap
/// target at the end of the zoom is still an individual school.
class SchoolClusterLayer extends ConsumerWidget {
  const SchoolClusterLayer({
    super.key,
    required this.municipalityId,
    required this.onSchoolTap,
  });

  final String municipalityId;
  final ValueChanged<SchoolPoint> onSchoolTap;

  /// Pixel radius a cluster may cover. Chosen so a whole municipality folds into
  /// one bubble at state zoom and into a handful of sub-clusters around zoom 11.
  static const _maxClusterRadius = 58;

  /// Clusters dissolve exactly where the resolution model says individual POIs
  /// become meaningful.
  static final _disableClusteringAtZoom = MapResolution.school.minZoom.toInt();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schools = ref.watch(schoolsProvider(municipalityId)).valueOrNull;
    if (schools == null || schools.isEmpty) return const SizedBox.shrink();

    return MarkerClusterLayerWidget(
      options: MarkerClusterLayerOptions(
        maxClusterRadius: _maxClusterRadius,
        maxZoom: 18,
        disableClusteringAtZoom: _disableClusteringAtZoom,
        size: const Size(40, 40),
        padding: const EdgeInsets.all(56),
        alignment: Alignment.center,
        zoomToBoundsOnClick: true,
        spiderfyCluster: true,
        showPolygon: false,
        // Each marker owns its own gesture: tapping a school must open its sheet
        // rather than being swallowed by the layer's hit handling.
        markerChildBehavior: true,
        computeSize: (markers) => Size.square(
          30 + math.min(markers.length, 12) * 1.6,
        ),
        markers: [
          for (final school in schools)
            Marker(
              point: school.location,
              width: 34,
              height: 34,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onSchoolTap(school),
                child: const _SchoolMarker(),
              ),
            ),
        ],
        builder: (context, markers) => _ClusterBubble(
          count: markers.length,
          size: 30 + math.min(markers.length, 12) * 1.6,
        ),
      ),
    );
  }
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count, required this.size});

  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: ModuleId.educacao.accent,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 2.5),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 6),
          ],
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: Text(
              '$count',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                height: 1,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SchoolMarker extends StatelessWidget {
  const _SchoolMarker();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: ModuleId.educacao.accent,
          shape: BoxShape.circle,
          border: Border.all(color: scheme.surface, width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x55000000), blurRadius: 4),
          ],
        ),
      ),
    );
  }
}
