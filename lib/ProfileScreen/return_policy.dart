import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/colors.dart';

class ReturnPolicy extends StatefulWidget {
  const ReturnPolicy({super.key});

  @override
  State<ReturnPolicy> createState() => _ReturnPolicyState();
}

class _ReturnPolicyState extends State<ReturnPolicy> {
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
                  "Shipping Policy",
                  style: GoogleFonts.jost(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 18.h),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Shipping Policy – Nexamart",
                    style: GoogleFonts.jost(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "Please read our delivery policy before placing an order.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("📍 Delivery Areas", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "We currently deliver in Ongole.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("⏱ Delivery Time", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "Orders are delivered within 2 hours depending on your location and slot availability.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("💰 Delivery Charges", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Free delivery on orders above ₹349.\n"
                        "• A small delivery charge of ₹20–₹40 applies on orders below the minimum value.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("📦 Order Tracking", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "You can track your order status directly in the Nexamart app.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("⚠ Failed Deliveries", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "If a delivery attempt fails due to incorrect address, unavailability of the customer, or any reason not caused by Nexamart, the order may be canceled or rescheduled with additional charges.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 20.h),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextStyle sectionTitle() {
    return GoogleFonts.jost(
      fontSize: 16.sp,
      fontWeight: FontWeight.w700,
      color: AppColors.primaryTextColor,
    );
  }

  TextStyle sectionText() {
    return GoogleFonts.jost(
      fontSize: 14.sp,
      color: AppColors.hintTextColor,
      height: 1.5,
    );
  }
}
