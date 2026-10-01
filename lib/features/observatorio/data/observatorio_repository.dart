import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/env.dart';
import '../../../core/network/dio_provider.dart';
import '../domain/map_resolution.dart';
import '../domain/observatorio_models.dart';
import '../domain/school_models.dart';
import '../domain/territory_feature.dart';
import 'geo_parser.dart';
import 'territory_request.dart';

/// Raw result of one territory request.
@immutable
class TerritoryPayload {
  const TerritoryPayload({
    required this.features,
    required this.spatialParamsApplied,
  });

  final List<TerritoryFeature> features;

  /// Whether the server honoured `resolution` / `bbox`.
  ///
  /// When `false`, [features] covers the *entire* territory level rather than
  /// just the requested box — which lets the caller treat the payload as full
  /// coverage instead of re-requesting on every pan.
  final bool spatialParamsApplied;
}

class ObservatorioRepository {
  ObservatorioRepository(this._dio, {bool? spatialEnabled})
      : _spatialEnabled = spatialEnabled ?? Env.spatialApiEnabled;

  final Dio _dio;

  /// Session-sticky capability bit. Starts from the [Env] kill-switch and is
  /// downgraded automatically the first time the API rejects the spatial
  /// parameters, so a backend that predates them still works untouched.
  bool _spatialEnabled;

  /// Whether viewport-scoped (`bbox`) fetching is currently attempted.
  bool get spatialEnabled => _spatialEnabled;

  /// Loads one geometry tier of one territory level.
  ///
  /// [TerritoryRequest.bbox] is sent as `bbox=minLon,minLat,maxLon,maxLat` and
  /// [TerritoryRequest.detail] as `resolution`. Both are optional from the
  /// server's perspective: on a 4xx the request is transparently retried
  /// without them.
  Future<TerritoryPayload> fetchTerritories(TerritoryRequest request) async {
    final wantsBairros = request.isBairro;
    final municipioId = request.municipioId;

    if (wantsBairros && (municipioId == null || municipioId.isEmpty)) {
      return const TerritoryPayload(
        features: <TerritoryFeature>[],
        spatialParamsApplied: false,
      );
    }

    final path =
        wantsBairros ? '/aggregations/neighborhoods' : '/aggregations/cities';
    final base = <String, Object?>{
      'include_geometria': true,
      if (wantsBairros)
        'municipio_id': municipioId
      else
        'sg_uf': request.uf.toUpperCase(),
    };

    if (!_spatialEnabled) {
      final response = await _dio.get<Object>(path, queryParameters: base);
      return _payload(response.data, request.detail, false);
    }

    final bbox = request.bbox;
    final spatial = <String, Object?>{
      'resolution': request.detail.apiValue,
      if (bbox != null) 'bbox': bbox.toBbox(),
    };

    try {
      final response = await _dio.get<Object>(
        path,
        queryParameters: {...base, ...spatial},
      );
      return await _payload(response.data, request.detail, true);
    } on DioException catch (error) {
      if (!_isRejection(error)) rethrow;
      // The API does not accept the spatial parameters: stop sending them for
      // the rest of the session and serve the whole territory instead.
      _spatialEnabled = false;
      final response = await _dio.get<Object>(path, queryParameters: base);
      return _payload(response.data, request.detail, false);
    }
  }

  Future<Map<String, dynamic>> fetchResumo({
    required bool bairro,
    required String id,
  }) async {
    final path = bairro ? '/bairros/$id/resumo' : '/municipios/$id/resumo';
    final response = await _dio.get<Map<String, dynamic>>(path);
    return response.data ?? <String, dynamic>{};
  }

  Future<StateSummary> fetchStateSummary(String uf) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/estados/${uf.toUpperCase()}/resumo',
    );
    return StateSummary.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<SchoolPoint>> fetchSchools(String municipioId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/escolas/geojson/paraiba',
      queryParameters: {'municipio_id': municipioId},
    );
    final features = response.data?['features'];
    if (features is! List) return const [];

    final schools = <SchoolPoint>[];
    for (final item in features) {
      if (item is! Map) continue;
      final school = SchoolPoint.fromFeature(
        item.map((key, value) => MapEntry(key.toString(), value)),
      );
      if (school != null) schools.add(school);
    }
    return schools;
  }

  Future<SchoolPage> fetchSchoolPage({
    required String municipioId,
    int page = 1,
    int pageSize = 20,
    String? search,
    List<String> dependencias = const [],
    String? localizacao,
  }) async {
    final term = search?.trim() ?? '';
    final response = await _dio.get<Map<String, dynamic>>(
      '/schools',
      queryParameters: {
        'municipio_id': municipioId,
        'page': page,
        'page_size': pageSize,
        if (term.isNotEmpty) ...{'search': term, 'fuzzy_search': true},
        if (dependencias.isNotEmpty) 'dependencia_adm': dependencias,
        if (localizacao != null) 'tipo_localizacao': [localizacao],
      },
    );
    return SchoolPage.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<SchoolDetail> fetchSchoolDetail(String inep) async {
    final response = await _dio.get<Map<String, dynamic>>('/$inep');
    return SchoolDetail.fromJson(response.data ?? <String, dynamic>{});
  }

  Future<List<int>> downloadPdf(String path) async {
    final response = await _dio.get<List<int>>(
      path,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(minutes: 3),
      ),
    );
    return response.data ?? const <int>[];
  }

  Future<List<SearchResult>> search(String query, {String? uf}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/busca/universal',
      queryParameters: {
        'q': query.trim(),
        if (uf != null) 'sg_uf': uf.toUpperCase(),
        'limit': 12,
      },
    );
    final results = response.data?['results'];
    if (results is! List) return const [];

    return results
        .whereType<Map>()
        .map((item) => SearchResult.fromJson(
              item.map((key, value) => MapEntry(key.toString(), value)),
            ))
        .toList(growable: false);
  }

  Future<TerritoryPayload> _payload(
    Object? data,
    MapDetail detail,
    bool spatialParamsApplied,
  ) async {
    final features = await parseTerritoryPayload(data, detail: detail);
    features.sort((a, b) => a.name.compareTo(b.name));
    return TerritoryPayload(
      features: features,
      spatialParamsApplied: spatialParamsApplied,
    );
  }

  /// A 4xx means "this request is wrong", which for us means the optional
  /// spatial parameters are unsupported. 5xx/timeouts are real failures and are
  /// allowed to propagate to the retry UI.
  bool _isRejection(DioException error) {
    final status = error.response?.statusCode;
    return status != null && status >= 400 && status < 500;
  }
}

final observatorioRepositoryProvider = Provider<ObservatorioRepository>((ref) {
  return ObservatorioRepository(ref.watch(dioProvider));
});
