import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/smart_category_suggestion.dart';
import 'dart:io';

CategoryItem category(String id, String name, {
  String kind = 'expense',
  List<String> aliases = const [],
  bool active = true,
}) => CategoryItem(
  id: id,
  name: name,
  essential: false,
  kind: kind,
  active: active,
  searchAliases: aliases,
);

TransactionItem event(String description, String categoryId, {
  String eventType = 'expense',
  String status = 'confirmed',
}) => TransactionItem(
  id: '${description}_${categoryId}_$eventType',
  eventType: eventType,
  description: description,
  amount: 100,
  occurredAt: DateTime(2026, 10, 15),
  status: status,
  source: 'test',
  categoryId: categoryId,
);

void main() {
  test('reuses exact categorized descriptions with explanation', () {
    final suggestion = suggestSmartCategory(
      description: 'MERCADO ÁGUA',
      eventType: 'expense',
      categories: [category('market', 'Supermercado')],
      history: [event('Mercado Agua', 'market')],
    );
    expect(suggestion?.category.id, 'market');
    expect(suggestion?.evidenceCount, 1);
  });

  test('conflicting history does not guess even if an alias matches', () {
    final suggestion = suggestSmartCategory(
      description: 'Uber',
      eventType: 'expense',
      categories: [
        category('ride', 'Transporte', aliases: ['uber']),
        category('other', 'Viagens'),
      ],
      history: [
        event('Uber', 'ride'),
        event('Uber', 'other'),
      ],
    );
    expect(suggestion, isNull);
  });

  test('aliases match complete words, not loose substrings', () {
    final categories = [
      category('ride', 'Transporte', aliases: ['uber']),
    ];
    expect(suggestSmartCategory(
      description: 'Uber corrida', eventType: 'card_purchase',
      categories: categories, history: const [],
    )?.category.id, 'ride');
    expect(suggestSmartCategory(
      description: 'Tuberose', eventType: 'expense',
      categories: categories, history: const [],
    ), isNull);
  });

  test('generic descriptions, conflicting aliases, and wrong kind abstain', () {
    final categories = [
      category('pix', 'Transporte', aliases: ['pix enviado']),
      category('market', 'Mercado', aliases: ['supermercado']),
      category('shopping', 'Compras', aliases: ['supermercado']),
      category('salary', 'Salário', kind: 'income', aliases: ['mercado']),
    ];
    expect(suggestSmartCategory(
      description: 'PIX enviada - Santander',
      eventType: 'expense', categories: categories, history: const [],
    ), isNull);
    expect(suggestSmartCategory(
      description: 'Supermercado Uber',
      eventType: 'expense', categories: categories, history: const [],
    ), isNull);
    expect(suggestSmartCategory(
      description: 'Mercado', eventType: 'income',
      categories: categories, history: const [],
    )?.category.id, 'salary');
    expect(suggestSmartCategory(
      description: 'Mercado', eventType: 'expense',
      categories: [category('inactive', 'Mercado', active: false)],
      history: const [],
    ), isNull);
  });

  test('never accepts cancelled history, other direction, or transfers', () {
    final cat = category('r', 'Restaurante');
    expect(suggestSmartCategory(
      description: 'Almoço viagem', eventType: 'expense',
      categories: [cat],
      history: [event('Almoço viagem', 'r', status: 'cancelled')],
    ), isNull);
    expect(suggestSmartCategory(
      description: 'Almoço viagem', eventType: 'transfer',
      categories: [cat],
      history: [event('Almoço viagem', 'r')],
    ), isNull);
  });

  test('quick register and classification inbox expose opt-in suggestions', () {
    final quick = File('lib/features/home/quick_register_sheet_v3.dart')
        .readAsStringSync();
    final inbox = File('lib/features/transactions/transaction_classification_inbox.dart')
        .readAsStringSync();
    expect(quick, contains('quick-register-smart-category-suggestion'));
    expect(inbox, contains('classification-smart-suggestion:'));
    expect(quick, contains('onChanged: (_) => setState(() {})'));
    expect(inbox, contains('selected = suggestion.category'));
  });
}
