import 'address.dart';
import 'json_utils.dart';

class OrderItem {
  final String id;
  final String productName;
  final String? variantName;
  final double unitPrice;
  final int quantity;
  final double lineTotal;
  final String? imageUrl;

  const OrderItem({
    required this.id,
    required this.productName,
    this.variantName,
    required this.unitPrice,
    required this.quantity,
    required this.lineTotal,
    this.imageUrl,
  });

  factory OrderItem.fromJson(Map<String, dynamic> j) => OrderItem(
        id: asString(j['id']),
        productName: asString(j['productName']),
        variantName: asStringOrNull(j['variantName']),
        unitPrice: asDouble(j['unitPrice']),
        quantity: asInt(j['quantity']),
        lineTotal: asDouble(j['lineTotal']),
        imageUrl: asStringOrNull(j['imageUrl']),
      );
}

class Order {
  final String id;
  final String orderNumber;
  final String status;
  final String paymentMethod;
  final String paymentStatus;
  final double itemsTotal;
  final double discountAmount;
  final double deliveryCharge;
  final double handlingCharge;
  final double finalAmount;
  final String? couponCode;
  final String? deliverySlot;
  final DateTime? placedAt;
  final DateTime? deliveredAt;
  final DeliveryAddress? address;
  final List<OrderItem> items;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.paymentMethod = 'COD',
    this.paymentStatus = 'PENDING',
    this.itemsTotal = 0,
    this.discountAmount = 0,
    this.deliveryCharge = 0,
    this.handlingCharge = 0,
    this.finalAmount = 0,
    this.couponCode,
    this.deliverySlot,
    this.placedAt,
    this.deliveredAt,
    this.address,
    this.items = const [],
  });

  /// A user-friendly status label.
  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'Order Placed';
      case 'CONFIRMED':
        return 'Confirmed';
      case 'PREPARING':
        return 'Preparing';
      case 'OUT_FOR_DELIVERY':
        return 'Out for Delivery';
      case 'DELIVERED':
        return 'Delivered';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  bool get isCancelled => status == 'CANCELLED';
  bool get isDelivered => status == 'DELIVERED';
  int get totalQuantity => items.fold(0, (s, it) => s + it.quantity);

  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: asString(j['id']),
        orderNumber: asString(j['orderNumber']),
        status: asString(j['status'], 'PENDING'),
        paymentMethod: asString(j['paymentMethod'], 'COD'),
        paymentStatus: asString(j['paymentStatus'], 'PENDING'),
        itemsTotal: asDouble(j['itemsTotal']),
        discountAmount: asDouble(j['discountAmount']),
        deliveryCharge: asDouble(j['deliveryCharge']),
        handlingCharge: asDouble(j['handlingCharge']),
        finalAmount: asDouble(j['finalAmount']),
        couponCode: asStringOrNull(j['couponCode']),
        deliverySlot: asStringOrNull(j['deliverySlot']),
        placedAt: DateTime.tryParse(asString(j['placedAt'])),
        deliveredAt: DateTime.tryParse(asString(j['deliveredAt'])),
        address: j['address'] is Map
            ? DeliveryAddress.fromJson(Map<String, dynamic>.from(j['address']))
            : null,
        items: asMapList(j['items']).map(OrderItem.fromJson).toList(),
      );

  /// Ordered status pipeline used by the tracking timeline (excludes the
  /// terminal CANCELLED state, handled separately).
  static const List<String> pipeline = [
    'PENDING',
    'CONFIRMED',
    'PREPARING',
    'OUT_FOR_DELIVERY',
    'DELIVERED',
  ];

  int get pipelineIndex => pipeline.indexOf(status);
}
