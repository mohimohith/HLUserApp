import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/format.dart';
import '../../data/models/order.dart';
import '../../data/repositories/repositories.dart';
import 'order_detail_screen.dart';

/// "My Orders" — paginated order history from `GET /orders/mine`.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final List<Order> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await Repos.orders.myOrders();
      setState(() => _orders
        ..clear()
        ..addAll(page.items));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        automaticallyImplyLeading: false,
        title: const Text('My Orders',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: OrdersScreen._primary))
          : _error != null
              ? Center(child: Text(_error!))
              : _orders.isEmpty
                  ? const _Empty()
                  : RefreshIndicator(
                      color: OrdersScreen._primary,
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _orders.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) => GestureDetector(
                          onTap: () =>
                              OrderDetailScreen.open(context, _orders[i]),
                          child: _OrderCard(order: _orders[i]),
                        ),
                      ),
                    ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});
  final Order order;

  Color get _statusColor {
    if (order.isDelivered) return const Color(0xff2E7D32);
    if (order.isCancelled) return const Color(0xffE53E3E);
    return const Color(0xffDD6B20);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('#${order.orderNumber}',
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(order.statusLabel,
                    style: TextStyle(
                        color: _statusColor, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${order.totalQuantity} item(s) • ${Money.rupees(order.finalAmount)}',
              style: const TextStyle(fontSize: 13, color: Color(0xff555555))),
          if (order.items.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              order.items.map((e) => e.productName).take(3).join(', '),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Color(0xff999999)),
            ),
          ],
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.receipt_long_outlined, size: 64, color: Color(0xffCBB7DA)),
          SizedBox(height: 16),
          Text('No orders yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
