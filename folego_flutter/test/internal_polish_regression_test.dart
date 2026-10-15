import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/quick_register_sheet.dart';
import 'package:folego/core/theme/app_typography.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/features/home/home_financial_hero.dart';

void main() {
  FolegoSnapshot snapshot(String due, int days) => FolegoSnapshot.fromJson({
    'as_of_date': '2026-10-15',
    'next_income_date': due,
    'days_until_income': days,
  });

  test(
    'same calendar date never says tomorrow even when server interval is one',
    () {
      expect(
        homeIncomeTimingLabel(snapshot('2026-10-15', 1)),
        'recebimento previsto hoje',
      );
    },
  );

  test('date is authoritative when the returned interval disagrees', () {
    expect(
      homeIncomeTimingLabel(snapshot('2026-10-16', 0)),
      'recebe amanhã · 16 out',
    );
    expect(
      homeIncomeTimingLabel(snapshot('2026-10-18', 1)),
      'recebe em 3 dias · 18 out',
    );
    expect(
      homeIncomeTimingLabel(snapshot('2026-10-14', 1)),
      'próximo recebimento · 14 out',
    );
  });

  testWidgets(
    'compact monetary typography remains readable at large text scale',
    (tester) async {
      TextStyle? style;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: Builder(
              builder: (context) {
                style = AppTypography.money(context, fontSize: 13);
                return Scaffold(
                  body: SizedBox(
                    width: 320,
                    child: Text('−R\$ 2.974,89', style: style),
                  ),
                );
              },
            ),
          ),
        ),
      );
      expect(style!.letterSpacing, 0);
      expect(style!.height, greaterThanOrEqualTo(1.2));
      expect(style!.decoration, TextDecoration.none);
      expect(tester.takeException(), isNull);
    },
  );
  for (final width in [320.0, 390.0, 768.0, 1440.0]) {
    for (final brightness in Brightness.values) {
      testWidgets(
        'new expense requires deliberate account and category at $width $brightness',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final client = SupabaseClient(
            'https://example.supabase.co',
            'synthetic',
            authOptions: const AuthClientOptions(autoRefreshToken: false),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: ThemeData(brightness: brightness),
              home: Scaffold(
                body: QuickRegisterSheet(
                  space: const FinancialSpace(id: 'synthetic', name: 'Teste'),
                  repository: FolegoRepository(client),
                  loadCatalog: () async => (
                    accounts: const [
                      AccountItem(
                        id: 'third-party',
                        name: 'Terceiros',
                        type: 'checking',
                      ),
                    ],
                    benefits: const <AccountItem>[],
                    cards: const [],
                    categories: <CategoryItem>[],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final dropdown = tester.widget<DropdownButtonFormField<String>>(
            find.byType(DropdownButtonFormField<String>),
          );
          expect(dropdown.initialValue, isNull);
          expect(find.text('selecionar'), findsOneWidget);
          expect(tester.takeException(), isNull);
          if (width >= 1024) {
            final title = tester.getRect(find.text('novo gasto'));
            expect(title.top, lessThan(350));
          }
        },
      );
    }
  }
}
