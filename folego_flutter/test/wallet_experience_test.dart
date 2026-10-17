import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/layout/app_breakpoints.dart';
import 'package:folego/data/models/wallet_detail.dart';
import 'package:folego/data/models/wallet_overview.dart';

void main() {
  group('Wallet responsive layout', () {
    test('maps target mobile, tablet and desktop widths to app breakpoints', () {
      expect(AppBreakpoints.fromWidth(375), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(390), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(430), AppLayoutSize.compact);
      expect(AppBreakpoints.fromWidth(768), AppLayoutSize.medium);
      expect(AppBreakpoints.fromWidth(1280), AppLayoutSize.expanded);
      expect(AppBreakpoints.fromWidth(1600), AppLayoutSize.wide);
    });
  });

  group('WalletCard', () {
    test('parses invoice and limit data from wallet contract', () {
      final card = WalletCard.fromJson({
        'id': 'card-1',
        'name': 'AMEX Gold',
        'issuer': 'Bradesco',
        'brand': 'American Express',
        'last_four': '1234',
        'closing_day': 5,
        'due_day': 10,
        'personal_limit': 1000,
        'issuer_limit': 1800,
        'available_limit': 250,
        'invoice_id': 'invoice-1',
        'due_date': '2026-10-10',
        'invoice_balance': 750,
      });

      expect(card.effectiveLimit, 1000);
      expect(card.usedLimit, 750);
      expect(card.limitUsageRatio, .75);
      expect(card.invoiceBalance, 750);
      expect(card.invoiceDueDate, DateTime(2026, 10, 10));
      expect(card.canPayInvoice, isTrue);
    });

    test('keeps usage above 100 percent visible for alert presentation', () {
      const card = WalletCard(
        id: 'card-1',
        name: 'Porto',
        closingDay: 5,
        dueDay: 10,
        invoiceBalance: 1200,
        personalLimit: 1000,
        availableLimit: 0,
        invoiceId: 'invoice-1',
      );

      expect(card.limitUsageRatio, 1.2);
      expect(card.canPayInvoice, isTrue);
    });
  });

  group('WalletDebt', () {
    test('calculates paid amount and progress only with original amount', () {
      const debt = WalletDebt(
        id: 'debt-1',
        name: 'Empréstimo',
        openingBalance: 10000,
        originalAmount: 10000,
        remainingBalance: 6000,
        nextAmount: 500,
        paidInstallments: 8,
        totalInstallments: 20,
      );

      expect(debt.paidAmount, 4000);
      expect(debt.progress, .4);
    });

    test('does not invent progress when original amount is absent', () {
      const debt = WalletDebt(
        id: 'debt-1',
        name: 'Acordo',
        openingBalance: 3000,
        remainingBalance: 1200,
        nextAmount: 0,
        paidInstallments: 0,
      );

      expect(debt.paidAmount, isNull);
      expect(debt.progress, isNull);
    });
  });

  group('WalletInstallment', () {
    test('calculates progress for an active overview installment', () {
      const item = WalletInstallment(
        id: 'purchase-1',
        description: 'Notebook',
        totalAmount: 4200,
        installmentsCount: 10,
        cardId: 'card-1',
        cardName: 'AMEX Gold',
        remainingInstallments: 8,
        remainingAmount: 3360,
      );

      expect(item.paidInstallments, 2);
      expect(item.progress, .2);
      expect(item.installmentAmount, 420);
      expect(item.isCompleted, isFalse);
    });

    test('keeps completed installment state available for presentation', () {
      const item = WalletInstallment(
        id: 'purchase-1',
        description: 'Curso',
        totalAmount: 600,
        installmentsCount: 3,
        cardId: 'card-1',
        cardName: 'Porto',
        remainingInstallments: 0,
        remainingAmount: 0,
      );

      expect(item.paidInstallments, 3);
      expect(item.progress, 1);
      expect(item.isCompleted, isTrue);
    });
  });

  group('WalletInstallmentPosition', () {
    test('uses next authoritative installment and preserves category/card', () {
      final item = WalletInstallmentPosition.fromPurchaseJson({
        'id': 'purchase-1',
        'description': 'Notebook',
        'merchant': 'Loja Tech',
        'installments_count': 10,
        'category': {'id': 'cat-1', 'name': 'Eletrônicos'},
        'card': {'id': 'card-1', 'name': 'AMEX Gold'},
        'card_installments': [
          {
            'id': 'i-1',
            'installment_number': 1,
            'total_installments': 10,
            'amount': 420,
            'competence_date': '2026-08-01',
            'status': 'paid',
            'invoice': {
              'id': 'inv-1',
              'due_date': '2026-08-10',
              'status': 'paid',
            },
          },
          {
            'id': 'i-2',
            'installment_number': 2,
            'total_installments': 10,
            'amount': 420,
            'competence_date': '2026-09-01',
            'status': 'paid',
            'invoice': {
              'id': 'inv-2',
              'due_date': '2026-09-10',
              'status': 'paid',
            },
          },
          {
            'id': 'i-3',
            'installment_number': 3,
            'total_installments': 10,
            'amount': 420,
            'competence_date': '2026-10-01',
            'status': 'invoiced',
            'invoice': {
              'id': 'inv-3',
              'due_date': '2026-10-10',
              'status': 'open',
            },
          },
        ],
      });

      expect(item.displayName, 'Loja Tech');
      expect(item.categoryName, 'Eletrônicos');
      expect(item.cardName, 'AMEX Gold');
      expect(item.currentInstallment, 3);
      expect(item.totalInstallments, 10);
      expect(item.installmentAmount, 420);
      expect(item.nextDueDate, DateTime(2026, 10, 10));
      expect(item.completed, isFalse);
      expect(item.progress, .2);
    });

    test('sorts open positions before completed ones', () {
      final openLater = WalletInstallmentPosition(
        purchaseId: 'open-later',
        description: 'B',
        cardId: 'card-1',
        cardName: 'Card',
        installmentAmount: 100,
        currentInstallment: 2,
        totalInstallments: 4,
        nextDueDate: DateTime(2026, 11, 10),
        completed: false,
      );
      final completed = WalletInstallmentPosition(
        purchaseId: 'done',
        description: 'C',
        cardId: 'card-1',
        cardName: 'Card',
        installmentAmount: 100,
        currentInstallment: 4,
        totalInstallments: 4,
        completed: true,
      );
      final openSooner = WalletInstallmentPosition(
        purchaseId: 'open-sooner',
        description: 'A',
        cardId: 'card-1',
        cardName: 'Card',
        installmentAmount: 100,
        currentInstallment: 1,
        totalInstallments: 4,
        nextDueDate: DateTime(2026, 10, 10),
        completed: false,
      );

      final sorted = sortWalletInstallmentPositions([
        completed,
        openLater,
        openSooner,
      ]);

      expect(
        sorted.map((item) => item.purchaseId),
        ['open-sooner', 'open-later', 'done'],
      );
    });
  });

  group('Wallet detail parsing', () {
    test('benefit movement uses benefit impact amount, not cash', () {
      final movement = WalletMovement.fromEventJson({
        'id': 'event-1',
        'event_type': 'benefit_expense',
        'description': 'Almoço',
        'amount': 42,
        'occurred_at': '2026-09-14T12:00:00-03:00',
        'category': {'id': 'food', 'name': 'Restaurantes'},
        'financial_impacts': [
          {
            'dimension': 'benefit',
            'amount': -42,
            'account_id': 'benefit-1',
          },
        ],
      });

      expect(movement.amount, -42);
      expect(movement.categoryName, 'Restaurantes');
    });

    test('debt installment exposes explicit overdue status only', () {
      final installment = WalletDebtInstallment.fromJson({
        'id': 'debt-installment-1',
        'installment_number': 2,
        'due_date': '2026-09-10',
        'planned_amount': 500,
        'paid_amount': 100,
        'status': 'overdue',
      });

      expect(installment.isOverdue, isTrue);
      expect(installment.remainingAmount, 400);
    });
  });
}
