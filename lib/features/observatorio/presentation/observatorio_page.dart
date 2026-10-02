import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/territory/estados_nordeste.dart';
import '../data/map_repository.dart';
import '../domain/indicator.dart';
import '../domain/observatorio_models.dart';
import '../domain/territory_feature.dart';
import '../domain/territory_layer.dart';
import 'map/map_providers.dart';
import 'map/territory_map.dart';
import 'observatorio_controller.dart';
import 'widgets/control_panel.dart';
import 'widgets/detail_sheet.dart';
import 'widgets/dossier_button.dart';
import 'widgets/odin_logo_badge.dart';
import 'widgets/panel.dart';
import 'widgets/place_search_bar.dart';
import 'widgets/school_sheet.dart';

class ObservatorioPage extends ConsumerWidget {
  const ObservatorioPage({super.key});

  Future<void> _openFeature(
    BuildContext context,
    WidgetRef ref,
    TerritoryFeature feature,
  ) async {
    final controller = ref.read(observatorioProvider.notifier);
    final layer = ref.read(observatorioProvider).layer;
    controller.select(feature.id);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DetailSheet(
        feature: feature,
        layer: layer,
        onExploreBairros: layer == TerritoryLayer.municipio
            ? () => controller.drillInto(feature.id, feature.name)
            : null,
        onShowSchoolsOnMap: layer == TerritoryLayer.municipio
            ? () => controller.drillInto(
                  feature.id,
                  feature.name,
                  showSchools: true,
                )
            : null,
      ),
    );

    controller.select(null);
  }

  Future<void> _openSchool(BuildContext context, SchoolPoint school) {
    final inep = school.inep;

    return showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SchoolSheet(
        school: school,
        onOpenDetail: inep == null || inep.isEmpty
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                context.push(AppRoutes.escola(inep));
              },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(observatorioProvider);
    final view = ref.watch(territoryViewProvider);
    final municipio = state.municipio;
    final schoolsAsync = state.showSchools && municipio != null
        ? ref.watch(schoolsProvider(municipio.id))
        : null;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: TerritoryMap(
                    onFeatureTap: (feature) => _openFeature(context, ref, feature),
                    onSchoolTap: (school) => _openSchool(context, school),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const OdinLogoBadge(),
                              const SizedBox(width: 8),
                              const Expanded(child: PlaceSearchBar()),
                              const SizedBox(width: 4),
                              IconButton.filledTonal(
                                tooltip: 'Sobre o ODIN',
                                onPressed: () => context.push(AppRoutes.sobre),
                                icon: const Icon(Icons.info_outline),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const _FilterRow(),
                        ],
                      ),
                    ),
                  ),
                ),
                if (view.isLoading)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Panel(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.4),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                view.request.layer == TerritoryLayer.bairro
                                    ? 'Carregando bairros…'
                                    : 'Carregando municípios…',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (view.error != null && !view.isLoading)
                  Positioned.fill(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Panel(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                describeError(view.error!),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: () => ref
                                    .read(territoryGeometryStoreProvider.notifier)
                                    .retry(view.request),
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (schoolsAsync != null && municipio != null)
                  Positioned(
                    left: 12,
                    bottom: 84,
                    child: _SchoolsStatus(
                      value: schoolsAsync,
                      onRetry: () => ref.invalidate(schoolsProvider(municipio.id)),
                    ),
                  ),
                if (state.municipio != null)
                  Positioned(
                    right: 12,
                    bottom: 28,
                    child: FloatingActionButton.extended(
                      heroTag: 'schools',
                      tooltip: state.showSchools ? 'Ocultar escolas' : 'Mostrar escolas',
                      backgroundColor: state.showSchools
                          ? ModuleId.educacao.accent
                          : Theme.of(context).colorScheme.surface,
                      foregroundColor: state.showSchools
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface,
                      onPressed: ref.read(observatorioProvider.notifier).toggleSchools,
                      icon: const Icon(Icons.school_outlined),
                      label: Text(state.showSchools ? 'Ocultar escolas' : 'Ver escolas'),
                    ),
                  ),
              ],
            ),
          ),
          const ControlPanel(),
        ],
      ),
    );
  }
}

class _FilterRow extends ConsumerWidget {
  const _FilterRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(observatorioProvider);
    final controller = ref.read(observatorioProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final estado = Nordeste.bySigla(state.uf);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          PopupMenuButton<String>(
            tooltip: 'Trocar estado',
            onSelected: controller.setUf,
            itemBuilder: (_) => [
              for (final item in Nordeste.estados)
                PopupMenuItem<String>(
                  value: item.sigla,
                  child: Text('${item.nome} (${item.sigla})'),
                ),
            ],
            child: Chip(
              backgroundColor: scheme.surface,
              avatar: Icon(Icons.map_outlined, size: 18, color: scheme.primary),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(estado.nome),
                  const Icon(Icons.arrow_drop_down, size: 20),
                ],
              ),
            ),
          ),
          if (state.municipio != null) ...[
            const SizedBox(width: 8),
            ActionChip(
              backgroundColor: scheme.surface,
              avatar: const Icon(Icons.arrow_back, size: 18),
              label: Text(state.municipio!.name),
              onPressed: controller.backToState,
            ),
            const SizedBox(width: 8),
            ActionChip(
              backgroundColor: scheme.surface,
              avatar: const Icon(Icons.format_list_bulleted, size: 18),
              label: const Text('Lista de escolas'),
              onPressed: () => context.push(
                AppRoutes.escolas(state.municipio!.id, state.municipio!.name),
              ),
            ),
            const SizedBox(width: 8),
            DossierButton(
              scope: DossierScope.municipio,
              id: state.municipio!.id,
              name: state.municipio!.name,
              compact: true,
            ),
          ] else ...[
            const SizedBox(width: 8),
            DossierButton(
              scope: DossierScope.estado,
              id: state.uf,
              name: estado.nome,
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _SchoolsStatus extends StatelessWidget {
  const _SchoolsStatus({required this.value, required this.onRetry});

  final AsyncValue<List<SchoolPoint>> value;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          value.when(
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            error: (_, __) => const Icon(Icons.error_outline, size: 18),
            data: (_) => Icon(
              Icons.school_outlined,
              size: 18,
              color: ModuleId.educacao.accent,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value.when(
              loading: () => 'Carregando escolas…',
              error: (_, __) => 'Falha ao carregar escolas',
              data: (items) => '${items.length} escolas no mapa',
            ),
          ),
          if (value.hasError)
            TextButton(onPressed: onRetry, child: const Text('Tentar de novo')),
        ],
      ),
    );
  }
}
