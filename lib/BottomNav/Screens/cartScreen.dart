import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../Checkout/checkout_screen.dart';
import '../../Provider/cart_provider.dart';
import '../../CustomWidgets/product_card.dart';
import '../../SearchProduct/search_product.dart';
import '../../compat/app_state.dart';
import '../../compat/legacy_adapters.dart';
import '../../data/models/cart.dart';
import '../../data/models/coupon.dart';
import '../../data/models/gift.dart';
import '../../data/repositories/repositories.dart';
import '../../utils/colors.dart';

/// Cart — exact legacy visual tree, wired to the new backend:
/// cart lines + totals from [Repos.cart], charges from BranchSettings, gift bar
/// from [Repos.gifts], coupon via [Repos.coupons.validate] and "Everyday
/// Essentials" from [Repos.products]. Quantity mutations go through
/// [CartProvider] then re-fetch the authoritative cart.
class CartScreen extends StatefulWidget {
  @override
  _CartScreenState createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with WidgetsBindingObserver {
  List<CartItem> cartItems = [];
  bool isLoading = true;
  double totalSellingAmount = 0.0;
  double totalPriceAmount = 0.0;
  String userName = "";
  String userEmail = "";

  String get userId => AppState.userId;
  String get branchId => AppState.branchIdOrEmpty;

  // Data variables
  String deliveryTime = '15 minutes';

  int giftPrice = 0;
  double giftTarget = 0;
  String giftName = '';
  String giftImage = '';
  bool _hasGift = false;

  bool get isGiftUnlocked => totalSellingAmount >= giftTarget;

  double get remainingAmount => giftTarget - totalSellingAmount;
  double get progressValue =>
      giftTarget <= 0 ? 0.0 : (totalSellingAmount / giftTarget).clamp(0.0, 1.0);

  List everydayEssentialsList = [];

  final TextEditingController _couponController = TextEditingController();
  bool _isApplyingCoupon = false;

  // Charges (from BranchSettings)
  double deliveryCharge = 0.0;
  double minium_amount = 0.0;
  double handling_charge = 0.0;
  double freeDelivery = 0.0;

  // Store selected coupon details. NOTE: the new backend returns the coupon
  // discount as a rupee AMOUNT (not a percentage like the old API), so
  // [selectedDiscount] now holds the computed rupee discount.
  String? selectedCodeName;
  double selectedDiscount = 0.0;
  double selectedMinAmount = 0.0;

  // Updated final amount calculation with coupon discount (rupee discount).
  double get finalWithCharge {
    double baseAmount = totalSellingAmount + handling_charge;

    // Apply delivery charge if cart amount is less than free delivery threshold
    if (totalSellingAmount < freeDelivery) {
      baseAmount += deliveryCharge;
    }

    // Apply coupon discount if applicable
    if (selectedDiscount > 0 && totalSellingAmount >= selectedMinAmount) {
      baseAmount -= selectedDiscount;
    }

    return baseAmount > 0 ? baseAmount : 0.0;
  }

  double get saveAmount {
    // Normal saving (MRP - Selling Price)
    double saving = totalPriceAmount - totalSellingAmount;

    // Coupon discount, if applicable
    if (selectedDiscount > 0 && totalSellingAmount >= selectedMinAmount) {
      saving += selectedDiscount;
    }

    return saving;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _couponController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshCartData();
    }
  }

  Future<void> _initializeCart() async {
    deliveryTime = AppState.deliveryTimeText.isNotEmpty
        ? AppState.deliveryTimeText
        : '15 minutes';
    await _loadCharges();
    await fetchProductsByType('Everyday Essentials');
    await fetchGift();
    await fetchCartItems();
  }

  Future<void> _refreshCartData() async {
    if (userId.isNotEmpty) {
      await fetchCartItems();
    }
  }

  Future<void> _loadCharges() async {
    if (branchId.isEmpty) return;
    try {
      final home = await Repos.home.getHome(branchId);
      final s = home.settings;
      if (!mounted) return;
      setState(() {
        handling_charge = s.handlingCharge;
        deliveryCharge = s.deliveryCharge;
        freeDelivery = s.freeDeliveryThreshold ?? 0.0;
        minium_amount = s.minOrderAmount;
        if (s.deliveryTimeText.isNotEmpty) deliveryTime = s.deliveryTimeText;
      });
    } catch (e) {
      debugPrint('Error loading charges: $e');
    }
  }

  Future<void> fetchGift() async {
    if (branchId.isEmpty) return;
    try {
      final List<Gift> gifts = await Repos.gifts.list(branchId);
      if (!mounted) return;
      if (gifts.isEmpty) {
        setState(() => _hasGift = false);
        return;
      }
      final gift = gifts.first;
      setState(() {
        _hasGift = true;
        giftPrice = gift.price.round();
        giftTarget = gift.targetAmount;
        giftName = gift.name;
        giftImage = gift.image ?? '';
      });
    } catch (e) {
      debugPrint("Error fetching gift: $e");
      if (mounted) setState(() => _hasGift = false);
    }
  }

  Future<void> fetchProductsByType(String type) async {
    if (branchId.isEmpty) return;
    try {
      final page = await Repos.products.list(
        branchId: branchId,
        tag: type,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        everydayEssentialsList = LegacyAdapters.products(page.items);
      });
    } catch (e) {
      debugPrint("Error fetching $type products: $e");
    }
  }

  Future<void> fetchCartItems() async {
    if (branchId.isEmpty || userId.isEmpty) {
      if (mounted) {
        setState(() {
          cartItems = [];
          isLoading = false;
        });
      }
      return;
    }

    try {
      final Cart cart = await Repos.cart.getCart(branchId);
      if (!mounted) return;
      setState(() {
        cartItems = cart.items;
        totalSellingAmount = cart.itemsTotal;
        totalPriceAmount = cart.itemsTotal + cart.savings;
      });
      _checkCouponValidity();
    } catch (e) {
      debugPrint('Error fetching cart: $e');
      if (mounted) setState(() => cartItems = []);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // Apply a coupon by typed code through the backend validator.
  Future<void> _applyCouponByCode() async {
    if (_couponController.text.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please enter coupon code",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14.sp,
      );
      return;
    }

    setState(() => _isApplyingCoupon = true);

    try {
      final CouponValidation result = await Repos.coupons.validate(
        branchId: branchId,
        code: _couponController.text.trim(),
        amount: totalSellingAmount,
      );

      if (result.valid) {
        _applyValidatedCoupon(
          code: result.code ?? _couponController.text.trim(),
          discount: result.discount,
          minAmount: result.minAmount ?? 0.0,
        );
        _couponController.clear();
        if (mounted) Navigator.pop(context);
      } else {
        Fluttertoast.showToast(
          msg: result.failureMessage,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 14.sp,
        );
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: "Error applying coupon",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 14.sp,
      );
    } finally {
      if (mounted) setState(() => _isApplyingCoupon = false);
    }
  }

  void _removeCoupon() {
    setState(() {
      selectedCodeName = null;
      selectedDiscount = 0.0;
      selectedMinAmount = 0.0;
    });

    Fluttertoast.showToast(
      msg: "Coupon removed",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14.sp,
    );
  }

  void _applyValidatedCoupon({
    required String code,
    required double discount,
    required double minAmount,
  }) {
    setState(() {
      selectedCodeName = code;
      selectedDiscount = discount;
      selectedMinAmount = minAmount;
    });

    Fluttertoast.showToast(
      msg: "Coupon Applied: $code",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      fontSize: 14.sp,
    );
  }

  Future<void> updateQuantity(CartItem item, int newQuantity) async {
    if (newQuantity < 1) return;

    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final ok = await cartProvider.changeQuantity(
      userId: userId,
      branchId: branchId,
      productId: item.productId,
      variantId: item.variantId ?? '',
      quantity: newQuantity,
    );
    if (ok) {
      await fetchCartItems();
    } else {
      Fluttertoast.showToast(
        msg: "Failed to update quantity",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    }
  }

  Future<void> removeItem(CartItem item) async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final ok = await cartProvider.removeItem(
      userId: userId,
      branchId: branchId,
      productId: item.productId,
      variantId: item.variantId ?? '',
    );
    if (ok) {
      await fetchCartItems();
    }
  }

  void _showGiftDetails() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Congratulations! 🎁',
            style: GoogleFonts.jost(
              fontWeight: FontWeight.bold,
              fontSize: 18.sp,
            ),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Gift Image
                Container(
                  width: 120.w,
                  height: 120.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10.r),
                    child: Image.network(
                      giftImage,
                      width: 100.w,
                      height: 100.h,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.card_giftcard,
                        size: 50.sp,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 15.h),

                // Gift Name
                Text(
                  giftName,
                  style: GoogleFonts.jost(
                    fontWeight: FontWeight.w600,
                    fontSize: 16.sp,
                    color: AppColors.primaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 10.h),

                // Gift Price
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.price_change,
                      size: 16.sp,
                      color: Colors.green,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      'Gift Value: ₹$giftPrice',
                      style: GoogleFonts.jost(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.sp,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),

                // Target Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.card_giftcard,
                      size: 16.sp,
                      color: AppColors.primaryColor,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      'Target: ₹${giftTarget.toStringAsFixed(0)}',
                      style: GoogleFonts.jost(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.sp,
                        color: AppColors.primaryColor,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),

                // Your Shopping Amount
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.shopping_cart,
                      size: 16.sp,
                      color: Colors.blue,
                    ),
                    SizedBox(width: 5.w),
                    Text(
                      'Your Cart: ₹${totalSellingAmount.toStringAsFixed(0)}',
                      style: GoogleFonts.jost(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.sp,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 15.h),

                // Congratulations Message
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'You have successfully unlocked this gift by shopping for ₹${giftTarget.toStringAsFixed(0)}+. This gift will be delivered with your order!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jost(
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  'Awesome!',
                  style: GoogleFonts.jost(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                    color: AppColors.primaryColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: isLoading
          ? Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      )
          : cartItems.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart,
              size: 80.sp,
              color: Colors.grey,
            ),
            Text(
              'Your cart is empty',
              style: GoogleFonts.jost(
                fontSize: 30.sp,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            SizedBox(
              height: 10.h,
            ),
            InkWell(
              child: Container(
                width: 180.w,
                height: 30.h,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius:
                  BorderRadius.circular(8.r), // 👈 Border Radius added
                ),
                child: Center(
                  child: Text(
                    'Continue Shopping',
                    style: GoogleFonts.jost(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            )
          ],
        ),
      )
          : Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 17.h),

              // Header
              Container(
                width: double.infinity,
                height: 60.h,
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      offset: Offset(0, 4),
                      blurRadius: 6,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.only(top: 10.h),
                  child: Row(
                    children: [
                      SizedBox(width: 16.w),
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          height: 25.h,
                          width: 28.w,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.only(left: 7.w),
                              child: Icon(
                                Icons.arrow_back_ios,
                                size: 15.sp,
                                color: AppColors.iconColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Text(
                        "My Cart",
                        style: GoogleFonts.jost(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Spacer(),
                      InkWell(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SearchProduct(),
                            ),
                          );
                          await _refreshCartData();
                        },
                        child: Padding(
                          padding: EdgeInsets.only(left: 1.w),
                          child: SvgPicture.asset(
                            'assets/svg/search.svg',
                            width: 16.h,
                            height: 16.w,
                          ),
                        ),
                      ),
                      SizedBox(width: 20.w),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.only(
                      bottom: 100.h,
                    ),
                    child: Column(
                      children: [
                        SizedBox(height: 14.h),

                        // Gift Section (hidden when the branch has no gift)
                        if (_hasGift)
                          Container(
                            child: Column(
                              children: [
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 16.w,
                                    right: 16.w,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: isGiftUnlocked
                                        ? 100.h
                                        : 78.h, // Increased height when unlocked
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor
                                          .withOpacity(0.1),
                                      borderRadius:
                                      BorderRadius.circular(10.r),
                                      border: Border.all(
                                        color: AppColors.lineColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 10.w),
                                        ClipRRect(
                                          borderRadius:
                                          BorderRadius.circular(10.r),
                                          child: Image.network(
                                            giftImage.isNotEmpty
                                                ? giftImage
                                                : 'assets/images/gift.png',
                                            width: 60.w,
                                            height: 60.h,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                Image.asset(
                                                  'assets/images/gift.png',
                                                  width: 60.w,
                                                  height: 60.h,
                                                ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              left: 10.w,
                                              top: 12.h,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  isGiftUnlocked
                                                      ? 'Congratulations! You unlocked a gift! 🎁'
                                                      : 'Special Deal! Buy for ₹${giftTarget.toStringAsFixed(0)} and\nget a surprise gift.',
                                                  style: GoogleFonts.jost(
                                                    height: 1.2,
                                                    fontWeight:
                                                    FontWeight.w500,
                                                    fontSize: 11.sp,
                                                  ),
                                                ),
                                                SizedBox(height: 5.h),
                                                Row(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius:
                                                      BorderRadius
                                                          .circular(
                                                          10.r),
                                                      child: Image.asset(
                                                        'assets/images/girt_icon.png',
                                                        width: 26.w,
                                                        height: 26.h,
                                                      ),
                                                    ),
                                                    SizedBox(width: 7.w),
                                                    Expanded(
                                                      child: Column(
                                                        mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .start,
                                                        crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                        children: [
                                                          Text(
                                                            isGiftUnlocked
                                                                ? 'You have earned: $giftName'
                                                                : 'Add products worth ₹${remainingAmount.toStringAsFixed(0)} more',
                                                            style: GoogleFonts
                                                                .jost(
                                                              height: 1.1,
                                                              fontWeight:
                                                              FontWeight
                                                                  .w400,
                                                              fontSize:
                                                              11.sp,
                                                              color: AppColors
                                                                  .secondaryTextColor,
                                                            ),
                                                          ),
                                                          if (isGiftUnlocked)
                                                            SizedBox(
                                                                height: 5.h),
                                                          if (isGiftUnlocked)
                                                            InkWell(
                                                              onTap: () {
                                                                _showGiftDetails();
                                                              },
                                                              child:
                                                              Container(
                                                                padding: EdgeInsets
                                                                    .symmetric(
                                                                  horizontal:
                                                                  10.w,
                                                                  vertical:
                                                                  4.h,
                                                                ),
                                                                decoration:
                                                                BoxDecoration(
                                                                  color: AppColors
                                                                      .primaryColor,
                                                                  borderRadius:
                                                                  BorderRadius.circular(5.r),
                                                                ),
                                                                child:
                                                                Text(
                                                                  'View Gift',
                                                                  style: GoogleFonts
                                                                      .jost(
                                                                    fontSize:
                                                                    10.sp,
                                                                    color: AppColors
                                                                        .primaryTextColor,
                                                                    fontWeight:
                                                                    FontWeight.w500,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                Transform.translate(
                                  offset: Offset(45.w, -15.h),
                                  child: Stack(
                                    children: [
                                      Container(
                                        width: 185.w,
                                        height: 3.4.h,
                                        decoration: BoxDecoration(
                                          color: Colors.grey.shade300,
                                          borderRadius:
                                          BorderRadius.circular(2.r),
                                        ),
                                      ),
                                      Container(
                                        width: 185.w * progressValue,
                                        height: 3.4.h,
                                        decoration: BoxDecoration(
                                          color: totalSellingAmount >=
                                              giftTarget
                                              ? Colors.green
                                              : AppColors.primaryColor,
                                          borderRadius:
                                          BorderRadius.circular(2.r),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.all(14.h),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: AppColors.gray,
                                width: 1.4,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 10.h),
                                Row(
                                  children: [
                                    SizedBox(width: 20.w),
                                    SvgPicture.asset(
                                      'assets/svg/time.svg',
                                      width: 14.w,
                                      height: 14.h,
                                    ),
                                    SizedBox(width: 4.w),
                                    Text(
                                      deliveryTime.toString(),
                                      style: GoogleFonts.jost(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Spacer(),
                                    Text(
                                      "${cartItems.length} items",
                                      style: GoogleFonts.jost(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    SizedBox(width: 20.w),
                                  ],
                                ),
                                Padding(
                                  padding: EdgeInsets.only(
                                    left: 20.w,
                                    right: 10.w,
                                    top: 10.h,
                                  ),
                                  child: DottedLine(
                                    dashColor: AppColors.lineColor,
                                    lineThickness: 2,
                                  ),
                                ),
                                ListView.builder(
                                  padding: EdgeInsets.all(12.w),
                                  itemCount: cartItems.length,
                                  shrinkWrap: true,
                                  physics:
                                  NeverScrollableScrollPhysics(),
                                  itemBuilder: (context, index) {
                                    final item = cartItems[index];
                                    final productName = item.productName;
                                    final variantName =
                                        item.variantName ?? '';
                                    final sellingPrice = item.unitPrice;
                                    // The new cart returns the unit (selling)
                                    // price; MRP/strike-through is not exposed
                                    // per line, so we show selling price only.
                                    final price = sellingPrice;
                                    final quantity = item.quantity;

                                    final discountPercentage = price > 0
                                        ? ((price - sellingPrice) /
                                        price *
                                        100)
                                        .round()
                                        : 0;

                                    return Padding(
                                      padding: EdgeInsets.only(
                                        left: 2.w,
                                        right: 2.w,
                                        bottom: 14.h,
                                      ),
                                      child: Row(
                                        crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                        children: [
                                          // Image
                                          Stack(
                                            children: [
                                              Container(
                                                width: 40.h,
                                                height: 40.h,
                                                decoration:
                                                BoxDecoration(
                                                  color: AppColors
                                                      .backgroundColor,
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                      10.r),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(
                                                          0.1),
                                                      blurRadius: 3,
                                                    ),
                                                  ],
                                                ),
                                                child: ClipRRect(
                                                  borderRadius:
                                                  BorderRadius
                                                      .circular(
                                                      12.r),
                                                  child: Center(
                                                    child: Icon(
                                                      Icons
                                                          .shopping_bag_outlined,
                                                      size: 24.sp,
                                                      color: AppColors
                                                          .primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              if (discountPercentage > 0)
                                                Positioned(
                                                  child: Container(
                                                    padding: EdgeInsets
                                                        .symmetric(
                                                      horizontal: 6.w,
                                                      vertical: 2.h,
                                                    ),
                                                    decoration:
                                                    BoxDecoration(
                                                      color: AppColors
                                                          .secondaryColor,
                                                      borderRadius:
                                                      BorderRadius
                                                          .only(
                                                        bottomRight:
                                                        Radius
                                                            .circular(
                                                            10.r),
                                                        topLeft: Radius
                                                            .circular(
                                                            10.r),
                                                      ),
                                                    ),
                                                    child: Text(
                                                      '$discountPercentage%\nOFF',
                                                      style: GoogleFonts
                                                          .jost(
                                                        fontSize: 5.sp,
                                                        color: AppColors
                                                            .primaryTextColor,
                                                        fontWeight:
                                                        FontWeight
                                                            .w400,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                          SizedBox(width: 10.w),

                                          // Name
                                          Container(
                                            width: 80.w,
                                            child: Column(
                                              crossAxisAlignment:
                                              CrossAxisAlignment
                                                  .start,
                                              children: [
                                                Text(
                                                  productName,
                                                  style:
                                                  GoogleFonts.jost(
                                                    fontSize: 11.sp,
                                                    height: 1.2,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                                ),
                                                SizedBox(height: 6.h),
                                                Text(
                                                  variantName,
                                                  style:
                                                  GoogleFonts.jost(
                                                    fontSize: 11.sp,
                                                    color: Colors.grey,
                                                    height: 1.2,
                                                  ),
                                                  maxLines: 2,
                                                  overflow:
                                                  TextOverflow
                                                      .ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 17.w),
                                          // Quantity controls
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: 7.h,
                                            ),
                                            child: Container(
                                              height: 20.h,
                                              decoration:
                                              BoxDecoration(
                                                borderRadius:
                                                BorderRadius
                                                    .circular(
                                                    10.r),
                                                color: AppColors
                                                    .primaryColor,
                                              ),
                                              child: Row(
                                                children: [
                                                  IconButton(
                                                    icon: Icon(
                                                      quantity == 1
                                                          ? Icons
                                                          .delete
                                                          : Icons
                                                          .remove,
                                                      color: AppColors
                                                          .primaryTextColor,
                                                      size: 15.sp,
                                                    ),
                                                    onPressed: () {
                                                      if (quantity >
                                                          1) {
                                                        updateQuantity(
                                                            item,
                                                            quantity -
                                                                1);
                                                      } else {
                                                        removeItem(
                                                            item);
                                                      }
                                                    },
                                                    padding:
                                                    EdgeInsets
                                                        .zero,
                                                  ),
                                                  Text(
                                                    quantity
                                                        .toString(),
                                                    style: GoogleFonts
                                                        .jost(
                                                      fontWeight:
                                                      FontWeight
                                                          .w500,
                                                      fontSize: 12.sp,
                                                      color: AppColors
                                                          .primaryTextColor,
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.add,
                                                      size: 15.sp,
                                                      color: AppColors
                                                          .primaryTextColor,
                                                    ),
                                                    onPressed: () {
                                                      updateQuantity(
                                                          item,
                                                          quantity +
                                                              1);
                                                    },
                                                    padding:
                                                    EdgeInsets
                                                        .zero,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          Spacer(),
                                          // Price
                                          Column(
                                            children: [
                                              Text(
                                                '₹${sellingPrice.toStringAsFixed(0)}',
                                                style:
                                                GoogleFonts.jost(
                                                  fontWeight:
                                                  FontWeight.w600,
                                                  fontSize: 12.sp,
                                                ),
                                              ),

                                              if (discountPercentage >
                                                  0)
                                                Text(
                                                  '₹${price.toStringAsFixed(0)}',
                                                  style: GoogleFonts
                                                      .jost(
                                                    fontWeight:
                                                    FontWeight
                                                        .normal,
                                                    fontSize: 12.sp,
                                                    decoration:
                                                    TextDecoration
                                                        .lineThrough,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),

                        // bill details
                        Padding(
                          padding: EdgeInsets.only(
                            left: 16.w,
                            right: 16.w,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius:
                              BorderRadius.circular(10.r),
                              border: Border.all(
                                color: AppColors.gray,
                                width: 1.4,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                SizedBox(height: 13.h),
                                Padding(
                                  padding:
                                  EdgeInsets.only(left: 22.sp),
                                  child: Text(
                                    'Bill Details',
                                    style: GoogleFonts.jost(
                                      fontWeight: FontWeight.w600,
                                      color:
                                      AppColors.secondaryTextColor,
                                      fontSize: 15.sp,
                                    ),
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: 1.h,
                                    color: AppColors.lineColor,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Row(
                                  children: [
                                    SizedBox(width: 22.w),
                                    SvgPicture.asset(
                                      'assets/svg/item_dis.svg',
                                      width: 14.w,
                                      height: 14.h,
                                    ),
                                    SizedBox(width: 18.w),
                                    Text(
                                      'Items total',
                                      style: GoogleFonts.jost(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Spacer(),

                                    if (totalPriceAmount >
                                        totalSellingAmount)
                                      Text(
                                        '₹${totalPriceAmount.toStringAsFixed(0)}',
                                        style:
                                        GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w400,
                                          fontSize: 12.sp,
                                          decoration: TextDecoration
                                              .lineThrough,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    SizedBox(width: 8.w),
                                    Text(
                                      '₹${totalSellingAmount.toStringAsFixed(0)}',
                                      style:
                                      GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w500,
                                        color: AppColors
                                            .secondaryTextColor,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                    SizedBox(width: 20.w),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                Row(
                                  children: [
                                    SizedBox(width: 20.w),
                                    SvgPicture.asset(
                                      'assets/svg/handling.svg',
                                      width: 14.w,
                                      height: 14.h,
                                    ),
                                    SizedBox(width: 15.w),
                                    Text(
                                      'Handling Charge',
                                      style: GoogleFonts.jost(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Spacer(),
                                    SizedBox(width: 8.w),
                                    Text(
                                      '₹${handling_charge.toStringAsFixed(0)}',
                                      style: GoogleFonts.jost(
                                        fontWeight: FontWeight.w500,
                                        color: AppColors
                                            .secondaryTextColor,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                    SizedBox(width: 20.w),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                Row(
                                  children: [
                                    SizedBox(width: 20.w),
                                    Icon(
                                      Icons.delivery_dining,
                                      size: 16.sp,
                                    ),
                                    SizedBox(width: 14.w),
                                    Text(
                                      'Delivery Charge',
                                      style: GoogleFonts.jost(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Spacer(),
                                    SizedBox(width: 8.w),
                                    Text(
                                      totalSellingAmount >=
                                          freeDelivery
                                          ? 'Free'
                                          : '₹${deliveryCharge.toStringAsFixed(0)}',
                                      style:
                                      GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.bold,
                                        color: totalSellingAmount >=
                                            freeDelivery
                                            ? Colors.green
                                            : Colors.black,
                                        fontSize: 12.sp,
                                      ),
                                    ),
                                    SizedBox(width: 20.w),
                                  ],
                                ),
                                SizedBox(height: 10.h),
                                InkWell(
                                  onTap: () {
                                    _showCouponBottomSheet();
                                  },
                                  child: Row(
                                    children: [
                                      SizedBox(width: 20.w),
                                      SvgPicture.asset(
                                        'assets/svg/c2.svg',
                                        width: 14.w,
                                        height: 14.h,
                                      ),
                                      SizedBox(width: 13.w),
                                      Text(
                                        'Apply Coupon',
                                        style: GoogleFonts.jost(
                                          fontSize: 13.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Spacer(),
                                      if (selectedCodeName !=
                                          null) ...[
                                        SizedBox(width: 8.w),
                                        Text(
                                          "$selectedCodeName  (₹${selectedDiscount.toStringAsFixed(0)} OFF)",
                                          style: GoogleFonts.jost(
                                            fontWeight:
                                            FontWeight.w600,
                                            color: Colors.green,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        InkWell(
                                          onTap: _removeCoupon,
                                          child: Icon(
                                            Icons.close,
                                            size: 16.sp,
                                            color: Colors.red,
                                          ),
                                        ),
                                      ] else ...[
                                        SizedBox(width: 8.w),
                                        Text(
                                          'Select',
                                          style: GoogleFonts
                                              .plusJakartaSans(
                                            fontWeight:
                                            FontWeight.w500,
                                            color: AppColors
                                                .secondaryTextColor,
                                            fontSize: 12.sp,
                                          ),
                                        ),
                                      ],
                                      Icon(
                                        Icons.keyboard_arrow_down,
                                        size: 20.sp,
                                      ),
                                      SizedBox(width: 16.w),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 20.w,
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: 1.h,
                                    color: AppColors.lineColor,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Row(
                                  children: [
                                    SizedBox(width: 20.w),
                                    Text(
                                      'To Pay',
                                      style: GoogleFonts.jost(
                                        fontSize: 15.sp,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Spacer(),
                                    SizedBox(width: 8.w),
                                    Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          '₹${finalWithCharge.toStringAsFixed(0)}',
                                          style: GoogleFonts.jost(
                                            fontSize: 16.sp,
                                            fontWeight:
                                            FontWeight.w700,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'You Save ₹${saveAmount <= 0 ? "0" : saveAmount.toStringAsFixed(0)}',
                                          style: GoogleFonts.jost(
                                            fontSize: 13.sp,
                                            fontWeight:
                                            FontWeight.w700,
                                            color: Colors.green,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(width: 16.w),
                                  ],
                                ),
                                SizedBox(height: 13.h),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: 14.h),
                        if (everydayEssentialsList.isNotEmpty)
                          buildSection(
                            'Everyday Essentials',
                            everydayEssentialsList,
                          ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: 16.w,
                            right: 16.w,
                          ),
                          child: InkWell(
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SearchProduct(),
                                ),
                              );
                              await _refreshCartData();
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
                                borderRadius:
                                BorderRadius.circular(7.r),
                              ),
                              child: Center(
                                child: Row(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.center,
                                  mainAxisAlignment:
                                  MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "See all Products",
                                      style: GoogleFonts.jost(
                                        fontSize: 16,
                                        color: AppColors
                                            .secondaryTextColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    SizedBox(width: 10.w),
                                    Icon(Icons.double_arrow,
                                        size: 16),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Bottom total section
          Positioned(
            left: 0,
            right: 0,
            bottom: 0.h,
            child: Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Total Price',
                            style:
                            GoogleFonts.jost(fontSize: 10.sp),
                          ),
                          Text(
                            '₹${finalWithCharge.toStringAsFixed(0)}',
                            style: GoogleFonts.jost(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16.sp,
                                color: Colors.green,
                              ),
                              SizedBox(width: 5.w),
                              Text(
                                'You Save ₹${saveAmount <= 0 ? "0" : saveAmount.toStringAsFixed(0)}',
                                style: GoogleFonts.jost(
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () {
                          // Check minimum order amount
                          if (totalSellingAmount < minium_amount) {
                            Fluttertoast.showToast(
                              msg:
                              "Minimum order amount is ₹${minium_amount.toStringAsFixed(0)}",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 14.sp,
                            );
                            return;
                          }

                          // Calculate actual delivery charge (0 if free delivery applies)
                          double actualDeliveryCharge =
                          totalSellingAmount >= freeDelivery
                              ? 0.0
                              : deliveryCharge;

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CheckoutScreen(
                                saveAmount: saveAmount,
                                finalWithCharge: finalWithCharge,
                                userId: userId,
                                userEmail: userEmail.toString(),
                                userName: userName.toString(),
                                giftName: (_hasGift &&
                                    totalSellingAmount >=
                                        giftTarget)
                                    ? giftName
                                    : "noGift",
                                deliveyCharge: actualDeliveryCharge,
                                handlingCharge: handling_charge,
                                coupon_code_name:
                                selectedCodeName ?? '',
                                branch_id: int.tryParse(branchId.toString()) ?? 0,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 170.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Checkout',
                                  style: GoogleFonts.jost(
                                    color: AppColors.primaryTextColor,
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(width: 14.w),
                                SvgPicture.asset(
                                  'assets/svg/arrow.svg',
                                  height: 12.h,
                                  color: AppColors.primaryTextColor,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
                  childAspectRatio: 0.38,
                ),
                itemCount: list.length > 6 ? 6 : list.length,
                itemBuilder: (context, index) {
                  final product = list[index];
                  return ProductCard(
                    product: product,
                    userId: userId,
                    branchId: branchId,
                    onCartUpdated: () {
                      _refreshCartData();
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

  void _checkCouponValidity() {
    if (selectedDiscount > 0 && totalSellingAmount < selectedMinAmount) {
      setState(() {
        selectedCodeName = null;
        selectedDiscount = 0.0;
        selectedMinAmount = 0.0;
      });

      Fluttertoast.showToast(
        msg:
        "Coupon removed as cart value decreased below minimum requirement",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.orange,
        textColor: Colors.white,
        fontSize: 14.sp,
      );
    }
  }

  void _showCouponBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16.r)),
      ),
      builder: (context) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: Repos.coupons.available(branchId).then(
              (raw) => raw.map(LegacyAdapters.coupon).toList()),
          builder: (context, snapshot) {
            final coupons = snapshot.data ?? const <Map<String, dynamic>>[];
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.7,
              child: Column(
                children: [
                  SizedBox(height: 10.h),
                  Container(
                    width: 50.w,
                    height: 4.h,
                    decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  SizedBox(height: 15.h),
                  Text("Available Coupons",
                      style: GoogleFonts.jost(
                          fontSize: 16.sp, fontWeight: FontWeight.w700)),

                  // Coupon code input field
                  Padding(
                    padding:
                    EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                )
                              ],
                            ),
                            child: TextField(
                              controller: _couponController,
                              decoration: InputDecoration(
                                hintText: "Enter coupon code",
                                hintStyle: GoogleFonts.jost(
                                    color: Colors.grey.shade600),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16.w, vertical: 14.h),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: BorderSide.none,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12.r),
                                  borderSide: BorderSide(
                                      color: AppColors.primaryColor,
                                      width: 1.5),
                                ),
                              ),
                              style: GoogleFonts.jost(fontSize: 14.sp),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        _isApplyingCoupon
                            ? Container(
                          padding: EdgeInsets.all(8.w),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                            AlwaysStoppedAnimation<Color>(
                                Theme.of(context).primaryColor),
                          ),
                        )
                            : Container(
                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(12.r),
                            boxShadow: [
                              BoxShadow(
                                color: Theme.of(context)
                                    .primaryColor
                                    .withOpacity(0.3),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _applyCouponByCode,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                              AppColors.primaryColor,
                              foregroundColor:
                              AppColors.primaryTextColor,
                              padding: EdgeInsets.symmetric(
                                  horizontal: 16.w,
                                  vertical: 14.h),
                              shape: RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius.circular(12.r),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              "Apply",
                              style: GoogleFonts.jost(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: snapshot.connectionState ==
                        ConnectionState.waiting
                        ? Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primaryColor))
                        : ListView.builder(
                      padding: EdgeInsets.zero,
                      itemCount: coupons.length,
                      itemBuilder: (context, index) {
                        final coupon = coupons[index];
                        return InkWell(
                          onTap: () {
                            _couponController.text =
                                coupon['code_name']?.toString() ?? '';
                            _applyCouponByCode();
                          },
                          child: _buildCouponCard(coupon),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCouponCard(Map<String, dynamic> coupon) {
    final isPrivate = coupon['status'] == "Private";

    if (isPrivate) {
      return Container();
    }

    final minAmount =
        double.tryParse(coupon['min_amount']?.toString() ?? '0') ?? 0.0;
    final canApply = totalSellingAmount >= minAmount;

    return Container(
      width: double.infinity,
      height: 85.h,
      margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        image: const DecorationImage(
          image: AssetImage('assets/images/coupons.png'),
          fit: BoxFit.fill,
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding:
            EdgeInsets.only(left: 20.w, right: 15.w, top: 6.h, bottom: 4.h),
            child: Row(
              children: [
                Text('Coupon',
                    style: GoogleFonts.jost(
                      color: AppColors.secondaryColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 15.sp,
                    )),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                  child: Padding(
                    padding:
                    EdgeInsets.symmetric(horizontal: 10.w, vertical: 2.h),
                    child: Center(
                        child: Text('Valid ${coupon['expri_date']}',
                            style: GoogleFonts.jost(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ))),
                  ),
                )
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 8.w, right: 6.w),
            child: DottedLine(
              dashColor: AppColors.secondaryColor,
              lineThickness: 1.7,
            ),
          ),
          Padding(
            padding: EdgeInsets.only(left: 25.w, right: 20.w, top: 10.h),
            child: Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        SvgPicture.asset('assets/svg/coupon.svg',
                            width: 18.w, color: AppColors.secondaryColor),
                        SizedBox(width: 4.w),
                        Text(coupon['title']?.toString() ?? '',
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.bold,
                              fontSize: 12.sp,
                            ))
                      ],
                    ),
                    Text(coupon['description']?.toString() ?? '',
                        style: GoogleFonts.jost(
                          fontWeight: FontWeight.w600,
                          fontSize: 12.sp,
                        )),
                    if (!canApply)
                      Text(
                        'Add ₹${(minAmount - totalSellingAmount).toStringAsFixed(0)} more to apply',
                        style: GoogleFonts.jost(
                          fontSize: 10.sp,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.secondaryColor.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 2.h,
                    ),
                    child: Center(
                      child: Text(
                        coupon['code_name']?.toString() ?? '',
                        style: GoogleFonts.jost(
                          fontSize: 12.sp,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
