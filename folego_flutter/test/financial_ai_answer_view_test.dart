import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/financial_ai_answer_view.dart';

void main() {
  Widget testSurface(String answer) => MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FinancialAiAnswerView(answer: answer),
        ),
      ),
    ),
  );

  testWidgets('canonical server totals become separate readable metric cards',
      (tester) async {
    await tester.pumpWidget(testSurface(
      'Resumo automático de 2026-11 (sem IA):\n'
      'Receitas registradas: R\$ 100,00.\n'
      'Despesas por competência: R\$ 75,00.\n'
      'Resultado do mês: R\$ 25,00.\n'
      'Valores baseados nos registros do Fôlego.',
    ));

    expect(find.text('receitas'), findsOneWidget);
    expect(find.text('despesas'), findsOneWidget);
    expect(find.text('resultado'), findsOneWidget);
    expect(find.text('R\$ 100,00'), findsOneWidget);
    expect(find.text('R\$ 75,00'), findsOneWidget);
    expect(find.text('R\$ 25,00'), findsOneWidget);
    expect(find.text('Valores baseados nos registros do Fôlego.'),
      findsOneWidget);
  });

  testWidgets('free-form AI explanation remains visible in full',
      (tester) async {
    await tester.pumpWidget(testSurface(
      'Considere revisar despesas variáveis antes da próxima compra.',
    ));
    expect(find.text('Considere revisar despesas variáveis antes da próxima compra.'),
      findsOneWidget);
    expect(find.text('receitas'), findsNothing);
  });
}
