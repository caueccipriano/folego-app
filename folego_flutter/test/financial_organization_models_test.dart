import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/category_tag.dart';
import 'package:folego/data/models/financial_annotation_target.dart';

void main() {
  test('categoria oculta continua parseável para gerenciamento', () {
    final category = CategoryItem.fromJson({
      'id': 'custom-1',
      'name': 'Minha categoria',
      'kind': 'expense',
      'essential': false,
      'active': false,
      'is_system': false,
      'is_selectable': true,
      'category_role': 'economic',
    });

    expect(category.active, isFalse);
    expect(category.isCustom, isTrue);
  });

  test('tag distingue projeto e pessoa', () {
    final project = CategoryTag.fromJson({
      'id': 'project-1',
      'name': 'Viagem Ouro Preto',
      'tag_type': 'project',
      'active': true,
    });
    final person = CategoryTag.fromJson({
      'id': 'person-1',
      'name': 'Giovani',
      'tag_type': 'person',
      'active': true,
    });

    expect(project.isProject, isTrue);
    expect(person.isPerson, isTrue);
  });

  test('atributos de evento mantêm dimensões independentes', () {
    final target = FinancialAnnotationTarget(
      id: 'event-1',
      targetType: FinancialAnnotationTargetType.event,
      title: 'Netflix',
      eventType: 'expense',
    ).copyWithAnnotations(
      necessityClass: 'want',
      behaviorClass: 'fixed',
      frequencyClass: 'recurring',
      tagIds: const ['tag-1'],
    );

    expect(target.necessityClass, 'want');
    expect(target.behaviorClass, 'fixed');
    expect(target.frequencyClass, 'recurring');
    expect(target.tagIds, const ['tag-1']);
  });

  test('recorrência mantém frequência conceitual recorrente', () {
    final recurring = FinancialAnnotationTarget(
      id: 'recurring-1',
      targetType: FinancialAnnotationTargetType.recurring,
      title: 'Energia',
      eventType: 'expense',
      frequencyClass: 'recurring',
    ).copyWithAnnotations(
      necessityClass: 'need',
      behaviorClass: 'variable',
      frequencyClass: 'one_off',
      tagIds: const [],
    );

    expect(recurring.isRecurring, isTrue);
    expect(recurring.frequencyClass, 'recurring');
  });
}
