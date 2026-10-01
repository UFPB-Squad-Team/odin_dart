import 'package:flutter_test/flutter_test.dart';
import 'package:odin_app/features/observatorio/domain/indicator.dart';
import 'package:odin_app/features/observatorio/domain/territory_layer.dart';

void main() {
  final internet =
      IndicatorCatalog.all.firstWhere((i) => i.id == 'pct_com_internet');

  test('reads nested, flat and string values', () {
    expect(internet.read({'educacao': {'pctComInternet': 82.5}}), 82.5);
    expect(internet.read({'pct_com_internet': '70'}), 70);
    expect(internet.read({}), isNull);
  });

  test('falls back to first available indicator for the bairro layer', () {
    final resolved = IndicatorCatalog.resolve(
      ModuleId.educacao,
      TerritoryLayer.bairro,
      'media_ideb_anos_iniciais',
    );
    expect(resolved.availableOn(TerritoryLayer.bairro), isTrue);
  });

  test('color scale interpolates between min and max', () {
    expect(internet.colorAt(0), internet.colorMin);
    expect(internet.colorAt(1), internet.colorMax);
  });
}
