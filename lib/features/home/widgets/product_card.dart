import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/format.dart';
import '../../../data/models/product.dart';
import '../../cart/cart_controller.dart';

/// A modern product tile: cached image, discount badge, price with strikethrough
/// MRP, and an inline ADD / quantity stepper wired to [CartController].
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.width, this.onTap});

  final Product product;
  final double? width;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final variant = product.defaultVariant;
    final discount = product.discountPercent;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xffEFEFEF)),
          boxShadow: const [
            BoxShadow(color: Color(0x0F000000), blurRadius: 10, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: AspectRatio(
                    aspectRatio: 1.1,
                    child: _Image(url: product.primaryImage),
                  ),
                ),
                if (discount > 0)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xff2E7D32),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$discount% OFF',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
                  ),
                  if (variant != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      variant.name,
                      style: const TextStyle(fontSize: 11, color: Color(0xff8A8A8A)),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(child: _PriceBlock(product: product)),
                      _AddButton(product: product),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        color: const Color(0xffF5F0F8),
        child: const Icon(Icons.image_outlined, color: Color(0xffCBB7DA), size: 36),
      );
    }
    return CachedNetworkImage(
      imageUrl: url!,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: const Color(0xffF5F0F8)),
      errorWidget: (_, __, ___) => Container(
        color: const Color(0xffF5F0F8),
        child: const Icon(Icons.broken_image_outlined, color: Color(0xffCBB7DA)),
      ),
    );
  }
}

class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.product});
  final Product product;

  @override
  Widget build(BuildContext context) {
    final price = product.displayPrice;
    final mrp = product.displayMrp;
    final hasDiscount = mrp > price;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Money.rupees(price),
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        if (hasDiscount)
          Text(
            Money.rupees(mrp),
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xff9E9E9E),
              decoration: TextDecoration.lineThrough,
            ),
          ),
      ],
    );
  }
}

/// ADD button that morphs into a − qty + stepper once the item is in the cart.
class _AddButton extends StatelessWidget {
  const _AddButton({required this.product});
  final Product product;

  static const Color _primary = Color(0xff960ad7);

  @override
  Widget build(BuildContext context) {
    final variant = product.defaultVariant;
    final cart = context.watch<CartController>();
    final qty = cart.quantityOf(product.id, variantId: variant?.id);
    final outOfStock = variant != null && !variant.inStock;

    if (outOfStock) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xffF1F1F1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text(
          'Out',
          style: TextStyle(fontSize: 11, color: Color(0xff9E9E9E), fontWeight: FontWeight.w600),
        ),
      );
    }

    if (qty == 0) {
      return InkWell(
        onTap: () => cart.add(product.id, variantId: variant?.id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _primary),
          ),
          child: const Text(
            'ADD',
            style: TextStyle(fontSize: 12, color: _primary, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: _primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepIcon(
            icon: Icons.remove,
            onTap: () => cart.changeQuantity(product.id, variantId: variant?.id, delta: -1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Text(
              '$qty',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          _StepIcon(
            icon: Icons.add,
            onTap: () => cart.changeQuantity(product.id, variantId: variant?.id, delta: 1),
          ),
        ],
      ),
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Icon(icon, size: 16, color: Colors.white),
      ),
    );
  }
}
