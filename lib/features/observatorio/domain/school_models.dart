import 'package:latlong2/latlong.dart';

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return <String, dynamic>{};
}

double? _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? _asInt(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

String? _asText(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

Object? _first(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value != null) return value;
  }
  return null;
}

class SchoolListItem {
  const SchoolListItem({
    required this.inep,
    required this.name,
    this.municipio,
    this.bairro,
    this.dependencia,
    this.localizacao,
    this.alunos,
  });

  factory SchoolListItem.fromJson(Map<String, dynamic> json) {
    final endereco = _asMap(json['endereco']);
    final matriculas = _asMap(json['matriculas']);
    final indicadores = _asMap(json['indicadores']);

    return SchoolListItem(
      inep: _asText(_first(json, ['escola_id_inep', 'escolaIdInep', 'inep'])) ??
          _asText(json['id']) ??
          '',
      name: _asText(_first(json, ['escola_nome', 'escolaNome', 'nome'])) ??
          'Escola sem nome',
      municipio: _asText(_first(json, ['municipio_nome', 'municipioNome'])),
      bairro: _asText(endereco['bairro'] ?? json['bairro']),
      dependencia: _asText(_first(json, ['dependencia_adm', 'dependenciaAdm'])),
      localizacao:
          _asText(_first(json, ['tipo_localizacao', 'tipoLocalizacao'])),
      alunos: _asInt(matriculas['totalAlunos'] ?? indicadores['totalAlunos']),
    );
  }

  final String inep;
  final String name;
  final String? municipio;
  final String? bairro;
  final String? dependencia;
  final String? localizacao;
  final int? alunos;
}

class SchoolPage {
  const SchoolPage({
    required this.items,
    required this.totalItems,
    required this.page,
    required this.pageSize,
  });

  factory SchoolPage.fromJson(Map<String, dynamic> json) {
    final raw = json['schools'] ?? json['items'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => SchoolListItem.fromJson(_asMap(item)))
            .where((item) => item.inep.isNotEmpty)
            .toList(growable: false)
        : const <SchoolListItem>[];

    return SchoolPage(
      items: items,
      totalItems: _asInt(json['total_items']) ?? items.length,
      page: _asInt(json['page']) ?? 1,
      pageSize: _asInt(json['page_size']) ?? items.length,
    );
  }

  final List<SchoolListItem> items;
  final int totalItems;
  final int page;
  final int pageSize;

  bool get hasMore => page * pageSize < totalItems;
}

class SchoolStage {
  const SchoolStage({
    required this.label,
    this.alunosPorTurma,
    this.aprovacao,
    this.reprovacao,
    this.horasAula,
  });

  final String label;
  final double? alunosPorTurma;
  final double? aprovacao;
  final double? reprovacao;
  final double? horasAula;

  bool get hasData =>
      (alunosPorTurma ?? 0) > 0 ||
      (aprovacao ?? 0) > 0 ||
      (reprovacao ?? 0) > 0 ||
      (horasAula ?? 0) > 0;
}

class InfraItem {
  const InfraItem(this.label, this.available);

  final String label;
  final bool available;
}

class InfraGroup {
  const InfraGroup(this.title, this.items);

  final String title;
  final List<InfraItem> items;
}

class SchoolDetail {
  const SchoolDetail({
    required this.inep,
    required this.name,
    this.municipio,
    this.uf,
    this.dependencia,
    this.localizacao,
    this.logradouro,
    this.numero,
    this.bairro,
    this.cep,
    this.location,
    this.totalAlunos,
    this.matriculas = const [],
    this.stages = const [],
    this.infra = const [],
    this.salas = const [],
  });

  factory SchoolDetail.fromJson(Map<String, dynamic> json) {
    final endereco = _asMap(json['endereco']);
    final matriculas = _asMap(json['matriculas']);
    final indicadores = _asMap(json['indicadores']);
    final infra = _asMap(json['infraestrutura']);
    final geo = _asMap(json['localizacao']);

    LatLng? location;
    final coordinates = geo['coordinates'];
    if (coordinates is List && coordinates.length >= 2) {
      final lng = _asDouble(coordinates[0]);
      final lat = _asDouble(coordinates[1]);
      if (lat != null && lng != null) location = LatLng(lat, lng);
    }

    InfraGroup group(String title, Map<String, dynamic> source, List<(String, String)> labels) {
      return InfraGroup(title, [
        for (final (key, label) in labels)
          if (source[key] is bool) InfraItem(label, source[key] as bool),
      ]);
    }

    final groups = <InfraGroup>[
      group('Estrutura', infra, _structureLabels),
      group('Internet', _asMap(infra['internet']), _internetLabels),
      group('Equipamentos', _asMap(infra['equipamentos']), _equipmentLabels),
    ].where((item) => item.items.isNotEmpty).toList(growable: false);

    final salas = _asMap(infra['salas']);

    return SchoolDetail(
      inep: _asText(_first(json, ['escola_id_inep', 'escolaIdInep'])) ?? '',
      name: _asText(_first(json, ['escola_nome', 'escolaNome'])) ??
          'Escola sem nome',
      municipio: _asText(_first(json, ['municipio_nome', 'municipioNome'])),
      uf: _asText(_first(json, ['estado_sigla', 'estadoSigla'])),
      dependencia: _asText(_first(json, ['dependencia_adm', 'dependenciaAdm'])),
      localizacao:
          _asText(_first(json, ['tipo_localizacao', 'tipoLocalizacao'])),
      logradouro: _asText(endereco['logradouro']),
      numero: _asText(endereco['numero']),
      bairro: _asText(endereco['bairro']),
      cep: _asText(endereco['cep']),
      location: location,
      totalAlunos:
          _asInt(matriculas['totalAlunos'] ?? indicadores['totalAlunos']),
      matriculas: [
        for (final (key, label) in _enrollmentLabels)
          if (_asInt(matriculas[key]) != null) (label, _asInt(matriculas[key])!),
      ],
      stages: [
        for (final (key, label) in _stageLabels)
          SchoolStage(
            label: label,
            alunosPorTurma: _asDouble(_asMap(indicadores[key])['alunosPorTurma']),
            aprovacao: _asDouble(_asMap(indicadores[key])['taxaAprovacao']),
            reprovacao: _asDouble(_asMap(indicadores[key])['taxaReprovacao']),
            horasAula: _asDouble(_asMap(indicadores[key])['horasAulaDiarias']),
          ),
      ].where((stage) => stage.hasData).toList(growable: false),
      infra: groups,
      salas: [
        if (_asInt(salas['utilizadas']) != null)
          ('Salas utilizadas', _asInt(salas['utilizadas'])!),
        if (_asInt(salas['climatizadas']) != null)
          ('Salas climatizadas', _asInt(salas['climatizadas'])!),
        if (_asInt(salas['acessiveis']) != null)
          ('Salas acessíveis', _asInt(salas['acessiveis'])!),
      ],
    );
  }

  static const _enrollmentLabels = <(String, String)>[
    ('educacaoInfantil', 'Educação infantil'),
    ('educacaoInfantilCreche', 'Creche'),
    ('educacaoInfantilPreEscola', 'Pré-escola'),
    ('fundamentalTotal', 'Ensino fundamental'),
    ('fundamentalAnosIniciais', 'Anos iniciais'),
    ('fundamentalAnosFinais', 'Anos finais'),
    ('ensinoMedio', 'Ensino médio'),
    ('eja', 'EJA'),
  ];

  static const _stageLabels = <(String, String)>[
    ('educacaoInfantil', 'Educação infantil'),
    ('fundamentalAnosIniciais', 'Fundamental — anos iniciais'),
    ('fundamentalAnosFinais', 'Fundamental — anos finais'),
    ('ensinoMedio', 'Ensino médio'),
  ];

  static const _structureLabels = <(String, String)>[
    ('possuiAcessibilidadePcd', 'Acessibilidade PCD'),
    ('possuiAguaPotavel', 'Água potável'),
    ('possuiEnergiaPublica', 'Energia pública'),
    ('possuiEsgotoRedePublica', 'Esgoto em rede pública'),
    ('possuiColetaLixo', 'Coleta de lixo'),
    ('possuiBiblioteca', 'Biblioteca'),
    ('possuiLaboratorioInformatica', 'Lab. de informática'),
    ('possuiLaboratorioCiencias', 'Lab. de ciências'),
    ('possuiQuadraEsportes', 'Quadra de esportes'),
    ('possuiPatioCoberto', 'Pátio coberto'),
    ('possuiPatioDescoberto', 'Pátio descoberto'),
    ('possuiPiscina', 'Piscina'),
    ('possuiCozinha', 'Cozinha'),
    ('possuiRefeitorio', 'Refeitório'),
  ];

  static const _internetLabels = <(String, String)>[
    ('possuiInternet', 'Internet'),
    ('internetParaAlunos', 'Internet para alunos'),
    ('internetAdministrativa', 'Internet administrativa'),
  ];

  static const _equipmentLabels = <(String, String)>[
    ('computadorPortatilAluno', 'Notebook para alunos'),
    ('desktopAluno', 'Computador de mesa para alunos'),
    ('tabletAluno', 'Tablet para alunos'),
    ('lousaDigital', 'Lousa digital'),
    ('multimidia', 'Projetor / multimídia'),
    ('impressora', 'Impressora'),
  ];

  final String inep;
  final String name;
  final String? municipio;
  final String? uf;
  final String? dependencia;
  final String? localizacao;
  final String? logradouro;
  final String? numero;
  final String? bairro;
  final String? cep;
  final LatLng? location;
  final int? totalAlunos;
  final List<(String, int)> matriculas;
  final List<SchoolStage> stages;
  final List<InfraGroup> infra;
  final List<(String, int)> salas;

  String? get streetLine {
    final street = [logradouro, numero].whereType<String>().join(', ');
    return street.isEmpty ? null : street;
  }

  String? get cityLine {
    final city = [municipio, uf].whereType<String>().join(' — ');
    return city.isEmpty ? null : city;
  }
}
