import 'json_utils.dart';

/// One line in the server-computed cart.
class CartItem {
  final String id;
  final String productId;
  final String productName;
  final String? variantId;
  final String? variantName;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final bool inStock;

  const CartItem({
    required this.id,
    required this.productId,
    required this.productName,
    this.variantId,
    this.variantName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.inStock = true,
  });

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        id: asString(j['id']),
        productId: asString(j['productId']),
        productName: asString(j['productName']),
        variantId: asStringOrNull(j['variantId']),
        variantName: asStringOrNull(j['variantName']),
        unitPrice: asDouble(j['unitPrice']),
        quantity: asInt(j['quantity']),
        lineTotal: asDouble(j['lineTotal']),
        inStock: asBool(j['inStock'], true),
      );
}

/// The full cart payload: lines + server-computed totals.
class Cart {
  final String? branchId;
  final List<CartItem> items;
  final int count;
  final double itemsTotal;
  final double savings;

  const Cart({
    this.branchId,
    this.items = const [],
    this.count = 0,
    this.itemsTotal = 0,
    this.savings = 0,
  });

  bool get isEmpty => items.isEmpty;

  static const Cart empty = Cart();

  factory Cart.fromJson(Map<String, dynamic> j) {
    final summary = j['summary'] is Map
        ? Map<String, dynamic>.from(j['summary'])
        : const <String, dynamic>{};
    return Cart(
      branchId: asStringOrNull(j['branchId']),
      items: asMapList(j['items']).map(CartItem.fromJson).toList(),
      count: asInt(summary['count']),
      itemsTotal: asDouble(summary['itemsTotal']),
      savings: asDouble(summary['savings']),
    );
  }
}
