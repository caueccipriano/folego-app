import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/shared/widgets/app_page_header.dart';
import 'package:folego/shared/widgets/app_section_header.dart';

void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required Size size,
    required Widget header,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: header,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('page heading keeps action below subtitle at 320px',
      (tester) async {
    await pumpHeader(
      tester,
      size: const Size(320, 700),
      header: AppPageHeader(
        title: 'planejamento financeiro',
        subtitle: 'acompanhe suas próximas decisões',
        trailing: OutlinedButton(
          key: const ValueKey('page-header-action'),
          onPressed: () {},
          child: const Text('editar planejamento'),
        ),
      ),
    );

    final title = tester.getRect(find.text('planejamento financeiro'));
    final subtitle = tester.getRect(
      find.text('acompanhe suas próximas decisões'),
    );
    final action = tester.getRect(
      find.byKey(const ValueKey('page-header-action')),
    );
    expect(title.bottom, lessThan(subtitle.top));
    expect(subtitle.bottom, lessThan(action.top));
    expect(action.right, lessThanOrEqualTo(304));
    expect(tester.takeException(), isNull);
  });

  testWidgets('page heading with leading keeps controls tappable at 390px',
      (tester) async {
    var tapped = false;
    await pumpHeader(
      tester,
      size: const Size(390, 844),
      header: AppPageHeader(
        title: 'minha carteira',
        subtitle: 'contas e cartões',
        leading: const SizedBox.square(
          dimension: 44,
          child: Icon(Icons.account_balance_wallet_outlined),
        ),
        trailing: TextButton(
          key: const ValueKey('page-header-action'),
          onPressed: () => tapped = true,
          child: const Text('gerenciar'),
        ),
      ),
    );
    final subtitle = tester.getRect(find.text('contas e cartões'));
    final action = tester.getRect(
      find.byKey(const ValueKey('page-header-action')),
    );
    expect(subtitle.bottom, lessThan(action.top));
    await tester.tap(find.byKey(const ValueKey('page-header-action')));
    expect(tapped, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('page heading retains horizontal action on desktop',
      (tester) async {
    await pumpHeader(
      tester,
      size: const Size(1024, 768),
      header: AppPageHeader(
        title: 'lançamentos',
        trailing: TextButton(
          key: const ValueKey('page-header-action'),
          onPressed: () {},
          child: const Text('filtrar'),
        ),
      ),
    );
    final title = tester.getRect(find.text('lançamentos'));
    final action = tester.getRect(
      find.byKey(const ValueKey('page-header-action')),
    );
    expect((title.center.dy - action.center.dy).abs(), lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('section heading stays readable with large accessibility text',
      (tester) async {
    await pumpHeader(
      tester,
      size: const Size(520, 800),
      textScale: 1.7,
      header: AppSectionHeader(
        title: 'próximos movimentos financeiros',
        subtitle: 'confira o que está perto de vencer antes de gastar',
        trailing: OutlinedButton(
          key: const ValueKey('section-header-action'),
          onPressed: () {},
          child: const Text('ver todos'),
        ),
      ),
    );
    final subtitle = tester.getRect(
      find.text('confira o que está perto de vencer antes de gastar'),
    );
    final action = tester.getRect(
      find.byKey(const ValueKey('section-header-action')),
    );
    expect(subtitle.bottom, lessThan(action.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('section heading keeps inline action at roomy width',
      (tester) async {
    await pumpHeader(
      tester,
      size: const Size(768, 800),
      header: AppSectionHeader(
        title: 'seu mês',
        trailing: TextButton(
          key: const ValueKey('section-header-action'),
          onPressed: () {},
          child: const Text('detalhes'),
        ),
      ),
    );
    final title = tester.getRect(find.text('seu mês'));
    final action = tester.getRect(
      find.byKey(const ValueKey('section-header-action')),
    );
    expect((title.center.dy - action.center.dy).abs(), lessThan(20));
    expect(tester.takeException(), isNull);
  });
}
