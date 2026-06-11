import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../../CategoryViewScreen/categoryViewScreen.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import '../bottomNavScreen.dart';
import '../../Provider/language_provider.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  List categories = [];
  bool isLoading = true;
  bool hasError = false;
  String errorMessage = '';

  int branchId = 0;
  String branchName  = "";

  @override
  void initState() {
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

      await  fetchMainCategoriesWithCategories();
    }
  }

  Future<void> fetchMainCategoriesWithCategories() async {
    if (branchId == 0) return; // ⛔ Fix added

    try {
      final url = Uri.parse('${ApiConstants.VIEW_MAIN_CATEGORY_CATEGORY}?branch_id=$branchId');
      final response = await http.get(url).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data is List) {
          categories = data;
        } else if (data is Map && data["success"] == true && data["data"] is List) {
          categories = data["data"];
        } else {
          throw Exception('Invalid Format From API');
        }
      } else {
        throw Exception('Failed: ${response.statusCode}');
      }
    } catch (e) {
      hasError = true;
      errorMessage = e.toString();
      debugPrint('Error fetching categories: $e');
    }

    if (mounted) setState(() => isLoading = false);
  }

  void onSubcategoryTap(int categoryId, String categoryImage, String categoryName, int subcategoryId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CategoryViewScreen(
          categoryId: categoryId,
          categoryImage: categoryImage,
          categoryName: categoryName,
          branchId: branchId,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Error loading categories',
            style: GoogleFonts.jost(
              fontSize: 16.sp,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            errorMessage,
            textAlign: TextAlign.center,
            style: GoogleFonts.jost(fontSize: 14.sp),
          ),
          SizedBox(height: 20.h),
          ElevatedButton(
            onPressed: fetchMainCategoriesWithCategories,
            child: Text('Retry', style: GoogleFonts.jost()),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: CircularProgressIndicator(
        color: AppColors.primaryColor,
      ),
    );
  }

  Widget _buildCategoryItem(Map<String, dynamic> category) {
    final subcategories = (category['subcategories'] as List?) ?? [];
    if (subcategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Main category title with language support
        Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            // Get the appropriate name based on language
            String categoryName = category['name']?.toString() ?? 'Unnamed Category';
            if (languageProvider.selectedLanguage == "Telugu") {
              String teluguName = category['name_telugu']?.toString() ?? '';
              if (teluguName.isNotEmpty) {
                categoryName = teluguName;
              }
            }

            return Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
              child: Text(
                categoryName,
                style: GoogleFonts.jost(
                  fontSize: 18.sp,
                ),
              ),
            );
          },
        ),

        // Subcategories grid
        GridView.builder(
          itemCount: subcategories.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 14.h,
            crossAxisSpacing: 12.w,
            childAspectRatio: 0.70,
          ),
          itemBuilder: (context, subIndex) {
            final subcat = subcategories[subIndex];
            final imageUrl = subcat['image'] != null
                ? ApiConstants.BASE_URL+"/category_api/${subcat['image']}"
                : '';

            return Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                // Get the appropriate subcategory name based on language
                String subcatName = subcat['name']?.toString() ?? 'Unnamed Subcategory';
                if (languageProvider.selectedLanguage == "Telugu") {
                  String teluguName = subcat['name_telugu']?.toString() ?? '';
                  if (teluguName.isNotEmpty) {
                    subcatName = teluguName;
                  }
                }

                return InkWell(
                  onTap: () {
                    if (category['id'] != null && subcat['id'] != null) {
                      onSubcategoryTap(
                        int.tryParse(subcat['id'].toString()) ?? 0,
                        subcat['image']?.toString() ?? '',
                        subcatName,
                        // subcat['name']?.toString() ?? '',
                        // subcat['name']?.toString() ?? '',
                        int.tryParse(category['id'].toString()) ?? 0,
                      );
                    }
                  },
                  child: Column(
                    children: [
                      Container(
                        width: 65.w,
                        height: 65.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Center(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8.r),
                            child: imageUrl.isNotEmpty
                                ? Image.network(
                              imageUrl,
                              width: 60.w,
                              height: 60.h,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Image.asset(
                                "assets/images/placeholder_categor.png",
                                fit: BoxFit.cover,
                              ),
                            )
                                : Icon(Icons.category, size: 30.sp),
                          ),
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Text(
                        subcatName,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.jost(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
        SizedBox(height: 14.h),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: 20.h),
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
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 10.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(width: 17.w),
                    InkWell(
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
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>BottomNavScreen()));
                      },
                    ),
                    SizedBox(width: 16.w),

                    // Title with language support
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, child) {
                        return Text(
                          languageProvider.selectedLanguage == "Telugu" ? 'అన్ని వర్గాలు' : 'All Categories',
                          style: GoogleFonts.jost(
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: hasError
                ? _buildErrorWidget()
                : isLoading
                ? _buildLoadingWidget()
                : categories.isEmpty
                ? Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                return Center(
                  child: Text(
                    languageProvider.selectedLanguage == "Telugu"
                        ? 'వర్గాలు కనుగొనబడలేదు'
                        : 'No categories found',
                    style: GoogleFonts.jost(fontSize: 16.sp),
                  ),
                );
              },
            )
                : RefreshIndicator(
              onRefresh: () => fetchMainCategoriesWithCategories(),
              child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return _buildCategoryItem(category);
              },
            ),
                ),
          )
        ],
      ),
    );
  }
}