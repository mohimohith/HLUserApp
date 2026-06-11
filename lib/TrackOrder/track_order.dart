import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../Help/help_screen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';

class TrackOrder extends StatefulWidget {
  final String status;
  final String orderId;
  final String userId;
  final int branchId;
  final VoidCallback? refreshCallback;

  const TrackOrder({
    super.key,
    required this.status,
    required this.orderId,
    required this.userId,
    required this.branchId,
    this.refreshCallback,
  });

  @override
  State<TrackOrder> createState() => _TrackOrderState();
}

class _TrackOrderState extends State<TrackOrder> {
  int currentStep = 0;
  String deliveryTime = '0';
  bool isLoading = false;
  String _currentStatus = '';
  List<dynamic> _allOrders = [];

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _setCurrentStepFromStatus();
    fetchDeliveryTime();
    _fetchLatestOrderStatus();
  }

  // ✅ API se latest order status fetch karega
  Future<void> _fetchLatestOrderStatus() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.GET_ORDER_BY_USER),
        body: {
          "user_id": widget.userId,
          "branch_id": widget.branchId.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _allOrders = (data["orders"] ?? []) as List;

          // Current order ka latest status find kare
          final currentOrder = _allOrders.firstWhere(
                (order) => (order["order"]?["id"]?.toString() ?? order["order"]?["order_id"]?.toString()) == widget.orderId,
            orElse: () => null,
          );

          if (currentOrder != null) {
            final latestStatus = currentOrder["order"]?["status"]?.toString() ?? widget.status;
            _currentStatus = latestStatus;
            _setCurrentStepFromStatus();
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching latest order status: $e");
    }
  }

  // ✅ Complete refresh function
  Future<void> refreshData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // 1. Latest order status fetch kare
      await _fetchLatestOrderStatus();

      // 2. Delivery time update kare
      await fetchDeliveryTime();

      // 3. Parent ko refresh ke liye notify kare
      if (widget.refreshCallback != null) {
        widget.refreshCallback!();
      }

      // Success message show kare
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Error message show kare
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update status'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchDeliveryTime() async {
    try {
      final url = Uri.parse(
        "${ApiConstants.DELIVERY_TIME}?branch_id=${widget.branchId}",
      );

      debugPrint("Delivery Time API URL: $url");

      final response = await http.get(url);

      debugPrint("Delivery Time Response: ${response.body}");

      if (response.statusCode != 200) {
        setState(() {
          deliveryTime = 'Server Error';
        });
        return;
      }

      final data = jsonDecode(response.body);

      final success = data['success'] == true ||
          data['success'] == 1 ||
          data['success'] == "true";

      if (success && data['data'] != null) {
        setState(() {
          deliveryTime = data['data']['time'].toString();
        });
      } else {
        setState(() {
          deliveryTime = 'Not available';
        });
      }
    } catch (e) {
      debugPrint("Delivery Time Error: $e");
      setState(() {
        deliveryTime = 'Error';
      });
    }
  }

  void _setCurrentStepFromStatus() {
    final status = _currentStatus.toLowerCase();
    switch (status) {
      case "pending":
        currentStep = 0;
        break;
      case "packed":
        currentStep = 1;
        break;
      case "way":
        currentStep = 2;
        break;
      case "delivered":
        currentStep = 3;
        break;
      case "completed":
        currentStep = 3;
        break;
      case "cancelled":
      case "canceled":
        currentStep = 3; // Cancelled bhi last step mein dikhega
        break;
      default:
        currentStep = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 17.h),

          // Header
          Container(
            width: double.infinity,
            height: 55.h,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  offset: Offset(0, 4.h),
                  blurRadius: 6.r,
                  spreadRadius: 1.r,
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(width: 16.w),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    height: 25.h,
                    width: 28.w,
                    decoration: BoxDecoration(
                      color: AppColors.primaryColor,
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(left: 7.w),
                        child: Icon(Icons.arrow_back_ios, color: AppColors.iconColor, size: 15.sp),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Text(
                  "Track Order",
                  style: GoogleFonts.jost(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                Spacer(),

                // Refresh Button
                IconButton(
                  onPressed: refreshData,
                  icon: isLoading
                      ? SizedBox(
                    width: 20.sp,
                    height: 20.sp,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.searchBorderHome,
                    ),
                  )
                      : Icon(
                    Icons.refresh,
                    color: AppColors.searchBorderHome,
                    size: 22.sp,
                  ),
                ),

                SizedBox(width: 8.w),

                // Help Button
                InkWell(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => HelpScreen()));
                  },
                  child: Container(
                    height: 25.h,
                    width: 28.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                    child: Center(
                      child: Icon(Icons.help_outline, color: AppColors.searchBorderHome, size: 22.sp),
                    ),
                  ),
                ),
                SizedBox(width: 20.w),
              ],
            ),
          ),

          // Loading Indicator
          if (isLoading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10.h),
              child: LinearProgressIndicator(
                minHeight: 2.h,
                backgroundColor: AppColors.backgroundColor,
                color: AppColors.primaryColor,
              ),
            ),



          // Estimated Delivery Card
          Padding(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 20.h),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.primaryColor,
                  width: 1.3.w,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  children: [
                    Text(
                      "Estimated Delivery",
                      style: GoogleFonts.jost(fontSize: 12.sp, color: Colors.black),
                    ),
                    SizedBox(height: 4.h),

                    // Delivery Time Text
                    Text(
                      deliveryTime == "1" ? "close" : formatDeliveryTime(deliveryTime),
                      style: GoogleFonts.jost(
                        fontSize: 36.sp,
                        fontWeight: FontWeight.bold,
                        color: deliveryTime == "1" ? Colors.red : AppColors.searchBorderHome,
                      ),
                    ),

                    // Agar deliveryTime 1 hai to "Minutes" hide karo
                    if (deliveryTime != "1")
                      Text(
                        "Minutes",
                        style: GoogleFonts.jost(
                          fontSize: 16.sp,
                          color: AppColors.searchBorderHome,
                        ),
                      ),

                    SizedBox(height: 8.h),


                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 10.h),

          // Order Steps
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: 40.w),
              child: ListView(
                children: [
                  orderStep(
                    stepIndex: 0,
                    icon: "🛒",
                    title: "Order Placed",
                    subtitle: "We have received your order",
                  ),
                  orderStep(
                    stepIndex: 1,
                    icon: "📦",
                    title: "Order Packed",
                    subtitle: "Your product is packed and ready to ship",
                  ),
                  orderStep(
                    stepIndex: 2,
                    icon: "🛵",
                    title: "On the way",
                    subtitle: "Our delivery partner will soon deliver the product",
                  ),
                  orderStep(
                    stepIndex: 3,
                    icon: _currentStatus.toLowerCase().contains('cancelled') ? "❌" : "✅",
                    title: _currentStatus.toLowerCase().contains('cancelled')
                        ? "Order Cancelled"
                        : "Product Delivered",
                    subtitle: _currentStatus.toLowerCase().contains('cancelled')
                        ? "Your order has been cancelled"
                        : "Your order has been delivered to your provided address.",
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget orderStep({
    required int stepIndex,
    required String icon,
    required String title,
    required String subtitle,
  }) {
    bool isCompleted = stepIndex <= currentStep;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step line and circle
        Column(
          children: [
            Container(
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: isCompleted ? AppColors.searchBorderHome : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: isCompleted
                  ? Icon(Icons.check, color: AppColors.backgroundColor, size: 16.sp)
                  : null,
            ),
            if (stepIndex != 3)
              Container(
                width: 3.w,
                height: 70.h,
                color: stepIndex < currentStep ? AppColors.primaryColor : Colors.grey[300],
              ),
          ],
        ),
        SizedBox(width: 15.w),

        // Step content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(icon, style: GoogleFonts.jost(fontSize: 18.sp)),
                  SizedBox(width: 6.w),
                  Text(
                    title,
                    style: GoogleFonts.jost(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 4.h),
              Text(
                subtitle,
                style: GoogleFonts.jost(fontSize: 12.sp, color: Colors.black54),
              ),
              SizedBox(height: 20.h),
            ],
          ),
        ),
      ],
    );
  }

  String formatDeliveryTime(String input) {
    input = input.replaceAll(' ', '');
    final match = RegExp(r'^(\d+)([a-zA-Z]+)').firstMatch(input);

    if (match != null) {
      final number = match.group(1) ?? '';
      final unit = match.group(2)?.substring(0, 0).toUpperCase() ?? '';
      return '$number $unit';
    } else {
      return input.substring(0, input.length.clamp(0, 6)).toUpperCase();
    }
  }

  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('delivered') || statusLower.contains('completed')) {
      return Colors.green;
    } else if (statusLower.contains('cancelled') || statusLower.contains('canceled')) {
      return Colors.red;
    } else if (statusLower.contains('processing') || statusLower.contains('shipped') || statusLower.contains('way')) {
      return Colors.orange;
    } else if (statusLower.contains('packed')) {
      return Colors.blue;
    } else {
      return Colors.orange;
    }
  }

  String _getStatusDescription(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('delivered')) {
      return "Order has been successfully delivered";
    } else if (statusLower.contains('completed')) {
      return "Order has been completed";
    } else if (statusLower.contains('cancelled') || statusLower.contains('canceled')) {
      return "Order has been cancelled";
    } else if (statusLower.contains('processing')) {
      return "Order is being processed";
    } else if (statusLower.contains('packed')) {
      return "Order has been packed";
    } else if (statusLower.contains('way')) {
      return "Order is on the way";
    } else {
      return "Order is pending";
    }
  }
}