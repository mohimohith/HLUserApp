import '../../core/network/api_client.dart';
import '../models/paginated.dart';
import '../models/product.dart';

/// Browse and search products. All listing is branch-scoped and paginated.
class ProductRepository {
  ProductRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<Paginated<Product>> list({
    required String branchId,
    String? categoryId,
    String? subCategoryId,
    String? mainCategoryId,
    String? brandId,
    String? tag,
    String? search,
    int page = 1,
    int limit = 20,
  }) async {
    final res = await _api.get<List<dynamic>>(
      '/products',
      query: {
        'branchId': branchId,
        if (categoryId != null) 'categoryId': categoryId,
        if (subCategoryId != null) 'subCategoryId': subCategoryId,
        if (mainCategoryId != null) 'mainCategoryId': mainCategoryId,
        if (brandId != null) 'brandId': brandId,
        if (tag != null) 'tag': tag,
        if (search != null && search.isNotEmpty) 'search': search,
        'page': page,
        'limit': limit,
      },
    );
    return Paginated.from(res.data, res.meta, Product.fromJson);
  }

  Future<Product> getById(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/products/$id');
    return Product.fromJson(res.data);
  }
}
