import 'package:flutter/material.dart';

import '../../data/models/product.dart';
import '../home/widgets/product_card.dart';
import 'product_detail_screen.dart';

/// A 2-column sliver grid of [ProductCard]s that open the product detail page
/// on tap. Shared by category browse, search and wishlist screens.
class ProductSliverGrid extends StatelessWidget {
  const ProductSliverGrid({super.key, required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.all(12),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.62,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, i) {
            final p = products[i];
            return ProductCard(
              product: p,
              onTap: () => ProductDetailScreen.open(context, p),
            );
          },
          childCount: products.length,
        ),
      ),
    );
  }
}
