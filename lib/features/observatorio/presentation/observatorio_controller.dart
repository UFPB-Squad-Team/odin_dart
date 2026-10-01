import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/territory/estados_nordeste.dart';
import '../data/observatorio_repository.dart';
import '../domain/indicator.dart';
import '../domain/observatorio_models.dart';
import '../domain/school_models.dart';
import '../domain/territory_layer.dart';

@immutable
class SelectedMunicipio {
  const SelectedMunicipio({required this.id, required this.name});

  final String id;
  final String name;
}

@immutable
class ObservatorioState {
  const ObservatorioState({
    this.uf = Nordeste.defaultUf,
    this.municipio,
    this.module = ModuleId.educacao,
    this.indicatorId,
    this.showSchools = false,
    this.selectedId,
  });

  final String uf;
  final SelectedMunicipio? municipio;
  final ModuleId module;
  final String? indicatorId;
  final bool showSchools;
  final String? selectedId;

  TerritoryLayer get layer =>
      municipio == null ? TerritoryLayer.municipio : TerritoryLayer.bairro;

  ObservatorioState copyWith({
    String? uf,
    SelectedMunicipio? municipio,
    bool clearMunicipio = false,
    ModuleId? module,
    String? indicatorId,
    bool clearIndicator = false,
    bool? showSchools,
    String? selectedId,
    bool clearSelected = false,
  }) {
    return ObservatorioState(
      uf: uf ?? this.uf,
      municipio: clearMunicipio ? null : (municipio ?? this.municipio),
      module: module ?? this.module,
      indicatorId: clearIndicator ? null : (indicatorId ?? this.indicatorId),
      showSchools: showSchools ?? this.showSchools,
      selectedId: clearSelected ? null : (selectedId ?? this.selectedId),
    );
  }
}

class ObservatorioController extends Notifier<ObservatorioState> {
  @override
  ObservatorioState build() => const ObservatorioState();

  void setUf(String uf) {
    if (uf == state.uf && state.municipio == null) return;
    state = ObservatorioState(
      uf: uf,
      module: state.module,
      indicatorId: state.indicatorId,
    );
  }

  void setModule(ModuleId module) {
    if (module == state.module) return;
    state = state.copyWith(module: module, clearIndicator: true);
  }

  void setIndicator(String id) {
    state = state.copyWith(indicatorId: id);
  }

  void drillInto(String id, String name, {bool showSchools = false}) {
    state = state.copyWith(
      municipio: SelectedMunicipio(id: id, name: name),
      showSchools: showSchools,
      clearSelected: true,
    );
  }

  void backToState() {
    state = state.copyWith(
      clearMunicipio: true,
      showSchools: false,
      clearSelected: true,
    );
  }

  void toggleSchools() {
    state = state.copyWith(showSchools: !state.showSchools);
  }

  void select(String? id) {
    state = id == null
        ? state.copyWith(clearSelected: true)
        : state.copyWith(selectedId: id);
  }
}

final observatorioProvider =
    NotifierProvider<ObservatorioController, ObservatorioState>(
  ObservatorioController.new,
);

final activeIndicatorProvider = Provider<Indicator>((ref) {
  final state = ref.watch(observatorioProvider);
  return IndicatorCatalog.resolve(state.module, state.layer, state.indicatorId);
});

final stateSummaryProvider =
    FutureProvider.family<StateSummary, String>((ref, uf) {
  return ref.watch(observatorioRepositoryProvider).fetchStateSummary(uf);
});

final schoolsProvider =
    FutureProvider.family<List<SchoolPoint>, String>((ref, municipioId) {
  return ref.watch(observatorioRepositoryProvider).fetchSchools(municipioId);
});

final schoolDetailProvider =
    FutureProvider.autoDispose.family<SchoolDetail, String>((ref, inep) {
  return ref.watch(observatorioRepositoryProvider).fetchSchoolDetail(inep);
});

final resumoProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, ({bool bairro, String id})>((ref, key) {
  return ref
      .watch(observatorioRepositoryProvider)
      .fetchResumo(bairro: key.bairro, id: key.id);
});

String describeError(Object error) {
  if (error is DioException) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return 'A API demorou a responder. Se o servidor estava dormindo, tente de novo em instantes.';
      case DioExceptionType.connectionError:
        return 'Sem conexão com a API do ODIN. Verifique sua internet.';
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode;
        return status == 404
            ? 'Dados não encontrados para este território.'
            : 'A API respondeu com erro ($status).';
      default:
        return 'Não foi possível carregar os dados.';
    }
  }
  return 'Não foi possível carregar os dados.';
}
