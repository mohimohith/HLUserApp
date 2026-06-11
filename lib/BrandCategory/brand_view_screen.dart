import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../BottomNav/Screens/cartScreen.dart';
import '../Provider/cart_provider.dart';
import '../CustomWidgets/product_card.dart';
import '../SearchProduct/search_product.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';

class BrandViewScreen extends StatefulWidget {
  final String brandName;
  const BrandViewScreen({super.key, required this.brandName});

  @override
  State<BrandViewScreen> createState() => _BrandViewScreenState();
}

class _BrandViewScreenState extends State<BrandViewScreen> {
  List allProducts = [];
  List filteredProducts = [];
  bool _isLoadingProducts = false;
  List<Map<String, dynamic>> cartList = [];

  String userEmail = "";
  String userName = "";
  String userID = "";

  int branchId = 0;
  String branchName  = "";


  @override
  void initState() {
    super.initState();
    fetchProducts();
    fetchUserData();
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

      // await  fetchProductsByType('Everyday Essentials');
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

  /// ✅ Cart quantity fetch
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

  Future<void> fetchProducts() async {
    setState(() {
      _isLoadingProducts = true;
    });

    try {
      // Build URL with parameters to get all products without pagination limits
      final uri = Uri.parse(ApiConstants.VIEW_ALL_PRODUCTS).replace(
        queryParameters: {
          'page': '1',
          'limit': '200', // Set a high limit to get all products
          'search': '', // Empty search to get all products
          // Remove category_id filter to get all categories
        },
      );

      var response = await http.get(uri);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            allProducts = data["products"] ?? [];
            // Filter products by brand name (case insensitive)
            filteredProducts = allProducts.where((p) =>
            p["brand_name"]?.toString().toLowerCase() == widget.brandName.toLowerCase()
            ).toList();
          });
        } else {
          // Handle API error
          print('API Error: ${data['message']}');
          setState(() {
            allProducts = [];
            filteredProducts = [];
          });
        }
      } else {
        // Handle HTTP error
        print('HTTP Error: ${response.statusCode}');
        setState(() {
          allProducts = [];
          filteredProducts = [];
        });
      }
    } catch (e) {
      // Handle network error
      print('Network Error: $e');
      setState(() {
        allProducts = [];
        filteredProducts = [];
      });
    } finally {
      setState(() {
        _isLoadingProducts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          Column(
            children: [
              SizedBox(height: 20.h),

              // ✅ Top AppBar
              buildAppBar(),

              SizedBox(height: 20.h),

              // ✅ Loading Indicator
              if (_isLoadingProducts)
                Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),

              // ✅ Products Grid OR Empty Message
              if (!_isLoadingProducts)
                Expanded(
                  child: filteredProducts.isNotEmpty
                      ? buildSection(filteredProducts)
                      : Center(
                    child: Text(
                      "No products found\nfor this brand!",
                      style: GoogleFonts.jost(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.hintTextColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),

          // ✅ Floating Cart Button (Only show if cartList is not empty)
          if (cartProvider.getTotalCartItems(userID) > 0)
            AnimatedPositioned(
              duration: Duration(milliseconds: 300),
              curve: Curves.slowMiddle,
              bottom: cartProvider.getTotalCartItems(userID) > 0 ? 40.h : -50.h,
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
                      // Refresh cart data when returning from cart screen
                      if (userID.isNotEmpty) {
                        fetchCartQuantity(userID);
                      }
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
                            "View Cart",
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
  }

  /// ✅ Top AppBar extracted for clarity
  Widget buildAppBar() {
    return Container(
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
                    child: Icon(Icons.arrow_back_ios, color: AppColors.iconColor, size: 15.sp),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                widget.brandName,
                style: GoogleFonts.jost(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(width: 16.w),
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
                    child: Icon(Icons.search, color: AppColors.iconColor, size: 15.sp),
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

  /// ✅ Grid Section
  Widget buildSection(List<dynamic> list) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 0.38,
        ),
        itemCount: list.length,
        itemBuilder: (context, index) {
          final product = list[index];
          return ProductCard(
            product: product,
            userId: userID,
            branchId: branchId,
            onCartUpdated: () {
              if (userID.isNotEmpty) {
                fetchCartQuantity(userID); // ✅ Real-time update
              }
            },
          );
        },
      ),
    );
  }
}