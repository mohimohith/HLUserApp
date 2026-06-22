import '../../core/network/api_client.dart';
import '../models/cart.dart';

/// Server-authoritative cart. Every mutation returns the recomputed cart so the
/// client never has to derive totals itself.
class CartRepository {
  CartRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<Cart> getCart(String branchId) async {
    final res = await _api.get<Map<String, dynamic>>(
      '/cart',
      query: {'branchId': branchId},
    );
    return Cart.fromJson(res.data);
  }

  Future<Cart> add({
    required String branchId,
    required String productId,
    String? variantId,
    int quantity = 1,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/cart',
      body: {
        'branchId': branchId,
        'productId': productId,
        if (variantId != null) 'variantId': variantId,
        'quantity': quantity,
      },
    );
    return Cart.fromJson(res.data);
  }

  Future<Cart> setQuantity(String itemId, int quantity) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/cart/$itemId',
      body: {'quantity': quantity},
    );
    return Cart.fromJson(res.data);
  }

  Future<Cart> remove(String itemId) async {
    final res = await _api.delete<Map<String, dynamic>>('/cart/$itemId');
    return Cart.fromJson(res.data);
  }

  Future<void> clear(String branchId) async {
    await _api.delete('/cart/clear', query: {'branchId': branchId});
  }
}
