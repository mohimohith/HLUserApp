import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/format.dart';
import '../../data/models/order.dart';
import '../../data/repositories/repositories.dart';

/// Order detail with a live status timeline ("track order"), item list,
/// delivery address and the full bill breakdown.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({super.key, required this.orderId, this.initial});

  final String orderId;
  final Order? initial;

  static const Color _primary = Color(0xff960ad7);

  static Future<void> open(BuildContext context, Order order) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailScreen(orderId: order.id, initial: order),
      ),
    );
  }

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Order? _order;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _order = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final full = await Repos.orders.getById(widget.orderId);
      if (mounted) {
        setState(() {
          _order = full;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          if (_order == null) _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
    return Scaffold(
      backgroundColor: const Color(0xffF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: Text(order != null ? '#${order.orderNumber}' : 'Order',
            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: _loading && order == null
          ? const Center(
              child: CircularProgressIndicator(color: OrderDetailScreen._primary))
          : order == null
              ? Center(child: Text(_error ?? 'Order unavailable'))
              : RefreshIndicator(
                  color: OrderDetailScreen._primary,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatusTimeline(order: order),
                      const SizedBox(height: 16),
                      _section('Items', _items(order)),
                      const SizedBox(height: 16),
                      if (order.address != null) ...[
                        _section('Delivery Address', _address(order)),
                        const SizedBox(height: 16),
                      ],
                      _section('Bill Details', _bill(order)),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
    );
  }

  Widget _section(String title, Widget child) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: child,
        ),
      ],
    );
  }

  Widget _items(Order order) {
    return Column(
      children: [
        for (final it in order.items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Container(
                  width: 24,
                  alignment: Alignment.center,
                  child: Text('${it.quantity}×',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, color: Color(0xff960ad7))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(it.productName,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      if (it.variantName != null)
                        Text(it.variantName!,
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xff999999))),
                    ],
                  ),
                ),
                Text(Money.rupees(it.lineTotal),
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _address(Order order) {
    final a = order.address!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(a.name, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(
          '${a.fullAddress}'
          '${a.landmark != null ? ', ${a.landmark}' : ''}'
          '${a.pinCode != null ? ' - ${a.pinCode}' : ''}',
          style: const TextStyle(fontSize: 13, color: Color(0xff666666)),
        ),
        Text(a.phone,
            style: const TextStyle(fontSize: 13, color: Color(0xff666666))),
      ],
    );
  }

  Widget _bill(Order order) {
    return Column(
      children: [
        _billRow('Item Total', Money.rupees(order.itemsTotal)),
        if (order.discountAmount > 0)
          _billRow('Discount', '- ${Money.rupees(order.discountAmount)}',
              color: const Color(0xff2E7D32)),
        if (order.deliveryCharge > 0)
          _billRow('Delivery Charge', Money.rupees(order.deliveryCharge)),
        if (order.handlingCharge > 0)
          _billRow('Handling Charge', Money.rupees(order.handlingCharge)),
        const Divider(height: 20),
        _billRow('Total', Money.rupees(order.finalAmount), bold: true),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.payments_outlined, size: 16, color: Color(0xff999999)),
            const SizedBox(width: 6),
            Text('${order.paymentMethod} • ${order.paymentStatus}',
                style: const TextStyle(fontSize: 12, color: Color(0xff999999))),
          ],
        ),
      ],
    );
  }

  Widget _billRow(String label, String value, {bool bold = false, Color? color}) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      fontSize: bold ? 15 : 13,
      color: color ?? Colors.black,
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

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.order});
  final Order order;

  static const Color _primary = Color(0xff960ad7);

  static const _labels = {
    'PENDING': 'Order Placed',
    'CONFIRMED': 'Confirmed',
    'PREPARING': 'Preparing',
    'OUT_FOR_DELIVERY': 'Out for Delivery',
    'DELIVERED': 'Delivered',
  };

  @override
  Widget build(BuildContext context) {
    if (order.isCancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xffFDECEC),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.cancel, color: Color(0xffE53E3E)),
            SizedBox(width: 10),
            Text('Order Cancelled',
                style: TextStyle(
                    color: Color(0xffE53E3E), fontWeight: FontWeight.w700)),
          ],
        ),
      );
    }

    final current = order.pipelineIndex;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < Order.pipeline.length; i++)
            _step(
              label: _labels[Order.pipeline[i]] ?? Order.pipeline[i],
              done: i <= current,
              active: i == current,
              isLast: i == Order.pipeline.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _step({
    required String label,
    required bool done,
    required bool active,
    required bool isLast,
  }) {
    final color = done ? _primary : const Color(0xffD8D2DE);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: done ? _primary : Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 2),
                ),
                child: done
                    ? const Icon(Icons.check, size: 13, color: Colors.white)
                    : null,
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: color),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 18, top: 1),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: active ? FontWeight.w800 : FontWeight.w500,
                color: done ? Colors.black : const Color(0xff9E9E9E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
