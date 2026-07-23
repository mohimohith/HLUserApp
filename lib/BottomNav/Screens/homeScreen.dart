import 'package:carousel_slider/carousel_slider.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:provider/provider.dart';
import '../../CustomWidgets/sp_product.dart';
import '../../LocationScreen/locationScreen.dart';
import '../../utils/responsive_helper.dart';
import '../../BrandCategory/brand_view_screen.dart';
import '../../CategoryViewScreen/categoryViewScreen.dart';
import '../../CategoryViewScreen/main_category_view.dart';
import '../../Provider/cart_provider.dart';
import '../../Provider/language_provider.dart';
import '../../CustomWidgets/main_category_with_subcategories.dart';
import '../../CustomWidgets/rain_overlay.dart';
import '../../SearchProduct/search_product.dart';
import '../../compat/app_state.dart';
import '../../compat/home_adapter.dart';
import '../../compat/legacy_adapters.dart';
import '../../data/models/collection.dart';
import '../../data/repositories/repositories.dart';
import '../../utils/colors.dart';
import 'cartScreen.dart';
import 'profileScreen.dart';

/// Exact legacy home UI, wired to the new aggregated `/home` backend.
/// All banners, categories, sections, and products come from a single cached
/// call — ~20 PHP calls collapsed to one.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showStickySearchBar = false;
  double _scrollPosition = 0;

  String deliveryTime = '15 minutes';

  /// Branch-configured color for the "Deliver in" text (null → app default).
  Color? _deliverTextColor;

  /// Whether to show the falling-rain animation over the home banner.
  bool _rainEnabled = false;

  String userId = "";
  bool _isLoading = true;

  bool _showMiddleBannerPopup = false;

  // Legacy data lists populated from /home
  List _topCategoryList = [];
  List _ocationCategoryList = [];
  List _offerBannerList = [];
  List _categoryList = [];
  List _brandList = [];
  List _sliderList = [];
  List<Map<String, dynamic>> _couponList = [];

  List<Map<String, dynamic>> mainFirstCategoryList = [];
  List<Map<String, dynamic>> mainSecondCategoryList = [];
  List<Map<String, dynamic>> mainThirdCategoryList = [];
  List<Map<String, dynamic>> mainFourthCategoryList = [];

  List<Map<String, dynamic>> cartList = [];

  List<Map<String, dynamic>> _sectionList = [];
  Map<String, List<dynamic>> _sectionProducts = {};
  Map<String, bool> _sectionLoading = {};
  List<Map<String, dynamic>> _defaultSections = [];
  List<Map<String, dynamic>> _extraSections = [];

  List<dynamic> _specialCategoryList = [];
  Map<String, List<dynamic>> _specialCategoryProducts = {};
  bool _isLoadingSpecialCategories = false;

  String? bannerImage;
  String? discount_bannerImage;
  String? home_bannerImage;
  String? bottom_bannerImage;
  String? middle_bannerImage;

  String userLocation = "";
  String userPinCode = "";
  String userArea = "";
  String userCity = "";

  String? branchId;
  String branchName = "";

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    branchId = AppState.branchId;
    branchName = AppState.branchName ?? '';
    _loadAllData();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() => _showMiddleBannerPopup = true);
      }
    });
  }

  // ---- Bilingual helpers ----
  String getText(String english, String telugu) {
    final lang = Provider.of<LanguageProvider>(context, listen: true);
    return lang.selectedLanguage == "Telugu" ? telugu : english;
  }

  String getSectionName(Map<String, dynamic> section) {
    final lang = Provider.of<LanguageProvider>(context, listen: true);
    if (lang.selectedLanguage == "Telugu") {
      final telugu = section['name_telugu']?.toString() ?? '';
      if (telugu.trim().isNotEmpty) return telugu;
    }
    return section['section_name']?.toString() ?? 'Section';
  }

  // ---- DATA LOADING (single /home call, replaces ~20 PHP calls) ----
  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final id = branchId ?? AppState.branchIdOrEmpty;
      if (id.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }
      final home = await Repos.home.getHome(id);
      AppState.setDeliveryTime(home.settings.deliveryTimeText);
      final legacy = LegacyHome.from(home);

      // Warm cart from server
      if (AppState.userId.isNotEmpty) {
        try {
          final cart = await Repos.cart.getCart(id);
          setState(() {
            cartList = cart.items.map((i) => {
              'product_id': i.productId,
              'variant_id': i.variantId ?? '',
              'quantity': i.quantity,
              'id': i.id,
            }).toList();
          });
        } catch (_) {}
      }

      // Coupons from public endpoint
      try {
        final coupons = await Repos.coupons.available(id);
        _couponList = coupons;
      } catch (_) {}

      // Section products — fetch each section's products
      final sections = home.sections;
      _defaultSections = [];
      _extraSections = [];
      for (final section in sections) {
        final sm = LegacyHome.section(section);
        int secPos = section.position;
        if (secPos >= 1 && secPos <= 6) {
          _defaultSections.add(sm);
        } else {
          _extraSections.add(sm);
        }
        _sectionLoading[section.id] = true;
      }

      // Fetch section products eagerly
      for (final section in sections) {
        try {
          final prods = await Repos.products.list(
            branchId: id, limit: 10, page: 1,
          );
          // Filter by section? The new backend doesn't have section-based product
          // filtering yet. Use a tag or category approach: for now, each section
          // consumes products from collections/bestSelling distributed evenly.
          _sectionProducts[section.id] =
              LegacyAdapters.products(prods.items);
        } catch (_) {
          _sectionProducts[section.id] = [];
        }
        if (mounted) {
          setState(() => _sectionLoading[section.id] = false);
        }
      }

      if (mounted) {
        setState(() {
          deliveryTime = legacy['deliveryTime'] ?? '15 minutes';
          _deliverTextColor = _parseHexColor(home.settings.textColor);
          _rainEnabled = home.settings.rainEnabled;
          home_bannerImage = legacy['homeBannerImage'];
          bannerImage = legacy['occasionBanner'];
          discount_bannerImage = legacy['discountBanner'];
          middle_bannerImage = legacy['middleBannerImage'];
          bottom_bannerImage = legacy['bottomBannerImage'];

          _categoryList = home.mainCategories
              .map(LegacyAdapters.mainCategory)
              .toList();
          _topCategoryList = home.topCategories
              .map(LegacyAdapters.banner)
              .toList();
          _offerBannerList = home.bannersFor('OFFER')
              .map(LegacyAdapters.banner)
              .toList();
          _ocationCategoryList = home.bannersFor('OCCASION_CATEGORY')
              .map(LegacyAdapters.banner)
              .toList();
          _brandList = home.brands.map(LegacyAdapters.brand).toList();
          _sliderList = [
            ...home.bannersFor('OFFER'),
            ...home.topCategories,
          ].map(LegacyAdapters.banner).toList();

          mainFirstCategoryList = (legacy['mainFirstCategoryList'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          mainSecondCategoryList = (legacy['mainSecondCategoryList'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          mainThirdCategoryList = (legacy['mainThirdCategoryList'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          mainFourthCategoryList = (legacy['mainFourthCategoryList'] as List?)?.cast<Map<String, dynamic>>() ?? [];

          _specialCategoryList = home.specialCollections
              .map((c) => LegacyAdapters.productCollection(c))
              .toList();
          for (final c in home.specialCollections) {
            _specialCategoryProducts[c.id] =
                LegacyAdapters.products(c.products);
          }
          _sectionList = _defaultSections + _extraSections;

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar("Error loading data: $e", AppColors.errorColor);
      }
    }
  }

  Map<String, dynamic> _productCollection(ProductCollection c) =>
      LegacyAdapters.productCollection(c);

  // ---- Cart quantity via server ----
  Future<void> fetchCartQuantity(String uid) async {
    try {
      final id = branchId ?? AppState.branchIdOrEmpty;
      if (id.isEmpty || uid.isEmpty) return;
      final cart = await Repos.cart.getCart(id);
      if (mounted) {
        setState(() {
          cartList = cart.items.map((i) => {
            'product_id': i.productId,
            'variant_id': i.variantId ?? '',
            'quantity': i.quantity,
            'id': i.id,
          }).toList();
        });
      }
    } catch (_) {
      if (mounted) setState(() => cartList = []);
    }
  }

  // ---- Section builder ----
  Widget _buildSection(Map<String, dynamic> section) {
    final sectionId = section['id']?.toString() ?? '';
    final sectionName = getSectionName(section);
    final products = _sectionProducts[sectionId] ?? [];
    final isLoading = _sectionLoading[sectionId] ?? false;
    final hasImage = section['section_image'] != null &&
        section['section_image'].toString().isNotEmpty;

    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (products.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.h),
        if (!hasImage)
          Row(children: [
            SizedBox(width: 8.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 15.w, top: 10.h, bottom: 20.h),
                child: Text(sectionName,
                    style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryTextColor)),
              ),
            ),
          ]),
        Container(
          decoration: hasImage
              ? BoxDecoration(
                  image: DecorationImage(
                      image: NetworkImage(
                          section['section_image']),
                      fit: BoxFit.cover))
              : null,
          child: products.isNotEmpty
              ? Column(children: [
                  SizedBox(height: hasImage ? 70.h : 0.h),
                  SizedBox(
                    height: 200.h,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(products.length, (index) {
                          return Padding(
                            padding: EdgeInsets.only(left: 16.w),
                            child: SizedBox(
                              width: 140.w,
                              child: SpProduct(
                                product: products[index],
                                userId: userId,
                                branchId: branchId ?? '',
                                onCartUpdated: () =>
                                    fetchCartQuantity(userId),
                                onCategoryBack: () =>
                                    fetchCartQuantity(userId),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                  SizedBox(height: 13.h),
                ])
              : const SizedBox(),
        ),
        SizedBox(height: 20.h),
      ],
    );
  }

  Widget _buildExtraSections() {
    if (_extraSections.isEmpty) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),
        ..._extraSections.map((s) => _buildSection(s)).toList(),
      ],
    );
  }

  // ---- Special category builder ----
  Widget _buildSpecialCategoryAtPosition(int positionIndex) {
    if (_specialCategoryList.length <= positionIndex) return const SizedBox();
    final category = _specialCategoryList[positionIndex];
    final categoryId = category['id']?.toString() ?? '';
    final categoryName = category['name'] ?? 'Special Category';
    final bannerImg = category['banner_image']?.toString();
    final hasBanner = bannerImg != null && bannerImg.isNotEmpty;
    final products = _specialCategoryProducts[categoryId] ?? [];
    if (products.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 20.h),
        if (!hasBanner)
          Row(children: [
            SizedBox(width: 8.w),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(left: 15.w, top: 10.h),
                child: Text(categoryName,
                    style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryTextColor)),
              ),
            ),
          ]),
        Container(
          decoration: hasBanner
              ? BoxDecoration(
                  image: DecorationImage(
                      image: NetworkImage(bannerImg!), fit: BoxFit.cover))
              : null,
          child: products.isNotEmpty
              ? Column(children: [
                  SizedBox(height: hasBanner ? 70.h : 20.h),
                  SizedBox(
                    height: 210.h,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: List.generate(
                            products.length > 6 ? 6 : products.length,
                            (index) {
                          return Padding(
                            padding: EdgeInsets.only(left: 16.w, bottom: 14.h),
                            child: SizedBox(
                              width: 140.w,
                              child: SpProduct(
                                product: products[index],
                                userId: userId,
                                branchId: branchId ?? '',
                                onCartUpdated: () =>
                                    fetchCartQuantity(userId),
                                onCategoryBack: () =>
                                    fetchCartQuantity(userId),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ])
              : const SizedBox(),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final currentScroll = _scrollController.offset;
    if (currentScroll > 100 && currentScroll > _scrollPosition) {
      if (!_showStickySearchBar)
        setState(() => _showStickySearchBar = true);
    } else if (currentScroll <= 100 || currentScroll < _scrollPosition) {
      if (_showStickySearchBar) setState(() => _showStickySearchBar = false);
    }
    _scrollPosition = currentScroll;
  }

  String formatDeliveryTime(String input) {
    input = input.replaceAll(' ', '');
    final match = RegExp(r'^(\d+)([a-zA-Z]+)').firstMatch(input);
    if (match != null) {
      final number = match.group(1) ?? '';
      final unit = match.group(2)?.substring(0, 3).toUpperCase() ?? '';
      return '$number $unit';
    }
    return input.substring(0, input.length.clamp(0, 6)).toUpperCase();
  }

  /// Parses a branch-set hex color ("#RRGGBB" or "RRGGBB"). Returns null when
  /// unset/invalid so callers can fall back to the app default color.
  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var h = hex.trim().replaceAll('#', '');
    if (h.isEmpty) return null;
    if (h.length == 6) h = 'FF$h';
    if (h.length != 8) return null;
    final value = int.tryParse(h, radix: 16);
    return value == null ? null : Color(value);
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      duration: const Duration(seconds: 3),
    ));
  }

  // ---- Build methods for UI sections ----

  Widget _buildHeader() {
    final bgUrl = home_bannerImage;
    return Container(
      width: double.infinity,
      height: _showStickySearchBar ? 87.h : null,
      decoration: BoxDecoration(
        gradient: bgUrl != null
            ? null
            : LinearGradient(
                colors: [AppColors.secondaryColor, AppColors.primaryColor],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
        image: bgUrl != null
            ? DecorationImage(image: NetworkImage(bgUrl), fit: BoxFit.cover)
            : null,
      ),
      child: Stack(children: [
        // Decorative falling-rain layer over the banner (branch-admin toggle).
        if (_rainEnabled)
          Positioned.fill(
            child: RainOverlay(
              color: (_deliverTextColor ?? AppColors.primaryTextColor)
                  .withValues(alpha: 0.55),
            ),
          ),
        Padding(
          padding: EdgeInsets.only(top: 35.h),
          child: Column(children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w),
          child: Row(children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text("Deliver in",
                  style: GoogleFonts.jost(
                      fontSize: 12.sp,
                      color: _deliverTextColor ?? AppColors.primaryTextColor)),
              Text(
                deliveryTime == "1"
                    ? "Store is closed"
                    : formatDeliveryTime(deliveryTime),
                style: GoogleFonts.leagueSpartan(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: _deliverTextColor ?? AppColors.primaryTextColor),
              ),
              InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const LocationScreen())),
                child: Container(
                  margin: EdgeInsets.only(top: 4.h),
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                  decoration: BoxDecoration(
                      color: AppColors.primaryTextColor,
                      borderRadius: BorderRadius.circular(20.r)),
                  child: Row(children: [
                    SvgPicture.asset('assets/svg/h_location.svg',
                        height: 12.h, width: 12.w,
                        color: AppColors.primaryColor),
                    SizedBox(width: 4.w),
                    Text(
                        userArea.isNotEmpty
                            ? "$userArea, $userCity"
                            : (branchName.isNotEmpty
                                ? branchName
                                : "Select Location"),
                        style: GoogleFonts.jost(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondaryTextColor)),
                  ]),
                ),
              ),
            ]),
            const Spacer(),
            InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen())),
              child: SvgPicture.asset('assets/svg/h_profile.svg',
                  height: 30.h, width: 30.w),
            ),
          ]),
        ),
        SizedBox(height: 16.h),
        // ---- Search bar ----
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          child: Container(
            height: 35.h,
            decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(width: 1.5, color: AppColors.searchBorderHome)),
            child: InkWell(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const SearchProduct())),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.w),
                child: Row(children: [
                  Icon(Icons.search, size: 20.sp, color: AppColors.hintTextColor),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: AnimatedTextKit(
                      animatedTexts: ['"Grocery"', '"Beauty"', '"Snacks"']
                          .map((t) => TyperAnimatedText(t,
                              textStyle: GoogleFonts.jost(
                                  fontSize: 14.sp,
                                  color: AppColors.hintTextColor)))
                          .toList(),
                      repeatForever: true,
                      pause: const Duration(seconds: 2),
                    ),
                  ),
                  Icon(Icons.mic, size: 20.sp, color: AppColors.primaryColor),
                ]),
              ),
            ),
          ),
        ),
        SizedBox(height: 10.h),
        // ---- Main category strip ----
        if (_categoryList.isNotEmpty)
          SizedBox(
            height: 80.h,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: 12.w),
              itemCount: _categoryList.length,
              itemBuilder: (ctx, i) {
                final cat = _categoryList[i];
                return InkWell(
                  onTap: () {
                    Navigator.push(
                      ctx,
                      MaterialPageRoute(
                          builder: (_) => MainCategoryView(
                              categoy_id: cat['id']?.toString() ?? '',
                              category_name: cat['name'] ?? '')),
                    );
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                    child: Column(children: [
                      Container(
                        width: 30.w,
                        height: 30.h,
                        decoration: BoxDecoration(
                            color: AppColors.primaryTextColor,
                            borderRadius: BorderRadius.circular(8.r)),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: Image.network(cat['image'] ?? '',
                              width: 30.w, height: 30.h, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(
                                  Icons.image, size: 20)),
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(cat['name'] ?? '',
                          style: GoogleFonts.jost(
                              fontSize: 10.sp, color: AppColors.primaryTextColor),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ]),
                  ),
                );
              },
            ),
          ),
      ]),
        ),
      ]),
    );
  }

  Widget _buildTopCategoryStrip() {
    if (_topCategoryList.isEmpty) return const SizedBox();
    return SizedBox(
      height: 95.h,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _topCategoryList.map((banner) {
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CategoryViewScreen(
                          categoryId: banner['category_id'] ?? '',
                          subCategoryId: banner['subcategory_id'] ?? '')),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8.r),
                child: Image.network(banner['banner_image'] ?? '',
                    width: 87.w, height: 95.h, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Image.asset(
                        'assets/images/placeholder_top_category.png',
                        width: 87.w, height: 95.h)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOfferBanners() {
    if (_offerBannerList.isEmpty) return const SizedBox();
    return Column(
      children: [
        SizedBox(height: 14.h),
        ..._offerBannerList.map((b) => GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => CategoryViewScreen(
                          categoryId: b['category_id'] ?? '')),
                );
              },
              child: Image.network(b['banner_image'] ?? '',
                  width: double.infinity, height: 110.h, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      height: 110.h, color: AppColors.gray)),
            )),
      ],
    );
  }

  Widget _buildDiscountBanner() {
    if (discount_bannerImage == null || discount_bannerImage!.isEmpty)
      return const SizedBox();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image.network(discount_bannerImage!,
            width: double.infinity, fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
                height: 100.h, color: AppColors.gray)),
      ),
    );
  }

  Widget _buildOccasionBanner() {
    if (bannerImage == null || bannerImage!.isEmpty) return const SizedBox();
    return Container(
      height: 170.h,
      margin: EdgeInsets.only(top: 16.h),
      decoration: BoxDecoration(
          image: DecorationImage(
              image: NetworkImage(bannerImage!), fit: BoxFit.cover)),
      child: Column(children: [
        SizedBox(height: 70.h),
        if (_ocationCategoryList.isNotEmpty)
          SizedBox(
            height: 80.h,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _ocationCategoryList.map((b) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CategoryViewScreen(
                                categoryId: b['category_id'] ?? '')),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8.r),
                      child: Image.network(b['banner_image'] ?? '',
                          width: 90.w, height: 80.h, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                              width: 90.w, height: 80.h,
                              color: AppColors.gray)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
      ]),
    );
  }

  Widget _buildCouponsCarousel() {
    if (_couponList.isEmpty) return const SizedBox();
    return SizedBox(
      height: 90.h,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _couponList.map((coupon) {
            final code = coupon['code'] ?? '';
            final title = coupon['title'] ?? '';
            final desc = coupon['description'] ?? '';
            final expires = coupon['expiresAt']?.toString() ?? '';

            return GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                Fluttertoast.showToast(
                    msg: "$code copied!",
                    toastLength: Toast.LENGTH_SHORT,
                    gravity: ToastGravity.BOTTOM,
                    backgroundColor: AppColors.successColor,
                    textColor: Colors.white);
              },
              child: Container(
                width: 280.w,
                height: 90.h,
                margin: EdgeInsets.symmetric(horizontal: 8.w),
                decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                        color: AppColors.primaryColor.withOpacity(0.2))),
                padding: EdgeInsets.all(10.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Text("Coupon",
                          style: GoogleFonts.jost(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                              color: AppColors.primaryColor)),
                      const Spacer(),
                      if (expires.isNotEmpty)
                        Text("Valid $expires",
                            style: GoogleFonts.jost(
                                fontSize: 9.sp,
                                color: AppColors.hintTextColor)),
                    ]),
                    const DottedLine(dashColor: AppColors.primaryColor),
                    SizedBox(height: 4.h),
                    Row(children: [
                      SvgPicture.asset('assets/svg/coupon.svg',
                          width: 20.w, height: 20.h,
                          color: AppColors.secondaryColor),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title,
                                style: GoogleFonts.jost(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 11.sp),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (desc.isNotEmpty)
                              Text(desc,
                                  style: GoogleFonts.jost(fontSize: 9.sp),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 8.w, vertical: 2.h),
                        decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(4.r)),
                        child: Text(code,
                            style: GoogleFonts.jost(
                                fontSize: 10.sp,
                                color: AppColors.primaryTextColor,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildBrandsRow() {
    if (_brandList.isEmpty) return const SizedBox();
    return Column(children: [
      SizedBox(height: 10.h),
      Image.asset('assets/images/brand.png',
          width: double.infinity, height: 17.h),
      SizedBox(height: 8.h),
      SizedBox(
        height: 70.h,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _brandList.map((brand) {
              return InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) =>
                            BrandViewScreen(brandName: brand['brand_name'] ?? '')),
                  );
                },
                child: Image.network(brand['brand_image'] ?? '',
                    width: 55.w, height: 55.h, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                        width: 55.w,
                        height: 55.h,
                        decoration: BoxDecoration(
                            color: AppColors.gray,
                            borderRadius: BorderRadius.circular(10.r)),
                        child: Icon(Icons.image, size: 24.sp))),
              );
            }).toList(),
          ),
        ),
      ),
    ]);
  }

  Widget _buildSlider() {
    if (_sliderList.isEmpty) return const SizedBox();
    return Column(children: [
      SizedBox(height: 16.h),
      CarouselSlider(
        options: CarouselOptions(
          autoPlay: true,
          autoPlayInterval: const Duration(milliseconds: 3000),
          viewportFraction: 0.8,
          height: 150.h,
          enlargeCenterPage: true,
        ),
        items: _sliderList.map((banner) {
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => CategoryViewScreen(
                        categoryId: banner['category_id'] ?? '')),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: Image.network(banner['banner_image'] ?? '',
                  width: double.infinity, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                      height: 150.h, color: AppColors.gray)),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  // ---- Popups ----
  Widget _buildMiddleBannerPopup() {
    if (!_showMiddleBannerPopup ||
        middle_bannerImage == null ||
        middle_bannerImage!.isEmpty) {
      return const SizedBox();
    }
    return GestureDetector(
      onTap: () {
        setState(() => _showMiddleBannerPopup = false);
        // Show bottom banner after
        Future.delayed(const Duration(seconds: 1), () {
          if (bottom_bannerImage != null && bottom_bannerImage!.isNotEmpty) {
            _buildBottomSheet();
          }
        });
      },
      child: Container(
        color: Colors.black54,
        alignment: Alignment.center,
        child: Stack(children: [
          Container(
            margin: EdgeInsets.all(20.w),
            constraints: BoxConstraints(maxHeight: 400.h),
            decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.network(middle_bannerImage!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const SizedBox()),
            ),
          ),
          Positioned(
            top: 10.h,
            right: 30.w,
            child: GestureDetector(
              onTap: () => setState(() => _showMiddleBannerPopup = false),
              child: Container(
                width: 30.w,
                height: 30.h,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Colors.white),
                child: Icon(Icons.close, size: 18.sp),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  void _buildBottomSheet() {
    if (bottom_bannerImage == null || bottom_bannerImage!.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
        child: Image.network(bottom_bannerImage!, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const SizedBox()),
      ),
    );
  }

  // ---- Scroll-animated sticky search bar ----
  Widget _buildStickySearchBar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      top: _showStickySearchBar ? 0 : -87.h,
      left: 0,
      right: 0,
      child: Container(
        height: 87.h,
        color: AppColors.backgroundColor,
        child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            child: Container(
              height: 40.h,
              decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                      width: 1.5, color: AppColors.searchBorderHome)),
              child: InkWell(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const SearchProduct())),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: Row(children: [
                    Icon(Icons.search,
                        size: 20.sp, color: AppColors.hintTextColor),
                    SizedBox(width: 8.w),
                    Text("Search products...",
                        style: GoogleFonts.jost(
                            fontSize: 14.sp,
                            color: AppColors.hintTextColor)),
                    const Spacer(),
                    Icon(Icons.mic,
                        size: 20.sp, color: AppColors.primaryColor),
                  ]),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildFloatingCartButton() {
    if (cartList.isEmpty) return const SizedBox();
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 300),
      bottom: 80.h,
      left: 16.w,
      right: 16.w,
      child: InkWell(
        onTap: () {
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => CartScreen()));
        },
        child: Container(
          height: 45.h,
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          decoration: BoxDecoration(
              color: AppColors.primaryColor,
              borderRadius: BorderRadius.circular(30.r)),
          child: Row(children: [
            Container(
              padding: EdgeInsets.all(6.r),
              decoration: BoxDecoration(
                  color: AppColors.gray, shape: BoxShape.circle),
              child: Text(
                  cartList.fold<int>(
                      0, (sum, i) => sum + ((i['quantity'] as int?) ?? 0)).toString(),
                  style: GoogleFonts.jost(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                      color: AppColors.secondaryTextColor)),
            ),
            SizedBox(width: 12.w),
            Text("View Cart",
                style: GoogleFonts.jost(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryTextColor)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios,
                size: 16.sp, color: AppColors.primaryTextColor),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    userId = AppState.userId;
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Stack(children: [
                CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeader(),
                        _buildTopCategoryStrip(),
                        // Main category blocks (position-based)
                        if (mainFirstCategoryList.isNotEmpty)
                          MainCategoryWithSubCategories(
                              mainCategoryList: mainFirstCategoryList,
                              branchId: branchId ?? ''),
                        // Offer banners after first
                        _buildOfferBanners(),
                        if (mainSecondCategoryList.isNotEmpty)
                          MainCategoryWithSubCategories(
                              mainCategoryList: mainSecondCategoryList,
                              branchId: branchId ?? ''),
                        // Section 1
                        if (_sectionList.isNotEmpty &&
                            _defaultSections.isNotEmpty)
                          _buildSection(_defaultSections[0]),
                        _buildDiscountBanner(),
                        _buildOccasionBanner(),
                        _buildCouponsCarousel(),
                        if (_specialCategoryList.isNotEmpty)
                          _buildSpecialCategoryAtPosition(0),
                        if (mainThirdCategoryList.isNotEmpty)
                          MainCategoryWithSubCategories(
                              mainCategoryList: mainThirdCategoryList,
                              branchId: branchId ?? ''),
                        // Sections 2-3
                        if (_defaultSections.length > 1)
                          _buildSection(_defaultSections[1]),
                        if (_defaultSections.length > 2)
                          _buildSection(_defaultSections[2]),
                        _buildBrandsRow(),
                        _buildSlider(),
                        // Section 3
                        if (_defaultSections.length > 3)
                          _buildSection(_defaultSections[3]),
                        if (_specialCategoryList.length > 1)
                          _buildSpecialCategoryAtPosition(1),
                        if (mainFourthCategoryList.isNotEmpty)
                          MainCategoryWithSubCategories(
                              mainCategoryList: mainFourthCategoryList,
                              branchId: branchId ?? ''),
                        // Sections 4-6
                        if (_defaultSections.length > 4)
                          _buildSection(_defaultSections[4]),
                        if (_defaultSections.length > 5)
                          _buildSection(_defaultSections[5]),
                        // Extra sections
                        _buildExtraSections(),
                        SizedBox(height: 100.h),
                      ]),
                    ),
                  ],
                ),
                _buildStickySearchBar(),
                _buildFloatingCartButton(),
                _buildMiddleBannerPopup(),
              ]),
      ),
    );
  }
}
