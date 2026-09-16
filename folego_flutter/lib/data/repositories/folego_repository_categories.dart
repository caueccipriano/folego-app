import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_item.dart';
import '../models/category_tag.dart';
import '../models/financial_annotation_target.dart';
import 'folego_repository.dart';

extension FolegoRepositoryCategories on FolegoRepository {
  SupabaseClient get _categoryClient => Supabase.instance.client;

  Future<List<CategoryItem>> listCategoryCatalog({
    required String spaceId,
    required String kind,
  }) async {
    if (kind != 'expense' && kind != 'income') {
      throw ArgumentError.value(kind, 'kind', 'Use expense ou income.');
    }

    final response = await _categoryClient.rpc(
      'get_category_catalog',
      params: {
        'p_space_id': spaceId,
        'p_kind': kind,
      },
    );

    final rows = List<Map<String, dynamic>>.from(response as List);
    return rows.map(CategoryItem.fromJson).toList(growable: false);
  }

  Future<List<CategoryItem>> listExpenseCategoryCatalog(String spaceId) {
    return listCategoryCatalog(spaceId: spaceId, kind: 'expense');
  }

  Future<List<CategoryItem>> listIncomeCategoryCatalog(String spaceId) {
    return listCategoryCatalog(spaceId: spaceId, kind: 'income');
  }

  /// Catálogo de administração.
  ///
  /// Diferente de get_category_catalog, inclui categorias econômicas ocultas
  /// para que o usuário consiga reativá-las nas configurações.
  Future<List<CategoryItem>> listManageableCategories(String spaceId) async {
    final response = await _categoryClient
        .from('categories')
        .select('''
          id,
          name,
          kind,
          parent_id,
          essential,
          active,
          color_hex,
          icon_key,
          is_system,
          system_key,
          category_role,
          is_selectable,
          search_aliases,
          sort_order
        ''')
        .eq('space_id', spaceId)
        .eq('category_role', 'economic')
        .order('kind')
        .order('sort_order')
        .order('name');

    final rows = List<Map<String, dynamic>>.from(response);
    final namesById = <String, String>{
      for (final row in rows)
        if (row['id'] is String && row['name'] is String)
          row['id'] as String: row['name'] as String,
    };

    return rows.map((row) {
      final parentId = row['parent_id'] as String?;
      return CategoryItem.fromJson({
        ...row,
        'parent_name': parentId == null ? null : namesById[parentId],
      });
    }).toList(growable: false);
  }

  Future<List<CategoryTag>> listAllCategoryTags(String spaceId) async {
    final response = await _categoryClient
        .from('tags')
        .select('id,name,tag_type,color_hex,active')
        .eq('space_id', spaceId)
        .order('tag_type')
        .order('name');

    return List<Map<String, dynamic>>.from(response)
        .map(CategoryTag.fromJson)
        .toList(growable: false);
  }

  Future<List<CategoryTag>> listCategoryTags(String spaceId) async {
    final tags = await listAllCategoryTags(spaceId);
    return tags.where((tag) => tag.active).toList(growable: false);
  }

  Future<String> createCategoryTag({
    required String spaceId,
    required String name,
    String type = 'tag',
    String? colorHex,
  }) async {
    _validateTag(type: type, name: name);

    final row = await _categoryClient
        .from('tags')
        .insert({
          'space_id': spaceId,
          'name': name.trim(),
          'tag_type': type,
          'color_hex': colorHex,
        })
        .select('id')
        .single();

    return row['id'] as String;
  }

  Future<void> updateCategoryTag({
    required String spaceId,
    required String tagId,
    required String name,
    required String type,
    String? colorHex,
    bool? active,
  }) async {
    _validateTag(type: type, name: name);

    final values = <String, dynamic>{
      'name': name.trim(),
      'tag_type': type,
      'color_hex': colorHex,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'active': ?active,
    };

    await _categoryClient
        .from('tags')
        .update(values)
        .eq('space_id', spaceId)
        .eq('id', tagId);
  }

  Future<void> setCategoryTagActive({
    required String spaceId,
    required String tagId,
    required bool active,
  }) async {
    await _categoryClient
        .from('tags')
        .update({
          'active': active,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('space_id', spaceId)
        .eq('id', tagId);
  }

  Future<String> createCustomCategory({
    required String spaceId,
    required String name,
    required String kind,
    String? parentId,
    bool essential = false,
    String colorHex = '#8C8CA8',
    String? iconKey,
    List<String> searchAliases = const <String>[],
  }) async {
    final data = await _categoryClient.rpc(
      'create_custom_category',
      params: {
        'p_space_id': spaceId,
        'p_name': name.trim(),
        'p_kind': kind,
        'p_parent_id': parentId,
        'p_essential': essential,
        'p_color_hex': colorHex,
        'p_search_aliases': searchAliases,
      },
    );
    final categoryId = data as String;

    if (iconKey != null) {
      await _categoryClient
          .from('categories')
          .update({
            'icon_key': iconKey,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('space_id', spaceId)
          .eq('id', categoryId)
          .eq('is_system', false)
          .eq('category_role', 'economic');
    }

    return categoryId;
  }

  Future<void> renameCustomCategory({
    required String spaceId,
    required String categoryId,
    required String name,
  }) async {
    await _categoryClient.rpc(
      'rename_custom_category',
      params: {
        'p_space_id': spaceId,
        'p_category_id': categoryId,
        'p_name': name.trim(),
      },
    );
  }

  Future<void> updateCustomCategoryPresentation({
    required String spaceId,
    required String categoryId,
    required String name,
    required bool essential,
    required String colorHex,
    String? iconKey,
    required List<String> searchAliases,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe o nome da categoria.');
    }

    final response = await _categoryClient
        .from('categories')
        .update({
          'name': name.trim(),
          'essential': essential,
          'color_hex': colorHex,
          if (iconKey != null) 'icon_key': iconKey,
          'search_aliases': searchAliases,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('space_id', spaceId)
        .eq('id', categoryId)
        .eq('is_system', false)
        .eq('category_role', 'economic')
        .select('id');

    final rows = List<Map<String, dynamic>>.from(response);
    if (rows.isEmpty) {
      throw StateError('custom_category_not_found');
    }
  }

  Future<void> setCategoryVisibility({
    required String spaceId,
    required String categoryId,
    required bool active,
  }) async {
    await _categoryClient.rpc(
      'set_category_visibility',
      params: {
        'p_space_id': spaceId,
        'p_category_id': categoryId,
        'p_active': active,
      },
    );
  }

  Future<List<FinancialAnnotationTarget>> listAnnotationTargets(
    String spaceId, {
    int eventLimit = 100,
  }) async {
    final base = await Future.wait<dynamic>([
      _categoryClient
          .from('financial_events')
          .select(
            'id,description,event_type,occurred_at,necessity_class,behavior_class,frequency_class,status',
          )
          .eq('space_id', spaceId)
          .inFilter(
            'event_type',
            const ['income', 'expense', 'card_purchase', 'benefit_expense'],
          )
          .neq('status', 'cancelled')
          .neq('status', 'ignored')
          .order('occurred_at', ascending: false)
          .limit(eventLimit),
      _categoryClient
          .from('recurring_items')
          .select(
            'id,name,item_type,starts_on,active,necessity_class,behavior_class',
          )
          .eq('space_id', spaceId)
          .order('active', ascending: false)
          .order('name'),
    ]);

    final events = List<Map<String, dynamic>>.from(base[0]);
    final recurring = List<Map<String, dynamic>>.from(base[1]);
    final eventIds = events
        .map((row) => row['id'])
        .whereType<String>()
        .toList(growable: false);
    final recurringIds = recurring
        .map((row) => row['id'])
        .whereType<String>()
        .toList(growable: false);

    final tagsByEvent = <String, List<String>>{};
    final tagsByRecurring = <String, List<String>>{};

    if (eventIds.isNotEmpty) {
      final response = await _categoryClient
          .from('financial_event_tags')
          .select('event_id,tag_id')
          .eq('space_id', spaceId)
          .inFilter('event_id', eventIds);

      for (final row in List<Map<String, dynamic>>.from(response)) {
        final eventId = row['event_id'] as String?;
        final tagId = row['tag_id'] as String?;
        if (eventId == null || tagId == null) continue;
        (tagsByEvent[eventId] ??= <String>[]).add(tagId);
      }
    }

    if (recurringIds.isNotEmpty) {
      final response = await _categoryClient
          .from('recurring_item_tags')
          .select('recurring_item_id,tag_id')
          .eq('space_id', spaceId)
          .inFilter('recurring_item_id', recurringIds);

      for (final row in List<Map<String, dynamic>>.from(response)) {
        final itemId = row['recurring_item_id'] as String?;
        final tagId = row['tag_id'] as String?;
        if (itemId == null || tagId == null) continue;
        (tagsByRecurring[itemId] ??= <String>[]).add(tagId);
      }
    }

    final targets = <FinancialAnnotationTarget>[
      for (final row in events)
        FinancialAnnotationTarget(
          id: row['id'] as String,
          targetType: FinancialAnnotationTargetType.event,
          title: row['description'] as String? ?? 'Lançamento',
          eventType: row['event_type'] as String? ?? 'event',
          date: _dateTimeOrNull(row['occurred_at']),
          necessityClass: row['necessity_class'] as String?,
          behaviorClass: row['behavior_class'] as String?,
          frequencyClass: row['frequency_class'] as String?,
          tagIds: List<String>.unmodifiable(
            tagsByEvent[row['id'] as String] ?? const <String>[],
          ),
        ),
      for (final row in recurring)
        FinancialAnnotationTarget(
          id: row['id'] as String,
          targetType: FinancialAnnotationTargetType.recurring,
          title: row['name'] as String? ?? 'Recorrência',
          eventType: row['item_type'] as String? ?? 'expense',
          date: _dateTimeOrNull(row['starts_on']),
          active: row['active'] as bool? ?? true,
          necessityClass: row['necessity_class'] as String?,
          behaviorClass: row['behavior_class'] as String?,
          frequencyClass: 'recurring',
          tagIds: List<String>.unmodifiable(
            tagsByRecurring[row['id'] as String] ?? const <String>[],
          ),
        ),
    ];

    targets.sort((a, b) {
      if (a.isRecurring != b.isRecurring) return a.isRecurring ? -1 : 1;
      final aDate = a.date;
      final bDate = b.date;
      if (aDate != null && bDate != null) return bDate.compareTo(aDate);
      return a.title.compareTo(b.title);
    });

    return targets;
  }

  Future<void> setEventAnnotations({
    required String spaceId,
    required String eventId,
    String? necessityClass,
    String? behaviorClass,
    String? frequencyClass,
    List<String> tagIds = const <String>[],
  }) async {
    await _categoryClient.rpc(
      'set_event_annotations',
      params: {
        'p_space_id': spaceId,
        'p_event_id': eventId,
        'p_necessity_class': necessityClass,
        'p_behavior_class': behaviorClass,
        'p_frequency_class': frequencyClass,
        'p_tag_ids': tagIds,
      },
    );
  }

  Future<void> setRecurringAnnotations({
    required String spaceId,
    required String itemId,
    String? necessityClass,
    String? behaviorClass,
    List<String> tagIds = const <String>[],
  }) async {
    await _categoryClient.rpc(
      'set_recurring_annotations',
      params: {
        'p_space_id': spaceId,
        'p_item_id': itemId,
        'p_necessity_class': necessityClass,
        'p_behavior_class': behaviorClass,
        'p_tag_ids': tagIds,
      },
    );
  }

  void _validateTag({
    required String type,
    required String name,
  }) {
    if (!const {'tag', 'project', 'person'}.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Tipo de tag inválido.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe o nome da tag.');
    }
  }

  DateTime? _dateTimeOrNull(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
