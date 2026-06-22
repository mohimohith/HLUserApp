import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/banner.dart';
import '../../data/models/home_data.dart';
import '../catalog/product_browse_screen.dart';
import '../product/product_detail_screen.dart';
import '../search/search_screen.dart';
import '../cart/cart_controller.dart';
import 'home_controller.dart';
import 'widgets/category_strip.dart';
import 'widgets/hero_carousel.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/product_rail.dart';

/// The new, fast homepage. Loads the entire page from a single `/home` call,
/// shows a shaped shimmer on first load, and renders banners, categories,
/// best-sellers and merchandised collections from typed models.
class ModernHomeScreen extends StatelessWidget {
  const ModernHomeScreen({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeController()..load(),
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  @override
  void initState() {
    super.initState();
    // Sync the cart for the resolved branch once the first frame settles.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _buildBody(context, home),
      ),
    );
  }

  Widget _buildBody(BuildContext context, HomeController home) {
    switch (home.status) {
      case HomeStatus.loading:
      case HomeStatus.initial:
        return const HomeSkeleton();
      case HomeStatus.error:
        return _ErrorState(message: home.error, onRetry: home.refresh);
      case HomeStatus.ready:
        return _Content(data: home.data!, onRefresh: home.refresh);
    }
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.data, required this.onRefresh});

  final HomeData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final specials = data.specialCollections;

    return RefreshIndicator(
      color: ModernHomeScreen._primary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _Header(branchName: data.branchName)),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
          if (data.heroBanners.isNotEmpty)
            SliverToBoxAdapter(
              child: HeroCarousel(
                banners: data.heroBanners,
                onTap: (b) => _openBanner(context, b),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          if (data.mainCategories.isNotEmpty) ...[
            const SliverToBoxAdapter(child: _SectionTitle('Shop by Category')),
            SliverToBoxAdapter(
              child: CategoryStrip(
                categories: data.mainCategories,
                onTap: (c) => ProductBrowseScreen.openMainCategory(context, c),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
          if (data.bestSelling.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: ProductRail(
                title: 'Best Sellers',
                products: data.bestSelling,
                onProductTap: (p) => ProductDetailScreen.open(context, p),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
          for (final c in specials) ...[
            SliverToBoxAdapter(
              child: ProductRail(
                title: c.name,
                products: c.products,
                onProductTap: (p) => ProductDetailScreen.open(context, p),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 20)),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 24)),
        ],
      ),
    );
  }
}

/// Deep-link a tapped hero banner to the relevant product list. Banners that
/// don't reference a category are treated as decorative (no-op).
void _openBanner(BuildContext context, AppBanner banner) {
  final title = banner.title ?? banner.sectionName ?? 'Offers';
  if (banner.subCategoryId != null) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ProductBrowseScreen(title: title, subCategoryId: banner.subCategoryId),
    ));
  } else if (banner.categoryId != null) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          ProductBrowseScreen(title: title, categoryId: banner.categoryId),
    ));
  }
}

class _Header extends StatelessWidget {
  const _Header({this.branchName});
  final String? branchName;

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartController>().totalItems;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: ModernHomeScreen._primary, size: 20),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  branchName ?? 'Select your store',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
              ),
              _CartBadge(count: cartCount),
            ],
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchScreen()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xffF6F2FA),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xffEADBF2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.search, color: Color(0xff8A8A8A), size: 20),
                  SizedBox(width: 10),
                  Text(
                    'Search for groceries, fruits & more',
                    style: TextStyle(color: Color(0xff8A8A8A), fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CartBadge extends StatelessWidget {
  const _CartBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xffF6F2FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.shopping_cart_outlined,
              color: ModernHomeScreen._primary, size: 22),
        ),
        if (count > 0)
          Positioned(
            right: -2,
            top: -4,
            child: Container(
              padding: const EdgeInsets.all(4),
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              decoration: const BoxDecoration(
                color: Color(0xffE53E3E),
                shape: BoxShape.circle,
              ),
              child: Text(
                '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Text(
        text,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 56, color: Color(0xffB99BD0)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: Color(0xff555555)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernHomeScreen._primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
