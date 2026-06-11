import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import '../BottomNav/Screens/order_screen.dart';
import '../Provider/cart_provider.dart';
import '../DeliveryAddress/delivery_address_screen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';

class CheckoutScreen extends StatefulWidget {
  final double saveAmount;
  final double finalWithCharge;
  final String userId;
  final String userEmail;
  final String userName;
  final String giftName;
  final double deliveyCharge;
  final double handlingCharge;
  final String coupon_code_name;
  // Add these new parameters
  final List<Map<String, dynamic>> cartItems;
  final bool isSingleProductCheckout;

  final int branch_id;

  CheckoutScreen({
    required this.saveAmount,
    required this.finalWithCharge,
    required this.userId,
    required this.userEmail,
    required this.userName,
    required this.giftName,
    required this.deliveyCharge,
    required this.handlingCharge,
    required this.coupon_code_name,
    // Add these to constructor
    this.cartItems = const [],
    this.isSingleProductCheckout = false,
    required this.branch_id,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String fullAddress = "";
  String location_id = "";
  int selectedIndex = 1;
  String selectedTimeSlot = '';
  String selectedPaymentMethod = 'cod';
  String selectedUpiApp = '';
  bool _isPlacingOrder = false;
  List<DateTime> localDates = [];


  String userEmail = "";
  String userName = "";
  String userStatus = "";
  String userPhone = ""; // Add this line for phone number
  bool hasProfileData = false;
  String deliveryTime = '0';

  // Razorpay instance
  late Razorpay _razorpay;






  @override
  void initState() {
    super.initState();
    fetchDeliveryTime();
    _loadSelectedAddress();
    fetchUserDetails(widget.userId);

    // Initialize Razorpay
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear(); // Removes all listeners
    super.dispose();
  }


  Future<void> fetchDeliveryTime() async {
    final url = Uri.parse(ApiConstants.DELIVERY_TIME);

    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          deliveryTime = data['data']['time'];
        });
      } else {
        setState(() {
          deliveryTime = 'No time found';
        });
      }
    } catch (e) {
      setState(() {
        deliveryTime = 'Error fetching time';
      });
    }
  }


  void _handlePaymentSuccess(PaymentSuccessResponse response) {
    // Payment successful - place the order
    print("Payment successful: ${response.paymentId}");

    capturePayment(response.paymentId!, widget.finalWithCharge.toInt() * 100);
    // Place order with Razorpay payment method
    _placeOrderAfterPayment(
      paymentMethod: 'razorpay',
      paymentId: response.paymentId!,
      context: context,
    );
  }

  Future<void> capturePayment(String paymentId, int amount) async {
    final response = await http.post(
      Uri.parse(ApiConstants.RAZORPAY_AUTO_CAPTURE_AMOUNT),
      body: {
        "payment_id": paymentId,
        "amount": amount.toString(),
      },
    );

    print("Capture response: ${response.body}");
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    // Payment failed
    print("Payment failed: ${response.code} - ${response.message}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Payment failed: ${response.message}'),
        backgroundColor: Colors.red,
      ),
    );

    setState(() {
      _isPlacingOrder = false;
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    // External wallet was used
    print("External wallet: ${response.walletName}");
  }



  Future<void> fetchUserDetails(String userId) async {
    final url = Uri.parse("${ApiConstants.BASE_URL}/auth/get_user.php?userId=$userId");
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success") {
          setState(() {
            userStatus = data["user"]["status"] ?? "";
            userEmail = data["user"]["email"] ?? "";
            userName = data["user"]["name"] ?? "";
            userPhone = data["user"]["login_id"] ?? ""; // Get phone number
            hasProfileData = userEmail.isNotEmpty && userName.isNotEmpty;
          });
        }
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }
  }

  // Listen for address updates when returning to this screen
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSelectedAddress();
  }

  Future<void> _loadSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      location_id = prefs.getString('selected_address_id') ?? "";
      fullAddress = prefs.getString('selected_address_full') ?? "";
    });
  }


  void _placeOrderAfterPayment({
    required String paymentMethod,
    required String paymentId,
    required BuildContext context,
  }) async {
    final url = Uri.parse(ApiConstants.PLACE_ORDER);

    // Prepare cart items data
    List<Map<String, dynamic>> itemsToOrder = [];

    if (widget.isSingleProductCheckout && widget.cartItems.isNotEmpty) {
      // If it's a single product checkout, only include that product
      itemsToOrder = widget.cartItems;
    } else {
      // If it's a full cart checkout, get all items from cart provider
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      // You'll need to implement a method to get cart items as list from your provider
      itemsToOrder = cartProvider.getCartItemsAsList(widget.userId);
    }

    final body = {
      "user_id": widget.userId,
      "coupon_code": widget.coupon_code_name,
      "discount_amount": widget.saveAmount.toString(),
      "delivery_charge": widget.deliveyCharge.toString(),
      "handling_charge": widget.handlingCharge.toString(),
      "payment_method": paymentMethod,
      "payment_id": paymentId,
      "dateTimeNow": DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()),
      "deliveryDate": DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()),
      "deliverTime": DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()),
      "location_id": location_id,
      "famount": widget.finalWithCharge.toString(),
      "gift": widget.giftName.toString(),
      "branch_id" : widget.branch_id.toString(),
      "user_email" : userEmail.isNotEmpty ? userEmail : widget.userEmail,
      "user_name": userName.isNotEmpty ? userName : widget.userName,
      // Add cart items to the request
      "cart_items": jsonEncode(itemsToOrder),
    };

    try {
      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      final data = jsonDecode(response.body);

      setState(() {
        _isPlacingOrder = false;
      });

      if (data['success'] == true) {
        print("✅ Order placed successfully!");

        // 🟢 IMPORTANT: Clear the cart after successful order placement
        final cartProvider = Provider.of<CartProvider>(context, listen: false);

        if (widget.isSingleProductCheckout && widget.cartItems.isNotEmpty) {
          // Remove only the specific product that was ordered
          for (var item in widget.cartItems) {
            cartProvider.removeCartItem(
                widget.userId,
                item['product_id'].toString(),
                item['variant_id'].toString()
            );
          }
        } else {
          // Clear entire cart for full checkout
          cartProvider.clearCart(widget.userId);
        }

        _showSuccessDialog(context);
      } else {
        print("❌ Failed: ${data['message']}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order failed: ${data['message']}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isPlacingOrder = false;
      });

      print("⚠️ Error placing order: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error placing order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }


  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          contentPadding: const EdgeInsets.all(16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Lottie.asset(
                'assets/success.json',
                width: 200,
                height: 200,
                repeat: false,
              ),
              SizedBox(height: 10.h),
              Text(
                "Your Order Has Been\nSuccessfully Placed",
                textAlign: TextAlign.center,
                style: GoogleFonts.jost(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 20.h),
              InkWell(
                onTap: () {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => OrderScreen()),
                  );
                },
                child: Container(
                  width: 120.w,
                  height: 27.h,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(7.r),
                  ),
                  child: Center(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Order',
                          style: GoogleFonts.jost(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryTextColor,
                          ),
                        ),
                        SizedBox(width: 7.w),
                        SvgPicture.asset(
                          'assets/svg/arrow.svg',
                          color: AppColors.primaryTextColor,
                          width: 15.w,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }


  void _processPayment() {
    // Add delivery time check at the beginning
    if (deliveryTime == '1') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Store is closed. Cannot place order at this time.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (location_id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a delivery address first'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (userStatus == "blocked") {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Your account is blocked. Cannot place order.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (!hasProfileData) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please complete your profile first'),
          backgroundColor: Colors.red,
        ),
      );
      _showCompleteProfileBottomSheet();
      return;
    }

    setState(() {
      _isPlacingOrder = true;
    });

    if (selectedPaymentMethod == 'cod') {
      _placeOrderAfterPayment(
        paymentMethod: 'COD',
        paymentId: '',
        context: context,
      );
    } else if (selectedPaymentMethod == 'razorpay') {
      _openRazorpayCheckout();
    } else if (selectedPaymentMethod == 'upi') {
      // Handle UPI payment (you can integrate specific UPI apps here)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please use Razorpay for UPI payments'),
          backgroundColor: Colors.orange,
        ),
      );
      setState(() {
        _isPlacingOrder = false;
      });
    }

  }

  void _showCompleteProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => CompleteProfileForm(
        userId: widget.userId,
        onProfileUpdated: () {
          fetchUserDetails(widget.userId);
          Navigator.pop(context);
        },
      ),
    );
  }



  void _openRazorpayCheckout() {

    String phone = (userPhone ?? '').trim();

    debugPrint('Original userPhone: <$phone>');

    String digitsOnly = phone.replaceAll(RegExp(r'\D'), '');
    debugPrint('Digits only: <$digitsOnly>');

    if (digitsOnly.length == 10) {
      digitsOnly = '91$digitsOnly'; // result: 918102337432
      debugPrint('Normalized to (no +): <$digitsOnly>');
    } else if (digitsOnly.length == 12 && digitsOnly.startsWith('91')) {
      // already has country code
      debugPrint('Already has country code (no +): <$digitsOnly>');
    } else if (digitsOnly.length >= 11 && digitsOnly.startsWith('0')) {

      digitsOnly = digitsOnly.replaceFirst(RegExp(r'^0+'), '');
      if (digitsOnly.length == 10) digitsOnly = '+91$digitsOnly';
      debugPrint('After stripping leading zero: <$digitsOnly>');
    } else {
      debugPrint('Unusual phone format, using as-is digitsOnly');
    }

    String plusVariant = '+$digitsOnly';

    var optionsPrefillNoPlus = {

      'key': 'rzp_live_RFbJpnCQq3wZm8',
      'amount': (widget.finalWithCharge * 100).toInt(),
      'name': 'Flikka',
      'description': 'Order Payment',
      'prefill': {
        'contact': digitsOnly, // try without +
        'email': userEmail.isNotEmpty ? userEmail : widget.userEmail,
      },
      'external': {'wallets': ['upi']}
    };

    // Log options (important)
    debugPrint('Razorpay options (no plus): $optionsPrefillNoPlus');

    try {
      _razorpay.open(optionsPrefillNoPlus);
    } catch (e) {
      debugPrint('Open failed with no-plus: $e');

      // fallback: try with +91 format
      var optionsPrefillPlus = Map<String, dynamic>.from(optionsPrefillNoPlus);
      optionsPrefillPlus['prefill'] = {
        'contact': plusVariant,
        'email': userEmail.isNotEmpty ? userEmail : widget.userEmail,
      };
      debugPrint('Trying fallback options (with +): $optionsPrefillPlus');

      try {
        _razorpay.open(optionsPrefillPlus);
      } catch (e2) {
        debugPrint('Fallback open failed too: $e2');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Payment init failed: $e2'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {


    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
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
                  padding:  EdgeInsets.only(top: 10.h),
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

                        "Checkout",
                        style: GoogleFonts.jost(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Spacer(),
                      SizedBox(width: 20.w),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: 100.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 14.h),

                      // Location Box
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 21.w),
                        child: Container(
                          width: double.infinity,
                          padding: EdgeInsets.all(16.w),
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.location_on,
                                color: AppColors.primaryColor,
                                size: 24.sp,
                              ),
                              SizedBox(width: 10.w),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Delivery Address",
                                      style: GoogleFonts.jost(
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      fullAddress.isNotEmpty
                                          ? fullAddress
                                          : "No address selected",
                                      style: GoogleFonts.jost(
                                        fontSize: 13.sp,
                                        color: fullAddress.isNotEmpty
                                            ? Colors.grey[700]
                                            : Colors.red,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              GestureDetector(
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DeliveryAddressScreen(),
                                    ),
                                  );
                                  _loadSelectedAddress();
                                },
                                child: Container(
                                  padding: EdgeInsets.all(6.w),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryColor,
                                    borderRadius: BorderRadius.circular(6.r),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 18.sp,
                                    color: AppColors.iconColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 14.h),

                      SizedBox(height: 15.h),

                      // Payment Methods Section
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 21.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Payment Method',
                              style: GoogleFonts.jost(
                                fontWeight: FontWeight.w600,
                                fontSize: 14.sp,
                              ),
                            ),
                            SizedBox(height: 10.h),

                            // Razorpay Payment Option
                            // Razorpay Payment Option (DISABLED)
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey, // Disabled
                                  width: 1.w,
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16.w),
                                child: GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Online Payment Disable!'),
                                        backgroundColor: AppColors.errorColor,
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      IgnorePointer( // Radio button disabled
                                        child: Radio<String>(
                                          value: 'razorpay',
                                          groupValue: '',
                                          onChanged: null,
                                        ),
                                      ),
                                      SizedBox(width: 5.w),
                                      Opacity(
                                        opacity: 0.4, // UI faded (disabled look)
                                        child: Container(
                                          width: 44.w,
                                          height: 21.h,
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: AppColors.lineColor,
                                              width: 1.w,
                                            ),
                                            borderRadius: BorderRadius.circular(5.r),
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(3.0.w),
                                            child: Image.asset(
                                              'assets/images/upi.png',
                                              width: 20.w,
                                              height: 20.h,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 15.w),
                                      Opacity(
                                        opacity: 0.4, // faded text
                                        child: Text(
                                          '(UPI/Cards/Net Banking)',
                                          style: GoogleFonts.jost(
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10),
                                      Icon(Icons.lock, size: 18.sp, color: Colors.grey), // Lock icon
                                    ],
                                  ),
                                ),
                              ),
                            ),


                            SizedBox(height: 15.h),

                            // COD Payment Option
                            Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: selectedPaymentMethod == 'cod'
                                      ? AppColors.primaryColor
                                      : AppColors.lineColor,
                                  width: selectedPaymentMethod == 'cod'
                                      ? 1.5.w
                                      : 1.w,
                                ),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(16.w),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      selectedPaymentMethod = 'cod';
                                    });
                                  },
                                  child: Row(
                                    children: [
                                      Radio<String>(
                                        value: 'cod',
                                        groupValue: selectedPaymentMethod,
                                        onChanged: (value) {
                                          setState(() {
                                            selectedPaymentMethod = value!;
                                          });
                                        },
                                        activeColor: AppColors.primaryColor,
                                      ),
                                      SizedBox(width: 5.w),
                                      Container(
                                        width: 44.w,
                                        height: 21.h,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.lineColor,
                                            width: 1.w,
                                          ),
                                          borderRadius: BorderRadius.circular(5.r),
                                        ),
                                        child: Padding(
                                          padding: EdgeInsets.all(3.0.w),
                                          child: Image.asset(
                                            'assets/images/case.png',
                                            width: 20.w,
                                            height: 20.h,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 15.w),
                                      Text(
                                        'Cash on Delivery',
                                        style: GoogleFonts.jost(
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
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
                            style: GoogleFonts.jost(fontSize: 10.sp),
                          ),
                          Text(
                            '₹${widget.finalWithCharge.toStringAsFixed(0)}',
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
                                'You Save ₹${widget.saveAmount <= 0 ? "0" : widget.saveAmount.toStringAsFixed(0)}',
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
                        onTap: _processPayment,
                        child: Container(
                          width: 170.w,
                          height: 40.h,
                          decoration: BoxDecoration(
                            color: location_id.isEmpty
                                ? Colors.grey
                                : AppColors.primaryColor,
                            borderRadius: BorderRadius.circular(30.r),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Place Order',
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

          if (_isPlacingOrder)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Container(
                  width: 120.w,
                  height: 120.h,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.primaryColor,
                        ),
                      ),
                      SizedBox(height: 15.h),
                      Center(
                        child: Text(
                          selectedPaymentMethod == 'razorpay'
                              ? 'Processing Payment...'
                              : 'Placing Order...',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.jost(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        )
                        ,
                      )
                      ,
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class CompleteProfileForm extends StatefulWidget {
  final String userId;
  final VoidCallback onProfileUpdated;

  const CompleteProfileForm({Key? key, required this.userId, required this.onProfileUpdated}) : super(key: key);

  @override
  _CompleteProfileFormState createState() => _CompleteProfileFormState();
}

class _CompleteProfileFormState extends State<CompleteProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isSubmitting = false;

  Future<bool> insertUser(String name, String email) async {
    final url = Uri.parse(ApiConstants.ADD_USER);

    try {
      final response = await http.post(
        url,
        body: {
          "login_id": widget.userId,
          "name": name,
          "email": email,
          "date_time": DateTime.now().toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data["success"] == "true";
      } else {
        print("Server error: ${response.statusCode}");
        return false;
      }
    } catch (e) {
      print("Error: $e");
      return false;
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      bool success = await insertUser(
        _nameController.text.trim(),
        _emailController.text.trim(),
      );

      setState(() => _isSubmitting = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Profile updated successfully!"))
        );
        widget.onProfileUpdated();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to update profile. Please try again."))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20.w,
          right: 20.w,
          top: 20.h
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 5.h,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10)
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text("Complete Your Profile",
                style: GoogleFonts.jost(fontSize: 18.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 15.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: "Full Name",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            SizedBox(height: 15.h),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email Address",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            SizedBox(height: 15.h),
            SizedBox(height: 20.h),
            _isSubmitting
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text("Save Profile",
                    style: GoogleFonts.jost(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600
                    )),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}