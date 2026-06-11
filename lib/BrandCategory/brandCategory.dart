import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../SearchProduct/search_product.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import 'brand_view_screen.dart';
import '../Provider/language_provider.dart'; // Add this import

class BrandCategory extends StatefulWidget {
  const BrandCategory({super.key});

  @override
  State<BrandCategory> createState() => _BrandCategoryState();
}

class _BrandCategoryState extends State<BrandCategory> {
  List _brandsList = [];
  int branchId = 0;
  String branchName  = "";

  @override
  void initState() {
    super.initState();
    fetchLocation();
  }

  // Helper method to get text based on language
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
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

      await  _fetchBrands();
    }
  }

  Future<void> _fetchBrands() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.VIEW_BRAND}?branch_id=$branchId'));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];

          if (mounted) {
            setState(() {
              _brandsList = data;
            });
          }
        } else {
          debugPrint("No brand found");
        }
      } else {
        debugPrint('Failed to load brands. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error while fetching brands: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: 14.h),
          buildAppBar(),
          Expanded(
            child: _brandsList.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: AppColors.primaryColor,
                  ),
                  SizedBox(height: 16.h),
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, child) {
                      return Text(
                        getText(context, "Loading brands...", "బ్రాండ్లు లోడ్ అవుతున్నాయి..."),
                        style: GoogleFonts.jost(
                          fontSize: 14.sp,
                          color: AppColors.primaryTextColor,
                        ),
                      );
                    },
                  ),
                ],
              ),
            )
                : Padding(
              padding: EdgeInsets.all(12.w),
              child: GridView.builder(
                padding: EdgeInsets.zero,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 0.w,
                  mainAxisSpacing: 15.h,
                  childAspectRatio: 0.9,
                ),
                itemCount: _brandsList.length,
                itemBuilder: (context, index) {
                  final brand = _brandsList[index];
                  return InkWell(
                    onTap: (){
                      Navigator.push(context, MaterialPageRoute(builder: (context)=>BrandViewScreen(brandName: brand['brand_name'])));
                    },
                    child: Padding(
                      padding:  EdgeInsets.all(8.0.w),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding:  EdgeInsets.only(bottom: 0.h),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // ✅ Brand Image
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8.r),
                                child: Image.network(
                                  ApiConstants.BASE_URL +
                                      "/brand_api/${brand['brand_image']}",
                                  height: 60.h,
                                  width: 60.w,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(Icons.image, size: 40),
                                ),
                              ),
                              SizedBox(height: 10.h),
                              // ✅ Brand Name - This comes from API, no language change here
                              Text(
                                brand['brand_name'] ?? "No Name",
                                style: GoogleFonts.jost(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ Top AppBar
  Widget buildAppBar() {
    return Container(
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
        padding:  EdgeInsets.only(top: 16.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 16.w),
            InkWell(
              onTap: () {
                Navigator.pop(context);
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
                    child: Icon(Icons.arrow_back_ios,color: AppColors.iconColor, size: 15.sp),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                return Text(
                  getText(context, "Brands", "బ్రాండ్లు"),
                  style: GoogleFonts.jost(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w700,
                  ),
                );
              },
            ),
            Spacer(),
            InkWell(
              onTap: () {
                Navigator.push(context,
                    MaterialPageRoute(builder: (context) => SearchProduct()));
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
                    padding: EdgeInsets.only(left: 1.w),
                    child: Icon(Icons.search,color: AppColors.iconColor, size: 15.sp),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
          ],
        ),
      ),
    );
  }
}