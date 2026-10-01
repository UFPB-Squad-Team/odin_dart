import 'dart:ui';

import '../../../core/theme/odin_colors.dart';
import 'territory_layer.dart';

enum ModuleId {
  educacao('Educação', 'Censo Escolar INEP', OdinColors.educacao),
  socioeconomico('Socioeconômico', 'Censo Demográfico IBGE 2022', OdinColors.socioeconomico);

  const ModuleId(this.label, this.source, this.accent);

  final String label;
  final String source;
  final Color accent;
}

Color _hex(String value) => Color(int.parse('FF$value', radix: 16));

double? _toDouble(Object? value) {
  if (value is num) {
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
  if (value is String) {
    final d = double.tryParse(value.replaceAll(',', '.'));
    return d != null && d.isFinite ? d : null;
  }
  return null;
}

class Indicator {
  Indicator({
    required this.id,
    required this.module,
    required this.group,
    required this.label,
    required this.description,
    required String colorMin,
    required String colorMax,
    required this.paths,
    this.unit,
    this.decimals = 1,
    this.higherIsBetter = true,
    this.onBairro = true,
  })  : colorMin = _hex(colorMin),
        colorMax = _hex(colorMax);

  final String id;
  final ModuleId module;
  final String group;
  final String label;
  final String description;
  final Color colorMin;
  final Color colorMax;
  final List<List<String>> paths;
  final String? unit;
  final int decimals;
  final bool higherIsBetter;
  final bool onBairro;

  bool availableOn(TerritoryLayer layer) =>
      layer == TerritoryLayer.municipio || onBairro;

  Color colorAt(double normalized) {
    final t = normalized.clamp(0.0, 1.0);
    return Color.lerp(colorMin, colorMax, t) ?? colorMax;
  }

  double? read(Map<String, dynamic> properties) {
    for (final path in paths) {
      Object? current = properties;
      for (final key in path) {
        if (current is Map) {
          current = current[key];
        } else {
          current = null;
          break;
        }
      }
      final value = _toDouble(current);
      if (value != null) return value;
    }
    return _toDouble(properties[id]);
  }
}

abstract final class IndicatorCatalog {
  static const _infra = 'Infraestrutura';
  static const _ideb = 'IDEB';
  static const _fluxo = 'Aprovação e abandono';
  static const _tdi = 'Distorção idade-série';
  static const _quant = 'Quantitativos';
  static const _raca = 'Cor ou raça';
  static const _educPop = 'Educação da população';
  static const _sane = 'Saneamento';
  static const _pop = 'População e domicílios';
  static const _hab = 'Habitação';

  static final List<Indicator> all = List.unmodifiable([
    ..._educacao,
    ..._socioeconomico,
  ]);

  static List<Indicator> forModule(ModuleId module, TerritoryLayer layer) {
    return all
        .where((i) => i.module == module && i.availableOn(layer))
        .toList(growable: false);
  }

  static Indicator resolve(
    ModuleId module,
    TerritoryLayer layer,
    String? indicatorId,
  ) {
    final options = forModule(module, layer);
    return options.firstWhere(
      (i) => i.id == indicatorId,
      orElse: () => options.first,
    );
  }

  static final List<Indicator> _educacao = [
    Indicator(id: 'pct_com_internet', module: ModuleId.educacao, group: _infra, label: 'Internet (geral)', description: 'Escolas com acesso à internet', unit: '%', colorMin: 'FEF3C7', colorMax: 'B45309', paths: const [['educacao', 'pctComInternet']]),
    Indicator(id: 'pct_com_internet_alunos', module: ModuleId.educacao, group: _infra, label: 'Internet para alunos', description: 'Escolas com internet disponível para alunos', unit: '%', colorMin: 'FEF3C7', colorMax: '92400E', paths: const [['educacao', 'pctComInternetAlunos']]),
    Indicator(id: 'pct_com_biblioteca', module: ModuleId.educacao, group: _infra, label: 'Biblioteca', description: 'Escolas com biblioteca ou sala de leitura', unit: '%', colorMin: 'EDE9FE', colorMax: '6D28D9', paths: const [['educacao', 'pctComBiblioteca']]),
    Indicator(id: 'pct_com_lab_informatica', module: ModuleId.educacao, group: _infra, label: 'Lab. informática', description: 'Escolas com laboratório de informática', unit: '%', colorMin: 'D1FAE5', colorMax: '065F46', paths: const [['educacao', 'pctComLaboratorioInformatica'], ['educacao', 'pctComLabInformatica']]),
    Indicator(id: 'pct_com_lab_ciencias', module: ModuleId.educacao, group: _infra, label: 'Lab. ciências', description: 'Escolas com laboratório de ciências', unit: '%', colorMin: 'ECFDF5', colorMax: '047857', paths: const [['educacao', 'pctComLaboratorioCiencias']]),
    Indicator(id: 'pct_com_quadra_esportes', module: ModuleId.educacao, group: _infra, label: 'Quadra de esportes', description: 'Escolas com quadra de esportes', unit: '%', colorMin: 'FEF3C7', colorMax: 'D97706', paths: const [['educacao', 'pctComQuadraEsportes']], onBairro: false),
    Indicator(id: 'pct_sem_acessibilidade', module: ModuleId.educacao, group: _infra, label: 'Sem acessibilidade PCD', description: 'Escolas sem infraestrutura de acessibilidade', unit: '%', colorMin: 'FEF9C3', colorMax: 'B91C1C', higherIsBetter: false, paths: const [['educacao', 'pctSemAcessibilidade']]),
    Indicator(id: 'media_ideb_anos_iniciais', module: ModuleId.educacao, group: _ideb, label: 'IDEB anos iniciais', description: 'IDEB médio dos anos iniciais do fundamental', colorMin: 'E0F2FE', colorMax: '0369A1', paths: const [['educacao', 'mediaIdebAnosIniciais']], onBairro: false),
    Indicator(id: 'media_ideb_anos_finais', module: ModuleId.educacao, group: _ideb, label: 'IDEB anos finais', description: 'IDEB médio dos anos finais do fundamental', colorMin: 'E0F2FE', colorMax: '0C4A6E', paths: const [['educacao', 'mediaIdebAnosFinals'], ['educacao', 'mediaIdebAnosFinais']], onBairro: false),
    Indicator(id: 'media_ideb_ensino_medio', module: ModuleId.educacao, group: _ideb, label: 'IDEB ensino médio', description: 'IDEB médio do ensino médio', colorMin: 'E0F2FE', colorMax: '164E63', paths: const [['educacao', 'mediaIdebEnsinoMedio']], onBairro: false),
    Indicator(id: 'media_taxa_aprovacao_ai', module: ModuleId.educacao, group: _fluxo, label: 'Aprovação (anos iniciais)', description: 'Taxa de aprovação nos anos iniciais', unit: '%', colorMin: 'ECFDF5', colorMax: '065F46', paths: const [['educacao', 'mediaTaxaAprovacaoAi']], onBairro: false),
    Indicator(id: 'media_taxa_aprovacao_af', module: ModuleId.educacao, group: _fluxo, label: 'Aprovação (anos finais)', description: 'Taxa de aprovação nos anos finais', unit: '%', colorMin: 'ECFDF5', colorMax: '047857', paths: const [['educacao', 'mediaTaxaAprovacaoAf']], onBairro: false),
    Indicator(id: 'media_taxa_abandono_af', module: ModuleId.educacao, group: _fluxo, label: 'Abandono (anos finais)', description: 'Taxa de abandono nos anos finais', unit: '%', colorMin: 'FEF9C3', colorMax: 'B91C1C', higherIsBetter: false, paths: const [['educacao', 'mediaTaxaAbandonoAf']], onBairro: false),
    Indicator(id: 'media_taxa_abandono_em', module: ModuleId.educacao, group: _fluxo, label: 'Abandono (ensino médio)', description: 'Taxa de abandono no ensino médio', unit: '%', colorMin: 'FEF9C3', colorMax: '991B1B', higherIsBetter: false, paths: const [['educacao', 'mediaTaxaAbandonoEm']], onBairro: false),
    Indicator(id: 'media_tdi_anos_iniciais', module: ModuleId.educacao, group: _tdi, label: 'Distorção (anos iniciais)', description: 'Distorção idade-série nos anos iniciais', unit: '%', colorMin: 'FFF7ED', colorMax: 'C2410C', higherIsBetter: false, paths: const [['educacao', 'mediaTdiAnosIniciais']], onBairro: false),
    Indicator(id: 'media_tdi_anos_finais', module: ModuleId.educacao, group: _tdi, label: 'Distorção (anos finais)', description: 'Distorção idade-série nos anos finais', unit: '%', colorMin: 'FFF7ED', colorMax: '9A3412', higherIsBetter: false, paths: const [['educacao', 'mediaTdiAnosFinais']], onBairro: false),
    Indicator(id: 'total_matriculas', module: ModuleId.educacao, group: _quant, label: 'Total de matrículas', description: 'Soma de matrículas ativas', decimals: 0, colorMin: 'E0F2FE', colorMax: '0369A1', paths: const [['educacao', 'totalMatriculas'], ['total_alunos']]),
    Indicator(id: 'total_escolas', module: ModuleId.educacao, group: _quant, label: 'Total de escolas', description: 'Número de escolas no território', decimals: 0, colorMin: 'F0FDF4', colorMax: '166534', paths: const [['educacao', 'totalEscolas']], onBairro: false),
  ];

  static final List<Indicator> _socioeconomico = [
    Indicator(id: 'pct_preta_parda', module: ModuleId.socioeconomico, group: _raca, label: 'Pop. preta/parda', description: 'População que se autodeclara preta ou parda', unit: '%', higherIsBetter: false, colorMin: 'FFF7ED', colorMax: 'C2410C', paths: const [['socioeconomico', 'raca', 'pctPretaParda']]),
    Indicator(id: 'pct_branca', module: ModuleId.socioeconomico, group: _raca, label: 'Pop. branca', description: 'População que se autodeclara branca', unit: '%', higherIsBetter: false, colorMin: 'FFF7ED', colorMax: '9A3412', paths: const [['socioeconomico', 'raca', 'pctBranca']]),
    Indicator(id: 'pct_indigena', module: ModuleId.socioeconomico, group: _raca, label: 'Pop. indígena', description: 'População que se autodeclara indígena', unit: '%', higherIsBetter: false, colorMin: 'ECFDF5', colorMax: '065F46', paths: const [['socioeconomico', 'raca', 'pctIndigena']]),
    Indicator(id: 'taxa_analfabetismo_15_mais', module: ModuleId.socioeconomico, group: _educPop, label: 'Analfabetismo 15+', description: 'Taxa de analfabetismo da população com 15 anos ou mais', unit: '%', higherIsBetter: false, colorMin: 'F0FDF4', colorMax: '15803D', paths: const [['socioeconomico', 'educacaoPopulacao', 'taxaAnalfabetismo15Mais']]),
    Indicator(id: 'pct_agua_rede_geral', module: ModuleId.socioeconomico, group: _sane, label: 'Água da rede geral', description: 'Domicílios abastecidos pela rede geral', unit: '%', colorMin: 'EFF6FF', colorMax: '1D4ED8', paths: const [['socioeconomico', 'saneamento', 'pctAguaRedeGeral']], onBairro: false),
    Indicator(id: 'pct_esgoto_rede_geral', module: ModuleId.socioeconomico, group: _sane, label: 'Esgoto da rede geral', description: 'Domicílios ligados à rede geral de esgoto', unit: '%', colorMin: 'F5F3FF', colorMax: '6D28D9', paths: const [['socioeconomico', 'saneamento', 'pctEsgotoRedeGeral']], onBairro: false),
    Indicator(id: 'pct_agua_nao_encanada', module: ModuleId.socioeconomico, group: _sane, label: 'Sem água encanada', description: 'Domicílios sem água encanada', unit: '%', higherIsBetter: false, colorMin: 'FEF9C3', colorMax: 'B91C1C', paths: const [['socioeconomico', 'saneamento', 'pctAguaNaoEncanada']]),
    Indicator(id: 'pct_agua_inadequada', module: ModuleId.socioeconomico, group: _sane, label: 'Água inadequada', description: 'Domicílios com abastecimento de água inadequado', unit: '%', higherIsBetter: false, colorMin: 'FEF9C3', colorMax: 'B91C1C', paths: const [['socioeconomico', 'saneamento', 'pctAguaInadequada']], onBairro: false),
    Indicator(id: 'pct_esgoto_inadequado', module: ModuleId.socioeconomico, group: _sane, label: 'Esgoto inadequado', description: 'Domicílios com esgotamento inadequado', unit: '%', higherIsBetter: false, colorMin: 'FEF9C3', colorMax: '991B1B', paths: const [['socioeconomico', 'saneamento', 'pctEsgotoInadequado']], onBairro: false),
    Indicator(id: 'pct_lixo_inadequado', module: ModuleId.socioeconomico, group: _sane, label: 'Lixo inadequado', description: 'Domicílios com destino inadequado do lixo', unit: '%', higherIsBetter: false, colorMin: 'FEF9C3', colorMax: '7F1D1D', paths: const [['socioeconomico', 'saneamento', 'pctLixoInadequado']], onBairro: false),
    Indicator(id: 'pct_dom_sem_banheiro', module: ModuleId.socioeconomico, group: _sane, label: 'Sem banheiro', description: 'Domicílios sem banheiro', unit: '%', higherIsBetter: false, colorMin: 'FEF9C3', colorMax: 'B91C1C', paths: const [['socioeconomico', 'saneamento', 'pctDomSemBanheiro']]),
    Indicator(id: 'total_populacao', module: ModuleId.socioeconomico, group: _pop, label: 'População total', description: 'Total de habitantes', decimals: 0, colorMin: 'F0FDF4', colorMax: '166534', paths: const [['socioeconomico', 'populacao', 'total']], onBairro: false),
    Indicator(id: 'total_domicilios', module: ModuleId.socioeconomico, group: _pop, label: 'Total de domicílios', description: 'Total de domicílios', decimals: 0, colorMin: 'F0FDF4', colorMax: '166534', paths: const [['socioeconomico', 'populacao', 'totalDomicilios']], onBairro: false),
    Indicator(id: 'pct_pop_masculina', module: ModuleId.socioeconomico, group: _pop, label: 'Pop. masculina', description: 'Participação da população masculina', unit: '%', higherIsBetter: false, colorMin: 'EFF6FF', colorMax: '1E40AF', paths: const [['socioeconomico', 'genero', 'pctPopMasculina']], onBairro: false),
    Indicator(id: 'pct_pop_feminina', module: ModuleId.socioeconomico, group: _pop, label: 'Pop. feminina', description: 'Participação da população feminina', unit: '%', higherIsBetter: false, colorMin: 'FDF2F8', colorMax: '9D174D', paths: const [['socioeconomico', 'genero', 'pctPopFeminina']], onBairro: false),
    Indicator(id: 'pct_jovens_15_29', module: ModuleId.socioeconomico, group: _pop, label: 'Jovens 15–29', description: 'Participação de jovens de 15 a 29 anos', unit: '%', higherIsBetter: false, colorMin: 'ECFDF5', colorMax: '047857', paths: const [['socioeconomico', 'estruturaEtaria', 'pctJovens15a29']], onBairro: false),
    Indicator(id: 'pct_adultos_30_59', module: ModuleId.socioeconomico, group: _pop, label: 'Adultos 30–59', description: 'Participação de adultos de 30 a 59 anos', unit: '%', higherIsBetter: false, colorMin: 'EFF6FF', colorMax: '1D4ED8', paths: const [['socioeconomico', 'estruturaEtaria', 'pctAdultos30a59']], onBairro: false),
    Indicator(id: 'pct_dom_unipessoal', module: ModuleId.socioeconomico, group: _hab, label: 'Dom. unipessoal', description: 'Domicílios com um único morador', unit: '%', higherIsBetter: false, colorMin: 'FFFBEB', colorMax: '92400E', paths: const [['socioeconomico', 'habitacao', 'pctDomUnipessoal']], onBairro: false),
    Indicator(id: 'pct_dom_tipo_casa', module: ModuleId.socioeconomico, group: _hab, label: 'Dom. tipo casa', description: 'Domicílios do tipo casa', unit: '%', higherIsBetter: false, colorMin: 'ECFDF5', colorMax: '065F46', paths: const [['socioeconomico', 'habitacao', 'pctDomTipoCasa']], onBairro: false),
    Indicator(id: 'pct_dom_tipo_apto', module: ModuleId.socioeconomico, group: _hab, label: 'Dom. tipo apartamento', description: 'Domicílios do tipo apartamento', unit: '%', higherIsBetter: false, colorMin: 'EFF6FF', colorMax: '1E40AF', paths: const [['socioeconomico', 'habitacao', 'pctDomTipoApto']], onBairro: false),
    Indicator(id: 'pct_dom_degradado', module: ModuleId.socioeconomico, group: _hab, label: 'Dom. degradado', description: 'Domicílios em condição degradada', unit: '%', higherIsBetter: false, colorMin: 'FEF9C3', colorMax: 'B91C1C', paths: const [['socioeconomico', 'habitacao', 'pctDomDegradado']]),
  ];
}
