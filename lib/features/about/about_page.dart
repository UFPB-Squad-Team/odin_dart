import 'package:flutter/material.dart';

import '../../core/theme/odin_colors.dart';
import '../observatorio/presentation/widgets/odin_logo_badge.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  static const _team = [
    'Samuel Colaço Lira Carvalho',
    'Brenno Henrique Alves da Silva Costa',
    'Deivyson Henrique Gomes Ribeiro',
    'Felipe Emidio de Medeiros Neto',
    'Gustavo Henrique Rocha Oliveira',
    'Ítalo Oliveira de Sousa',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 8),
          child: Text(
            text.toUpperCase(),
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Sobre o ODIN')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Center(child: OdinLogoBadge(size: 96)),
          const SizedBox(height: 16),
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => OdinColors.brandGradient.createShader(bounds),
              child: const Text(
                'ODIN',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              'Observatório de Dados Integrados do Nordeste',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ),
          heading('O projeto'),
          Text(
            'Projeto de extensão da UFPB (LEMA) que reúne bases públicas dispersas e de difícil leitura em um único mapa, para apoiar a sociedade civil e o poder público com evidências claras no planejamento urbano, educacional e social.',
            style: theme.textTheme.bodyMedium,
          ),
          heading('O que você encontra'),
          Text(
            'Indicadores de educação (Censo Escolar) e socioeconômicos (Censo Demográfico do IBGE) dos nove estados do Nordeste, com navegação por estado, município, bairro e escola.',
            style: theme.textTheme.bodyMedium,
          ),
          heading('Equipe de extensão'),
          for (final name in _team)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(name, style: theme.textTheme.bodyMedium),
            ),
          const SizedBox(height: 8),
          Text(
            'Coordenação: Jorge Henrique Norões Viana',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          heading('Créditos do mapa'),
          Text(
            '© OpenStreetMap contributors · © CARTO',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Versão beta 0.1.0',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ),
        ],
      ),
    );
  }
}
