import '../../core/network/api_client.dart';
import '../models/order.dart';
import '../models/paginated.dart';

class OrderRepository {
  OrderRepository({ApiClient? client}) : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Place an order from the current cart. Server validates stock, applies the
  /// coupon and branch charges, snapshots line items and clears the cart.
  Future<Order> place({
    required String branchId,
    required String addressId,
    String paymentMethod = 'COD',
    String? couponCode,
    String? giftName,
    String? deliverySlot,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/orders',
      body: {
        'branchId': branchId,
        'addressId': addressId,
        'paymentMethod': paymentMethod,
        if (couponCode != null && couponCode.isNotEmpty) 'couponCode': couponCode,
        if (giftName != null && giftName.isNotEmpty) 'giftName': giftName,
        if (deliverySlot != null && deliverySlot.isNotEmpty) 'deliverySlot': deliverySlot,
      },
    );
    return Order.fromJson(res.data);
  }

  Future<Paginated<Order>> myOrders({int page = 1, int limit = 20}) async {
    final res = await _api.get<List<dynamic>>(
      '/orders/mine',
      query: {'page': page, 'limit': limit},
    );
    return Paginated.from(res.data, res.meta, Order.fromJson);
  }

  Future<Order> getById(String id) async {
    final res = await _api.get<Map<String, dynamic>>('/orders/$id');
    return Order.fromJson(res.data);
  }
}
