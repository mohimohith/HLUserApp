import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../core/network/api_exception.dart';
import '../../core/utils/format.dart';
import '../../data/models/product.dart';
import '../../data/repositories/repositories.dart';
import '../cart/cart_controller.dart';

/// Full product page on the new backend: image gallery, variant picker, price,
/// highlights/info, description, wishlist toggle and a sticky add-to-cart bar.
class ProductDetailScreen extends StatefulWidget {
  const ProductDetailScreen({super.key, required this.productId, this.initial});

  /// Product id to load the full record for.
  final String productId;

  /// Optional already-known summary (from a card) for instant first paint.
  final Product? initial;

  static const Color _primary = Color(0xff960ad7);

  /// Convenience navigation helper used by cards, rails and search results.
  static Future<void> open(BuildContext context, Product product) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProductDetailScreen(productId: product.id, initial: product),
      ),
    );
  }

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  Product? _product;
  int _variantIndex = 0;
  int _imageIndex = 0;
  bool _loading = true;
  bool _wished = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _product = widget.initial;
    _loading = widget.initial == null;
    _load();
    _loadWishlist();
  }

  ProductVariant? get _variant {
    final variants = _product?.variants ?? const [];
    if (variants.isEmpty) return null;
    return variants[_variantIndex.clamp(0, variants.length - 1)];
  }

  Future<void> _load() async {
    try {
      final full = await Repos.products.getById(widget.productId);
      if (!mounted) return;
      setState(() {
        _product = full;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_product == null) _error = e.message;
      });
    }
  }

  Future<void> _loadWishlist() async {
    try {
      final wished = await Repos.wishlist.check(widget.productId);
      if (mounted) setState(() => _wished = wished);
    } catch (_) {
      // Wishlist state is non-critical.
    }
  }

  Future<void> _toggleWishlist() async {
    final next = !_wished;
    setState(() => _wished = next);
    try {
      if (next) {
        await Repos.wishlist.add(widget.productId);
      } else {
        await Repos.wishlist.remove(widget.productId);
      }
    } catch (_) {
      if (mounted) setState(() => _wished = !next); // roll back
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = _product;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text('Product',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            onPressed: product == null ? null : _toggleWishlist,
            icon: Icon(
              _wished ? Icons.favorite : Icons.favorite_border,
              color: _wished ? const Color(0xffE53E3E) : Colors.black54,
            ),
          ),
        ],
      ),
      body: _loading && product == null
          ? const Center(
              child: CircularProgressIndicator(color: ProductDetailScreen._primary))
          : product == null
              ? _ErrorBody(message: _error ?? 'Product unavailable', onRetry: _load)
              : _body(product),
      bottomNavigationBar:
          product == null ? null : _AddBar(product: product, variant: _variant),
    );
  }

  Widget _body(Product product) {
    final images = product.images;
    final variant = _variant;
    final highlights = product.attributes.where((a) => a.isHighlight).toList();
    final info = product.attributes.where((a) => !a.isHighlight).toList();

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        // Gallery -----------------------------------------------------------
        SizedBox(
          height: 300,
          child: images.isEmpty
              ? Container(
                  color: const Color(0xffF5F0F8),
                  child: const Icon(Icons.image_outlined,
                      size: 64, color: Color(0xffCBB7DA)),
                )
              : Column(
                  children: [
                    Expanded(
                      child: PageView.builder(
                        itemCount: images.length,
                        onPageChanged: (i) => setState(() => _imageIndex = i),
                        itemBuilder: (_, i) => CachedNetworkImage(
                          imageUrl: images[i].url,
                          fit: BoxFit.contain,
                          placeholder: (_, __) =>
                              Container(color: const Color(0xffF7F2FB)),
                          errorWidget: (_, __, ___) => const Icon(
                              Icons.broken_image_outlined,
                              color: Color(0xffCBB7DA)),
                        ),
                      ),
                    ),
                    if (images.length > 1) ...[
                      const SizedBox(height: 10),
                      AnimatedSmoothIndicator(
                        activeIndex: _imageIndex,
                        count: images.length,
                        effect: const ExpandingDotsEffect(
                          dotHeight: 7,
                          dotWidth: 7,
                          activeDotColor: ProductDetailScreen._primary,
                          dotColor: Color(0xffDCCDE8),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ],
                ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (product.brandName != null)
                Text(product.brandName!.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 11,
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xff960ad7))),
              const SizedBox(height: 4),
              Text(product.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, height: 1.2)),
              if (product.nameTelugu != null && product.nameTelugu!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(product.nameTelugu!,
                    style: const TextStyle(fontSize: 14, color: Color(0xff777777))),
              ],
              const SizedBox(height: 14),

              // Price -------------------------------------------------------
              if (variant != null) _PriceRow(variant: variant),
              const SizedBox(height: 16),

              // Variants ----------------------------------------------------
              if (product.variants.length > 1) ...[
                const Text('Select Pack',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < product.variants.length; i++)
                      _VariantChip(
                        variant: product.variants[i],
                        selected: i == _variantIndex,
                        onTap: () => setState(() => _variantIndex = i),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
              ],

              // Highlights --------------------------------------------------
              if (highlights.isNotEmpty) ...[
                const Text('Highlights',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 8),
                ...highlights.map((a) => _AttrRow(attr: a.attribute, value: a.value)),
                const SizedBox(height: 18),
              ],

              // Description -------------------------------------------------
              if ((product.description ?? '').trim().isNotEmpty) ...[
                const Text('Description',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 8),
                Text(product.description!,
                    style: const TextStyle(
                        fontSize: 13.5, height: 1.5, color: Color(0xff444444))),
                const SizedBox(height: 18),
              ],

              // Info table --------------------------------------------------
              if (info.isNotEmpty) ...[
                const Text('Product Information',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                const SizedBox(height: 8),
                ...info.map((a) => _AttrRow(attr: a.attribute, value: a.value)),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({required this.variant});
  final ProductVariant variant;

  @override
  Widget build(BuildContext context) {
    final hasDiscount = variant.mrp > variant.sellingPrice;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(Money.rupees(variant.sellingPrice),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
        const SizedBox(width: 10),
        if (hasDiscount) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(Money.rupees(variant.mrp),
                style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xff9E9E9E),
                    decoration: TextDecoration.lineThrough)),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: const Color(0xff2E7D32),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text('${variant.discountPercent}% OFF',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700)),
          ),
        ],
        const Spacer(),
        if (!variant.inStock)
          const Text('Out of stock',
              style: TextStyle(
                  color: Color(0xffE53E3E),
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
      ],
    );
  }
}

class _VariantChip extends StatelessWidget {
  const _VariantChip({
    required this.variant,
    required this.selected,
    required this.onTap,
  });
  final ProductVariant variant;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xffF3E9FA) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? const Color(0xff960ad7) : const Color(0xffE0E0E0),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(variant.name,
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: selected ? const Color(0xff960ad7) : Colors.black)),
            Text(Money.rupees(variant.sellingPrice),
                style: const TextStyle(fontSize: 12, color: Color(0xff777777))),
          ],
        ),
      ),
    );
  }
}

class _AttrRow extends StatelessWidget {
  const _AttrRow({required this.attr, required this.value});
  final String attr;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(attr,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xff888888), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xff333333), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Sticky bottom bar: ADD button that becomes a stepper for the selected variant.
class _AddBar extends StatelessWidget {
  const _AddBar({required this.product, required this.variant});
  final Product product;
  final ProductVariant? variant;

  static const Color _primary = Color(0xff960ad7);

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartController>();
    final qty = cart.quantityOf(product.id, variantId: variant?.id);
    final outOfStock = variant != null && !variant!.inStock;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (variant != null)
                  Text(Money.rupees(variant!.sellingPrice),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                Text(variant?.name ?? '',
                    style: const TextStyle(fontSize: 12, color: Color(0xff888888))),
              ],
            ),
            const Spacer(),
            if (outOfStock)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xffF1F1F1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('Out of Stock',
                    style: TextStyle(
                        color: Color(0xff9E9E9E), fontWeight: FontWeight.w700)),
              )
            else if (qty == 0)
              ElevatedButton(
                onPressed: () =>
                    cart.add(product.id, variantId: variant?.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _primary,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add to Cart',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              )
            else
              Container(
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, color: Colors.white),
                      onPressed: () => cart.changeQuantity(product.id,
                          variantId: variant?.id, delta: -1),
                    ),
                    Text('$qty',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16)),
                    IconButton(
                      icon: const Icon(Icons.add, color: Colors.white),
                      onPressed: () => cart.changeQuantity(product.id,
                          variantId: variant?.id, delta: 1),
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

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(0xffB99BD0)),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Color(0xff666666))),
          const SizedBox(height: 16),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
