import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../OrderSummary/order_summary.dart';
import '../../TrackOrder/track_order.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import '../bottomNavScreen.dart';
import '../../Provider/language_provider.dart';

class OrderScreen extends StatefulWidget {
  const OrderScreen({super.key});

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> with TickerProviderStateMixin {
  bool isLoading = true;
  List orders = [];
  late final TabController _tabController;
  String userName = "";
  String userEmail = "";
  String userId = "";
  int branchId = 0;
  String branchName = "";

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchLocation();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Refresh function
  Future<void> refreshOrders() async {
    setState(() {
      isLoading = true;
    });
    await fetchUserData();
  }

  Future<void> fetchLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? uArea = prefs.getString('user_area_h');
    String? uCity = prefs.getString('user_city_h');
    int bId = prefs.getInt('selected_branch_id') ?? 0;
    String? bName = prefs.getString('selected_branch_name');

    if ((uArea != null && uArea.trim().isNotEmpty) ||
        (uCity != null && uCity.trim().isNotEmpty)) {
      setState(() {
        branchId = bId;
        branchName = bName ?? "";
      });

      await fetchUserData();
    }
  }

  // Helper method to get text based on language
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? user_ID = prefs.getString('user_id');
    if (user_ID != null) {
      setState(() => userId = user_ID);
      await fetchOrders(userId);
    }
  }

  Future<void> fetchOrders(String userId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.GET_ORDER_BY_USER),
        body: {
          "user_id": userId,
          "branch_id": branchId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          orders = (data["orders"] ?? []) as List;
          isLoading = false;
        });
      } else {
        throw Exception("Failed to load orders");
      }
    } catch (e) {
      debugPrint("Error: $e");
      setState(() => isLoading = false);
    }
  }

  bool _isCompleteStatus(String? statusRaw) {
    final status = (statusRaw ?? '').toLowerCase();
    return status.contains('delivered') ||
        status.contains('completed') ||
        status.contains('cancelled') ||
        status.contains('canceled');
  }

  @override
  Widget build(BuildContext context) {
    final activeOrders = orders.where((o) => !_isCompleteStatus((o["order"]?["status"]).toString())).toList();
    final completeOrders = orders.where((o) => _isCompleteStatus((o["order"]?["status"]).toString())).toList();

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: 17.h),
          // Header
          Container(
            width: double.infinity,
            height: 65.h,
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
              padding: EdgeInsets.only(top: 12.h),
              child: Row(
                children: [
                  SizedBox(width: 16.w),
                  InkWell(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => BottomNavScreen()));
                    },
                    child: Container(
                      height: 25.h,
                      width: 30.w,
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor,
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Center(
                        child: Padding(
                          padding: EdgeInsets.only(left: 7.w),
                          child: Icon(Icons.arrow_back_ios, size: 15.sp, color: AppColors.iconColor),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, child) {
                      return Text(
                        getText(context, "My Order", "నా ఆర్డర్"),
                        style: GoogleFonts.jost(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                  Spacer(),
                  // Refresh Button
                  IconButton(
                    onPressed: refreshOrders,
                    icon: Icon(
                      Icons.refresh,
                      size: 22.sp,
                      color: AppColors.searchBorderHome,
                    ),
                  ),
                  SizedBox(width: 16.w),
                ],
              ),
            ),
          ),

          SizedBox(height: 8.h),
          _Tabs(tabController: _tabController, context: context),
          SizedBox(height: 8.h),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
              controller: _tabController,
              children: [
                _OrderList(
                  orders: activeOrders,
                  context: context,
                  buildCard: _buildActiveOrderCard,
                  refreshOrders: refreshOrders, // Pass refresh function
                ),
                _OrderList(
                  orders: completeOrders,
                  context: context,
                  buildCard: _buildCompletedOrderCard,
                  refreshOrders: refreshOrders, // Pass refresh function
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveOrderCard(Map orderMap) {
    final orderData = orderMap["order"] ?? {};
    final orderItems = (orderMap["items"] ?? []) as List;

    final finalAmount = orderData['final_amount'] ?? orderData['grand_total'] ?? orderData['amount'] ?? '';
    final orderId = orderData['id']?.toString() ?? orderData['order_id']?.toString() ?? '';
    final createdAt = orderData['order_datetime']?.toString() ?? orderData['order_date']?.toString() ?? '';
    final status = orderData['status']?.toString() ?? '';
    final itemCount = orderItems.fold<int>(0, (sum, it) => sum + (int.tryParse(it['quantity']?.toString() ?? '0') ?? 0));
    final images = orderItems.map<String>((it) => (it['image_url'] ?? it['image'] ?? '').toString()).where((u) => u.isNotEmpty).toList();

    final showImages = images.take(2).toList();
    final extraCount = images.length > 3 ? images.length - 2 : (images.length == 3 ? 1 : 0);

    // Date formatting
    String dateText = '';
    String timeText = '';
    try {
      DateTime parsedDate = DateFormat("dd-MM-yyyy hh:mm a").parse(createdAt);
      dateText = DateFormat("dd MMM").format(parsedDate);
      timeText = DateFormat("hh:mm a").format(parsedDate);
    } catch (e) {
      debugPrint("Date parsing error: $e");
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSummary(orderMap: orderMap),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("$itemCount Items",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.sp, fontWeight: FontWeight.w700)),
                Spacer(),
                Text("Order id - #000$orderId",
                    style: GoogleFonts.plusJakartaSans(fontSize: 12.sp, fontWeight: FontWeight.w700)),
              ],
            ),

            SizedBox(height: 1.h),
            Row(
              children: [
                Text(
                  '₹${(double.tryParse(finalAmount) ?? 0).toStringAsFixed(0)}',
                  style: GoogleFonts.jost(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.black54,
                  ),
                ),
                SizedBox(width: 4.w),
                Text("•",
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500, color: Colors.black54, fontSize: 12.sp)),
                SizedBox(width: 4.w),
                Text(dateText,
                    style: GoogleFonts.jost(fontSize: 10.sp, fontWeight: FontWeight.w500, color: Colors.black54)),
                SizedBox(width: 4.w),
                Text("•",
                    style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w500, color: Colors.black54, fontSize: 12.sp)),
                SizedBox(width: 4.w),
                Text(timeText,
                    style: GoogleFonts.jost(fontSize: 10.sp, fontWeight: FontWeight.w500, color: Colors.black54)),
              ],
            ),

            SizedBox(height: 8.h),
            // Order status display
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                return Text(
                  "${getText(context, "Status", "స్థితి")}: ${status.toUpperCase()}",
                  style: GoogleFonts.jost(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                );
              },
            ),

            SizedBox(height: 12.h),
            // Product list
            Row(
              children: [
                ...showImages.map((url) => _Thumb(url: url)),
                if (images.length >= 3)
                  _ThirdThumbWithOverlay(url: images[2], overlayText: extraCount > 0 ? "+$extraCount" : null),
                Spacer(),

                // OrderScreen.dart mein _buildActiveOrderCard function mein TrackOrder call update karein

                InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TrackOrder(
                          status: status,
                          orderId: orderId,
                          userId: userId, // ✅ Add userId
                          branchId: branchId, // ✅ Add branchId
                          refreshCallback: refreshOrders, // Pass refresh function
                        ),
                      ),
                    );
                  },
                  child: Container(
                    width: 120.w,
                    height: 27.h,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    child: Consumer<LanguageProvider>(
                      builder: (context, languageProvider, child) {
                        return Center(
                          child: Text(
                            getText(context, 'Track Order', 'ఆర్డర్ ట్రాక్ చేయండి'),
                            style: GoogleFonts.jost(
                              fontSize: 11.sp,
                              color: AppColors.primaryTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )


              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedOrderCard(Map orderMap) {
    final orderData = orderMap["order"] ?? {};
    final orderItems = (orderMap["items"] ?? []) as List;

    final finalAmount = orderData['final_amount'] ?? orderData['grand_total'] ?? orderData['amount'] ?? '';
    final orderId = orderData['id']?.toString() ?? orderData['order_id']?.toString() ?? '';
    final createdAt = orderData['order_datetime']?.toString() ?? orderData['order_date']?.toString() ?? '';
    final status = orderData['status']?.toString() ?? '';
    final itemCount = orderItems.fold<int>(0, (sum, it) => sum + (int.tryParse(it['quantity']?.toString() ?? '0') ?? 0));
    final images = orderItems.map<String>((it) => (it['image_url'] ?? it['image'] ?? '').toString()).where((u) => u.isNotEmpty).toList();

    final showImages = images.take(2).toList();
    final extraCount = images.length > 3 ? images.length - 2 : (images.length == 3 ? 1 : 0);

    // Date formatting
    String dateText = '';
    String timeText = '';
    try {
      DateTime parsedDate = DateFormat("dd-MM-yyyy hh:mm a").parse(createdAt);
      dateText = DateFormat("dd MMM").format(parsedDate);
      timeText = DateFormat("hh:mm a").format(parsedDate);
    } catch (e) {
      debugPrint("Date parsing error: $e");
    }

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderSummary(orderMap: orderMap),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: const Color(0xFFECECEC)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 35.w,
                  height: 35.w,
                  child: Icon(Icons.check, color: AppColors.successColor, size: 20.sp),
                  decoration: BoxDecoration(
                      color: Color(0xFF38A169).withOpacity(0.3), borderRadius: BorderRadius.circular(6.r)),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text("$itemCount Items",
                              style: GoogleFonts.plusJakartaSans(fontSize: 12.sp, fontWeight: FontWeight.w700)),
                          Spacer(),
                          Text("Order id - #000$orderId",
                              style: GoogleFonts.plusJakartaSans(fontSize: 12.sp, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      SizedBox(height: 1.h),
                      Row(
                        children: [
                          Text(
                            '₹${(double.tryParse(finalAmount) ?? 0).toStringAsFixed(0)}',
                            style: GoogleFonts.jost(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Text("•",
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w500, color: Colors.black54, fontSize: 12.sp)),
                          SizedBox(width: 4.w),
                          Text(dateText,
                              style: GoogleFonts.jost(fontSize: 10.sp, fontWeight: FontWeight.w500, color: Colors.black54)),
                          SizedBox(width: 4.w),
                          Text("•",
                              style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w500, color: Colors.black54, fontSize: 12.sp)),
                          SizedBox(width: 4.w),
                          Text(timeText,
                              style: GoogleFonts.jost(fontSize: 10.sp, fontWeight: FontWeight.w500, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 8.h),
            // Order status display
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                return Text(
                  "${getText(context, "Status", "స్థితి")}: ${status.toUpperCase()}",
                  style: GoogleFonts.jost(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(status),
                  ),
                );
              },
            ),

            SizedBox(height: 12.h),
            // Product list
            Row(
              children: [
                ...showImages.map((url) => _Thumb(url: url)),
                if (images.length >= 3)
                  _ThirdThumbWithOverlay(url: images[2], overlayText: extraCount > 0 ? "+$extraCount" : null),
                Spacer(),

                // Track Order button for completed orders too
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => OrderSummary(orderMap: orderMap)));
                  },
                  child: Container(
                    width: 120.w,
                    height: 27.h,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(7.r),
                    ),
                    child: Consumer<LanguageProvider>(
                      builder: (context, languageProvider, child) {
                        return Center(
                          child: Text(
                            getText(context, 'View Details', 'వివరాలు చూడండి'),
                            style: GoogleFonts.jost(
                              fontSize: 11.sp,
                              color: AppColors.primaryTextColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('delivered') || statusLower.contains('completed')) {
      return Colors.green;
    } else if (statusLower.contains('cancelled') || statusLower.contains('canceled')) {
      return Colors.red;
    } else if (statusLower.contains('processing') || statusLower.contains('shipped')) {
      return Colors.orange;
    } else {
      return Colors.orange;
    }
  }
}

// ================== SMALL WIDGETS ===================

class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabController, required this.context});
  final TabController tabController;
  final BuildContext context;

  // Helper method to get text based on language
  String getText(String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 16.w, right: 16.w),
      child: Container(
        child: TabBar(
          controller: tabController,
          isScrollable: false,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: UnderlineTabIndicator(
            borderSide: BorderSide(
              width: 3.w,
              color: AppColors.primaryColor,
            ),
            insets: EdgeInsets.zero,
          ),
          labelColor: Colors.black,
          unselectedLabelColor: Colors.black54,
          tabs: [
            Tab(
              child: Text(
                getText('Active', 'యాక్టివ్'),
                style: GoogleFonts.jost(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Tab(
              child: Text(
                getText('History', 'చరిత్ర'),
                style: GoogleFonts.jost(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderList extends StatelessWidget {
  const _OrderList({
    required this.orders,
    required this.context,
    required this.buildCard,
    required this.refreshOrders,
  });

  final List orders;
  final BuildContext context;
  final Widget Function(Map order) buildCard;
  final Future<void> Function() refreshOrders;

  // Helper method to get text based on language
  String getText(String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  @override
  Widget build(BuildContext context) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          getText('No orders found', 'ఆర్డర్లు కనుగొనబడలేదు'),
          style: TextStyle(fontSize: 14.sp),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: refreshOrders,
      child: ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: orders.length,
        itemBuilder: (_, i) => buildCard(orders[i] as Map),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url});
  final String url;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 40.w,
      margin: EdgeInsets.only(right: 8.w),
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
      clipBehavior: Clip.antiAlias,
      child: url.isEmpty
          ? const Icon(Icons.image_not_supported_outlined)
          : Padding(
        padding: const EdgeInsets.all(8.0),
        child: Image.network(url, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class _ThirdThumbWithOverlay extends StatelessWidget {
  const _ThirdThumbWithOverlay({required this.url, this.overlayText});
  final String url;
  final String? overlayText;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        _Thumb(url: url),
        if (overlayText != null)
          Positioned(
            child: Container(
              width: 40.w,
              height: 35.h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.45),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(overlayText!,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12.sp)),
            ),
          ),
      ],
    );
  }
}