import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/colors.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
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
                        child: Icon(Icons.arrow_back_ios,color: AppColors.iconColor, size: 15.sp),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Text(
                  "About",
                  style: GoogleFonts.jost(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 20.h),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "About Us",
                    style: GoogleFonts.jost(
                      fontSize: 20.sp,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primaryColor,
                    ),
                  ),
                  SizedBox(height: 12.h),

                  Text(
                    "Welcome to Nexamart, your trusted online grocery delivery partner. We believe grocery shopping should be simple, fast, and stress-free. That’s why we bring fresh fruits, vegetables, daily essentials, packaged goods, and more directly to your doorstep.",
                    style: GoogleFonts.jost(
                      fontSize: 14.sp,
                      color: AppColors.hintTextColor,
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 10.h),

                  Text(
                    "At Nexamart, we focus on:\n\n"
                        "• Quality Products – Only the best items are selected for you.\n"
                        "• On-Time Delivery – Groceries delivered when you need them.\n"
                        "• Affordable Prices – Everyday essentials at pocket-friendly rates.\n"
                        "• Customer Care – Quick support whenever you need help.",
                    style: GoogleFonts.jost(
                      fontSize: 14.sp,
                      color: AppColors.hintTextColor,
                      height: 1.6,
                    ),
                  ),

                  SizedBox(height: 10.h),

                  Text(
                    "Whether it’s your weekly grocery list or a last-minute need, Nexamart makes shopping easy, reliable, and convenient.",
                    style: GoogleFonts.jost(
                      fontSize: 14.sp,
                      color: AppColors.hintTextColor,
                      height: 1.5,
                    ),
                  ),

                  SizedBox(height: 20.h),

                  Center(
                    child: Text(
                      "Nexamart — Freshness Delivered.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jost(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
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
}
