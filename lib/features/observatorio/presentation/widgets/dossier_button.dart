import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../data/observatorio_repository.dart';
import '../observatorio_controller.dart';

enum DossierScope { municipio, estado }

String _slug(String value) {
  const from = 'áàâãäéèêëíìîïóòôõöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  final buffer = StringBuffer();
  for (final rune in value.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index >= 0 ? to[index] : char);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

class DossierButton extends ConsumerStatefulWidget {
  const DossierButton({
    super.key,
    required this.scope,
    required this.id,
    required this.name,
    this.compact = false,
  });

  final DossierScope scope;
  final String id;
  final String name;
  final bool compact;

  @override
  ConsumerState<DossierButton> createState() => _DossierButtonState();
}

class _DossierButtonState extends ConsumerState<DossierButton> {
  bool _loading = false;
  String? _error;

  String get _path => widget.scope == DossierScope.municipio
      ? '/municipios/${widget.id}/dossie'
      : '/estados/${widget.id.toUpperCase()}/dossie';

  String get _fileName =>
      'dossie_${_slug(widget.name)}_${widget.id.toLowerCase()}.pdf';

  void _report(String message) {
    if (!mounted) return;
    if (widget.compact) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    } else {
      setState(() => _error = message);
    }
  }

  Future<void> _run() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final bytes = await ref.read(observatorioRepositoryProvider).downloadPdf(_path);
      if (bytes.isEmpty) {
        _report('O servidor devolveu um PDF vazio.');
        return;
      }

      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/$_fileName');
      await file.writeAsBytes(bytes, flush: true);

      final result = await OpenFilex.open(file.path, type: 'application/pdf');
      if (result.type != ResultType.done) {
        _report('PDF gerado, mas nenhum aplicativo para abrir PDF foi encontrado.');
      }
    } on DioException catch (error) {
      _report(describeError(error));
    } catch (_) {
      _report('Não foi possível gerar o dossiê.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.compact) {
      return ActionChip(
        backgroundColor: scheme.surface,
        avatar: _loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.picture_as_pdf_outlined, size: 18),
        label: Text(_loading ? 'Gerando…' : 'Dossiê PDF'),
        onPressed: _loading ? null : _run,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _run,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.picture_as_pdf_outlined),
          label: Text(_loading ? 'Gerando dossiê…' : 'Gerar dossiê (PDF)'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.error),
            ),
          ),
      ],
    );
  }
}
