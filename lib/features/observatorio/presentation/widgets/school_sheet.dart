import 'package:flutter/material.dart';

import '../../../../core/utils/formatters.dart';
import '../../domain/indicator.dart';
import '../../domain/observatorio_models.dart';

class SchoolSheet extends StatelessWidget {
  const SchoolSheet({super.key, required this.school, this.onOpenDetail});

  final SchoolPoint school;
  final VoidCallback? onOpenDetail;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = <(String, String)>[
      if (school.dependencia != null) ('Dependência', school.dependencia!),
      if (school.localizacao != null) ('Localização', school.localizacao!),
      if (school.bairro != null && school.bairro!.isNotEmpty) ('Bairro', school.bairro!),
      if (school.municipio != null) ('Município', school.municipio!),
      if (school.alunos != null)
        ('Alunos', formatNumber(school.alunos!.toDouble())),
      if (school.ideb != null) ('IDEB', formatNumber(school.ideb!, decimals: 1)),
      if (school.inep != null) ('Código INEP', school.inep!),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: ModuleId.educacao.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ESCOLA',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              school.name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.$1,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        row.$2,
                        textAlign: TextAlign.end,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            if (onOpenDetail != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onOpenDetail,
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Ver detalhes da escola'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
