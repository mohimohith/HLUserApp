import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/colors.dart';

class TermsCondition extends StatefulWidget {
  const TermsCondition({super.key});

  @override
  State<TermsCondition> createState() => _TermsConditionState();
}

class _TermsConditionState extends State<TermsCondition> {
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
                  "Terms & Conditions",
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
                    "Terms & Conditions – Nexamart",
                    style: GoogleFonts.jost(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "By downloading and using the Nexamart app, you agree to the following terms. Please read carefully before proceeding.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 18.h),
                  Text("1️⃣ Use of Service", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• The app is for personal, non-commercial use only.\n"
                        "• You agree to provide accurate information while placing orders.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 18.h),
                  Text("2️⃣ Orders & Pricing", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Prices and item availability may change without notice.\n"
                        "• In case of incorrect pricing, we reserve the right to cancel or modify the order.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 18.h),
                  Text("3️⃣ Payments", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Payments can be made online or via Cash on Delivery (if available).\n"
                        "• Orders are processed only after successful payment confirmation.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 18.h),
                  Text("4️⃣ Cancellations & Refunds", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Orders can be canceled before dispatch.\n"
                        "• Refunds, if applicable, will be processed within 3–4 business days.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 18.h),
                  Text("5️⃣ Delivery", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• We aim to deliver on time, but delays may occur due to unforeseen issues.\n"
                        "• Customers must ensure availability at the delivery location.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 18.h),
                  Text("6️⃣ Prohibited Use", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Fraud, misuse, or violation of laws may result in account termination.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 18.h),
                  Text("7️⃣ Limitation of Liability", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Nexamart is not responsible for indirect, incidental, or consequential losses resulting from use of the app or services.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 25.h),
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
