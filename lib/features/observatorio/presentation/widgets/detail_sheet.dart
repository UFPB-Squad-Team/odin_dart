import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../domain/indicator.dart';
import '../../domain/territory_feature.dart';
import '../../domain/territory_layer.dart';
import '../observatorio_controller.dart';
import 'dossier_button.dart';

class DetailSheet extends ConsumerWidget {
  const DetailSheet({
    super.key,
    required this.feature,
    required this.layer,
    this.onExploreBairros,
    this.onShowSchoolsOnMap,
  });

  final TerritoryFeature feature;
  final TerritoryLayer layer;
  final VoidCallback? onExploreBairros;
  final VoidCallback? onShowSchoolsOnMap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isBairro = layer == TerritoryLayer.bairro;
    final canFetch = !isBairro || feature.id.length == 10;
    final resumo = canFetch
        ? ref.watch(resumoProvider((bairro: isBairro, id: feature.id)))
        : null;
    final remote = resumo?.valueOrNull;
    final scheme = Theme.of(context).colorScheme;

    double? valueOf(Indicator indicator) {
      final local = indicator.read(feature.properties);
      final fetched = remote == null ? null : indicator.read(remote);

      if (indicator.decimals == 0 && indicator.unit == null) {
        final candidates = [local, fetched].whereType<double>();
        if (candidates.isEmpty) return null;
        return candidates.reduce((a, b) => a > b ? a : b);
      }
      return fetched ?? local;
    }

    final uf = (remote?['sg_uf'] ?? feature.uf)?.toString();
    final subtitle = [
      if (uf != null && uf.isNotEmpty) uf,
      isBairro ? 'Bairro' : 'Município',
    ].join(' · ');

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            Text(
              feature.name,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (resumo != null && resumo.isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            if (resumo != null && resumo.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Detalhes completos indisponíveis agora. Exibindo os dados do mapa.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            if (!isBairro) ...[
              const SizedBox(height: 16),
              if (onExploreBairros != null)
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onExploreBairros!();
                  },
                  icon: const Icon(Icons.map_outlined),
                  label: const Text('Explorar bairros'),
                ),
              const SizedBox(height: 8),
              FilledButton.tonalIcon(
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(AppRoutes.escolas(feature.id, feature.name));
                },
                icon: const Icon(Icons.format_list_bulleted),
                label: const Text('Lista de escolas do município'),
              ),
              if (onShowSchoolsOnMap != null) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onShowSchoolsOnMap!();
                  },
                  icon: const Icon(Icons.place_outlined),
                  label: const Text('Ver escolas no mapa'),
                ),
              ],
              const SizedBox(height: 8),
              DossierButton(
                scope: DossierScope.municipio,
                id: feature.id,
                name: feature.name,
              ),
            ],
            for (final module in ModuleId.values)
              _ModuleSection(module: module, valueOf: valueOf),
          ],
        );
      },
    );
  }
}

class _ModuleSection extends StatelessWidget {
  const _ModuleSection({required this.module, required this.valueOf});

  final ModuleId module;
  final double? Function(Indicator) valueOf;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = <String, List<(Indicator, double)>>{};

    for (final indicator in IndicatorCatalog.all.where((i) => i.module == module)) {
      final value = valueOf(indicator);
      if (value == null) continue;
      groups.putIfAbsent(indicator.group, () => []).add((indicator, value));
    }

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outline),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: module.accent, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    module.label,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const Spacer(),
                  Text(
                    module.source,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
              if (groups.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    'Sem dados disponíveis neste território.',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ),
              for (final entry in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 14, bottom: 4),
                  child: Text(
                    entry.key.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                  ),
                ),
                for (final (indicator, value) in entry.value)
                  _MetricRow(indicator: indicator, value: value, accent: module.accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.indicator,
    required this.value,
    required this.accent,
  });

  final Indicator indicator;
  final double value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isPercent = indicator.unit == '%';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(indicator.label, style: Theme.of(context).textTheme.bodyMedium),
              ),
              Text(
                formatWithUnit(value, decimals: indicator.decimals, unit: indicator.unit),
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          if (isPercent)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (value / 100).clamp(0.0, 1.0),
                  minHeight: 5,
                  color: accent,
                  backgroundColor: accent.withAlpha(35),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
