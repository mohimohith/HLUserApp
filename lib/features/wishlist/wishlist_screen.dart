import 'package:flutter/material.dart';

import '../../core/network/api_exception.dart';
import '../../data/models/product.dart';
import '../../data/repositories/repositories.dart';
import '../product/product_grid.dart';

/// Saved products from `GET /wishlist`.
class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  List<Product> _products = [];
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
      final list = await Repos.wishlist.list();
      if (mounted) setState(() => _products = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Wishlist',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: WishlistScreen._primary))
          : _error != null
              ? Center(child: Text(_error!))
              : _products.isEmpty
                  ? const _Empty()
                  : RefreshIndicator(
                      color: WishlistScreen._primary,
                      onRefresh: _load,
                      child: CustomScrollView(
                        slivers: [
                          ProductSliverGrid(products: _products),
                          const SliverToBoxAdapter(child: SizedBox(height: 16)),
                        ],
                      ),
                    ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_border, size: 64, color: Color(0xffCBB7DA)),
          SizedBox(height: 16),
          Text('No saved items yet',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          SizedBox(height: 6),
          Text('Tap the heart on a product to save it',
              style: TextStyle(color: Color(0xff999999), fontSize: 13)),
        ],
      ),
    );
  }
}
