import 'package:latlong2/latlong.dart';

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

class StateSummary {
  const StateSummary({
    required this.uf,
    required this.nome,
    required this.totalMunicipios,
    required this.totalEscolas,
    required this.totalAlunos,
    required this.populacao,
    required this.idebIniciais,
  });

  factory StateSummary.fromJson(Map<String, dynamic> json) {
    final educacao = json['educacao'];
    final socio = json['socioeconomico'];
    final edu = educacao is Map ? educacao : const <String, dynamic>{};
    final soc = socio is Map ? socio : const <String, dynamic>{};

    return StateSummary(
      uf: (json['sg_uf'] ?? '').toString(),
      nome: (json['estado'] ?? json['sg_uf'] ?? '').toString(),
      totalMunicipios: _asInt(json['total_municipios']) ?? 0,
      totalEscolas: _asInt(edu['total_escolas']) ?? 0,
      totalAlunos: _asInt(edu['total_alunos']) ?? 0,
      populacao: _asInt(soc['populacao_total']) ?? 0,
      idebIniciais: _asDouble(edu['avg_ideb_iniciais']),
    );
  }

  final String uf;
  final String nome;
  final int totalMunicipios;
  final int totalEscolas;
  final int totalAlunos;
  final int populacao;
  final double? idebIniciais;
}

enum SearchKind {
  escola,
  logradouro,
  cep,
  municipio,
  bairro,
  outro;

  static SearchKind parse(String? value) {
    return SearchKind.values.firstWhere(
      (kind) => kind.name == value,
      orElse: () => SearchKind.outro,
    );
  }

  String get label {
    switch (this) {
      case SearchKind.escola:
        return 'Escola';
      case SearchKind.logradouro:
        return 'Logradouro';
      case SearchKind.cep:
        return 'CEP';
      case SearchKind.municipio:
        return 'Município';
      case SearchKind.bairro:
        return 'Bairro';
      case SearchKind.outro:
        return 'Local';
    }
  }
}

class SearchResult {
  const SearchResult({
    required this.id,
    required this.kind,
    required this.label,
    required this.subtitle,
    required this.municipioId,
    this.location,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    LatLng? location;
    final coordinates = json['coordinates'];
    if (coordinates is List && coordinates.length >= 2) {
      final lng = _asDouble(coordinates[0]);
      final lat = _asDouble(coordinates[1]);
      if (lat != null && lng != null) location = LatLng(lat, lng);
    }

    return SearchResult(
      id: (json['id'] ?? '').toString(),
      kind: SearchKind.parse(json['kind']?.toString()),
      label: (json['label'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      municipioId: (json['municipioIdIbge'] ?? '').toString(),
      location: location,
    );
  }

  final String id;
  final SearchKind kind;
  final String label;
  final String subtitle;
  final String municipioId;
  final LatLng? location;
}

class SchoolPoint {
  const SchoolPoint({
    required this.id,
    required this.name,
    required this.location,
    this.dependencia,
    this.localizacao,
    this.bairro,
    this.municipio,
    this.ideb,
    this.alunos,
    this.inep,
  });

  static SchoolPoint? fromFeature(Map<String, dynamic> feature) {
    final geometry = feature['geometry'];
    final propsRaw = feature['properties'];
    if (geometry is! Map || propsRaw is! Map) return null;

    final coordinates = geometry['coordinates'];
    if (coordinates is! List || coordinates.length < 2) return null;
    final lng = _asDouble(coordinates[0]);
    final lat = _asDouble(coordinates[1]);
    if (lat == null || lng == null) return null;

    final props = propsRaw.map((k, v) => MapEntry(k.toString(), v));
    final inep = (props['escola_id_inep'] ?? props['inep'])?.toString();
    final id = (feature['id'] ?? props['id'] ?? inep ?? '$lat,$lng').toString();

    return SchoolPoint(
      id: id,
      name: (props['escola_nome'] ?? 'Escola sem nome').toString(),
      location: LatLng(lat, lng),
      dependencia: props['dependencia_adm']?.toString(),
      localizacao: props['tipo_localizacao']?.toString(),
      bairro: props['bairro']?.toString(),
      municipio: props['municipio_nome']?.toString(),
      ideb: _asDouble(props['ideb']),
      alunos: _asInt(props['totalAlunos']),
      inep: inep,
    );
  }

  final String id;
  final String name;
  final LatLng location;
  final String? dependencia;
  final String? localizacao;
  final String? bairro;
  final String? municipio;
  final double? ideb;
  final int? alunos;
  final String? inep;
}
