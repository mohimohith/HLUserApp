import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../cart/cart_controller.dart';
import '../cart/cart_screen.dart';
import '../home/modern_home_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';

/// The migrated customer app shell: a 4-tab bottom navigation hosting the new
/// modern screens (home, cart, orders, profile), all on the new backend.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  late final List<Widget> _tabs = const [
    ModernHomeScreen(),
    CartScreen(),
    OrdersScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartController>().totalItems;

    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppShell._primary.withOpacity(0.12),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: AppShell._primary),
            label: 'Home',
          ),
          NavigationDestination(
            icon: _CartIcon(count: cartCount, filled: false),
            selectedIcon: _CartIcon(count: cartCount, filled: true),
            label: 'Cart',
          ),
          const NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: AppShell._primary),
            label: 'Orders',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: AppShell._primary),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class _CartIcon extends StatelessWidget {
  const _CartIcon({required this.count, required this.filled});
  final int count;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(filled ? Icons.shopping_cart : Icons.shopping_cart_outlined,
            color: filled ? AppShell._primary : null),
        if (count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: Container(
              padding: const EdgeInsets.all(3),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              decoration: const BoxDecoration(
                color: Color(0xffE53E3E),
                shape: BoxShape.circle,
              ),
              child: Text('$count',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700)),
            ),
          ),
      ],
    );
  }
}
