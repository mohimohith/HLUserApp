import 'package:flutter/material.dart';

import '../../core/utils/format.dart';
import '../../data/models/order.dart';
import '../orders/order_detail_screen.dart';

/// Confirmation shown after a successful order placement.
class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.order});

  final Order order;
  static const Color _primary = Color(0xff960ad7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 96,
                height: 96,
                decoration: const BoxDecoration(
                  color: Color(0xffE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle,
                    color: Color(0xff2E7D32), size: 64),
              ),
              const SizedBox(height: 24),
              const Text('Order Placed!',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text('Order #${order.orderNumber}',
                  style: const TextStyle(fontSize: 14, color: Color(0xff777777))),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xffF7F7F9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _row('Items', '${order.totalQuantity}'),
                    _row('Item Total', Money.rupees(order.itemsTotal)),
                    if (order.discountAmount > 0)
                      _row('Discount', '- ${Money.rupees(order.discountAmount)}'),
                    if (order.deliveryCharge > 0)
                      _row('Delivery', Money.rupees(order.deliveryCharge)),
                    if (order.handlingCharge > 0)
                      _row('Handling', Money.rupees(order.handlingCharge)),
                    const Divider(height: 20),
                    _row('Total Payable', Money.rupees(order.finalAmount), bold: true),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    OrderDetailScreen.open(context, order);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Track Order',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  onPressed: () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
                  child: const Text('Continue Shopping',
                      style: TextStyle(
                          fontSize: 15,
                          color: _primary,
                          fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 16 : 13,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label, style: style),
          const Spacer(),
          Text(value, style: style),
        ],
      ),
    );
  }
}
