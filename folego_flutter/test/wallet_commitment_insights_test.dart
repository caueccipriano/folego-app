import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/models/wallet_commitment_insights.dart';

WalletCard card(String id, {DateTime? due, double invoice = 0, String? invoiceId}) =>
    WalletCard(
      id: id,
      name: id,
      closingDay: 10,
      dueDay: 17,
      invoiceBalance: invoice,
      invoiceId: invoiceId,
      invoiceDueDate: due,
    );

WalletInstallment installment(String id, {
  required int remaining,
  required DateTime? nextDue,
  double totalAmount = 300,
  int count = 3,
}) => WalletInstallment(
      id: id,
      description: id,
      totalAmount: totalAmount,
      installmentsCount: count,
      cardId: 'c1',
      cardName: 'Cartão',
      remainingInstallments: remaining,
      remainingAmount: totalAmount * remaining / count,
      nextDueDate: nextDue,
    );

void main() {
  test('upcoming invoices count only open known due dates in window', () {
    final value = summarizeDueCardInvoices([
      card('a', due: DateTime(2026, 10, 16), invoice: 250, invoiceId: 'a1'),
      card('b', due: DateTime(2026, 11, 14), invoice: 100, invoiceId: 'b1'),
      card('c', due: DateTime(2026, 11, 16), invoice: 100, invoiceId: 'c1'),
      card('d', due: DateTime(2026, 10, 14), invoice: 15, invoiceId: 'd1'),
      card('e', due: DateTime(2026, 10, 17), invoice: 500),
    ], DateTime(2026, 10, 15));
    expect(value.count, 2);
    expect(value.total, 350);
    expect(value.overdueCount, 1);
  });

  test('last installment only when due date and month are known', () {
    final result = summarizeEndingInstallments([
      installment('last', remaining: 1, nextDue: DateTime(2026, 10, 20)),
      installment('next', remaining: 2, nextDue: DateTime(2026, 10, 23)),
      installment('no date', remaining: 1, nextDue: null),
      installment('later', remaining: 1, nextDue: DateTime(2026, 11, 1)),
    ], DateTime(2026, 10, 15));
    expect(result.count, 1);
    expect(result.lastInstallmentTotal, 100);
  });

  test('wallet and home present labeled, read-only breakdowns', () {
    final home = File('lib/features/home/home_financial_hero.dart').readAsStringSync();
    final wallet = File('lib/features/wallet/wallet_screen_base.dart').readAsStringSync();
    expect(home, contains('home-spending-incomplete-input'));
    expect(home, contains('snapshot.cashHeadroom'));
    expect(wallet, contains('wallet-upcoming-invoice-summary'));
    expect(wallet, contains('wallet-ending-installments'));
    expect(wallet, contains('não some novamente'));
  });
}
