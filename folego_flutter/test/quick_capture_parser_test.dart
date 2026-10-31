import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/home/quick_capture_parser.dart';

void main() {
  test('preenche rascunhos BRL sem salvar lançamentos', () {
    final draft = QuickCaptureDraft.parse('Uber 27,90');
    expect(draft?.description, 'Uber');
    expect(draft?.amountText, '27,90');

    final withSymbol = QuickCaptureDraft.parse('Mercado R\$ 1.234,56');
    expect(withSymbol?.description, 'Mercado');
    expect(withSymbol?.amountText, '1234,56');
  });

  test('aceita ponto decimal sem confundir datas', () {
    expect(QuickCaptureDraft.parse('Café 12.50')?.amountText, '12,50');
    expect(QuickCaptureDraft.parse('Curso 2026'), isNull);
    expect(QuickCaptureDraft.parse('Condomínio 10/2026'), isNull);
    expect(QuickCaptureDraft.parse(''), isNull);
  });

  test('rejeita valores inválidos e negativos', () {
    expect(QuickCaptureDraft.parse('Uber -27,90'), isNull);
    expect(QuickCaptureDraft.parse('Uber 0,00'), isNull);
    expect(QuickCaptureDraft.parse('Uber 12,3'), isNull);
    expect(QuickCaptureDraft.parse('Uber'), isNull);
  });
}
