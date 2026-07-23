import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../CategoryViewScreen/categoryViewScreen.dart';
import '../utils/responsive_helper.dart';
import '../Provider/language_provider.dart';

class MainCategoryWithSubCategories extends StatelessWidget {
  final List<Map<String, dynamic>> mainCategoryList;
  final VoidCallback? onCategoryBack;
  final String branchId;

  const MainCategoryWithSubCategories({
    super.key,
    required this.mainCategoryList,
    this.onCategoryBack,
    this.branchId = '',
  });

  // ✅ Helper method to get text based on language
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  // ✅ Helper method to get main category name
  String getMainCategoryName(BuildContext context, Map<String, dynamic> mainCategory) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    final String englishName = mainCategory['name'] ?? '';
    final String teluguName = mainCategory['name_telugu'] ?? '';

    if (languageProvider.selectedLanguage == "Telugu" && teluguName.isNotEmpty) {
      return teluguName;
    } else {
      return englishName.isNotEmpty ? englishName : "Category";
    }
  }

  // ✅ Helper method to get subcategory name
  String getSubCategoryName(BuildContext context, Map<String, dynamic> subCategory) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    final String englishName = subCategory['category_name'] ?? '';
    final String teluguName = subCategory['name_telugu'] ?? '';

    if (languageProvider.selectedLanguage == "Telugu" && teluguName.isNotEmpty) {
      return teluguName;
    } else {
      return englishName.isNotEmpty ? englishName : "Sub Category";
    }
  }

  @override
  Widget build(BuildContext context) {
    if (mainCategoryList.isEmpty) return SizedBox.shrink();

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Padding(
          padding: EdgeInsets.only(
            left: ResponsiveHelper.getResponsiveWidth(context,
              mobile: 10.w,
              tablet: 15.w,
              desktop: 20.w,
            ),
            top: ResponsiveHelper.getResponsiveHeight(context,
              mobile: 8.h,
              tablet: 10.h,
              desktop: 12.h,
            ),
            right: ResponsiveHelper.getResponsiveWidth(context,
              mobile: 10.w,
              tablet: 15.w,
              desktop: 20.w,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: mainCategoryList.map((mainCat) {
              final List categories = mainCat['categories'] ?? [];

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with name and gradient line
                  Padding(
                    padding: EdgeInsets.all(
                      ResponsiveHelper.getResponsiveWidth(context,
                        mobile: 8.0,
                        tablet: 10.0,
                        desktop: 12.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          getMainCategoryName(context, mainCat), // ✅ Language-specific name
                          style: GoogleFonts.jost(
                            fontSize: ResponsiveHelper.getResponsiveFontSize(context,
                              mobile: 14.sp,
                              tablet: 16.sp,
                              desktop: 18.sp,
                            ),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          width: ResponsiveHelper.getResponsiveWidth(context,
                            mobile: 10.w,
                            tablet: 12.w,
                            desktop: 15.w,
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 1.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black,
                                  Colors.black.withOpacity(0.5),
                                  Colors.black.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: ResponsiveHelper.getResponsiveHeight(context,
                      mobile: 8.h,
                      tablet: 10.h,
                      desktop: 12.h,
                    ),
                  ),

                  // Grid of subcategories
                  GridView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: ResponsiveHelper.getCrossAxisCount(context,
                        mobile: 4,
                        tablet: 5,
                        desktop: 6,
                      ),
                      mainAxisSpacing: ResponsiveHelper.getResponsiveHeight(context,
                        mobile: 8.h,
                        tablet: 10.h,
                        desktop: 12.h,
                      ),
                      crossAxisSpacing: ResponsiveHelper.getResponsiveWidth(context,
                        mobile: 12.w,
                        tablet: 15.w,
                        desktop: 18.w,
                      ),
                      childAspectRatio: ResponsiveHelper.isDesktop(context) ? 0.8 : ResponsiveHelper.isTablet(context) ? 0.75 : 0.72,
                    ),
                    itemCount: categories.length > 8 ? 8 : categories.length,
                    itemBuilder: (context, index) {
                      final item = categories[index];
                      return GestureDetector(
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CategoryViewScreen(
                                categoryId: item['category_id']?.toString() ?? '',
                                categoryName: getSubCategoryName(context, item),
                                categoryImage: item['category_image'],
                              ),
                            ),
                          );

                          if (onCategoryBack != null) {
                            onCategoryBack!();
                          }
                        },
                        child: Column(
                          children: [
                            Container(
                              width: ResponsiveHelper.getResponsiveWidth(context,
                                mobile: 65.w,
                                tablet: 70.w,
                                desktop: 80.w,
                              ),
                              height: ResponsiveHelper.getResponsiveHeight(context,
                                mobile: 60.h,
                                tablet: 70.h,
                                desktop: 80.h,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10.r),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10.r),
                                child: Image.network(
                                  item['category_image'] ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Image.asset(
                                    "assets/images/placeholder_category.png",
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(
                              height: ResponsiveHelper.getResponsiveHeight(context,
                                mobile: 6.h,
                                tablet: 8.h,
                                desktop: 10.h,
                              ),
                            ),
                            SizedBox(
                              width: ResponsiveHelper.getResponsiveWidth(context,
                                mobile: 60.w,
                                tablet: 70.w,
                                desktop: 80.w,
                              ),
                              child: Text(
                                getSubCategoryName(context, item), // ✅ Language-specific name
                                style: GoogleFonts.jost(
                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context,
                                    mobile: 10.sp,
                                    tablet: 11.sp,
                                    desktop: 12.sp,
                                  ),
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              );
            }).toList(),
          ),
        );
      },
    );
  }
}