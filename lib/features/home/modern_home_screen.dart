import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

import '../../data/models/banner.dart';
import '../../data/models/catalog.dart';
import '../../data/models/collection.dart';
import '../../data/models/home_data.dart';
import '../catalog/product_browse_screen.dart';
import '../product/product_detail_screen.dart';
import '../profile/profile_screen.dart';
import '../search/search_screen.dart';
import '../cart/cart_controller.dart';
import 'home_controller.dart';
import 'widgets/home_skeleton.dart';
import 'widgets/product_card.dart';

/// The home screen — restyled to match the original NexaMart layout (home-banner
/// header, top-category strip, offer/discount/occasion banners, product rails,
/// brands and the middle/bottom banner popups) while loading everything from the
/// single aggregated `/home` call on the new backend.
class ModernHomeScreen extends StatelessWidget {
  const ModernHomeScreen({super.key});

  static const Color primary = Color(0xff960ad7);

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
  bool _promosShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CartController>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = context.watch<HomeController>();

    // Once the home payload is ready, show the middle-banner popup (and then the
    // bottom-banner sheet) exactly like the old app — but only once per mount.
    if (home.status == HomeStatus.ready && !_promosShown) {
      _promosShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _maybeShowPromos(home.data!);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: _buildBody(context, home),
    );
  }

  Widget _buildBody(BuildContext context, HomeController home) {
    switch (home.status) {
      case HomeStatus.loading:
      case HomeStatus.initial:
        return const SafeArea(child: HomeSkeleton());
      case HomeStatus.error:
        return SafeArea(child: _ErrorState(message: home.error, onRetry: home.refresh));
      case HomeStatus.ready:
        return _Content(data: home.data!, onRefresh: home.refresh);
    }
  }

  Future<void> _maybeShowPromos(HomeData data) async {
    final middle = data.bannersFor('MIDDLE');
    final bottom = data.bannersFor('BOTTOM');

    if (middle.isNotEmpty) {
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withOpacity(0.55),
        builder: (_) => _PromoDialog(imageUrl: middle.first.imageUrl),
      );
    }

    if (bottom.isNotEmpty) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!mounted) return;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => _PromoSheet(imageUrl: bottom.first.imageUrl),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Main scrollable content
// ---------------------------------------------------------------------------

class _Content extends StatelessWidget {
  const _Content({required this.data, required this.onRefresh});

  final HomeData data;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final offers = data.bannersFor('OFFER');
    final discount = data.bannersFor('DISCOUNT');
    final occasion = data.bannersFor('OCCASION');
    final occasionCats = data.bannersFor('OCCASION_CATEGORY');
    final rails = data.specialCollections;

    return RefreshIndicator(
      color: ModernHomeScreen.primary,
      onRefresh: onRefresh,
      child: CustomScrollView(
        slivers: [
          // Header (home-banner background: location, search, categories, top cats)
          SliverToBoxAdapter(child: _Header(data: data)),

          // First product rail
          if (rails.isNotEmpty)
            SliverToBoxAdapter(child: _CollectionRail(collection: rails.first)),

          // Offer banners
          for (final b in offers)
            SliverToBoxAdapter(child: _FullWidthBanner(banner: b, height: 110)),

          // Best sellers
          if (data.bestSelling.isNotEmpty)
            SliverToBoxAdapter(
              child: _ProductRail(
                title: 'Best Sellers',
                products: data.bestSelling,
              ),
            ),

          // Discount banner
          if (discount.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                child: _BannerImage(
                  url: discount.first.imageUrl,
                  onTap: () => _openBanner(context, discount.first),
                ),
              ),
            ),

          // Remaining collection rails
          for (final c in rails.skip(1))
            SliverToBoxAdapter(child: _CollectionRail(collection: c)),

          // Occasion banner with its category strip
          if (occasion.isNotEmpty)
            SliverToBoxAdapter(
              child: _OccasionBanner(
                banner: occasion.first,
                categories: occasionCats,
              ),
            ),

          // Brands
          if (data.brands.isNotEmpty)
            SliverToBoxAdapter(child: _BrandsRow(brands: data.brands)),

          SliverToBoxAdapter(child: SizedBox(height: 24.h)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Header — home banner background + location/search/categories/top-categories
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.data});
  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final homeBanner = data.bannersFor('HOME');
    final hasBanner = homeBanner.isNotEmpty;
    final deliveryText = data.settings.deliveryTimeText;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        // Fall back to the brand gradient when no home banner is configured so
        // the white header text stays legible.
        gradient: hasBanner
            ? null
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xff960ad7), Color(0xff7111a1)],
              ),
        image: hasBanner
            ? DecorationImage(
                image: CachedNetworkImageProvider(homeBanner.first.imageUrl),
                fit: BoxFit.fill,
              )
            : null,
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.only(top: 38.h, left: 20.w, right: 20.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Deliver in',
                      style: GoogleFonts.jost(
                        color: Colors.white,
                        fontWeight: FontWeight.w400,
                        fontSize: 12.sp,
                      ),
                    ),
                    Text(
                      deliveryText,
                      style: GoogleFonts.leagueSpartan(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                        child: Row(
                          children: [
                            SvgPicture.asset('assets/svg/h_location.svg',
                                height: 10.h),
                            SizedBox(width: 4.w),
                            Text(
                              data.branchName ?? 'Select store',
                              style: GoogleFonts.jost(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.only(top: 20.h),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileScreen()),
                    ),
                    child: SvgPicture.asset('assets/svg/h_profile.svg',
                        width: 20.w, height: 20.h),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 8.h),
          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20.w),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              ),
              child: Container(
                width: double.infinity,
                height: 38.h,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                      color: ModernHomeScreen.primary, width: 1.5),
                ),
                child: Padding(
                  padding:
                      EdgeInsets.symmetric(vertical: 4.h, horizontal: 10.w),
                  child: Row(
                    children: [
                      Icon(Icons.search,
                          size: 22.sp, color: const Color(0xff4B4A4A)),
                      SizedBox(width: 6.w),
                      Text('Search ',
                          style: GoogleFonts.jost(
                              fontSize: 14.sp, fontWeight: FontWeight.w500)),
                      SizedBox(
                        width: 90.w,
                        child: AnimatedTextKit(
                          repeatForever: true,
                          pause: const Duration(milliseconds: 2000),
                          animatedTexts: [
                            for (final w in const ['"Grocery"', '"Beauty"', '"Snacks"'])
                              TyperAnimatedText(
                                w,
                                textStyle: GoogleFonts.jost(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.w500),
                                speed: const Duration(milliseconds: 80),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.mic,
                          size: 19.sp, color: const Color(0xff4B4A4A)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),
          // Main category strip (small icons)
          if (data.mainCategories.isNotEmpty)
            SizedBox(
              height: 80.h,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Row(
                  children: [
                    for (final c in data.mainCategories)
                      _MainCategoryIcon(category: c),
                  ],
                ),
              ),
            ),
          SizedBox(height: 18.h),
          // Top categories (banner tiles)
          if (data.topCategories.isNotEmpty)
            SizedBox(
              height: 95.h,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final b in data.topCategories)
                      Padding(
                        padding: EdgeInsets.only(left: 16.w),
                        child: GestureDetector(
                          onTap: () => _openBanner(context, b),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: CachedNetworkImage(
                              imageUrl: b.imageUrl,
                              width: 87.w,
                              height: 95.h,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Image.asset(
                                'assets/images/placeholder_top_category.png',
                                width: 87.w,
                                height: 95.h,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          SizedBox(height: 18.h),
        ],
      ),
    );
  }
}

class _MainCategoryIcon extends StatelessWidget {
  const _MainCategoryIcon({required this.category});
  final MainCategory category;

  @override
  Widget build(BuildContext context) {
    final parts = category.name.split(' ');
    return GestureDetector(
      onTap: () => ProductBrowseScreen.openMainCategory(context, category),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.w),
        child: Column(
          children: [
            SizedBox(
              width: 30.w,
              height: 30.h,
              child: (category.image != null && category.image!.isNotEmpty)
                  ? CachedNetworkImage(
                      imageUrl: category.image!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Image.asset(
                          'assets/images/placeholder_category.png',
                          fit: BoxFit.cover),
                    )
                  : Image.asset('assets/images/placeholder_category.png',
                      fit: BoxFit.cover),
            ),
            SizedBox(height: 5.h),
            SizedBox(
              width: 56.w,
              child: Column(
                children: [
                  if (parts.length > 1) ...[
                    Text(
                      parts.sublist(0, parts.length - 1).join(' '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jost(
                          fontSize: 8.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w500),
                    ),
                    Text(
                      parts.last,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jost(
                          fontSize: 8.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w500),
                    ),
                  ] else
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jost(
                          fontSize: 8.sp,
                          color: Colors.white,
                          fontWeight: FontWeight.w500),
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

// ---------------------------------------------------------------------------
// Rails & banners
// ---------------------------------------------------------------------------

/// A product rail backed by a [ProductCollection], with the collection image as
/// a background banner (mirrors the old "section" rails).
class _CollectionRail extends StatelessWidget {
  const _CollectionRail({required this.collection});
  final ProductCollection collection;

  @override
  Widget build(BuildContext context) {
    if (collection.products.isEmpty) return const SizedBox.shrink();
    final hasImage = collection.image != null && collection.image!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.h),
        if (!hasImage)
          Padding(
            padding: EdgeInsets.only(left: 16.w, bottom: 12.h),
            child: Text(
              collection.name,
              style: GoogleFonts.poppins(
                  fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
          ),
        Container(
          decoration: hasImage
              ? BoxDecoration(
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(collection.image!),
                    fit: BoxFit.cover,
                  ),
                )
              : null,
          child: Column(
            children: [
              SizedBox(height: hasImage ? 70.h : 0),
              SizedBox(
                height: 244.h,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: collection.products.length,
                  separatorBuilder: (_, __) => SizedBox(width: 12.w),
                  itemBuilder: (_, i) => SizedBox(
                    width: 152.w,
                    child: ProductCard(
                      product: collection.products[i],
                      onTap: () => ProductDetailScreen.open(
                          context, collection.products[i]),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 13.h),
            ],
          ),
        ),
      ],
    );
  }
}

/// A plain titled product rail (best sellers).
class _ProductRail extends StatelessWidget {
  const _ProductRail({required this.title, required this.products});
  final String title;
  final List products;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.h),
        Padding(
          padding: EdgeInsets.only(left: 16.w, bottom: 12.h),
          child: Text(title,
              style: GoogleFonts.poppins(
                  fontSize: 16.sp, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 244.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: products.length,
            separatorBuilder: (_, __) => SizedBox(width: 12.w),
            itemBuilder: (_, i) => SizedBox(
              width: 152.w,
              child: ProductCard(
                product: products[i],
                onTap: () => ProductDetailScreen.open(context, products[i]),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FullWidthBanner extends StatelessWidget {
  const _FullWidthBanner({required this.banner, required this.height});
  final AppBanner banner;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: GestureDetector(
        onTap: () => _openBanner(context, banner),
        child: CachedNetworkImage(
          imageUrl: banner.imageUrl,
          width: double.infinity,
          height: height.h,
          fit: BoxFit.fill,
          errorWidget: (_, __, ___) => Container(
            width: double.infinity,
            height: height.h,
            color: Colors.grey[200],
            child: Icon(Icons.broken_image, size: 40.sp, color: Colors.grey),
          ),
        ),
      ),
    );
  }
}

class _BannerImage extends StatelessWidget {
  const _BannerImage({required this.url, this.onTap});
  final String url;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: CachedNetworkImage(
        imageUrl: url,
        width: double.infinity,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => const SizedBox.shrink(),
      ),
    );
  }
}

class _OccasionBanner extends StatelessWidget {
  const _OccasionBanner({required this.banner, required this.categories});
  final AppBanner banner;
  final List<AppBanner> categories;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 170.h,
      width: double.infinity,
      margin: EdgeInsets.only(top: 15.h),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: CachedNetworkImageProvider(banner.imageUrl),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 70.h),
          if (categories.isNotEmpty)
            SizedBox(
              height: 80.h,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final c in categories)
                      Padding(
                        padding: EdgeInsets.only(left: 17.w),
                        child: GestureDetector(
                          onTap: () => _openBanner(context, c),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: CachedNetworkImage(
                              imageUrl: c.imageUrl,
                              width: 90.w,
                              height: 80.h,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  const Icon(Icons.broken_image, size: 60),
                            ),
                          ),
                        ),
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

class _BrandsRow extends StatelessWidget {
  const _BrandsRow({required this.brands});
  final List<Brand> brands;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.h),
        Padding(
          padding: EdgeInsets.only(left: 16.w, bottom: 12.h),
          child: Text('Shop by Brand',
              style: GoogleFonts.poppins(
                  fontSize: 16.sp, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 84.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: brands.length,
            separatorBuilder: (_, __) => SizedBox(width: 12.w),
            itemBuilder: (_, i) {
              final b = brands[i];
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductBrowseScreen(title: b.name, brandId: b.id),
                  ),
                ),
                child: Container(
                  width: 84.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: const Color(0xffEFEFEF)),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (b.image != null && b.image!.isNotEmpty)
                      ? CachedNetworkImage(
                          imageUrl: b.image!,
                          fit: BoxFit.contain,
                          errorWidget: (_, __, ___) => Center(
                            child: Text(b.name,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: GoogleFonts.jost(fontSize: 11.sp)),
                          ),
                        )
                      : Center(
                          child: Text(b.name,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: GoogleFonts.jost(fontSize: 11.sp)),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Promo popups (middle banner dialog + bottom banner sheet)
// ---------------------------------------------------------------------------

/// Whether a banner media URL points at a video clip (by extension).
bool _isVideoUrl(String url) {
  final lower = url.toLowerCase();
  return lower.endsWith('.mp4') || lower.endsWith('.webm');
}

class _PromoDialog extends StatelessWidget {
  const _PromoDialog({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.topRight,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                margin: EdgeInsets.only(bottom: 8.h),
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.black),
              ),
            ),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(16.r),
            // Videos autoplay muted + looping; GIFs/images animate via
            // CachedNetworkImage.
            child: _isVideoUrl(imageUrl)
                ? _PromoVideo(url: imageUrl)
                : CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Auto-playing, looping, muted video for the middle-banner advertisement popup.
class _PromoVideo extends StatefulWidget {
  const _PromoVideo({required this.url});
  final String url;

  @override
  State<_PromoVideo> createState() => _PromoVideoState();
}

class _PromoVideoState extends State<_PromoVideo> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller = controller;
    controller
        .initialize()
        .then((_) {
          if (!mounted) return;
          controller
            ..setLooping(true)
            ..setVolume(0)
            ..play();
          setState(() => _ready = true);
        })
        .catchError((_) {
          if (!mounted) return;
          setState(() => _failed = true);
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return const SizedBox.shrink();
    final controller = _controller;
    if (!_ready || controller == null) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return AspectRatio(
      aspectRatio: controller.value.aspectRatio == 0
          ? 16 / 9
          : controller.value.aspectRatio,
      child: VideoPlayer(controller),
    );
  }
}

class _PromoSheet extends StatelessWidget {
  const _PromoSheet({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 180.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.fill,
                width: double.infinity,
                height: double.infinity,
                errorWidget: (_, __, ___) => Center(
                  child: Icon(Icons.error, size: 50.sp, color: Colors.grey),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Navigate from a tapped banner/top-category to the relevant product list.
void _openBanner(BuildContext context, AppBanner banner) {
  final title = banner.title ?? banner.sectionName ?? 'Products';
  if (banner.subCategoryId != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductBrowseScreen(title: title, subCategoryId: banner.subCategoryId),
      ),
    );
  } else if (banner.categoryId != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ProductBrowseScreen(title: title, categoryId: banner.categoryId),
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
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xff555555))),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: ModernHomeScreen.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
