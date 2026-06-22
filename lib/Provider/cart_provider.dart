import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

import '../utils/api_constants.dart';

class CartProvider with ChangeNotifier {
  // Using a more efficient data structure
  final Map<String, Map<String, int>> _cartQuantities = {};
  final Map<String, Map<String, int>> _cartIds = {};

  // Shared delivery time - set once to avoid duplicate API calls
  String _deliveryTime = '';
  String get deliveryTime => _deliveryTime;

  void setDeliveryTime(String time) {
    _deliveryTime = time;
    notifyListeners();
  }

  // 🟢 Update cart quantities
  void updateCartQuantities(
      String userId,
      String productId,
      String variantId,
      int quantity,
      int cartId,
      ) {
    if (userId.isEmpty) return;

    // Initialize user maps if they don't exist
    _cartQuantities.putIfAbsent(userId, () => {});
    _cartIds.putIfAbsent(userId, () => {});

    final key = _getCartKey(productId, variantId);
    _cartQuantities[userId]![key] = quantity;
    _cartIds[userId]![key] = cartId;

    notifyListeners();
  }

  // 🟢 Remove item from cart
  void removeCartItem(String userId, String productId, String variantId) {
    if (userId.isEmpty) return;

    final key = _getCartKey(productId, variantId);
    _cartQuantities[userId]?.remove(key);
    _cartIds[userId]?.remove(key);
    notifyListeners();
  }

  // 🟢 Get quantity of a product
  int getQuantity(String userId, String productId, String variantId) {
    if (userId.isEmpty) return 0;

    final key = _getCartKey(productId, variantId);
    return _cartQuantities[userId]?[key] ?? 0;
  }

  // 🟢 Get cartId of a product
  int getCartId(String userId, String productId, String variantId) {
    if (userId.isEmpty) return 0;

    final key = _getCartKey(productId, variantId);
    return _cartIds[userId]?[key] ?? 0;
  }

  // 🟢 Get total quantity of all items for a user
  int getTotalCartItems(String userId) {
    if (userId.isEmpty || !_cartQuantities.containsKey(userId)) return 0;

    int total = 0;
    _cartQuantities[userId]!.forEach((key, qty) {
      total += qty;
    });
    return total;
  }

  // 🟢 Clear cart for specific user
  void clearCart(String userId) {
    if (userId.isEmpty) return;

    _cartQuantities.remove(userId);
    _cartIds.remove(userId);
    notifyListeners();
  }

  // 🟢 Clear all cart data completely
  void clearAllCartData() {
    _cartQuantities.clear();
    _cartIds.clear();
    notifyListeners();
  }

  // 🟢 Get cart items as list for a user
  List<Map<String, dynamic>> getCartItemsAsList(String userId) {
    if (userId.isEmpty || !_cartQuantities.containsKey(userId)) return [];

    List<Map<String, dynamic>> items = [];

    _cartQuantities[userId]!.forEach((key, quantity) {
      final parts = key.split('-');
      if (parts.length >= 2) {
        final productId = parts[0];
        final variantId = parts[1];
        final cartId = _cartIds[userId]![key] ?? 0;

        items.add({
          'product_id': productId,
          'variant_id': variantId,
          'quantity': quantity,
          'cart_id': cartId,
        });
      }
    });

    return items;
  }

  // 🟢 Get total quantity of a specific product (across all variants)
  int getProductTotalQuantity(String userId, String productId) {
    if (userId.isEmpty || !_cartQuantities.containsKey(userId)) return 0;

    int total = 0;
    _cartQuantities[userId]!.forEach((key, qty) {
      if (key.startsWith('$productId-')) {
        total += qty;
      }
    });
    return total;
  }

  // 🟢 Refresh cart data from API
  Future<bool> refreshCartData(String userId, int branchId) async {
    if (userId.isEmpty || branchId <= 0) {
      clearCart(userId);
      return false;
    }

    try {
      final url = Uri.parse(
          '${ApiConstants.GET_CART_ITEMS}?user_id=$userId&branch_id=$branchId'
      );

      final response = await http.get(url);

      if (response.statusCode != 200) {
        // Don't clear local data on network failure — keep what we have
        return false;
      }

      final data = json.decode(response.body);

      if (data['success'] == true && data['cart'] != null) {
        // Only clear AFTER successful response
        _cartQuantities.remove(userId);
        _cartIds.remove(userId);

        _cartQuantities[userId] = {};
        _cartIds[userId] = {};

        for (var item in data['cart']) {
          final productId = item['product_id']?.toString() ?? '';
          final variantId = item['variant_id']?.toString() ?? '';
          final quantity = int.tryParse(item['quantity']?.toString() ?? '0') ?? 0;
          final cartId = int.tryParse(item['id']?.toString() ?? '0') ?? 0;

          if (productId.isNotEmpty && variantId.isNotEmpty) {
            final key = _getCartKey(productId, variantId);
            _cartQuantities[userId]![key] = quantity;
            _cartIds[userId]![key] = cartId;
          }
        }

        notifyListeners();
        return true;
      } else {
        // Don't clear on API failure either — server might be temporarily down
        return false;
      }
    } catch (e) {
      // Don't clear on network error — preserve existing cart data
      return false;
    }
  }


  // 🟢 Check if a product variant is in cart
  bool isInCart(String userId, String productId, String variantId) {
    if (userId.isEmpty) return false;

    final key = _getCartKey(productId, variantId);
    return _cartQuantities[userId]?[key] != null &&
        (_cartQuantities[userId]![key] ?? 0) > 0;
  }

  // 🟢 Get all cart items for a user as a map
  Map<String, Map<String, dynamic>> getCartItemsAsMap(String userId) {
    if (userId.isEmpty || !_cartQuantities.containsKey(userId)) return {};

    final Map<String, Map<String, dynamic>> items = {};

    _cartQuantities[userId]!.forEach((key, quantity) {
      final parts = key.split('-');
      if (parts.length >= 2) {
        final productId = parts[0];
        final variantId = parts[1];
        final cartId = _cartIds[userId]![key] ?? 0;

        items[key] = {
          'product_id': productId,
          'variant_id': variantId,
          'quantity': quantity,
          'cart_id': cartId,
        };
      }
    });

    return items;
  }

  // 🟢 Helper method to generate consistent cart key
  String _getCartKey(String productId, String variantId) {
    return '$productId-$variantId';
  }

  // 🟢 Get all product IDs in cart for a user
  List<String> getProductIdsInCart(String userId) {
    if (userId.isEmpty || !_cartQuantities.containsKey(userId)) return [];

    final productIds = <String>{};

    _cartQuantities[userId]!.forEach((key, _) {
      final parts = key.split('-');
      if (parts.isNotEmpty) {
        productIds.add(parts[0]);
      }
    });

    return productIds.toList();
  }

  // 🟢 Check if cart is empty for a user
  bool isCartEmpty(String userId) {
    if (userId.isEmpty || !_cartQuantities.containsKey(userId)) return true;
    return _cartQuantities[userId]!.isEmpty;
  }

  // 🟢 Get total number of unique items in cart
  int getUniqueItemsCount(String userId) {
    if (userId.isEmpty || !_cartQuantities.containsKey(userId)) return 0;
    return _cartQuantities[userId]!.length;
  }

  void clearCartData(String userId) {
    // Remove all entries for this user
    _cartQuantities.removeWhere((key, value) => key.startsWith('$userId-'));
    _cartIds.removeWhere((key, value) => key.startsWith('$userId-'));
    notifyListeners();
  }
}