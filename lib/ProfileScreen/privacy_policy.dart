import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import '../utils/colors.dart';

class PrivacyPolicy extends StatefulWidget {
  const PrivacyPolicy({super.key});

  @override
  State<PrivacyPolicy> createState() => _PrivacyPolicyState();
}

class _PrivacyPolicyState extends State<PrivacyPolicy> {
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
                  "Privacy Policy",
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
                    "Privacy Policy – Nexamart",
                    style: GoogleFonts.jost(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    "At Nexamart, your privacy is important to us. This policy explains how we collect, use, and protect your information.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("🔹 Information We Collect", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• Personal details like name, address, email, and phone number.\n"
                        "• Payment details (processed securely through third-party gateways).\n"
                        "• Location details to ensure accurate delivery.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("🔹 How We Use Your Information", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• To process and deliver your orders.\n"
                        "• To send updates, offers, and notifications (only if you opt-in).\n"
                        "• To improve our services and customer experience.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text("🔹 Data Protection", style: sectionTitle()),
                  SizedBox(height: 8.h),
                  Text(
                    "• We never sell or share your personal data with unauthorized parties.\n"
                        "• Your data may be shared only for delivery, payment processing, or legal compliance.\n"
                        "• All sensitive information is stored and transmitted securely.",
                    style: sectionText(),
                  ),

                  SizedBox(height: 16.h),
                  Text(
                    "By using Nexamart, you agree to the collection and use of your information under this Privacy Policy.",
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
