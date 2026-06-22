import 'package:flutter/material.dart';

import '../../../data/models/product.dart';
import 'product_card.dart';

/// A titled horizontal rail of product cards (best-selling, collections, ...).
class ProductRail extends StatelessWidget {
  const ProductRail({
    super.key,
    required this.title,
    required this.products,
    this.onSeeAll,
    this.onProductTap,
  });

  final String title;
  final List<Product> products;
  final VoidCallback? onSeeAll;
  final void Function(Product product)? onProductTap;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
              if (onSeeAll != null)
                GestureDetector(
                  onTap: onSeeAll,
                  child: const Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xff960ad7),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 244,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: products.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => ProductCard(
              product: products[i],
              width: 152,
              onTap: () => onProductTap?.call(products[i]),
            ),
          ),
        ),
      ],
    );
  }
}
