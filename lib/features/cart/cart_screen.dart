import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/format.dart';
import '../../data/models/cart.dart';
import '../checkout/checkout_screen.dart';
import 'cart_controller.dart';

/// Modern cart: server-computed lines and totals, inline steppers, and a
/// sticky bill summary that leads into checkout.
class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();

    return Scaffold(
      backgroundColor: const Color(0xffF7F7F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text('My Cart',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: cart.isLoading && cart.isEmpty
          ? const Center(child: CircularProgressIndicator(color: CartScreen._primary))
          : cart.isEmpty
              ? const _EmptyCart()
              : _CartBody(cart: cart.cart),
      bottomNavigationBar: cart.isEmpty ? null : _BillBar(cart: cart.cart),
    );
  }
}

class _CartBody extends StatelessWidget {
  const _CartBody({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: cart.items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CartTile(item: cart.items[i]),
    );
  }
}

class _CartTile extends StatelessWidget {
  const _CartTile({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartController>();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.productName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                if (item.variantName != null) ...[
                  const SizedBox(height: 2),
                  Text(item.variantName!,
                      style: const TextStyle(fontSize: 12, color: Color(0xff8A8A8A))),
                ],
                const SizedBox(height: 6),
                Text(Money.rupees(item.unitPrice),
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                if (!item.inStock)
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text('Out of stock',
                        style: TextStyle(color: Color(0xffE53E3E), fontSize: 11)),
                  ),
              ],
            ),
          ),
          _Stepper(
            quantity: item.quantity,
            onDec: () => cart.changeQuantity(item.productId,
                variantId: item.variantId, delta: -1),
            onInc: () => cart.changeQuantity(item.productId,
                variantId: item.variantId, delta: 1),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.quantity, required this.onDec, required this.onInc});
  final int quantity;
  final VoidCallback onDec;
  final VoidCallback onInc;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: CartScreen._primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.remove, color: Colors.white),
            onPressed: onDec,
          ),
          Text('$quantity',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          IconButton(
            iconSize: 16,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: onInc,
          ),
        ],
      ),
    );
  }
}

class _BillBar extends StatelessWidget {
  const _BillBar({required this.cart});
  final Cart cart;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2))],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(Money.rupees(cart.itemsTotal),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                if (cart.savings > 0)
                  Text('You save ${Money.rupees(cart.savings)}',
                      style: const TextStyle(fontSize: 11, color: Color(0xff2E7D32))),
              ],
            ),
            const Spacer(),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CheckoutScreen()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: CartScreen._primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Checkout',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.shopping_cart_outlined, size: 64, color: Color(0xffCBB7DA)),
          SizedBox(height: 16),
          Text('Your cart is empty',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Add items to get started',
              style: TextStyle(color: Color(0xff999999), fontSize: 13)),
        ],
      ),
    );
  }
}
