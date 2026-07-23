import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:provider/provider.dart';
import '../BottomNav/Screens/cartScreen.dart';
import '../CategoryViewScreen/categoryViewScreen.dart';
import '../CustomWidgets/product_card.dart';
import '../Provider/cart_provider.dart';
import '../Provider/language_provider.dart';
import '../SearchProduct/search_product.dart';
import '../SimilarProducts/similar_product.dart';
import '../compat/app_state.dart';
import '../compat/legacy_adapters.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';


class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({Key? key, required this.product})
      : super(key: key);

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  String userEmail = "";
  String userName = "";
  String userID = "";
  int selectedVariantIndex = 0;
  final _pageController = PageController();
  bool _showDetails = false;
  String deliveryTime = '';
  String CATEGORY_ID = "";
  List<Map<String, dynamic>> _couponList = [];
  List products = [];
  bool _isLoadingProducts = false;
  bool isLoading = false;

  String branchId = '';
  String branchName  = "";

  @override
  void initState() {
    super.initState();
    fetchLocation();
    fetchUserData();
    CATEGORY_ID = widget.product['category_id'] ?? '';

  }

  // Helper method to get product name based on selected language
  String getProductName() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    final String englishName = widget.product['name'] ?? '';
    final String teluguName = widget.product['name_telugu'] ?? '';

    if (languageProvider.selectedLanguage == "Telugu" && teluguName.isNotEmpty) {
      return teluguName;
    } else {
      return englishName.isNotEmpty ? englishName : "Product Name";
    }
  }

  // Helper method to get category name based on selected language
  String getCategoryName() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    final String englishCategory = widget.product['category'] ?? '';
    final String teluguCategory = widget.product['category_telugu'] ?? '';

    if (languageProvider.selectedLanguage == "Telugu" && teluguCategory.isNotEmpty) {
      return teluguCategory;
    } else {
      return englishCategory.isNotEmpty ? englishCategory : "Category";
    }
  }

  // Helper method to get subcategory name based on selected language
  String getSubCategoryName() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    final String englishSubCategory = widget.product['subcategory'] ?? '';
    final String teluguSubCategory = widget.product['subcategory_telugu'] ?? '';

    if (languageProvider.selectedLanguage == "Telugu" && teluguSubCategory.isNotEmpty) {
      return teluguSubCategory;
    } else {
      return englishSubCategory.isNotEmpty ? englishSubCategory : "Subcategory";
    }
  }

  // Helper method to get text
  String getText(String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.getText(english, telugu);
  }

  Future<void> fetchLocation() async {
    branchId = AppState.branchIdOrEmpty;
    branchName = AppState.branchName ?? '';
    _fetchCoupons();
    await fetchAllProductsFromCategory();
    deliveryTime = AppState.deliveryTimeText.isNotEmpty ? AppState.deliveryTimeText : '17 MIN';
  }

  Future<void> fetchUserData() async {
    final uid = AppState.userId;
    if (uid.isNotEmpty) {
      setState(() => userID = uid);
      await fetchCartQuantities(uid);
    }
  }

  Future<void> fetchCartQuantities(String userId) async {
    if (userId.isEmpty || branchId.isEmpty) return;
    try {
      final cart = await Repos.cart.getCart(branchId);
      final cp = Provider.of<CartProvider>(context, listen: false);
      cp.clearCart(userId);
      for (final item in cart.items) {
        cp.updateCartQuantities(
            userId, item.productId, item.variantId ?? '',
            item.quantity, item.id);
      }
    } catch (_) {
      Provider.of<CartProvider>(context, listen: false).clearCart(userId);
    }
  }

  Future<void> addToCart() async {
    final variant = widget.product['variants'][selectedVariantIndex];
    final int stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
    if (stock <= 0) {
      Fluttertoast.showToast(
        msg: getText("This product is out of stock!", "ఈ ఉత్పత్తి స్టాక్లో లేదు!"),
        toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red, textColor: Colors.white,
      );
      return;
    }
    setState(() => isLoading = true);
    try {
      final variantId = variant['id'].toString();
      final cp = Provider.of<CartProvider>(context, listen: false);
      final ok = await cp.addItem(
          userId: userID, branchId: branchId,
          productId: widget.product['id'].toString(),
          variantId: variantId);
      if (ok) {
        Fluttertoast.showToast(
          msg: getText("Added to cart!", "కార్ట్‌కి జోడించబడింది!"),
          toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green, textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: getText("Failed to add to cart!", "కార్ట్‌కి జోడించడం విఫలమైంది!"),
          toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red, textColor: Colors.white,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: getText("Something went wrong!", "ఏదో తప్పు జరిగింది!"),
        toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red, textColor: Colors.white,
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> updateQuantity(int newQuantity) async {
    final variant = widget.product['variants'][selectedVariantIndex];
    final variantId = variant['id'].toString();
    final productId = widget.product['id'].toString();
    final stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
    if (newQuantity > stock) {
      Fluttertoast.showToast(
        msg: getText("Only $stock items available in stock", "$stock ఐటమ్లు మాత్రమే స్టాక్‌లో అందుబాటులో ఉన్నాయి"),
        toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
        backgroundColor: AppColors.errorColor, textColor: Colors.white);
      return;
    }
    setState(() => isLoading = true);
    try {
      final cp = Provider.of<CartProvider>(context, listen: false);
      final ok = await cp.changeQuantity(
          userId: userID, branchId: branchId,
          productId: productId, variantId: variantId,
          quantity: newQuantity);
      if (!ok) {
        Fluttertoast.showToast(
          msg: getText("Failed to update quantity", "పరిమాణం నవీకరించడం విఫలమైంది"),
          toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red, textColor: Colors.white);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: getText("Network error. Please try again.", "నెట్‌వర్క్ లోపం. దయచేసి మళ్లీ ప్రయత్నించండి."),
        toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red, textColor: Colors.white);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> removeFromCart() async {
    final variant = widget.product['variants'][selectedVariantIndex];
    final variantId = variant['id'].toString();
    final productId = widget.product['id'].toString();
    setState(() => isLoading = true);
    try {
      final cp = Provider.of<CartProvider>(context, listen: false);
      final ok = await cp.removeItem(
          userId: userID, branchId: branchId,
          productId: productId, variantId: variantId);
      if (ok) {
        Fluttertoast.showToast(
          msg: getText("Removed from cart", "కార్ట్ నుండి తీసివేయబడింది"),
          toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green, textColor: Colors.white);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: getText("Error removing from cart", "కార్ట్ నుండి తీసివేయడంలో లోపం"),
        toastLength: Toast.LENGTH_SHORT, gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red, textColor: Colors.white);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchAllProductsFromCategory() async {
    if (CATEGORY_ID.isEmpty) return;
    setState(() { _isLoadingProducts = true; products = []; });
    try {
      final res = await Repos.products.list(
          branchId: branchId, categoryId: CATEGORY_ID, page: 1, limit: 50);
      if (mounted) setState(() => products = LegacyAdapters.products(res.items));
    } catch (e) {
      debugPrint("Error fetching products: $e");
      if (mounted) setState(() => products = []);
    } finally {
      if (mounted) setState(() => _isLoadingProducts = false);
    }
  }

  Future<void> _fetchCoupons() async {
    try {
      final coupons = await Repos.coupons.available(branchId);
      if (mounted && coupons.isNotEmpty) {
        setState(() => _couponList =
            coupons.map((c) => LegacyAdapters.coupon(c)).toList().cast<Map<String, dynamic>>());
      }
    } catch (e) { debugPrint("Error fetching coupons: $e"); }
  }

  /// Legacy compat — no-op since delivery time comes from AppState.
  Future<void> fetchDeliveryTime() async {
    deliveryTime = AppState.deliveryTimeText.isNotEmpty
        ? AppState.deliveryTimeText
        : '17 MIN';
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }


  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    final productId = widget.product['id'].toString();
    final variantId =
    widget.product['variants'][selectedVariantIndex]['id'].toString();
    final currentQuantity = cartProvider.getQuantity(
      userID,
      productId,
      variantId,
    );

    final List images = widget.product['images'] ?? [];

    // Use helper method to get product name based on language
    final String productName = getProductName();

    final List variants = widget.product['variants'] ?? [];
    final currentVariant = variants[selectedVariantIndex];
    final double price =
        double.tryParse(currentVariant['price']?.toString() ?? '0') ?? 0;
    final int stock =
        int.tryParse(currentVariant['stock']?.toString() ?? '0') ?? 0;
    final double sellingPrice =
        double.tryParse(currentVariant['selling_price']?.toString() ?? '0') ??
            0;
    final int discount =
    price > 0 ? (((price - sellingPrice) / price) * 100).round() : 0;

    final List info = widget.product['info'] ?? [];
    final List highlights = widget.product['highlights'] ?? [];

    final String subCategoryName = getSubCategoryName();
    final String subcategory_id = widget.product['subcategory_id'] ?? '';
    final String category_id = widget.product['category_id'] ?? '';
    final String category_name = getCategoryName();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  height: 350.h,
                  decoration: BoxDecoration(
                      color: const Color(0xffF5F5F5),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(10),
                        bottomRight: Radius.circular(10),
                      )
                  ),
                  child: Stack(
                    children: [
                      // Background Image Section
                      SizedBox(
                        width: double.infinity,
                        height: double.infinity,
                        child: PageView.builder(
                          controller: _pageController,
                          itemCount: images.length,
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16.r),
                              child: Image.network(
                                '${images[index]}',
                                fit: BoxFit.fill, // Changed to cover for full container
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: Icon(
                                      Icons.broken_image,
                                      size: 60.sp,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),

                      // Back Button and Search Button
                      Positioned(
                        top: 40.h,
                        left: 16.w,
                        right: 16.w,
                        child: Row(
                          children: [
                            InkWell(
                              child: Container(
                                width: 35.w,
                                height: 30.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100.r),
                                  color: AppColors.primaryColor,
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: 8.w,
                                      top: 5.h,
                                      bottom: 5.h,
                                    ),
                                    child: Icon(
                                      Icons.arrow_back_ios,
                                      color: AppColors.iconColor,
                                      size: 15.sp,
                                    ),
                                  ),
                                ),
                              ),
                              onTap: () {
                                Navigator.pop(context);
                              },
                            ),
                            const Spacer(),
                            InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => SearchProduct(),
                                  ),
                                );
                                setState(() {
                                  fetchCartQuantities(userID);
                                });
                              },
                              child: Container(
                                width: 35.w,
                                height: 30.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(100.r),
                                  color: AppColors.primaryColor,
                                ),
                                child: Center(
                                  child: Padding(
                                    padding: EdgeInsets.only(
                                      left: 2.w,
                                      top: 5.h,
                                      bottom: 5.h,
                                    ),
                                    child: Icon(
                                      Icons.search,
                                      color: AppColors.iconColor,
                                      size: 15.sp,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Page Indicator
                      Positioned(
                        bottom: 20.h,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: SmoothPageIndicator(
                            controller: _pageController,
                            count: images.length,
                            effect: WormEffect(
                              dotHeight: 7.h,
                              dotWidth: 7.w,
                              activeDotColor: AppColors.primaryColor,
                              dotColor: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20.h),

                Padding(
                  padding:  EdgeInsets.only(left: 15.w,right: 15.w),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundColor,
                      borderRadius: BorderRadius.circular(20.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                            left: 20.w,
                            right: 20.w,
                            top: 10.h,
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  SvgPicture.asset(
                                    'assets/svg/time.svg',
                                    height: 13.h,
                                  ),
                                  Text(
                                    deliveryTime == "1"
                                        ? getText(" close", " మూసివేయండి")
                                        : formatDeliveryTime(deliveryTime).toUpperCase(),
                                    style: GoogleFonts.jost(
                                      fontSize: 10.sp,
                                      color: AppColors.secondaryTextColor,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                  SizedBox(width: 10.w),
                                ],
                              ),
                              SizedBox(height: 7.h),
                              Text(
                                productName,
                                style: GoogleFonts.jost(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.secondaryTextColor,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              SizedBox(height: 5.h),
                              Row(
                                children: [
                                  Text(
                                    '₹${sellingPrice.toStringAsFixed(0)}',
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15.sp,
                                      color: AppColors.secondaryTextColor,
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  if (discount > 0)
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 8.w,
                                        vertical: 2.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondaryColor
                                            .withOpacity(0.3),
                                        borderRadius:
                                        BorderRadius.circular(2.r),
                                      ),
                                      child: Text(
                                        '$discount% ${getText("Off", "ఆఫ్")}',
                                        style: GoogleFonts.jost(
                                          fontSize: 12.sp,
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  SizedBox(height: 10.h),
                                ],
                              ),
                              SizedBox(height: 6.h),
                              if (discount > 0) // ✅ sirf tab dikhega jab discount > 0
                                Row(
                                  children: [
                                    Text(
                                      'MRP',
                                      style: GoogleFonts.jost(
                                        color: AppColors.DisountPriceColor,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      '₹${price.toStringAsFixed(0)}',
                                      style: GoogleFonts.plusJakartaSans(
                                        color: AppColors.DisountPriceColor,
                                        fontSize: 14.sp,
                                        decoration: TextDecoration.lineThrough,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Text(
                                      getText('(Incl. of all taxes)', '(అన్ని పన్నులు చేర్చబడ్డాయి)'),
                                      style: GoogleFonts.jost(
                                        color: AppColors.DisountPriceColor,
                                        fontSize: 14.sp,
                                      ),
                                    ),
                                  ],
                                ),

                              SizedBox(height: 5.h),
                              Text(
                                getText("Select Unit", "యూనిట్ ఎంచుకోండి"),
                                style: GoogleFonts.jost(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(
                                height: 60.h,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  child: ConstrainedBox(
                                    constraints: BoxConstraints(
                                      minWidth: MediaQuery.of(context).size.width,
                                    ),
                                    child: Row(
                                      children: List.generate(variants.length, (index) {
                                        final v = variants[index];
                                        final isSelected = index == selectedVariantIndex;

                                        final double itemPrice =
                                            double.tryParse(v['price']?.toString() ?? '0') ?? 0;
                                        final double itemSellingPrice =
                                            double.tryParse(v['selling_price']?.toString() ?? '0') ?? 0;

                                        final int itemDiscount = itemPrice > 0
                                            ? (((itemPrice - itemSellingPrice) / itemPrice) * 100).round()
                                            : 0;

                                        return Padding(
                                          padding: EdgeInsets.only(right: 12.w),
                                          child: InkWell(
                                            onTap: () {
                                              setState(() {
                                                selectedVariantIndex = index;
                                              });
                                            },
                                            child: Container(
                                              width: 100.w,
                                              height: 55.h,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors: [
                                                    AppColors.secondaryColor,
                                                    AppColors.backgroundColor,
                                                  ],
                                                ),
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(25.r),
                                                  bottomRight: Radius.circular(25.r),
                                                ),
                                                border: Border.all(
                                                  color: AppColors.secondaryColor,
                                                  width: 1.w,
                                                ),
                                              ),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // 🎯 Badge hamesha dikhega
                                                  Padding(
                                                    padding: EdgeInsets.only(left: 12.w, top: 3.h),
                                                    child: Text(
                                                      '$itemDiscount% ${getText("OFF", "ఆఫ్")}',
                                                      style: GoogleFonts.jost(
                                                        color: AppColors.primaryTextColor,
                                                        fontWeight: FontWeight.w400,
                                                        fontSize: 10.sp,
                                                      ),
                                                    ),
                                                  ),

                                                  // Variant details
                                                  Container(
                                                    width: 100.w,
                                                    height: 35.h,
                                                    decoration: BoxDecoration(
                                                      gradient: isSelected
                                                          ? LinearGradient(
                                                        begin: Alignment.centerLeft,
                                                        end: Alignment.centerRight,
                                                        colors: [
                                                          Color(0xffe5d5eb),
                                                          Color(0xffe5d5eb),
                                                        ],
                                                      )
                                                          : null,
                                                      color: isSelected
                                                          ? null
                                                          : AppColors.backgroundColor,
                                                      borderRadius: BorderRadius.only(
                                                        topLeft: Radius.circular(25.r),
                                                        bottomRight: Radius.circular(25.r),
                                                      ),
                                                    ),
                                                    child: Padding(
                                                      padding: EdgeInsets.only(left: 12.w, top: 4.h),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            v['name'] ?? '',
                                                            style: GoogleFonts.jost(
                                                              fontSize: 12.sp,
                                                              fontWeight: FontWeight.w400,
                                                            ),
                                                          ),
                                                          RichText(
                                                            text: TextSpan(
                                                              children: [
                                                                TextSpan(
                                                                  text:
                                                                  '₹${itemSellingPrice.toStringAsFixed(0)} ',
                                                                  style: GoogleFonts.jost(
                                                                    color: Colors.black,
                                                                    fontSize: 12.sp,
                                                                    fontWeight: FontWeight.w600,
                                                                  ),
                                                                ),

                                                                // ✅ LineThrough sirf tab dikhe jab discount > 0
                                                                if (itemDiscount > 0)
                                                                  TextSpan(
                                                                    text: '₹${itemPrice.toStringAsFixed(0)}',
                                                                    style: GoogleFonts.plusJakartaSans(
                                                                      color: Colors.grey,
                                                                      fontSize: 10.sp,
                                                                      decoration:
                                                                      TextDecoration.lineThrough,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 10.h),
                        InkWell(
                          onTap: () {
                            // Check if there are any details to show
                            final hasDetails = highlights.isNotEmpty || info.isNotEmpty;

                            if (hasDetails) {
                              setState(() {
                                _showDetails = !_showDetails;
                              });
                            } else {
                              Fluttertoast.showToast(
                                msg: getText("No details available for this product", "ఈ ఉత్పత్తికి వివరాలు అందుబాటులో లేవు"),
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.grey,
                                textColor: Colors.white,
                              );
                            }
                          },
                          child: Container(
                            width: double.infinity,
                            height: 33.h,
                            decoration: BoxDecoration(
                              color: AppColors.gray,
                              borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(20.r),
                                bottomLeft: Radius.circular(20.r),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  getText("View product details", "ఉత్పత్తి వివరాలను వీక్షించండి"),
                                  style: GoogleFonts.jost(
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13.sp,
                                  ),
                                ),
                                SizedBox(width: 7.w),
                                Icon(
                                  _showDetails
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  size: 22.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: 15.h),
                // Product details section (shown when _showDetails is true)
                if (_showDetails)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Highlights section
                        if (highlights.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 10.h),
                              Text(
                                getText("Highlights", "ముఖ్యాంశాలు"),
                                style: GoogleFonts.jost(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10.h),

                              ...highlights.map(
                                    (item) => Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width:
                                        MediaQuery.of(context).size.width *
                                            0.3, // 30% width for attribute
                                        child: Text(
                                          '${item['attribute']}:',
                                          style: GoogleFonts.jost(
                                            fontSize: 14.sp,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 0.w,
                                      ), // Add some spacing between attribute and value
                                      SizedBox(
                                        width:
                                        MediaQuery.of(context).size.width *
                                            0.7 -
                                            32.w -
                                            8.w, // 70% width minus padding and spacing
                                        child: Text(
                                          item['value'] ?? '',
                                          style: GoogleFonts.jost(
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 15.h),
                            ],
                          ),

                        // Info section
                        if (info.isNotEmpty)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                getText("Product Details", "ఉత్పత్తి వివరాలు"),
                                style: GoogleFonts.jost(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              ...info.map(
                                    (item) => Padding(
                                  padding: EdgeInsets.only(bottom: 8.h),
                                  child: Row(
                                    crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(
                                        width:
                                        MediaQuery.of(context).size.width *
                                            0.3, // 30% width for attribute
                                        child: Text(
                                          '${item['attribute']}:',
                                          style: GoogleFonts.jost(
                                            fontSize: 14.sp,
                                            color: Colors.grey,
                                            fontWeight: FontWeight.w400,
                                          ),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 0.w,
                                      ), // Add some spacing between attribute and value
                                      SizedBox(
                                        width:
                                        MediaQuery.of(context).size.width *
                                            0.7 -
                                            32.w -
                                            8.w, // 70% width minus padding and spacing
                                        child: Text(
                                          item['value'] ?? '',
                                          style: GoogleFonts.jost(
                                            fontSize: 14.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 15.h),
                            ],
                          ),
                      ],
                    ),
                  ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Explore Product
                    Padding(
                      padding: EdgeInsets.only(left: 16.w, right: 16.w),
                      child: InkWell(
                        child: Row(
                          children: [
                            Container(
                              width: 40.h,
                              height: 40.h,
                              decoration: BoxDecoration(
                                color: AppColors.backgroundColor,
                                borderRadius: BorderRadius.circular(5.r),
                                border: Border.all(
                                  color: AppColors.gray,
                                  width: 1.w,
                                ),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(5.r),
                                child: Center(
                                  child: Image.network(
                                    widget.product['images'][0],
                                    width: 35.w,
                                    height: 35.h,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (_, __, ___) =>
                                        Icon(Icons.image, size: 24.sp),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 10.w),
                            Text(
                              getText("Explore all " + subCategoryName + "'s Item", "అన్ని " + subCategoryName + " విషయాలు అన్వేషించండి"),
                              style: GoogleFonts.jost(
                                fontWeight: FontWeight.w500,
                                fontSize: 14.sp,
                              ),
                            ),
                            Spacer(),
                            SvgPicture.asset('assets/svg/forword_icon.svg'),
                            SizedBox(width: 10.w),
                          ],
                        ),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (context) => CategoryViewScreen(
                                categoryId: category_id.toString(),
                                subCategoryId: subcategory_id.toString(),
                                categoryName: category_name,
                                categoryImage: "",
                                branchId: branchId.toString(),
                              ),
                            ),
                          );
                          setState(() {
                            fetchCartQuantities(userID);
                          });
                        },
                      ),
                    ),
                    // Border Line
                    SizedBox(height: 12.h),
                    Padding(
                      padding: EdgeInsets.only(left: 16.w, right: 16.w),
                      child: Container(
                        width: double.infinity,
                        height: 1.h,
                        color: Colors.grey.withOpacity(0.5),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    // Coupons & Offers
                    Padding(
                      padding: EdgeInsets.only(left: 16.w, right: 16.w),
                      child: Text(
                        getText('Coupons & Offers', 'కూపన్లు & ఆఫర్లు'),
                        style: GoogleFonts.jost(
                          fontSize: 15.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),

                    SizedBox(
                      height: 90.h,
                      child: ListView.builder(
                        padding: EdgeInsets.only(left: 12.w),
                        scrollDirection: Axis.horizontal,
                        itemCount: _couponList.length,
                        itemBuilder: (context, index) {
                          final coupon = _couponList[index];

                          final isPrivate = coupon['status'] == "Private";

                          if (isPrivate) {
                            // Agar private hai to skip karna hai
                            return const SizedBox.shrink();
                          }

                          return GestureDetector(
                            onTap: () {
                              // Clipboard copy
                              Clipboard.setData(
                                ClipboardData(text: coupon['code_name']),
                              );

                              // Toast show
                              Fluttertoast.showToast(
                                msg: getText("Coupon code copied!", "కూపన్ కోడ్ కాపీ చేయబడింది!"),
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.black87,
                                textColor: Colors.white,
                                fontSize: 14.sp,
                              );
                            },
                            child: Container(
                              width: 280.w,
                              margin: EdgeInsets.only(right: 8.w),
                              decoration: const BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage(
                                    'assets/images/coupons.png',
                                  ),
                                  fit: BoxFit.fill,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 20.w,
                                      right: 15.w,
                                      top: 6.h,
                                      bottom: 4.h,
                                    ),
                                    child: Row(
                                      children: [
                                        Text(
                                          getText('Coupon', 'కూపన్'),
                                          style: GoogleFonts.jost(
                                            color: AppColors.secondaryColor,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 15.sp,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.backgroundColor,
                                            borderRadius: BorderRadius.circular(
                                              3.r,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10.w,
                                              vertical: 2.h,
                                            ),
                                            child: Center(
                                              child: Text(
                                                getText('Valid ${coupon['expri_date']}', 'చెల్లుబాటు ${coupon['expri_date']}'),
                                                style: GoogleFonts.jost(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 8.w,
                                      right: 6.w,
                                    ),
                                    child: DottedLine(
                                      dashColor: AppColors.secondaryColor,
                                      lineThickness: 1.7,
                                    ),
                                  ),
                                  Padding(
                                    padding: EdgeInsets.only(
                                      left: 25.w,
                                      right: 20.w,
                                      top: 10.h,
                                    ),
                                    child: Row(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/svg/coupon.svg',
                                                  width: 18.w,
                                                  color:
                                                  AppColors.secondaryColor,
                                                ),
                                                SizedBox(width: 4.w),
                                                Text(
                                                  coupon['title'] ?? '',
                                                  style: GoogleFonts.jost(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              coupon['description'] ?? '',
                                              style: GoogleFonts.jost(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const Spacer(),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: AppColors.secondaryColor
                                                .withOpacity(0.3),
                                            borderRadius: BorderRadius.circular(
                                              3.r,
                                            ),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 10.w,
                                              vertical: 2.h,
                                            ),
                                            child: Center(
                                              child: Text(
                                                coupon['code_name'] ?? '',
                                                style: GoogleFonts.jost(
                                                  fontSize: 12.sp,
                                                  color: AppColors.primaryColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    SizedBox(
                      height: 20.h,
                    ),

                    // Best Selling
                    if (products.isNotEmpty)
                      buildSection(getText('Similar products', 'ఇలాంటి ఉత్పత్తులు'), products),
                    // See All Products
                    Transform.translate(
                      offset: Offset(0, -20.h),
                      child: Padding(
                        padding: EdgeInsets.only(left: 16.w, right: 16.w),
                        child: InkWell(
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) => SimilarProduct(
                                  category_id: CATEGORY_ID,
                                  category_name: category_name,
                                ),
                              ),
                            );

                            setState(() {
                              fetchCartQuantities(userID);
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            height: 40.h,
                            decoration: BoxDecoration(
                              color: AppColors.gray,
                              border: Border.all(
                                width: 1.2,
                                color: AppColors.primaryColor,
                              ),
                              borderRadius: BorderRadius.circular(7.r),
                            ),
                            child: Center(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Overlapping Images
                                  SizedBox(
                                    width: (3 * 20) + 28,
                                    child: Stack(
                                      clipBehavior: Clip.none,
                                      children: List.generate(
                                        products.length > 3 ? 3 : products.length,
                                            (index) {
                                          final product = products[index];
                                          return Positioned(
                                            left: index * 20,
                                            child: Padding(
                                              padding: EdgeInsets.only(top: 5.h),
                                              child: Container(
                                                width: 28.h,
                                                height: 28.h,
                                                decoration: BoxDecoration(
                                                  color:
                                                  AppColors.backgroundColor,
                                                  borderRadius:
                                                  BorderRadius.circular(
                                                    100.r,
                                                  ),
                                                  border: Border.all(
                                                    color: Colors.grey
                                                        .withOpacity(0.5),
                                                  ),
                                                ),
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    6.0,
                                                  ),
                                                  child: Image.network(
                                                    product['images'][0],
                                                    width: 27.w,
                                                    height: 27.h,
                                                    fit: BoxFit.contain,
                                                    errorBuilder:
                                                        (_, __, ___) => Icon(
                                                      Icons.image,
                                                      size: 24.sp,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  // Text
                                  Text(
                                    getText("See all Products", "అన్ని ఉత్పత్తులను చూడండి"),
                                    style: GoogleFonts.jost(
                                      fontSize: 16,
                                      color: AppColors.secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  // Arrow Icon
                                  Icon(Icons.double_arrow, size: 16),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 120.h),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              width: double.infinity,
              height: 70.w,
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 2,
                    blurRadius: 2,
                    offset: Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 20.w),
                  if (currentQuantity > 0)
                    Expanded(
                      child: Container(
                        height: 36.h,
                        margin: EdgeInsets.only(right: 8.w),
                        decoration: BoxDecoration(
                          color: AppColors.backgroundColor,
                          borderRadius: BorderRadius.circular(40.r),
                          border: Border.all(
                            color: AppColors.primaryColor,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.remove,
                                size: 18.sp,
                                color: AppColors.secondaryTextColor,
                              ),
                              onPressed: () {
                                if (currentQuantity > 1) {
                                  updateQuantity(currentQuantity - 1);
                                } else {
                                  removeFromCart();
                                }
                              },
                            ),
                            Text(
                              currentQuantity.toString(),
                              style: GoogleFonts.jost(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryTextColor,
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.add,
                                size: 18.sp,
                                color: AppColors.secondaryTextColor,
                              ),
                              onPressed: () {
                                updateQuantity(currentQuantity + 1);
                              },
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          if (userID.isNotEmpty) {
                            final variant =
                            widget
                                .product['variants'][selectedVariantIndex];
                            final int stock =
                                int.tryParse(
                                  variant['stock']?.toString() ?? '0',
                                ) ??
                                    0;

                            if (stock > 0) {
                              addToCart();
                            } else {
                              Fluttertoast.showToast(
                                msg: getText("This product is out of stock!", "ఈ ఉత్పత్తి స్టాక్లో లేదు!"),
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                              );
                            }
                          } else {
                            // Handle case when user is not logged in
                            Fluttertoast.showToast(
                              msg: getText("Please login to add to cart", "కార్ట్‌కి జోడించడానికి దయచేసి లాగిన్ అవ్వండి"),
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                          }
                        },
                        child: Container(
                          height: 36.h,
                          margin: EdgeInsets.only(right: 8.w),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors:
                              stock > 0
                                  ? [
                                AppColors.primaryColor,
                                AppColors.primaryColor,
                              ]
                                  : [Colors.grey, Colors.grey],
                            ),
                            borderRadius: BorderRadius.circular(40.r),
                          ),
                          child: Center(
                            child:
                            isLoading
                                ? SizedBox(
                              width: 20.w,
                              height: 20.w,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                                : Text(
                              stock > 0
                                  ? getText('Add to Cart', 'కార్ట్‌కి జోడించండి')
                                  : getText('Out of Stock', 'స్టాక్ లేదు'),
                              style: GoogleFonts.jost(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primaryTextColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  // ... (previous code remains the same)
                  Expanded(
                    child: InkWell(
                      onTap: () async {
                        if (userID.isNotEmpty) {
                          final variant =
                          widget.product['variants'][selectedVariantIndex];
                          final int stock =
                              int.tryParse(
                                variant['stock']?.toString() ?? '0',
                              ) ??
                                  0;

                          if (stock > 0) {
                            final variantId = variant['id'].toString();
                            final productId = widget.product['id'].toString();

                            // Check if product is already in cart
                            final currentCartQuantity = cartProvider
                                .getQuantity(userID, productId, variantId);

                            if (currentCartQuantity == 0) {
                              // Only add to cart if not already present
                              setState(() {
                                isLoading = true;
                              });

                              try {
                                // Use CartProvider for server-authoritative cart add
                                final cp = Provider.of<CartProvider>(context, listen: false);
                                final ok = await cp.addItem(
                                    userId: userID, branchId: branchId,
                                    productId: productId, variantId: variantId);
                                if (ok) {
                                  Fluttertoast.showToast(
                                    msg: getText("Added to cart!", "కార్ట్‌కి జోడించబడింది!"),
                                    toastLength: Toast.LENGTH_SHORT,
                                    gravity: ToastGravity.BOTTOM,
                                    backgroundColor: Colors.green,
                                    textColor: Colors.white,
                                  );
                                }
                              } catch (e) {
                                print('Error adding to cart: $e');
                                Fluttertoast.showToast(
                                  msg: getText("Failed to add to cart", "కార్ట్‌కి జోడించడం విఫలమైంది"),
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.red,
                                  textColor: Colors.white,
                                );
                              } finally {
                                setState(() {
                                  isLoading = false;
                                });
                              }
                            }

                            // Navigate to cart screen regardless of whether product was just added or already exists
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CartScreen(),
                              ),
                            );

                            setState(() {
                              fetchCartQuantities(userID);
                            });
                          } else {
                            Fluttertoast.showToast(
                              msg: getText("This product is out of stock!", "ఈ ఉత్పత్తి స్టాక్లో లేదు!"),
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                            );
                          }
                        } else {
                          // Handle case when user is not logged in
                          Fluttertoast.showToast(
                            msg: getText("Please login to proceed", "కొనసాగించడానికి దయచేసి లాగిన్ అవ్వండి"),
                            toastLength: Toast.LENGTH_SHORT,
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.red,
                            textColor: Colors.white,
                          );
                        }
                      },
                      child: Container(
                        height: 36.h,
                        margin: EdgeInsets.only(left: 8.w),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: AppColors.primaryColor,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(40.r),
                        ),
                        child: Center(
                          child:
                          isLoading
                              ? SizedBox(
                            width: 20.w,
                            height: 20.w,
                            child: CircularProgressIndicator(
                              color: AppColors.primaryColor,
                              strokeWidth: 2,
                            ),
                          )
                              : Text(
                            getText('Buy Now', 'ఇప్పుడే కొనండి'),
                            style: GoogleFonts.jost(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.secondaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ... (rest of the code remains the same),
                  SizedBox(width: 20.w),
                ],
              ),
            ),
          ),

          if (cartProvider.getTotalCartItems(userID) > 0)
            AnimatedPositioned(
              duration: Duration(milliseconds: 300),
              curve: Curves.slowMiddle,
              bottom: cartProvider.getTotalCartItems(userID) > 0 ? 70.h : -50.h,
              left: 110.w,
              right: 110.w,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 300),
                opacity: cartProvider.getTotalCartItems(userID) > 0 ? 1.0 : 0.0,
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CartScreen()),
                    );
                    setState(() {
                      fetchCartQuantities(userID);
                    });
                  },
                  child: Container(
                    height: 38.h,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: AppColors.gray,
                              borderRadius: BorderRadius.circular(50.r),
                            ),
                            child: Center(
                              child: Text(
                                cartProvider
                                    .getTotalCartItems(userID)
                                    .toString(),
                                style: GoogleFonts.poppins(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                          ),
                          Spacer(),
                          Text(
                            getText("View Cart", "కార్ట్ చూడండి"),
                            style: GoogleFonts.jost(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryTextColor,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.arrow_forward_ios_outlined,
                            color: AppColors.iconColor,
                            size: 16.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String formatDeliveryTime(String input) {
    input = input.replaceAll(' ', '');
    final match = RegExp(r'^(\d+)([a-zA-Z]+)').firstMatch(input);

    if (match != null) {
      final number = match.group(1) ?? '';
      final unit = match.group(2)?.substring(0, 3).toUpperCase() ?? '';
      return '$number $unit';
    } else {
      return input.substring(0, input.length.clamp(0, 6)).toUpperCase();
    }
  }

  Widget buildSection(String title, List<dynamic> list) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 16.w, right: 16.w),
          child: Text(
            title,
            style: GoogleFonts.jost(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -20.h),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: SizedBox(
              height: 530.h,
              child: GridView.builder(
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10.w,
                  mainAxisSpacing: 12.h,
                  childAspectRatio: 0.40,
                ),
                itemCount: list.length > 6 ? 6 : list.length,
                itemBuilder: (context, index) {
                  final product = list[index];
                  return ProductCard(
                    product: product,
                    userId: userID,
                    branchId: branchId.toString(),
                    onCartUpdated: () {
                      fetchCartQuantities(userID);
                    },
                    onCategoryBack: () {
                      setState(() {
                        fetchCartQuantities(userID);
                      });
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}