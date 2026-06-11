import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../BottomNav/Screens/cartScreen.dart';
import '../Provider/cart_provider.dart';
import '../Provider/language_provider.dart';
import '../CustomWidgets/product_card.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';

class CategoryViewScreen extends StatefulWidget {
  final int? categoryId;
  final int? subCategoryId;
  final String? categoryName;
  final String? categoryImage;
  final int branchId;

  const CategoryViewScreen({
    Key? key,
    this.categoryId,
    this.subCategoryId,
    this.categoryName,
    this.categoryImage,
    required this.branchId,
  }) : super(key: key);

  @override
  State<CategoryViewScreen> createState() => _CategoryViewScreenState();
}

class _CategoryViewScreenState extends State<CategoryViewScreen> {
  late int selectedCategoryId;
  late int selectedSubCategoryId;
  late String selectedCategoryName;
  late String selectedSubCategoryName;

  List subcategories = [];
  List products = [];
  bool _isLoadingProducts = false;
  List<String> menuList = ['Brands', 'Sort'];
  List<String> shortList = ['Relevance (default)', 'Price (low to high)', 'Price (high to low)', 'Discount (high to low)'];
  List<Map<String, dynamic>> cartList = [];

  String? selectedBrand;
  String? selectedSortOption;
  List<String> brands = [];
  TextEditingController brandSearchController = TextEditingController();

  String userEmail = "";
  String userName = "";
  String userID = "";

  int branchId = 0;
  String branchName  = "";

  @override
  void initState() {
    super.initState();
    fetchUserData();
    selectedCategoryId = widget.categoryId ?? 0;
    selectedCategoryName = widget.categoryName ?? "";
    selectedSubCategoryId = widget.subCategoryId ?? 0;
    selectedSubCategoryName = "All";
    brandSearchController = TextEditingController();
    _initializeCategoryData();
  }

  @override
  void dispose() {
    brandSearchController.dispose();
    super.dispose();
  }

  // Helper method to get text based on language
  String getText(String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  // Helper method to get subcategory name based on language
  String getSubCategoryName(Map<String, dynamic> subcategory) {
    final languageProvider =
    Provider.of<LanguageProvider>(context, listen: false); // ✅ FIX

    final String englishName = subcategory['sub_category_name'] ?? '';
    final String teluguName = subcategory['name_telugu'] ?? '';

    if (languageProvider.selectedLanguage == "Telugu" && teluguName.isNotEmpty) {
      return teluguName;
    } else {
      return englishName.isNotEmpty ? englishName : "Subcategory";
    }
  }

  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? user_ID = prefs.getString('user_id');
    if (user_ID != null) {
      setState(() => userID = user_ID);
      await fetchCartQuantity(user_ID);
    }
  }

  Future<void> fetchCartQuantity(String id) async {
    final url = Uri.parse(
      '${ApiConstants.GET_CART_ITEMS}?user_id=$id',
    );
    try {
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success']) {
        final cartItems = List<Map<String, dynamic>>.from(data['cart'] ?? []);
        setState(() {
          cartList = cartItems;
        });
      } else {
        setState(() {
          cartList = [];
        });
      }
    } catch (e) {
      setState(() {
        cartList = [];
      });
    }
  }

  Future<void> _initializeCategoryData() async {
    await fetchSubcategories();
    if (selectedSubCategoryId == 0) {
      await fetchAllProductsFromCategory();
    } else {
      await fetchProducts(selectedSubCategoryId);
    }
  }

  Future<void> fetchSubcategories() async {
    final url = Uri.parse(ApiConstants.VIEW_SUB_CATEGORY);
    try {
      final res = await http.post(
        url,
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        },
        body: {
          'category_id': selectedCategoryId.toString(),
        },
      );

      if (res.statusCode == 200) {
        // First try to decode with UTF-8
        String responseBody = utf8.decode(res.bodyBytes);
        final data = jsonDecode(responseBody);

        if (!mounted) return;

        if (data['success'] == true && data['subcategories'] is List) {
          setState(() {
            subcategories = [
              {
                'id': 0,
                'sub_category_name': 'All',
                'name_telugu': 'అన్ని',
                'sub_category_image': widget.categoryImage,
              },
              ...data['subcategories'],
            ];
          });

          // Debug: Print telugu names to check encoding
          for (var subcat in data['subcategories']) {
            if (subcat['name_telugu'] != null) {
              print("Telugu name from API: ${subcat['name_telugu']}");
            }
          }
        } else {
          setState(() {
            subcategories = [
              {
                'id': 0,
                'sub_category_name': 'All',
                'name_telugu': 'అన్ని',
                'sub_category_image': widget.categoryImage,
              },
            ];
          });
        }
      }
    } catch (e) {
      print("Error fetching subcategories: $e");
      if (!mounted) return;
      setState(() {
        subcategories = [
          {
            'id': 0,
            'sub_category_name': 'All',
            'name_telugu': 'అన్ని',
            'sub_category_image': widget.categoryImage,
          },
        ];
      });
    }
  }


  Future<void> fetchProducts(int subId) async {
    setState(() {
      _isLoadingProducts = true;
      products = [];
      selectedBrand = null;
      selectedSortOption = null;
    });

    final url = Uri.parse(
      '${ApiConstants.VIEW_PRODUCTS_BY_SUBCATEGORY}?subcategory_id=$subId&branch_id=${widget.branchId}',
    );
    try {
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() {
            products = data['products'];
            _processProductVariants();
            _extractBrands();
          });
        } else {
          setState(() {
            products = [];
          });
        }
      } else {
        setState(() {
          products = [];
        });
      }
    } catch (e) {
      setState(() {
        products = [];
      });
    } finally {
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  Future<void> fetchAllProductsFromCategory() async {
    setState(() {
      _isLoadingProducts = true;
      products = [];
      selectedBrand = null;
      selectedSortOption = null;
    });

    final url = Uri.parse(
      '${ApiConstants.VIEW_ALL_PRODUCTS_BY_CATEGORY}?category_id=$selectedCategoryId&branch_id=${widget.branchId}',
    );
    try {
      final res = await http.get(url);

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        setState(() {
          if (data is List) {
            products = data;
          } else if (data['products'] != null) {
            products = data['products'];
          } else {
            products = [];
          }
          _processProductVariants();
          _extractBrands();
        });
      } else {
        setState(() {
          products = [];
        });
      }
    } catch (e) {
      setState(() {
        products = [];
      });
    } finally {
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  void _extractBrands() {
    Set<String> brandSet = {};
    for (var product in products) {
      if (product['brand_name'] != null && product['brand_name'].toString().isNotEmpty) {
        brandSet.add(product['brand_name'].toString());
      }
    }
    setState(() {
      brands = brandSet.toList()..sort();
    });
  }

  void _processProductVariants() {
    for (var product in products) {
      if (product['variants'] != null && product['variants'].isNotEmpty) {
        product['selectedVariantName'] = product['variants'][0]['name'];
        product['selectedPrice'] = double.tryParse(
          product['variants'][0]['selling_price'].toString(),
        );
      } else {
        product['selectedVariantName'] = null;
        product['selectedPrice'] = null;
      }
    }
  }

  List<dynamic> getFilteredProducts() {
    List<dynamic> filteredProducts = List.from(products);

    if (selectedBrand != null && selectedBrand!.isNotEmpty) {
      filteredProducts = filteredProducts.where((product) =>
      product['brand_name']?.toString() == selectedBrand
      ).toList();
    }

    if (selectedSortOption != null) {
      switch (selectedSortOption) {
        case 'Price (low to high)':
          filteredProducts.sort((a, b) {
            double priceA = a['selectedPrice'] ?? double.infinity;
            double priceB = b['selectedPrice'] ?? double.infinity;
            return priceA.compareTo(priceB);
          });
          break;
        case 'Price (high to low)':
          filteredProducts.sort((a, b) {
            double priceA = a['selectedPrice'] ?? 0;
            double priceB = b['selectedPrice'] ?? 0;
            return priceB.compareTo(priceA);
          });
          break;
        case 'Discount (high to low)':
          filteredProducts.sort((a, b) {
            double discountA = double.tryParse(a['discount'].toString()) ?? 0;
            double discountB = double.tryParse(b['discount'].toString()) ?? 0;
            return discountB.compareTo(discountA);
          });
          break;
        default:
          break;
      }
    }

    return filteredProducts;
  }

  Widget _buildCategoryImage(String? imageUrl, double size) {
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Image.network(
        ApiConstants.BASE_URL + '/category_api/$imageUrl',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _buildDefaultImage(size),
      );
    } else {
      return _buildDefaultImage(size);
    }
  }

  Widget _buildDefaultImage(double size) {
    return Padding(
      padding:  EdgeInsets.only(top: 5.h),
      child: SvgPicture.asset(
        'assets/svg/category.svg',
        width: size * 0.6,
        height: size * 0.6,
        fit: BoxFit.contain,
        color: AppColors.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isTablet = screenWidth > 600;
    final isLargeScreen = screenWidth > 900;

    final sidebarWidth = isLargeScreen ? screenWidth * 0.12 : (isTablet ? screenWidth * 0.15 : screenWidth * 0.22);
    final headerHeight = isTablet ? 70.0 : 60.0;
    final backButtonSize = isTablet ? 32.0 : 28.0;
    final backButtonIconSize = isTablet ? 18.0 : 15.0;
    final titleFontSize = isTablet ? 20.0 : 17.0;
    final filterButtonHeight = isLargeScreen ? 60.0 : (isTablet ? 55.0 : 50.0);

    final gridCrossAxisCount = isLargeScreen ? 3 : (isTablet ? 3 : 2);
    final gridAspectRatio = isLargeScreen ? 0.65 : (isTablet ? 0.58 : 0.50);
    final gridSpacing = isTablet ? 12.0 : 8.0;

    final filteredProducts = getFilteredProducts();

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: AppColors.backgroundColor,
          body: Stack(
            children: [
              Column(
                children: [
                  SizedBox(height: isTablet ? 30 : 20),
                  Container(
                    width: double.infinity,
                    height: 63.h,
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
                      padding: EdgeInsets.only(top: 12.h),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: screenWidth * 0.04),
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: Container(
                              height: backButtonSize,
                              width: backButtonSize,
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor,
                                borderRadius: BorderRadius.circular(100),
                              ),
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.only(left: backButtonSize * 0.25),
                                  child: Icon(Icons.arrow_back_ios, size: backButtonIconSize, color: AppColors.iconColor),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: screenWidth * 0.04),
                          Text(
                            selectedCategoryName,
                            style: GoogleFonts.jost(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Expanded(
                    child: Row(
                      children: [
                        // Left Container
                        Padding(
                          padding: EdgeInsets.only(top: isTablet ? 12 : 8),
                          child: Container(
                            width: sidebarWidth,
                            decoration: BoxDecoration(
                                color: AppColors.backgroundColor,
                                borderRadius: BorderRadius.only(
                                  topRight: Radius.circular(isTablet ? 15 : 10),
                                ),
                                border: Border.all(
                                  color: Color(0xffE8E6E6),
                                  width: 1,
                                )
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: subcategories.length,
                              itemBuilder: (context, index) {
                                final subcat = subcategories[index];
                                final int newSubCatId = (subcat['id'] is int)
                                    ? subcat['id']
                                    : int.tryParse(subcat['id'].toString()) ?? 0;
                                final bool isSelected = newSubCatId == selectedSubCategoryId;

                                final imageSize = isLargeScreen ? 60.0 : (isTablet ? 55.0 : 50.0);
                                final textSize = isLargeScreen ? 14.0 : (isTablet ? 15.0 : 12.0);
                                final verticalMargin = isTablet ? 9.0 : 8.0;
                                final horizontalPadding = isTablet ? screenWidth * 0.015 : screenWidth * 0.02;

                                return GestureDetector(
                                  onTap: () {
                                    if (newSubCatId != selectedSubCategoryId) {
                                      setState(() {
                                        selectedSubCategoryId = newSubCatId;
                                        selectedSubCategoryName = getSubCategoryName(subcat);
                                        selectedBrand = null;
                                        selectedSortOption = null;
                                      });

                                      if (newSubCatId == 0) {
                                        fetchAllProductsFromCategory();
                                      } else {
                                        fetchProducts(newSubCatId);
                                      }
                                    }
                                  },
                                  child: Stack(
                                    children: [
                                      Container(
                                        margin: EdgeInsets.symmetric(vertical: verticalMargin),
                                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Container(
                                              decoration: BoxDecoration(),
                                              child: Center(
                                                child: ClipRRect(
                                                  borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
                                                  child: newSubCatId == 0
                                                      ? _buildCategoryImage(subcat['sub_category_image'], imageSize)
                                                      : Image.network(
                                                    ApiConstants.BASE_URL + '/sub_category_api/${subcat['sub_category_image']}',
                                                    width: imageSize,
                                                    height: imageSize,
                                                    fit: BoxFit.contain,
                                                    errorBuilder: (_, __, ___) => _buildDefaultImage(imageSize),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            AnimatedDefaultTextStyle(
                                              duration: Duration(milliseconds: 300),
                                              style: GoogleFonts.jost(
                                                fontSize: textSize,
                                                color: AppColors.primaryTextColor,
                                                fontWeight: isSelected ? FontWeight.w400 : FontWeight.w500,
                                              ),
                                              child: Text(
                                                getSubCategoryName(subcat),
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.jost(color: AppColors.secondaryTextColor),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      AnimatedPositioned(
                                        duration: Duration(milliseconds: 300),
                                        curve: Curves.easeOutCubic,
                                        right: isSelected ? 0 : -4.w,
                                        top: 8.h,
                                        child: AnimatedContainer(
                                          duration: Duration(milliseconds: 300),
                                          curve: Curves.easeOutCubic,
                                          decoration: BoxDecoration(
                                            color: AppColors.primaryColor,
                                            borderRadius: BorderRadius.only(
                                              topLeft: Radius.circular(10.r),
                                              bottomLeft: Radius.circular(10.r),
                                            ),
                                          ),
                                          width: isSelected ? 4.w : 0,
                                          height: 40.h,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),

                        // Right Container
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(height: 10.h),
                              Row(
                                children: [
                                  Spacer(),
                                  InkWell(
                                    onTap: () => _showCombinedFilterSheet(3.toString()),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.gray,
                                        borderRadius: BorderRadius.circular(20.r),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                      child: SvgPicture.asset('assets/svg/filter.svg',height: 14.h,width: 20.w),
                                    ),
                                  ),
                                  Spacer(),
                                  InkWell(
                                    onTap: () => _showCombinedFilterSheet('brand'),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.gray,
                                        borderRadius: BorderRadius.circular(20.r),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 5.w),
                                          Text(
                                            getText('Brands', 'బ్రాండ్లు'),
                                            style: GoogleFonts.jost(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Icon(Icons.keyboard_arrow_down),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                  InkWell(
                                    onTap: () => _showCombinedFilterSheet('sort'),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: AppColors.gray,
                                        borderRadius: BorderRadius.circular(20.r),
                                      ),
                                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                                      child: Row(
                                        children: [
                                          SizedBox(width: 5.w),
                                          Text(
                                            getText('Sort', 'క్రమం'),
                                            style: GoogleFonts.jost(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                          Icon(Icons.keyboard_arrow_down),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Spacer(),
                                ],
                              ),

                              SizedBox(height: 10.h),

                              Expanded(
                                child: _isLoadingProducts
                                    ? Center(child: CircularProgressIndicator())
                                    : filteredProducts.isEmpty
                                    ? Center(
                                  child: Text(
                                    getText("No products found", "ఉత్పత్తులు ఏవీ కనుగొనబడలేదు"),
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                )
                                    : GridView.builder(
                                  padding: EdgeInsets.all(10.w),
                                  itemCount: filteredProducts.length,
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: gridCrossAxisCount,
                                    childAspectRatio: gridAspectRatio,
                                    crossAxisSpacing: gridSpacing,
                                    mainAxisSpacing: gridSpacing,
                                  ),
                                  itemBuilder: (context, index) {
                                    final product = filteredProducts[index];
                                    return ProductCard(
                                      product: product,
                                      userId: userID,
                                      branchId: widget.branchId,
                                      onCartUpdated: () {
                                        fetchCartQuantity(userID);
                                      },
                                      onCategoryBack: (){
                                        setState(() {
                                          fetchCartQuantity(userID);
                                        });
                                      },
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (cartProvider.getTotalCartItems(userID) > 0)
                AnimatedPositioned(
                  duration: Duration(milliseconds: 300),
                  curve: Curves.slowMiddle,
                  bottom: cartProvider.getTotalCartItems(userID) > 0 ? 30.h : -50.h,
                  left: 110.w,
                  right: 110.w,
                  child: AnimatedOpacity(
                    duration: Duration(milliseconds: 300),
                    opacity: cartProvider.getTotalCartItems(userID) > 0 ? 1.0 : 0.0,
                    child: InkWell(
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => CartScreen()),
                        );
                        setState(() {
                          fetchCartQuantity(userID);
                        });
                      },
                      child: Container(
                        height: 38.h,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(30.r),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Row(
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: AppColors.gray,
                                  borderRadius: BorderRadius.circular(50.r),
                                ),
                                child: Center(
                                  child: Text(
                                    cartProvider.getTotalCartItems(userID).toString(),
                                    style: GoogleFonts.poppins(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                              ),
                              Spacer(),
                              Text(
                                getText("View Cart", "కార్ట్ చూడండి"),
                                style: GoogleFonts.jost(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryTextColor,
                                ),
                              ),
                              Spacer(),
                              Icon(
                                Icons.arrow_forward_ios_outlined,
                                color: AppColors.iconColor,
                                size: 16.sp,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showCombinedFilterSheet(String initialTab) async {
    int selectedTab = initialTab == 'brand' ? 0 : 1;
    String? tempSelectedBrand = selectedBrand;
    String? tempSelectedSortOption = selectedSortOption;
    List<String> filteredBrands = List.from(brands);
    TextEditingController searchController = TextEditingController();

    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isLargeScreen = screenWidth > 900;

    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(isTablet ? 25.r : 20.r)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(
                              left: isTablet ? 30.w : 25.w,
                              right: isTablet ? 30.w : 25.w,
                              bottom: isTablet ? 24.h : 20.h,
                              top: isTablet ? 24.h : 20.h),
                          child: Row(
                            children: [
                              Text(
                                getText('Filter', 'ఫిల్టర్'),
                                style: GoogleFonts.jost(
                                  fontSize: isLargeScreen ? 18.sp : (isTablet ? 17.sp : 16.sp),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Spacer(),
                              GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: EdgeInsets.all(5),
                                  decoration: BoxDecoration(
                                    color: AppColors.backgroundColor,
                                    borderRadius: BorderRadius.circular(100.r),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 3,
                                        offset: Offset(0, 0),
                                      ),
                                    ],
                                  ),
                                  child: Icon(Icons.close, size: 16.sp),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          height: 0.6.h,
                          color: Colors.grey,
                        ),
                        IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ...menuList.asMap().entries.map((entry) {
                                    int index = entry.key;
                                    String item = entry.value;
                                    bool isSelected = selectedTab == index;
                                    return GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          selectedTab = index;
                                          searchController.clear();
                                          filteredBrands = List.from(brands);
                                        });
                                      },
                                      child: Padding(
                                        padding: EdgeInsets.only(top: 25.h),
                                        child: Row(
                                          children: [
                                            AnimatedContainer(
                                              duration: Duration(milliseconds: 300),
                                              height: 22.h,
                                              width: 5.w,
                                              decoration: BoxDecoration(
                                                color: isSelected
                                                    ? AppColors.primaryColor
                                                    : Colors.transparent,
                                                borderRadius: BorderRadius.only(
                                                    topRight: Radius.circular(7.r),
                                                    bottomRight: Radius.circular(7.r)),
                                              ),
                                            ),
                                            SizedBox(width: 10.w),
                                            Text(
                                              index == 0
                                                  ? getText('Brands', 'బ్రాండ్లు')
                                                  : getText('Sort', 'క్రమం'),
                                              style: GoogleFonts.jost(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w500,
                                                color: isSelected
                                                    ? AppColors.primaryColor
                                                    : AppColors.secondaryTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ],
                              ),
                              SizedBox(width: 10.w),
                              Container(width: 0.6.w, color: Colors.grey),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(
                                      left: isTablet ? 24.w : 20.w,
                                      right: isTablet ? 24.w : 20.w,
                                      top: isTablet ? 24.h : 20.h,
                                      bottom: isTablet ? 18.h : 10.h),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      if (selectedTab == 0) ...[
                                        SizedBox(
                                          height: isTablet ? 35.w : 30.w,
                                          child: Center(
                                            child: TextField(
                                              controller: searchController,
                                              onChanged: (value) {
                                                setState(() {
                                                  filteredBrands = brands
                                                      .where((brand) => brand
                                                      .toLowerCase()
                                                      .contains(value.toLowerCase()))
                                                      .toList();
                                                });
                                              },
                                              decoration: InputDecoration(
                                                hintText: getText('Search brands', 'బ్రాండ్లను శోధించండి'),
                                                hintStyle: GoogleFonts.jost(
                                                  color: AppColors.secondaryTextColor,
                                                  fontSize: isTablet ? 14.sp : 12.sp,
                                                ),
                                                prefixIcon: Icon(Icons.search,
                                                    color: AppColors.secondaryTextColor,
                                                    size: isTablet ? 20.sp : 18.sp),
                                                prefixIconConstraints: BoxConstraints(
                                                  minHeight: 36.h,
                                                  minWidth: 36.w,
                                                ),
                                                contentPadding: EdgeInsets.symmetric(
                                                    vertical: 4.h, horizontal: 1.w),
                                                enabledBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(5.r),
                                                  borderSide: BorderSide(color: Colors.grey),
                                                ),
                                                focusedBorder: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(5.r),
                                                  borderSide: BorderSide(color: Colors.grey),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius: BorderRadius.circular(5.r),
                                                  borderSide: BorderSide(color: Colors.grey),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 10.h),
                                        ...filteredBrands.map((brand) {
                                          return RadioListTile<String>(
                                            title: Text(
                                              brand,
                                              style: GoogleFonts.jost(
                                                fontSize: isLargeScreen ? 16.sp : (isTablet ? 15.sp : 14.sp),
                                                color: AppColors.secondaryTextColor,
                                              ),
                                            ),
                                            value: brand,
                                            groupValue: tempSelectedBrand,
                                            onChanged: (String? value) {
                                              setState(() {
                                                tempSelectedBrand = value;
                                              });
                                            },
                                            activeColor: AppColors.primaryColor,
                                            contentPadding: EdgeInsets.symmetric(
                                              horizontal: isTablet ? 8.w : 4.w,
                                              vertical: isTablet ? 2.h : 0,
                                            ),
                                            dense: true,
                                          );
                                        }).toList(),
                                      ] else ...[
                                        SizedBox(height: 10.h),
                                        ...shortList.map((option) {
                                          String displayOption = option;
                                          if (option == 'Relevance (default)') {
                                            displayOption = getText('Relevance (default)', 'సంబంధం (డిఫాల్ట్)');
                                          } else if (option == 'Price (low to high)') {
                                            displayOption = getText('Price (low to high)', 'ధర (తక్కువ నుండి ఎక్కువ)');
                                          } else if (option == 'Price (high to low)') {
                                            displayOption = getText('Price (high to low)', 'ధర (ఎక్కువ నుండి తక్కువ)');
                                          } else if (option == 'Discount (high to low)') {
                                            displayOption = getText('Discount (high to low)', 'డిస్కౌంట్ (ఎక్కువ నుండి తక్కువ)');
                                          }

                                          return RadioListTile<String>(
                                            title: Text(
                                              displayOption,
                                              style: GoogleFonts.jost(
                                                fontSize: isLargeScreen ? 16.sp : (isTablet ? 15.sp : 14.sp),
                                                color: AppColors.secondaryTextColor,
                                              ),
                                            ),
                                            value: option,
                                            groupValue: tempSelectedSortOption,
                                            onChanged: (String? value) {
                                              setState(() {
                                                tempSelectedSortOption = value;
                                              });
                                            },
                                            activeColor: AppColors.primaryColor,
                                            contentPadding: EdgeInsets.zero,
                                            dense: true,
                                          );
                                        }).toList(),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: double.infinity,
                          height: isTablet ? 70.h : 60.h,
                          decoration: BoxDecoration(
                            color: AppColors.backgroundColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 3,
                                offset: Offset(0, -2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: EdgeInsets.only(
                                left: isTablet ? 30.w : 25.w,
                                right: isTablet ? 30.w : 25.w),
                            child: Row(
                              children: [
                                InkWell(
                                  child: Text(
                                    getText('Clear all', 'అన్నీ క్లియర్ చేయండి'),
                                    style: GoogleFonts.jost(
                                      color: (tempSelectedBrand != null ||
                                          tempSelectedSortOption != null)
                                          ? AppColors.secondaryTextColor
                                          : Colors.grey,
                                      fontWeight: FontWeight.w500,
                                      fontSize: isTablet ? 18.sp : 16.sp,
                                    ),
                                  ),
                                  onTap: (tempSelectedBrand != null ||
                                      tempSelectedSortOption != null)
                                      ? () {
                                    setState(() {
                                      tempSelectedBrand = null;
                                      tempSelectedSortOption = null;
                                    });
                                  }
                                      : null,
                                ),
                                Spacer(),
                                InkWell(
                                  child: Container(
                                    width: isTablet ? 130.w : 110.w,
                                    height: isTablet ? 35.h : 30.h,
                                    decoration: BoxDecoration(
                                      color: (tempSelectedBrand != null ||
                                          tempSelectedSortOption != null)
                                          ? AppColors.primaryColor
                                          : Colors.grey,
                                      borderRadius: BorderRadius.circular(20.r),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.2),
                                          blurRadius: 3,
                                          offset: Offset(0, 0),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        getText('Apply', 'వర్తింపజేయండి'),
                                        style: GoogleFonts.jost(
                                          color: AppColors.primaryTextColor,
                                          fontWeight: FontWeight.w500,
                                          fontSize: isTablet ? 18.sp : 16.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                  onTap: (tempSelectedBrand != null ||
                                      tempSelectedSortOption != null)
                                      ? () {
                                    Navigator.pop(context, {
                                      'brand': tempSelectedBrand,
                                      'sort': tempSelectedSortOption,
                                    });
                                  }
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (result != null && mounted) {
      setState(() {
        selectedBrand = result['brand'];
        selectedSortOption = result['sort'];
      });
    }
  }
}