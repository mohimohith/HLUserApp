import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../Provider/language_provider.dart';

import '../compat/app_state.dart';
import '../compat/legacy_adapters.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';
import 'categoryViewScreen.dart';

class MainCategoryView extends StatefulWidget {
  final String categoy_id;
  final String category_name;
  final String branchID;

  MainCategoryView({
    required this.categoy_id,
    required this.category_name,
    this.branchID = '',
  });

  @override
  State<MainCategoryView> createState() => _MainCategoryViewState();
}

class _MainCategoryViewState extends State<MainCategoryView> {
  List categories = [];
  bool isLoading = true;
  bool hasError = false;

  String get branchId =>
      widget.branchID.isNotEmpty ? widget.branchID : AppState.branchIdOrEmpty;

  // Helper method to get text based on selected language
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  Future<void> fetchCategories(String categoryId) async {
    try {
      // Categories under the selected main category come from /home.
      final home = await Repos.home.getHome(branchId);
      final match = home.mainCategories
          .where((m) => m.id == categoryId)
          .toList();

      final List<Map<String, dynamic>> mapped = match.isNotEmpty
          ? match.first.categories.map(LegacyAdapters.category).toList()
          : <Map<String, dynamic>>[];

      if (!mounted) return;
      setState(() {
        categories = mapped;
        isLoading = false;
        hasError = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        hasError = true;
        isLoading = false;
      });
      debugPrint('Fetch Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    fetchCategories(widget.categoy_id);
  }

  Widget _buildCategoryGrid(List categories) {
    return GridView.builder(
      itemCount: categories.length,
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 14.h,
        crossAxisSpacing: 12.w,
        childAspectRatio: 0.72,
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        final name = category['category_name'] ??
            getText(context, 'No Name', 'పేరు లేదు'); // Fallback text
        // Absolute image URL from the adapter; use it directly.
        final imageUrl = (category['category_image'] ?? '').toString();

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CategoryViewScreen(
                  categoryId: category['category_id'].toString(),
                  categoryName: category['category_name'],
                  categoryImage: imageUrl,
                  branchId: branchId,
                ),
              ),
            );
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
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.broken_image, size: 30.sp),
                    )
                        : Icon(Icons.category, size: 30.sp),
                  ),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                name,
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
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 50.sp, color: Colors.red),
          SizedBox(height: 16.h),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return Text(
                getText(
                  context,
                  'Category Not Available',
                  'కేటగిరీ అందుబాటులో లేదు',
                ),
                style: GoogleFonts.jost(fontSize: 16.sp),
              );
            },
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              setState(() {
                isLoading = true;
                hasError = false;
              });
              fetchCategories(widget.categoy_id);
            },
            child: Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                return Text(
                    getText(context, 'Retry', 'మళ్లీ ప్రయత్నించండి'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16.h),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return Text(
                getText(context, 'Loading categories...', 'వర్గాలు లోడ్ అవుతున్నాయి...'),
                style: GoogleFonts.jost(),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: 20.h),
          // App Bar - with LanguageProvider
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
              padding: EdgeInsets.only(top: 10.h),
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
                          child: Icon(Icons.arrow_back_ios,
                              size: 15.sp, color: AppColors.primaryTextColor),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  // Screen title - with LanguageProvider
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, child) {
                      return Text(
                        widget.category_name,
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

          /// Fixed content area
          Expanded(
            child: hasError
                ? _buildErrorWidget()
                : isLoading
                ? _buildLoadingWidget()
                : categories.isEmpty
                ? Center(
              child: Consumer<LanguageProvider>(
                builder: (context, languageProvider, child) {
                  return Text(
                    getText(context, 'No categories found',
                        'వర్గాలు ఏవీ కనుగొనబడలేదు'),
                    style: GoogleFonts.jost(fontSize: 16.sp),
                  );
                },
              ),
            )
                : _buildCategoryGrid(categories),
          ),
        ],
      ),
    );
  }
}
