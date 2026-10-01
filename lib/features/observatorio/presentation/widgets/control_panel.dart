import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/indicator.dart';
import '../map/map_providers.dart';
import '../observatorio_controller.dart';
import 'indicator_picker_sheet.dart';
import 'panel.dart';

class ControlPanel extends ConsumerWidget {
  const ControlPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(observatorioProvider);
    final indicator = ref.watch(activeIndicatorProvider);
    final choropleth = ref.watch(choroplethProvider);
    final scheme = Theme.of(context).colorScheme;
    final controller = ref.read(observatorioProvider.notifier);

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Panel(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.municipio == null) _StateSummaryLine(uf: state.uf),
              SegmentedButton<ModuleId>(
                showSelectedIcon: false,
                style: SegmentedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  selectedBackgroundColor: state.module.accent.withAlpha(45),
                  selectedForegroundColor: scheme.onSurface,
                ),
                segments: [
                  for (final module in ModuleId.values)
                    ButtonSegment<ModuleId>(
                      value: module,
                      label: Text(module.label),
                      icon: Icon(Icons.circle, size: 10, color: module.accent),
                    ),
                ],
                selected: {state.module},
                onSelectionChanged: (selection) =>
                    controller.setModule(selection.first),
              ),
              const SizedBox(height: 8),
              InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => showIndicatorPicker(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Indicador no mapa',
                              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                            ),
                            Text(
                              indicator.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.unfold_more, color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _Legend(indicator: indicator, data: choropleth),
            ],
          ),
        ),
      ),
    );
  }
}

class _StateSummaryLine extends ConsumerWidget {
  const _StateSummaryLine({required this.uf});

  final String uf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(stateSummaryProvider(uf)).valueOrNull;
    if (summary == null) return const SizedBox.shrink();

    final parts = <String>[
      '${formatNumber(summary.totalMunicipios.toDouble())} municípios',
      '${formatNumber(summary.totalEscolas.toDouble())} escolas',
      '${formatNumber(summary.totalAlunos.toDouble())} alunos',
    ];

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        '${summary.uf} · ${parts.join(' · ')}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.indicator, required this.data});

  final Indicator indicator;
  final ChoroplethData? data;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final labelStyle = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);

    if (data == null) {
      return Text('Sem dados para este indicador', style: labelStyle);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: scheme.outline),
            gradient: LinearGradient(
              colors: [indicator.colorMin, indicator.colorMax],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              formatWithUnit(data!.min, decimals: indicator.decimals, unit: indicator.unit),
              style: labelStyle,
            ),
            Text('${data!.count} com dados', style: labelStyle),
            Text(
              formatWithUnit(data!.max, decimals: indicator.decimals, unit: indicator.unit),
              style: labelStyle,
            ),
          ],
        ),
      ],
    );
  }
}
