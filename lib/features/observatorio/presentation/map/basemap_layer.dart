import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_map_tiles/vector_map_tiles.dart';

import '../../../../core/config/env.dart';

abstract final class BasemapStyles {
  static const light =
      'https://basemaps.cartocdn.com/gl/positron-gl-style/style.json';
  static const dark =
      'https://basemaps.cartocdn.com/gl/dark-matter-gl-style/style.json';
}

final basemapStyleProvider =
    FutureProvider.family<Style?, bool>((ref, dark) async {
  try {
    return await StyleReader(
      uri: dark ? BasemapStyles.dark : BasemapStyles.light,
    ).read();
  } catch (_) {
    return null;
  }
});

class BasemapLayer extends ConsumerWidget {
  const BasemapLayer({super.key, required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(basemapStyleProvider(dark)).valueOrNull;

    if (style == null) return _RasterFallback(dark: dark);

    return VectorTileLayer(
      key: ValueKey(dark),
      tileProviders: style.providers,
      theme: style.theme,
      sprites: style.sprites,
    );
  }
}

class _RasterFallback extends StatelessWidget {
  const _RasterFallback({required this.dark});

  final bool dark;

  @override
  Widget build(BuildContext context) {
    return TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: Env.userAgentPackage,
      maxNativeZoom: 19,
      tileBuilder: dark
          ? (context, tileWidget, tile) =>
              darkModeTilesContainerBuilder(context, tileWidget)
          : null,
    );
  }
}
