import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_item.dart';
import '../models/category_tag.dart';
import 'folego_repository.dart';

extension FolegoRepositoryCategories on FolegoRepository {
  Future<List<CategoryItem>> listCategoryCatalog({
    required String spaceId,
    required String kind,
  }) async {
    if (kind != 'expense' && kind != 'income') {
      throw ArgumentError.value(kind, 'kind', 'Use expense ou income.');
    }

    final response = await Supabase.instance.client.rpc(
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

  Future<List<CategoryTag>> listCategoryTags(String spaceId) async {
    final response = await Supabase.instance.client
        .from('tags')
        .select('id,name,tag_type,color_hex,active')
        .eq('space_id', spaceId)
        .eq('active', true)
        .order('tag_type')
        .order('name');

    return List<Map<String, dynamic>>.from(response)
        .map(CategoryTag.fromJson)
        .toList(growable: false);
  }

  Future<String> createCategoryTag({
    required String spaceId,
    required String name,
    String type = 'tag',
    String? colorHex,
  }) async {
    if (!const {'tag', 'project', 'person'}.contains(type)) {
      throw ArgumentError.value(type, 'type', 'Tipo de tag inválido.');
    }
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe o nome da tag.');
    }

    final row = await Supabase.instance.client
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

  Future<String> createCustomCategory({
    required String spaceId,
    required String name,
    required String kind,
    String? parentId,
    bool essential = false,
    String colorHex = '#8C8CA8',
    List<String> searchAliases = const <String>[],
  }) async {
    final data = await Supabase.instance.client.rpc(
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
    return data as String;
  }

  Future<void> renameCustomCategory({
    required String spaceId,
    required String categoryId,
    required String name,
  }) async {
    await Supabase.instance.client.rpc(
      'rename_custom_category',
      params: {
        'p_space_id': spaceId,
        'p_category_id': categoryId,
        'p_name': name.trim(),
      },
    );
  }

  Future<void> setCategoryVisibility({
    required String spaceId,
    required String categoryId,
    required bool active,
  }) async {
    await Supabase.instance.client.rpc(
      'set_category_visibility',
      params: {
        'p_space_id': spaceId,
        'p_category_id': categoryId,
        'p_active': active,
      },
    );
  }

  Future<void> setEventAnnotations({
    required String spaceId,
    required String eventId,
    String? necessityClass,
    String? behaviorClass,
    String? frequencyClass,
    List<String> tagIds = const <String>[],
  }) async {
    await Supabase.instance.client.rpc(
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
    await Supabase.instance.client.rpc(
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
}
