import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../Help/help_screen.dart';
import '../compat/app_state.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';

class TrackOrder extends StatefulWidget {
  /// The new-backend order id (cuid) — used to fetch the live order.
  final String orderId;
  final String status;
  final String userId;
  final String branchId;
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
  bool isLoading = false;
  String _currentStatus = '';

  /// Branch-admin-set estimated delivery date/time, fetched from the backend.
  DateTime? _estimatedDeliveryAt;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.status;
    _setCurrentStepFromStatus();
    _fetchOrder();
  }

  /// Fetches the live order (status + estimated delivery) from the new backend,
  /// replacing the legacy per-card PHP calls.
  Future<void> _fetchOrder() async {
    if (widget.orderId.isEmpty) return;
    try {
      final order = await Repos.orders.getById(widget.orderId);
      if (!mounted) return;
      setState(() {
        _currentStatus = order.status;
        _estimatedDeliveryAt = order.estimatedDeliveryAt;
        _setCurrentStepFromStatus();
      });
    } catch (e) {
      debugPrint("Error fetching order: $e");
    }
  }

  Future<void> refreshData() async {
    setState(() => isLoading = true);
    try {
      await _fetchOrder();
      widget.refreshCallback?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order status updated'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to update status'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /// Maps the backend order status enum onto the 4-step tracking timeline.
  void _setCurrentStepFromStatus() {
    switch (_currentStatus.toUpperCase()) {
      case "PENDING":
      case "CONFIRMED":
        currentStep = 0;
        break;
      case "PREPARING":
        currentStep = 1;
        break;
      case "OUT_FOR_DELIVERY":
        currentStep = 2;
        break;
      case "DELIVERED":
      case "CANCELLED":
        currentStep = 3;
        break;
      default:
        currentStep = 0;
    }
  }

  bool get _isCancelled => _currentStatus.toUpperCase() == 'CANCELLED';

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
                  color: Colors.black.withValues(alpha: 0.1),
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
                        child: Icon(Icons.arrow_back_ios,
                            color: AppColors.iconColor, size: 15.sp),
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
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => HelpScreen()));
                  },
                  child: Container(
                    height: 25.h,
                    width: 28.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                    child: Center(
                      child: Icon(Icons.help_outline,
                          color: AppColors.searchBorderHome, size: 22.sp),
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
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: AppColors.primaryColor,
                  width: 1.3.w,
                ),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: _buildEstimatedDelivery(),
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
                    subtitle:
                        "Our delivery partner will soon deliver the product",
                  ),
                  orderStep(
                    stepIndex: 3,
                    icon: _isCancelled ? "❌" : "✅",
                    title:
                        _isCancelled ? "Order Cancelled" : "Product Delivered",
                    subtitle: _isCancelled
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

  /// The estimated-delivery block: shows the branch-admin date/time as
  /// "by date : time", or falls back to the branch delivery-time text.
  Widget _buildEstimatedDelivery() {
    if (_isCancelled) {
      return Column(
        children: [
          Text("Order Cancelled",
              style: GoogleFonts.jost(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red)),
        ],
      );
    }

    final dt = _estimatedDeliveryAt?.toLocal();

    if (dt != null) {
      final dateStr = DateFormat('dd MMM yyyy').format(dt);
      final timeStr = DateFormat('h:mm a').format(dt);
      return Column(
        children: [
          Text("Estimated Delivery",
              style: GoogleFonts.jost(fontSize: 12.sp, color: Colors.black)),
          SizedBox(height: 6.h),
          Text("by",
              style: GoogleFonts.jost(
                  fontSize: 14.sp, color: AppColors.searchBorderHome)),
          SizedBox(height: 2.h),
          Text(
            "$dateStr  :  $timeStr",
            textAlign: TextAlign.center,
            style: GoogleFonts.jost(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: AppColors.searchBorderHome,
            ),
          ),
          SizedBox(height: 8.h),
        ],
      );
    }

    // No admin-set time yet → show the branch delivery-time text (e.g. "30 Minutes").
    final fallback = AppState.deliveryTimeText.trim();
    return Column(
      children: [
        Text("Estimated Delivery",
            style: GoogleFonts.jost(fontSize: 12.sp, color: Colors.black)),
        SizedBox(height: 4.h),
        Text(
          fallback.isNotEmpty ? fallback : "Not available",
          textAlign: TextAlign.center,
          style: GoogleFonts.jost(
            fontSize: 30.sp,
            fontWeight: FontWeight.bold,
            color: AppColors.searchBorderHome,
          ),
        ),
        SizedBox(height: 8.h),
      ],
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
                color:
                    isCompleted ? AppColors.searchBorderHome : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: isCompleted
                  ? Icon(Icons.check,
                      color: AppColors.backgroundColor, size: 16.sp)
                  : null,
            ),
            if (stepIndex != 3)
              Container(
                width: 3.w,
                height: 70.h,
                color: stepIndex < currentStep
                    ? AppColors.primaryColor
                    : Colors.grey[300],
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
}
