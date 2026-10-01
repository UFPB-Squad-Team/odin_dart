import 'package:flutter_test/flutter_test.dart';
import 'package:odin_app/features/observatorio/domain/school_models.dart';

void main() {
  test('parses a paginated school response', () {
    final page = SchoolPage.fromJson({
      'schools': [
        {
          'escola_id_inep': 25000001,
          'escola_nome': 'Escola Modelo',
          'municipio_nome': 'João Pessoa',
          'dependencia_adm': 'Municipal',
          'tipo_localizacao': 'Urbana',
          'endereco': {'bairro': 'Manaíra'},
          'matriculas': {'totalAlunos': 420},
        },
      ],
      'total_items': 45,
      'page': 1,
      'page_size': 20,
    });

    expect(page.items, hasLength(1));
    expect(page.items.first.inep, '25000001');
    expect(page.items.first.bairro, 'Manaíra');
    expect(page.items.first.alunos, 420);
    expect(page.hasMore, isTrue);
  });

  test('parses school detail and hides empty stages', () {
    final detail = SchoolDetail.fromJson({
      'escola_id_inep': 25000001,
      'escola_nome': 'Escola Modelo',
      'municipio_nome': 'João Pessoa',
      'estado_sigla': 'PB',
      'localizacao': {
        'type': 'Point',
        'coordinates': [-34.83, -7.09],
      },
      'endereco': {'logradouro': 'Rua A', 'numero': '10'},
      'matriculas': {'totalAlunos': 300, 'ensinoMedio': 120},
      'indicadores': {
        'ensinoMedio': {'alunosPorTurma': 32.5, 'taxaAprovacao': 88.0},
        'educacaoInfantil': {'alunosPorTurma': 0.0, 'taxaAprovacao': 0.0},
      },
      'infraestrutura': {
        'possuiBiblioteca': true,
        'possuiPiscina': false,
        'internet': {'possuiInternet': true},
        'salas': {'utilizadas': 12},
      },
    });

    expect(detail.inep, '25000001');
    expect(detail.streetLine, 'Rua A, 10');
    expect(detail.cityLine, 'João Pessoa — PB');
    expect(detail.location?.latitude, -7.09);
    expect(detail.stages, hasLength(1));
    expect(detail.stages.first.label, 'Ensino médio');
    expect(detail.matriculas.single, ('Ensino médio', 120));
    expect(detail.infra.first.items.any((i) => i.label == 'Biblioteca' && i.available), isTrue);
    expect(detail.salas.single, ('Salas utilizadas', 12));
  });
}
