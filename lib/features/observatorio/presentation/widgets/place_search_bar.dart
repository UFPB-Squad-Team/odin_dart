import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/observatorio_repository.dart';
import '../../domain/observatorio_models.dart';
import '../map/map_controller.dart';
import '../observatorio_controller.dart';

class PlaceSearchBar extends ConsumerWidget {
  const PlaceSearchBar({super.key});

  IconData _iconFor(SearchKind kind) {
    switch (kind) {
      case SearchKind.escola:
        return Icons.school_outlined;
      case SearchKind.logradouro:
        return Icons.signpost_outlined;
      case SearchKind.cep:
        return Icons.markunread_mailbox_outlined;
      case SearchKind.municipio:
        return Icons.location_city_outlined;
      case SearchKind.bairro:
        return Icons.holiday_village_outlined;
      case SearchKind.outro:
        return Icons.place_outlined;
    }
  }

  double _zoomFor(SearchKind kind) {
    switch (kind) {
      case SearchKind.municipio:
        return 11;
      case SearchKind.bairro:
        return 14;
      case SearchKind.escola:
      case SearchKind.logradouro:
      case SearchKind.cep:
      case SearchKind.outro:
        return 16;
    }
  }

  void _select(WidgetRef ref, SearchResult result) {
    final location = result.location;
    if (location != null) {
      ref.read(mapControllerProvider).move(location, _zoomFor(result.kind));
    }
    if (result.kind == SearchKind.municipio) {
      final id = result.municipioId.isNotEmpty ? result.municipioId : result.id;
      ref.read(observatorioProvider.notifier).drillInto(id, result.label);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SearchAnchor.bar(
      barHintText: 'Buscar escola, bairro, município ou CEP',
      barElevation: const WidgetStatePropertyAll<double>(3),
      barPadding: const WidgetStatePropertyAll<EdgeInsets>(
        EdgeInsets.symmetric(horizontal: 14),
      ),
      suggestionsBuilder: (context, controller) async {
        final query = controller.text.trim();
        if (query.length < 2) {
          return const [
            ListTile(
              leading: Icon(Icons.search),
              title: Text('Digite ao menos 2 caracteres'),
            ),
          ];
        }

        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (controller.text.trim() != query) return const <Widget>[];

        try {
          final uf = ref.read(observatorioProvider).uf;
          final results = await ref
              .read(observatorioRepositoryProvider)
              .search(query, uf: uf);

          if (results.isEmpty) {
            return const [
              ListTile(
                leading: Icon(Icons.search_off),
                title: Text('Nenhum resultado'),
              ),
            ];
          }

          return [
            for (final result in results)
              ListTile(
                leading: Icon(_iconFor(result.kind)),
                title: Text(result.label),
                subtitle: Text(
                  result.subtitle.isEmpty
                      ? result.kind.label
                      : '${result.kind.label} · ${result.subtitle}',
                ),
                onTap: () {
                  controller.closeView(result.label);
                  FocusScope.of(context).unfocus();
                  _select(ref, result);
                },
              ),
          ];
        } catch (error) {
          return [
            ListTile(
              leading: const Icon(Icons.error_outline),
              title: Text(describeError(error)),
            ),
          ];
        }
      },
    );
  }
}
