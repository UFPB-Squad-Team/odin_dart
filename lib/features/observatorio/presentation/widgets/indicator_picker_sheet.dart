import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/indicator.dart';
import '../observatorio_controller.dart';

Future<void> showIndicatorPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const IndicatorPickerSheet(),
  );
}

class IndicatorPickerSheet extends ConsumerWidget {
  const IndicatorPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(observatorioProvider);
    final active = ref.watch(activeIndicatorProvider);
    final scheme = Theme.of(context).colorScheme;
    final indicators = IndicatorCatalog.forModule(state.module, state.layer);

    final groups = <String, List<Indicator>>{};
    for (final indicator in indicators) {
      groups.putIfAbsent(indicator.group, () => []).add(indicator);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scroll) {
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            Text(
              'Indicador · ${state.module.label}',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              '${state.module.source} · ${state.layer.label}',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            for (final entry in groups.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 4),
                child: Text(
                  entry.key.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: state.module.accent,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                ),
              ),
              for (final indicator in entry.value)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(indicator.label),
                  subtitle: Text(indicator.description),
                  leading: Container(
                    width: 28,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(
                        colors: [indicator.colorMin, indicator.colorMax],
                      ),
                    ),
                  ),
                  trailing: indicator.id == active.id
                      ? Icon(Icons.check_circle, color: state.module.accent)
                      : null,
                  onTap: () {
                    ref.read(observatorioProvider.notifier).setIndicator(indicator.id);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ],
        );
      },
    );
  }
}
