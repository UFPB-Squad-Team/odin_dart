import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/indicator.dart';
import '../../domain/school_models.dart';
import '../observatorio_controller.dart';

class SchoolDetailPage extends ConsumerWidget {
  const SchoolDetailPage({super.key, required this.inep});

  final String inep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(schoolDetailProvider(inep));

    return Scaffold(
      appBar: AppBar(title: const Text('Escola')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(describeError(error), textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => ref.invalidate(schoolDetailProvider(inep)),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
        data: (school) => _SchoolDetailBody(school: school),
      ),
    );
  }
}

class _SchoolDetailBody extends StatelessWidget {
  const _SchoolDetailBody({required this.school});

  final SchoolDetail school;

  @override
  Widget build(BuildContext context) {
    final accent = ModuleId.educacao.accent;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final addressRows = <(String, String)>[
      if (school.streetLine != null) ('Endereço', school.streetLine!),
      if (school.bairro != null) ('Bairro', school.bairro!),
      if (school.cityLine != null) ('Cidade', school.cityLine!),
      if (school.cep != null) ('CEP', school.cep!),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        Text(
          school.name,
          style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (school.dependencia != null) _Tag(text: school.dependencia!, color: accent),
            if (school.localizacao != null)
              _Tag(text: school.localizacao!, color: scheme.onSurfaceVariant),
            if (school.inep.isNotEmpty)
              _Tag(text: 'INEP ${school.inep}', color: scheme.onSurfaceVariant),
          ],
        ),
        if (school.totalAlunos != null) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Matrículas',
            accent: accent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatNumber(school.totalAlunos!.toDouble()),
                  style: textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                Text(
                  'alunos matriculados',
                  style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (school.matriculas.isNotEmpty) const SizedBox(height: 8),
                for (final (label, value) in school.matriculas)
                  _Row(label: label, value: formatNumber(value.toDouble())),
              ],
            ),
          ),
        ],
        if (addressRows.isNotEmpty)
          _Section(
            title: 'Localização',
            accent: accent,
            child: Column(
              children: [
                for (final (label, value) in addressRows) _Row(label: label, value: value),
              ],
            ),
          ),
        for (final stage in school.stages)
          _Section(
            title: stage.label,
            accent: accent,
            child: Column(
              children: [
                if (stage.alunosPorTurma != null)
                  _Row(
                    label: 'Alunos por turma',
                    value: formatNumber(stage.alunosPorTurma!, decimals: 1),
                  ),
                if (stage.aprovacao != null)
                  _Row(
                    label: 'Aprovação',
                    value: formatWithUnit(stage.aprovacao!, decimals: 1, unit: '%'),
                  ),
                if (stage.reprovacao != null)
                  _Row(
                    label: 'Reprovação',
                    value: formatWithUnit(stage.reprovacao!, decimals: 1, unit: '%'),
                  ),
                if (stage.horasAula != null)
                  _Row(
                    label: 'Horas-aula por dia',
                    value: formatWithUnit(stage.horasAula!, decimals: 1, unit: 'h'),
                  ),
              ],
            ),
          ),
        for (final group in school.infra)
          _Section(
            title: group.title,
            accent: accent,
            child: Column(
              children: [
                for (final item in group.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(
                          item.available ? Icons.check_circle : Icons.cancel_outlined,
                          size: 20,
                          color: item.available ? accent : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            item.label,
                            style: textTheme.bodyMedium?.copyWith(
                              color: item.available ? null : scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        if (school.salas.isNotEmpty)
          _Section(
            title: 'Salas',
            accent: accent,
            child: Column(
              children: [
                for (final (label, value) in school.salas)
                  _Row(label: label, value: formatNumber(value.toDouble())),
              ],
            ),
          ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.accent, required this.child});

  final String title;
  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
