import 'package:flutter/foundation.dart';

import '../data/models/cart.dart';
import '../data/repositories/repositories.dart';

/// Cart state, backed by the server-authoritative `/cart` API (Repos.cart).
///
/// The public READ surface (getQuantity / getProductTotalQuantity /
/// getTotalCartItems / isInCart ...) is kept identical to the old PHP-era
/// provider so the ported widget trees keep working unchanged. The old inline
/// `http` mutations are replaced by the async helpers [addItem] /
/// [changeQuantity] / [removeItem], which call the backend and then resync the
/// local maps from the returned [Cart].
///
/// Quantities are keyed by `"<productId>-<variantId>"`; for each key we also
/// remember the server cart-item id needed for PATCH/DELETE.
class CartProvider with ChangeNotifier {
  final Map<String, Map<String, int>> _cartQuantities = {};
  final Map<String, Map<String, String>> _cartItemIds = {};

  String _getCartKey(String productId, String variantId) => '$productId-$variantId';

  String _bucket(String userId) => userId.isEmpty ? '_guest' : userId;

  // ---------------------------------------------------------------------------
  // Reads (same signatures as the legacy provider)
  // ---------------------------------------------------------------------------

  int getQuantity(String userId, String productId, String variantId) {
    final key = _getCartKey(productId, variantId);
    return _cartQuantities[_bucket(userId)]?[key] ?? 0;
  }

  /// Server cart-item id for a line, or null if it's not in the cart.
  String? cartItemId(String userId, String productId, String variantId) {
    final key = _getCartKey(productId, variantId);
    return _cartItemIds[_bucket(userId)]?[key];
  }

  /// Legacy shim — old widgets called this to get an int id; no longer used for
  /// mutations (kept so any stray reference still compiles).
  int getCartId(String userId, String productId, String variantId) => 0;

  int getTotalCartItems(String userId) {
    final map = _cartQuantities[_bucket(userId)];
    if (map == null) return 0;
    var total = 0;
    map.forEach((_, qty) => total += qty);
    return total;
  }

  int getProductTotalQuantity(String userId, String productId) {
    final map = _cartQuantities[_bucket(userId)];
    if (map == null) return 0;
    var total = 0;
    map.forEach((key, qty) {
      if (key.startsWith('$productId-')) total += qty;
    });
    return total;
  }

  bool isInCart(String userId, String productId, String variantId) =>
      getQuantity(userId, productId, variantId) > 0;

  bool isCartEmpty(String userId) {
    final map = _cartQuantities[_bucket(userId)];
    return map == null || map.isEmpty;
  }

  int getUniqueItemsCount(String userId) =>
      _cartQuantities[_bucket(userId)]?.length ?? 0;

  List<String> getProductIdsInCart(String userId) {
    final map = _cartQuantities[_bucket(userId)];
    if (map == null) return [];
    final ids = <String>{};
    for (final key in map.keys) {
      final parts = key.split('-');
      if (parts.isNotEmpty) ids.add(parts[0]);
    }
    return ids.toList();
  }

  /// Legacy compat: returns cart items as a list of maps with the old keys.
  List<Map<String, dynamic>> getCartItemsAsList(String userId) {
    final bucket = _bucket(userId);
    final qty = _cartQuantities[bucket];
    final ids = _cartItemIds[bucket];
    if (qty == null) return [];
    final result = <Map<String, dynamic>>[];
    qty.forEach((key, quantity) {
      final parts = key.split('-');
      if (parts.length >= 2) {
        result.add({
          'product_id': parts[0],
          'variant_id': parts[1],
          'quantity': quantity,
          'cart_id': ids?[key] ?? 0,
        });
      }
    });
    return result;
  }

  // ---------------------------------------------------------------------------
  // Local mutators (kept for compatibility; server is the source of truth)
  // ---------------------------------------------------------------------------

  void updateCartQuantities(
    String userId,
    String productId,
    String variantId,
    int quantity,
    Object? itemId,
  ) {
    final bucket = _bucket(userId);
    _cartQuantities.putIfAbsent(bucket, () => {});
    _cartItemIds.putIfAbsent(bucket, () => {});
    final key = _getCartKey(productId, variantId);
    _cartQuantities[bucket]![key] = quantity;
    if (itemId != null) _cartItemIds[bucket]![key] = itemId.toString();
    notifyListeners();
  }

  void removeCartItem(String userId, String productId, String variantId) {
    final bucket = _bucket(userId);
    final key = _getCartKey(productId, variantId);
    _cartQuantities[bucket]?.remove(key);
    _cartItemIds[bucket]?.remove(key);
    notifyListeners();
  }

  void clearCart(String userId) {
    final bucket = _bucket(userId);
    _cartQuantities.remove(bucket);
    _cartItemIds.remove(bucket);
    notifyListeners();
  }

  void clearAllCartData() {
    _cartQuantities.clear();
    _cartItemIds.clear();
    notifyListeners();
  }

  void clearCartData(String userId) => clearCart(userId);

  // ---------------------------------------------------------------------------
  // Server-backed operations
  // ---------------------------------------------------------------------------

  void _syncFromCart(String userId, Cart cart) {
    final bucket = _bucket(userId);
    final qty = <String, int>{};
    final ids = <String, String>{};
    for (final item in cart.items) {
      final key = _getCartKey(item.productId, item.variantId ?? '');
      qty[key] = item.quantity;
      ids[key] = item.id;
    }
    _cartQuantities[bucket] = qty;
    _cartItemIds[bucket] = ids;
    notifyListeners();
  }

  /// Pull the authoritative cart for [branchId] and repopulate local maps.
  Future<bool> refreshCartData(String userId, String branchId) async {
    if (branchId.isEmpty || userId.isEmpty) {
      clearCart(userId);
      return false;
    }
    try {
      final cart = await Repos.cart.getCart(branchId);
      _syncFromCart(userId, cart);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> addItem({
    required String userId,
    required String branchId,
    required String productId,
    required String variantId,
  }) async {
    try {
      final cart = await Repos.cart.add(
        branchId: branchId,
        productId: productId,
        variantId: variantId.isEmpty ? null : variantId,
      );
      _syncFromCart(userId, cart);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> changeQuantity({
    required String userId,
    required String branchId,
    required String productId,
    required String variantId,
    required int quantity,
  }) async {
    final itemId = cartItemId(userId, productId, variantId);
    if (itemId == null) {
      final ok = await addItem(
          userId: userId, branchId: branchId, productId: productId, variantId: variantId);
      if (!ok || quantity <= 1) return ok;
      return changeQuantity(
          userId: userId,
          branchId: branchId,
          productId: productId,
          variantId: variantId,
          quantity: quantity);
    }
    try {
      final cart = quantity <= 0
          ? await Repos.cart.remove(itemId)
          : await Repos.cart.setQuantity(itemId, quantity);
      _syncFromCart(userId, cart);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> removeItem({
    required String userId,
    required String branchId,
    required String productId,
    required String variantId,
  }) async {
    final itemId = cartItemId(userId, productId, variantId);
    if (itemId == null) return true;
    try {
      final cart = await Repos.cart.remove(itemId);
      _syncFromCart(userId, cart);
      return true;
    } catch (_) {
      return false;
    }
  }
}
