import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/utils/formatters.dart';
import '../../data/observatorio_repository.dart';
import '../../domain/indicator.dart';
import '../../domain/school_models.dart';
import '../observatorio_controller.dart';

class SchoolsPage extends ConsumerStatefulWidget {
  const SchoolsPage({
    super.key,
    required this.municipioId,
    required this.municipioNome,
  });

  final String municipioId;
  final String municipioNome;

  @override
  ConsumerState<SchoolsPage> createState() => _SchoolsPageState();
}

class _SchoolsPageState extends ConsumerState<SchoolsPage> {
  static const _dependencias = ['Federal', 'Estadual', 'Municipal', 'Privada'];
  static const _localizacoes = ['Urbana', 'Rural'];

  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _selectedDependencias = <String>{};
  Timer? _debounce;

  List<SchoolListItem> _items = const [];
  String? _localizacao;
  Object? _error;
  int _page = 0;
  int _total = 0;
  int _generation = 0;
  bool _loading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load(reset: true));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 400) {
      _load(reset: false);
    }
  }

  Future<void> _load({required bool reset}) async {
    if (!reset && (_loading || !_hasMore || _error != null)) return;

    final generation = reset ? ++_generation : _generation;
    setState(() {
      if (reset) {
        _items = const [];
        _page = 0;
        _total = 0;
        _hasMore = true;
      }
      _error = null;
      _loading = true;
    });

    try {
      final page = await ref.read(observatorioRepositoryProvider).fetchSchoolPage(
            municipioId: widget.municipioId,
            page: _page + 1,
            search: _search.text,
            dependencias: _selectedDependencias.toList(growable: false),
            localizacao: _localizacao,
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = [..._items, ...page.items];
        _page += 1;
        _total = page.totalItems;
        _hasMore = page.items.isNotEmpty && page.hasMore;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted) _load(reset: true);
    });
  }

  void _toggleDependencia(String value) {
    setState(() {
      if (!_selectedDependencias.add(value)) _selectedDependencias.remove(value);
    });
    _load(reset: true);
  }

  void _toggleLocalizacao(String value) {
    setState(() => _localizacao = _localizacao == value ? null : value);
    _load(reset: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Escolas'),
            Text(
              widget.municipioNome,
              style: textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Buscar escola pelo nome',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          _load(reset: true);
                        },
                      ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final value in _dependencias)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text(value),
                      selected: _selectedDependencias.contains(value),
                      onSelected: (_) => _toggleDependencia(value),
                    ),
                  ),
                for (final value in _localizacoes)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(value),
                      selected: _localizacao == value,
                      onSelected: (_) => _toggleLocalizacao(value),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _loading && _items.isEmpty
                    ? 'Carregando…'
                    : '${formatNumber(_total.toDouble())} escolas',
                style: textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_items.isEmpty && _error != null) {
      return _Message(
        icon: Icons.cloud_off_outlined,
        text: describeError(_error!),
        action: FilledButton.icon(
          onPressed: () => _load(reset: true),
          icon: const Icon(Icons.refresh),
          label: const Text('Tentar novamente'),
        ),
      );
    }

    if (_items.isEmpty && !_loading) {
      return const _Message(
        icon: Icons.school_outlined,
        text: 'Nenhuma escola encontrada com esses filtros.',
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      itemCount: _items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        if (index == _items.length) {
          if (_loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          if (_error != null) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: TextButton.icon(
                  onPressed: () {
                    setState(() => _error = null);
                    _load(reset: false);
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Falha ao carregar mais. Tentar de novo'),
                ),
              ),
            );
          }
          return const SizedBox(height: 8);
        }

        final item = _items[index];
        return _SchoolCard(
          item: item,
          accent: ModuleId.educacao.accent,
          borderColor: scheme.outline,
          onTap: () => context.push(AppRoutes.escola(item.inep)),
        );
      },
    );
  }
}

class _SchoolCard extends StatelessWidget {
  const _SchoolCard({
    required this.item,
    required this.accent,
    required this.borderColor,
    required this.onTap,
  });

  final SchoolListItem item;
  final Color accent;
  final Color borderColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final details = [
      item.bairro,
      item.localizacao,
      if (item.alunos != null) '${formatNumber(item.alunos!.toDouble())} alunos',
    ].whereType<String>().join(' · ');

    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: accent.withAlpha(32),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school_outlined, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (item.dependencia != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          item.dependencia!,
                          style: textTheme.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    if (details.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          details,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.action});

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: scheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
