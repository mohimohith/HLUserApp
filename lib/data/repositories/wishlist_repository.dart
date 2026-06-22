import '../../core/network/api_client.dart';
import '../models/product.dart';

class WishlistRepository {
  WishlistRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<List<Product>> list() async {
    final res = await _api.get<List<dynamic>>('/wishlist');
    return res.data
        .whereType<Map>()
        .map((e) {
          final m = Map<String, dynamic>.from(e);
          // Endpoint returns wishlist rows that embed the product.
          final product = m['product'] is Map ? Map<String, dynamic>.from(m['product']) : m;
          return Product.fromJson(product);
        })
        .toList();
  }

  Future<void> add(String productId) =>
      _api.post('/wishlist', body: {'productId': productId});

  Future<bool> check(String productId) async {
    final res = await _api.get<Map<String, dynamic>>('/wishlist/check/$productId');
    final d = res.data;
    return d['inWishlist'] == true || d['exists'] == true || d['wishlisted'] == true;
  }

  Future<void> remove(String productId) => _api.delete('/wishlist/$productId');
}
