import 'dart:convert';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/api_constants.dart';
import '../utils/colors.dart';


class CouponScreen extends StatefulWidget {
  const CouponScreen({super.key});

  @override
  State<CouponScreen> createState() => _CouponScreenState();
}

class _CouponScreenState extends State<CouponScreen> {
  List<Map<String, dynamic>> _couponList = [];

  int branchId = 0;
  String branchName  = "";



  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    fetchLocation();
  }

  Future<void> fetchLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? uArea = prefs.getString('user_area_h');
    String? uCity = prefs.getString('user_city_h');
    int bId = prefs.getInt('selected_branch_id') ?? 0;
    String? bName  = prefs.getString('selected_branch_name');

    // agar dono me se koi ek bhi null na ho
    if ((uArea != null && uArea.trim().isNotEmpty) ||
        (uCity != null && uCity.trim().isNotEmpty)) {
      setState(() {
        branchId = bId;
        branchName = bName ?? "";
      });

      await  _fetchCoupons();
    }
  }



  Future<void> _fetchCoupons() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.VIEW_COUPON}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          setState(() => _couponList = List<Map<String, dynamic>>.from(decoded['data']));
        }
      }
    } catch (e) {
      debugPrint("Error fetching coupons: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body:
      Column(
        children: [
          // Header

          SizedBox(height: 17.h,),
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
              padding:  EdgeInsets.only(top: 14.h),
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
                          child: Icon(Icons.arrow_back_ios,color: AppColors.iconColor, size: 15.sp),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Text(
                    "Coupon",
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

          SizedBox(height: 10.h,),

      Expanded(
        child: Builder(
          builder: (context) {
            // Sirf wahi coupons show honge jinka status "Private" nahi hai
            final visibleCoupons = _couponList
                .where((coupon) => coupon['status'] != "Private")
                .toList();

            return ListView.builder(
              padding: EdgeInsets.zero,
              scrollDirection: Axis.vertical,
              itemCount: visibleCoupons.length,
              itemBuilder: (context, index) {
                final coupon = visibleCoupons[index];

                return InkWell(
                  onTap: () {
                    Clipboard.setData(
                      ClipboardData(text: coupon['code_name']),
                    );
                    Fluttertoast.showToast(
                      msg: "Coupon code copied!",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                      backgroundColor: Colors.black87,
                      textColor: Colors.white,
                      fontSize: 14.sp,
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    height: 85.h,
                    margin: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                    decoration: const BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/images/coupons.png'),
                        fit: BoxFit.fill,
                      ),
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                              left: 20.w, right: 15.w, top: 6.h, bottom: 4.h),
                          child: Row(
                            children: [
                              Text(
                                'Coupon',
                                style: GoogleFonts.jost(
                                  color: AppColors.secondaryColor,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.sp,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.backgroundColor,
                                  borderRadius: BorderRadius.circular(3.r),
                                ),
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 10.w, vertical: 2.h),
                                  child: Center(
                                    child: Text(
                                      'Valid ${coupon['expri_date']}',
                                      style: GoogleFonts.jost(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
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
                          padding: EdgeInsets.only(
                              left: 25.w, right: 20.w, top: 10.h),
                          child: Row(
                            children: [
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      SvgPicture.asset(
                                        'assets/svg/coupon.svg',
                                        width: 18.w,
                                        color: AppColors.secondaryColor,
                                      ),
                                      SizedBox(width: 4.w),
                                      Text(
                                        coupon['title'],
                                        style: GoogleFonts.jost(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  Text(
                                    coupon['description'],
                                    style: GoogleFonts.jost(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12.sp,
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
                                      coupon['code_name'],
                                      style: GoogleFonts.jost(
                                        fontSize: 12.sp,
                                        color: AppColors.primaryColor,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                              )
                            ],
                          ),
                        )
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),

      ],
      ),
    );
  }
}
