import '../../data/models/category_item.dart';
import '../../data/models/category_tag.dart';
import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';

/// Fronteira pequena e injetável usada pela tela de Organização.
///
/// A implementação de produção continua delegando aos repositórios canônicos;
/// a abstração existe para separar o ciclo de vida de Categorias e Marcadores e
/// permitir testes de atraso/erro sem depender de Supabase real.
abstract interface class FinancialOrganizationDataSource {
  Future<FinancialSpace> getPrimarySpace();

  Future<List<CategoryItem>> listCategories(String spaceId);

  Future<List<CategoryTag>> listMarkers(String spaceId);

  Future<void> createCategory({
    required String spaceId,
    required String name,
    required String kind,
    String? parentId,
  });

  Future<void> updateCategory({
    required String spaceId,
    required CategoryItem category,
    required String name,
  });

  Future<void> setCategoryActive({
    required String spaceId,
    required String categoryId,
    required bool active,
  });

  Future<void> createMarker({
    required String spaceId,
    required String name,
    required String type,
  });

  Future<void> updateMarker({
    required String spaceId,
    required CategoryTag marker,
    required String name,
    required String type,
  });

  Future<void> setMarkerActive({
    required String spaceId,
    required String markerId,
    required bool active,
  });
}

class RepositoryFinancialOrganizationDataSource
    implements FinancialOrganizationDataSource {
  RepositoryFinancialOrganizationDataSource(this.repository);

  final FolegoRepository repository;

  @override
  Future<FinancialSpace> getPrimarySpace() => repository.getPrimarySpace();

  @override
  Future<List<CategoryItem>> listCategories(String spaceId) =>
      repository.listManageableCategories(spaceId);

  @override
  Future<List<CategoryTag>> listMarkers(String spaceId) =>
      repository.listAllCategoryTags(spaceId);

  @override
  Future<void> createCategory({
    required String spaceId,
    required String name,
    required String kind,
    String? parentId,
  }) async {
    await repository.createCustomCategory(
      spaceId: spaceId,
      name: name,
      kind: kind,
      parentId: parentId,
    );
  }

  @override
  Future<void> updateCategory({
    required String spaceId,
    required CategoryItem category,
    required String name,
  }) =>
      repository.updateCustomCategoryPresentation(
        spaceId: spaceId,
        categoryId: category.id,
        name: name,
        essential: category.essential,
        colorHex: category.colorHex ?? '#8C8CA8',
        iconKey: category.iconKey,
        searchAliases: category.searchAliases,
      );

  @override
  Future<void> setCategoryActive({
    required String spaceId,
    required String categoryId,
    required bool active,
  }) =>
      repository.setCategoryVisibility(
        spaceId: spaceId,
        categoryId: categoryId,
        active: active,
      );

  @override
  Future<void> createMarker({
    required String spaceId,
    required String name,
    required String type,
  }) async {
    await repository.createCategoryTag(
      spaceId: spaceId,
      name: name,
      type: type,
    );
  }

  @override
  Future<void> updateMarker({
    required String spaceId,
    required CategoryTag marker,
    required String name,
    required String type,
  }) =>
      repository.updateCategoryTag(
        spaceId: spaceId,
        tagId: marker.id,
        name: name,
        type: type,
        colorHex: marker.colorHex,
        active: marker.active,
      );

  @override
  Future<void> setMarkerActive({
    required String spaceId,
    required String markerId,
    required bool active,
  }) =>
      repository.setCategoryTagActive(
        spaceId: spaceId,
        tagId: markerId,
        active: active,
      );
}
