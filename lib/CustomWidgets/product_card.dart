import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../ProductDetailScreen/product_details_screen.dart';
import '../compat/app_state.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';
import '../utils/responsive_helper.dart';
import '../Provider/cart_provider.dart';
import '../Provider/language_provider.dart';

/// Product tile — exact legacy visual tree, wired to the new backend:
/// cart through [CartProvider] (server-authoritative), wishlist through
/// [Repos.wishlist], delivery time from [AppState], and ABSOLUTE image URLs.
class ProductCard extends StatefulWidget {
  final Map<String, dynamic> product;
  final String userId;
  final String branchId;
  final VoidCallback? onCartUpdated;
  final VoidCallback? onWishlistUpdated;
  final VoidCallback? onCategoryBack;

  const ProductCard({
    Key? key,
    required this.product,
    this.userId = '',
    this.branchId = '',
    this.onCartUpdated,
    this.onWishlistUpdated,
    this.onCategoryBack,
  }) : super(key: key);

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  String deliveryTime = '17 MIN';
  bool isLoading = false;
  bool isWishlisted = false;
  bool isWishlistLoading = false;

  String get _userId => widget.userId.isNotEmpty ? widget.userId : AppState.userId;
  String get _branchId =>
      widget.branchId.isNotEmpty ? widget.branchId : AppState.branchIdOrEmpty;

  @override
  void initState() {
    super.initState();
    deliveryTime =
        AppState.deliveryTimeText.isNotEmpty ? AppState.deliveryTimeText : '17 MIN';
    checkWishlistStatus();
  }

  String getProductName(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final String englishName = widget.product['name'] ?? '';
    final String teluguName = widget.product['name_telugu'] ?? '';
    if (languageProvider.selectedLanguage == "Telugu" && teluguName.isNotEmpty) {
      return teluguName;
    } else {
      return englishName.isNotEmpty ? englishName : "Product Name";
    }
  }

  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  Future<void> checkWishlistStatus() async {
    if (_userId.isEmpty) return;
    setState(() => isWishlistLoading = true);
    try {
      final inList = await Repos.wishlist.check(widget.product['id'].toString());
      if (mounted) setState(() => isWishlisted = inList);
    } catch (e) {
      debugPrint('Error checking wishlist status: $e');
    } finally {
      if (mounted) setState(() => isWishlistLoading = false);
    }
  }

  Future<void> toggleWishlist(BuildContext context) async {
    if (_userId.isEmpty) {
      Fluttertoast.showToast(
        msg: getText(context, "Please login to add to wishlist",
            "విష్లిస్ట్‌కి జోడించడానికి దయచేసి లాగిన్ అవ్వండి"),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() => isWishlistLoading = true);
    try {
      final productId = widget.product['id'].toString();
      if (isWishlisted) {
        await Repos.wishlist.remove(productId);
      } else {
        await Repos.wishlist.add(productId);
      }
      setState(() => isWishlisted = !isWishlisted);
      widget.onWishlistUpdated?.call();
      Fluttertoast.showToast(
        msg: isWishlisted
            ? getText(context, "Added to wishlist", "విష్లిస్ట్‌కి జోడించబడింది")
            : getText(context, "Removed from wishlist", "విష్లిస్ట్ నుండి తీసివేయబడింది"),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: isWishlisted ? Colors.green : Colors.orange,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
      Fluttertoast.showToast(
        msg: getText(context, "Something went wrong", "ఏదో తప్పు జరిగింది"),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) setState(() => isWishlistLoading = false);
    }
  }

  void _showToastMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.errorColor,
      ),
    );
  }

  Future<void> addToCart(BuildContext context, String variantId, String imageUrl) async {
    setState(() => isLoading = true);
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final ok = await cartProvider.addItem(
        userId: _userId,
        branchId: _branchId,
        productId: widget.product['id'].toString(),
        variantId: variantId,
      );
      if (ok) {
        widget.onCartUpdated?.call();
        Fluttertoast.showToast(
          msg: getText(context, "Added to cart", "కార్ట్‌కి జోడించబడింది"),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: getText(context, "Failed to add to cart", "కార్ట్‌కి జోడించడం విఫలమైంది"),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> updateQuantity(BuildContext context, String variantId, int newQuantity) async {
    setState(() => isLoading = true);
    try {
      final variants = widget.product['variants'] as List<dynamic>;
      final variant = variants.cast<Map<String, dynamic>>().firstWhere(
        (v) => (v['id'] ?? '').toString() == variantId,
        orElse: () => <String, dynamic>{},
      );
      if (variant.isNotEmpty) {
        final stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
        if (newQuantity > stock) {
          _showToastMessage(
            context,
            getText(context, 'Only $stock items available in stock',
                '$stock ఐటమ్లు మాత్రమే స్టాక్‌లో అందుబాటులో ఉన్నాయి'),
          );
          return;
        }
      }

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final ok = await cartProvider.changeQuantity(
        userId: _userId,
        branchId: _branchId,
        productId: widget.product['id'].toString(),
        variantId: variantId,
        quantity: newQuantity,
      );
      if (ok) {
        widget.onCartUpdated?.call();
      } else {
        Fluttertoast.showToast(
          msg: getText(context, "Failed to update quantity", "పరిమాణం నవీకరించడం విఫలమైంది"),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> removeFromCart(BuildContext context, String variantId) async {
    setState(() => isLoading = true);
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final ok = await cartProvider.removeItem(
        userId: _userId,
        branchId: _branchId,
        productId: widget.product['id'].toString(),
        variantId: variantId,
      );
      if (ok) {
        widget.onCartUpdated?.call();
        Fluttertoast.showToast(
          msg: getText(context, "Removed from cart", "కార్ట్ నుండి తీసివేయబడింది"),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      }
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  String _imageOf(Map<String, dynamic> product) {
    final images = product['images'];
    if (images is List && images.isNotEmpty) return images[0].toString();
    return (product['image'] ?? '').toString();
  }

  void _showVariantBottomSheet(BuildContext context, List variants) {
    final productName = getProductName(context);
    final productImage = _imageOf(widget.product);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final cartProvider = Provider.of<CartProvider>(context);

              void localAddToCart(String variantId) async {
                await addToCart(context, variantId, productImage);
                setModalState(() {});
              }

              void localUpdateQuantity(String variantId, int newQty) async {
                await updateQuantity(context, variantId, newQty);
                setModalState(() {});
              }

              void localRemoveFromCart(String variantId) async {
                await removeFromCart(context, variantId);
                setModalState(() {});
              }

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 15.w),
                      child: Text(
                        productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jost(
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryTextColor,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Flexible(
                      fit: FlexFit.loose,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: const ClampingScrollPhysics(),
                        itemCount: variants.length,
                        itemBuilder: (context, index) {
                          final variant = variants[index];
                          final variantName = variant['name'] ?? 'N/A';
                          final variantPrice =
                              double.tryParse(variant['price']?.toString() ?? '0') ?? 0;
                          final stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
                          final variantSellingPrice =
                              double.tryParse(variant['selling_price']?.toString() ?? '0') ?? 0;
                          final discountPercentage = variantPrice > 0
                              ? ((variantPrice - variantSellingPrice) / variantPrice * 100).round()
                              : 0;
                          final variantId = variant['id']?.toString() ?? '';
                          final quantity = cartProvider.getQuantity(
                            _userId,
                            widget.product['id'].toString(),
                            variantId,
                          );
                          final isOutOfStock = stock <= 0;

                          return Padding(
                            padding: EdgeInsets.only(left: 10.w, right: 10.w),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 10.h),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              padding: EdgeInsets.all(8.w),
                              child: Stack(
                                children: [
                                  Row(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 50.h,
                                            height: 50.h,
                                            decoration: BoxDecoration(
                                              color: AppColors.backgroundColor,
                                              borderRadius: BorderRadius.circular(10.r),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 0.1,
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12.r),
                                              child: Center(
                                                child: Image.network(
                                                  productImage,
                                                  width: ResponsiveHelper.getResponsiveWidth(context,
                                                      mobile: 40.w, tablet: 50.w, desktop: 60.w),
                                                  height: ResponsiveHelper.getResponsiveHeight(context,
                                                      mobile: 40.h, tablet: 50.h, desktop: 60.h),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) => Icon(Icons.image,
                                                      size: ResponsiveHelper.getResponsiveFontSize(
                                                          context,
                                                          mobile: 24.sp,
                                                          tablet: 28.sp,
                                                          desktop: 32.sp)),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondaryColor,
                                                borderRadius: BorderRadius.only(
                                                  bottomRight: Radius.circular(10.r),
                                                  topLeft: Radius.circular(10.r),
                                                ),
                                              ),
                                              child: Text(
                                                '$discountPercentage%\n${getText(context, "OFF", "ఆఫ్")}',
                                                style: GoogleFonts.jost(
                                                  fontSize: ResponsiveHelper.getResponsiveFontSize(
                                                      context,
                                                      mobile: 5.sp,
                                                      tablet: 6.sp,
                                                      desktop: 7.sp),
                                                  color: AppColors.primaryTextColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Text(
                                          variantName,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          if (isOutOfStock) {
                                            return Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(6.r),
                                              ),
                                              child: Text(
                                                getText(context, 'Out of Stock', 'స్టాక్ లేదు'),
                                                style: GoogleFonts.jost(
                                                  fontSize: 12.sp,
                                                  color: Colors.grey[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          } else if (constraints.maxWidth > 200) {
                                            return Row(
                                              children: [
                                                Text(
                                                  '₹${variantSellingPrice.toStringAsFixed(0)}',
                                                  style: GoogleFonts.jost(
                                                      fontWeight: FontWeight.w600, fontSize: 15.sp),
                                                ),
                                                if (discountPercentage > 0) ...[
                                                  SizedBox(width: 5.w),
                                                  Text(
                                                    '₹${variantPrice.toStringAsFixed(0)}',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontWeight: FontWeight.normal,
                                                      fontSize: 12.sp,
                                                      decoration: TextDecoration.lineThrough,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                                SizedBox(width: 10.w),
                                                _buildCartControl(context, quantity, variantId, stock,
                                                    localRemoveFromCart, localUpdateQuantity, localAddToCart),
                                              ],
                                            );
                                          } else {
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      '₹${variantSellingPrice.toStringAsFixed(0)}',
                                                      style: GoogleFonts.jost(
                                                          fontWeight: FontWeight.w600, fontSize: 15.sp),
                                                    ),
                                                    if (discountPercentage > 0) ...[
                                                      SizedBox(width: 5.w),
                                                      Text(
                                                        '₹${variantPrice.toStringAsFixed(0)}',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontWeight: FontWeight.normal,
                                                          fontSize: 12.sp,
                                                          decoration: TextDecoration.lineThrough,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                SizedBox(height: 5.h),
                                                _buildCartControl(context, quantity, variantId, stock,
                                                    localRemoveFromCart, localUpdateQuantity, localAddToCart),
                                              ],
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  if (isOutOfStock)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 10.h),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCartControl(
      BuildContext context,
      int quantity,
      String variantId,
      int stock,
      Function(String) removeFromCart,
      Function(String, int) updateQuantity,
      Function(String) addToCart) {
    final decoration = BoxDecoration(
      color: AppColors.primaryColor,
      borderRadius: BorderRadius.circular(7.r),
    );
    final textStyle = GoogleFonts.jost(
      fontWeight: FontWeight.w500,
      fontSize: 14.sp,
      color: AppColors.primaryTextColor,
    );

    if (quantity > 0) {
      return Container(
        decoration: decoration,
        height: 24.h,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16.sp,
                    icon: Icon(quantity == 1 ? Icons.delete : Icons.remove,
                        color: AppColors.primaryTextColor),
                    onPressed: () {
                      if (quantity == 1) {
                        removeFromCart(variantId);
                      } else {
                        updateQuantity(variantId, quantity - 1);
                      }
                    },
                  ),
                  Text(quantity.toString(), style: textStyle),
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16.sp,
                    icon: Icon(Icons.add, color: AppColors.primaryTextColor),
                    onPressed: () {
                      if (quantity + 1 > stock) {
                        _showToastMessage(
                            context,
                            getText(context, 'Only $stock items available in stock',
                                '$stock ఐటమ్లు మాత్రమే స్టాక్‌లో అందుబాటులో ఉన్నాయి'));
                      } else {
                        updateQuantity(variantId, quantity + 1);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          if (stock <= 0) {
            _showToastMessage(
                context, getText(context, 'Product is out of stock', 'ఉత్పత్తి స్టాక్లో లేదు'));
          } else {
            addToCart(variantId);
          }
        },
        child: Container(
          decoration: decoration,
          height: 24.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Center(
              child: Text(
                getText(context, 'Add to Cart', 'కార్ట్‌కి జోడించండి'),
                style: GoogleFonts.jost(
                  color: AppColors.primaryTextColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            final productName = getProductName(context);
            final productImage = _imageOf(widget.product);

            final variants = widget.product['variants'] as List?;
            final Map<String, dynamic>? firstVariant =
                (variants != null && variants.isNotEmpty) ? variants[0] : null;

            final variantName = firstVariant?['name'] ?? 'N/A';
            final variantPrice = double.tryParse(firstVariant?['price']?.toString() ?? '0') ?? 0;
            final stock = int.tryParse(firstVariant?['stock']?.toString() ?? '0') ?? 0;
            final variantSellingPrice =
                double.tryParse(firstVariant?['selling_price']?.toString() ?? '0') ?? 0;
            final discountPercentage = variantPrice > 0
                ? ((variantPrice - variantSellingPrice) / variantPrice * 100).round()
                : 0;
            final String firstVariantId = firstVariant?['id']?.toString() ?? '';

            final allOutOfStock = variants != null &&
                variants.isNotEmpty &&
                variants.every((variant) =>
                    (int.tryParse(variant['stock']?.toString() ?? '0') ?? 0) <= 0);

            return SizedBox(
              height: 150.h,
              child: InkWell(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 100.h,
                        height: 100.h,
                        margin: EdgeInsets.only(top: 8.h),
                        child: Stack(
                          children: [
                            Container(
                              width: 100.h,
                              height: 100.h,
                              decoration: BoxDecoration(
                                color: AppColors.backgroundColor,
                                borderRadius: BorderRadius.circular(10.r),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 3),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: Center(
                                  child: Image.network(
                                    productImage,
                                    width: 80.w,
                                    height: 80.h,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      "assets/images/placeholder_product_card.png",
                                      width: 80.w,
                                      height: 80.h,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryColor,
                                  borderRadius: BorderRadius.only(
                                    bottomRight: Radius.circular(10.r),
                                    topLeft: Radius.circular(10.r),
                                  ),
                                ),
                                child: Text(
                                  '$discountPercentage%\n${getText(context, "OFF", "ఆఫ్")}',
                                  style: GoogleFonts.jost(
                                    fontSize: 8.sp,
                                    color: AppColors.primaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 7,
                              child: GestureDetector(
                                onTap: () {
                                  if (!isWishlistLoading) toggleWishlist(context);
                                },
                                child: isWishlistLoading
                                    ? SizedBox(
                                        width: ResponsiveHelper.getResponsiveWidth(context,
                                            mobile: 14.w, tablet: 16.w, desktop: 18.w),
                                        height: ResponsiveHelper.getResponsiveHeight(context,
                                            mobile: 14.h, tablet: 16.h, desktop: 18.h),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: const AlwaysStoppedAnimation<Color>(
                                              AppColors.primaryColor),
                                        ),
                                      )
                                    : SvgPicture.asset(
                                        isWishlisted
                                            ? 'assets/svg/wishlist_red.svg'
                                            : 'assets/svg/fev.svg',
                                        width: ResponsiveHelper.getResponsiveWidth(context,
                                            mobile: 14.w, tablet: 16.w, desktop: 18.w),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 6.h),
                      SizedBox(
                        height: 20.h,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Flexible(
                              child: Container(
                                constraints: BoxConstraints(maxWidth: 80.w),
                                decoration: BoxDecoration(
                                  color: AppColors.gray,
                                  borderRadius: BorderRadius.circular(10.r),
                                ),
                                padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 1.h),
                                child: Text(
                                  variantName,
                                  style: GoogleFonts.jost(
                                    fontSize: 10.sp,
                                    color: AppColors.secondaryTextColor,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            SvgPicture.asset('assets/svg/time.svg',
                                height: ResponsiveHelper.getResponsiveHeight(context,
                                    mobile: 10.h, tablet: 12.h, desktop: 14.h)),
                            Flexible(
                              child: Text(
                                deliveryTime == "1"
                                    ? getText(context, " close", " మూసివేయండి")
                                    : formatDeliveryTime(deliveryTime).toUpperCase(),
                                style: GoogleFonts.jost(
                                  fontSize: 10.sp,
                                  color: AppColors.secondaryTextColor,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 35.h,
                        width: 110.w,
                        padding: EdgeInsets.symmetric(horizontal: 1.w),
                        child: Text(
                          productName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.jost(fontWeight: FontWeight.w500, fontSize: 13.sp),
                        ),
                      ),
                      SizedBox(
                        height: 18.h,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Text(
                              '₹${variantSellingPrice.toStringAsFixed(0)}',
                              style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.w600, fontSize: 15.sp),
                            ),
                            if (discountPercentage > 0) ...[
                              SizedBox(width: 6.w),
                              Text(
                                '₹${variantPrice.toStringAsFixed(0)}',
                                style: GoogleFonts.dmSans(
                                  fontWeight: FontWeight.normal,
                                  fontSize: 12.sp,
                                  decoration: TextDecoration.lineThrough,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        height: 30.h,
                        width: 110.w,
                        padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 4.h),
                        child: allOutOfStock
                            ? _buildOutOfStockButton(context)
                            : _buildMainCartButton(context, variants, firstVariantId, stock),
                      ),
                    ],
                  ),
                ),
                onTap: () async {
                  if (allOutOfStock) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProductDetailsScreen(product: widget.product),
                    ),
                  );
                  widget.onCategoryBack?.call();
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMainCartButton(BuildContext context, List? variants, String variantId, int stock) {
    final productImage = _imageOf(widget.product);

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final productQuantity =
            cartProvider.getProductTotalQuantity(_userId, widget.product['id'].toString());

        if (productQuantity > 0) {
          return Container(
            width: double.infinity,
            height: 24.h,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Container(
              height: 24.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondaryColor, AppColors.primaryColor],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.circular(7.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(maxWidth: 30.w),
                    icon: Icon(
                      productQuantity == 1 ? Icons.delete : Icons.remove,
                      size: ResponsiveHelper.getResponsiveFontSize(context,
                          mobile: 16.sp, tablet: 18.sp, desktop: 20.sp),
                      color: AppColors.primaryTextColor,
                    ),
                    onPressed: () {
                      final vars = widget.product['variants'] as List;
                      for (var variant in vars) {
                        final vId = variant['id']?.toString() ?? '';
                        final quantity = cartProvider.getQuantity(
                            _userId, widget.product['id'].toString(), vId);
                        if (quantity > 0) {
                          if (quantity == 1) {
                            removeFromCart(context, vId);
                          } else {
                            updateQuantity(context, vId, quantity - 1);
                          }
                          break;
                        }
                      }
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        productQuantity.toString(),
                        style: GoogleFonts.jost(
                          fontWeight: FontWeight.w500,
                          fontSize: 14.sp,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(maxWidth: 30.w),
                    icon: Icon(
                      Icons.add,
                      size: ResponsiveHelper.getResponsiveFontSize(context,
                          mobile: 16.sp, tablet: 18.sp, desktop: 20.sp),
                      color: AppColors.primaryTextColor,
                    ),
                    onPressed: () {
                      final vars = widget.product['variants'] as List;
                      for (var variant in vars) {
                        final vId = variant['id']?.toString() ?? '';
                        final quantity = cartProvider.getQuantity(
                            _userId, widget.product['id'].toString(), vId);
                        if (quantity > 0) {
                          final variantStock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
                          if (quantity + 1 > variantStock) {
                            _showToastMessage(
                                context,
                                getText(context, 'Only $variantStock items available in stock',
                                    '$variantStock ఐటమ్లు మాత్రమే స్టాక్‌లో అందుబాటులో ఉన్నాయి'));
                          } else {
                            updateQuantity(context, vId, quantity + 1);
                          }
                          break;
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        } else {
          return GestureDetector(
            onTap: () {
              if ((variants?.length ?? 0) > 1) {
                _showVariantBottomSheet(context, variants!);
              } else if (variantId.isNotEmpty) {
                if (stock <= 0) {
                  _showToastMessage(context,
                      getText(context, 'Product is out of stock', 'ఉత్పత్తి స్టాక్లో లేదు'));
                } else {
                  addToCart(context, variantId, productImage);
                }
              }
            },
            child: Container(
              width: double.infinity,
              height: 24.h,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.secondaryColor, AppColors.primaryColor],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.circular(7.r),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        (variants?.length ?? 0) > 1
                            ? '${variants?.length} ${getText(context, "Options", "ఎంపికలు")}'
                            : getText(context, 'Add to Cart', 'కార్ట్‌కి జోడించండి'),
                        style: GoogleFonts.jost(
                          color: AppColors.primaryTextColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if ((variants?.length ?? 0) > 1)
                      Padding(
                        padding: EdgeInsets.only(left: 4.w),
                        child: Icon(Icons.keyboard_arrow_down,
                            size: 18.sp, color: AppColors.primaryTextColor),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildOutOfStockButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 24.h,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(7.r),
      ),
      child: Center(
        child: Text(
          getText(context, 'Out of Stock', 'స్టాక్ లేదు'),
          style: GoogleFonts.jost(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 12.sp,
          ),
        ),
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
}
