import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Provider/cart_provider.dart';
import '../../CustomWidgets/product_card.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import '../bottomNavScreen.dart';
import 'cartScreen.dart';


class WishlistScreen extends StatefulWidget {


  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {

  List<dynamic> wishlistProducts = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String userEmail = "";
  String userName = "";
  String userID = "";

  int branchId = 0;
  String branchName  = "";

  List<Map<String, dynamic>> cartList = [];

  @override
  void initState() {
    super.initState();
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
      fetchWishlist(user_ID);
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

  Future<void> fetchWishlist(String userID) async {
    if (userID.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConstants.GET_WISHLIST}?user_id=$userID');
      final response = await http.get(url);

      print("Wishlist API Response: ${response.body}"); // Debugging

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true && data['wishlist'] != null) {
          setState(() {
            wishlistProducts = List<Map<String, dynamic>>.from(data['wishlist']);
          });
        } else {
          setState(() {
            wishlistProducts = [];
          });
        }
      } else {
        setState(() {
          wishlistProducts = [];
        });
      }
    } catch (e) {
      print('Error fetching wishlist: $e');
      setState(() {
        wishlistProducts = [];
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }



  Future<void> removeFromWishlist(String productId) async {
    try {
      final url = Uri.parse(ApiConstants.REMOVE_FROM_WISHLIST);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userID,
          'product_id': productId,
        }),
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        // ✅ सिर्फ local list update करो, दोबारा full fetch की ज़रूरत नहीं
        setState(() {
          wishlistProducts.removeWhere((item) => item['product_id'].toString() == productId);
        });
      }
    } catch (e) {
      print('Error removing from wishlist: $e');
    }
  }

  Future<void> _refreshWishlist() async {
    setState(() {
      isRefreshing = true;
    });
    await fetchWishlist(userID);
    setState(() {
      isRefreshing = false;
    });
  }

  @override
  Widget build(BuildContext context) {

    final cartProvider = Provider.of<CartProvider>(context);

    return Scaffold(

      backgroundColor: AppColors.backgroundColor,

      body: Stack(
        children: [
          userID.isEmpty
              ? Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.favorite_border, size: 50.sp, color: Colors.grey),
                SizedBox(height: 16.h),
                Text(
                  'Please login to view your wishlist',
                  style: GoogleFonts.jost(
                    fontSize: 16.sp,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          )
              : RefreshIndicator(
            onRefresh: _refreshWishlist,
            child: isLoading
                ? Center(child: CircularProgressIndicator())
                : wishlistProducts.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [


                  Icon(Icons.favorite_border, size: 50.sp, color: Colors.grey),
                  SizedBox(height: 16.h),
                  Text(
                    'Your wishlist is empty',
                    style: GoogleFonts.jost(
                      fontSize: 16.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],

              ),
            )


                : Column(
              children: [


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
                    padding: EdgeInsets.only(top: 10.h),
                    child: Center(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(width: 16.w),
                          InkWell(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context)=>BottomNavScreen()));
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
                                  child: Icon(Icons.arrow_back_ios, size: 15.sp,color: AppColors.iconColor,),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Text(
                            "Wishlist",
                            style: GoogleFonts.jost(
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Spacer(),

                          SizedBox(width: 16.w),
                        ],
                      ),
                    ),
                  ),
                ),


                Expanded(
                  child: GridView.builder(
                    padding: EdgeInsets.all(12.w),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12.w,
                      mainAxisSpacing: 12.h,
                      childAspectRatio: 0.40,
                    ),
                    itemCount: wishlistProducts.length,
                    itemBuilder: (context, index) {
                      final product = wishlistProducts[index];
                      return ProductCard(
                        product: product,
                        userId: userID,
                        branchId: branchId,
                        onCartUpdated: () {
                          fetchCartQuantity(userID); // ✅ Real-time update
                        },
                        onWishlistUpdated: (){
                          fetchWishlist(userID);
                        },

                        onCategoryBack: (){
                          setState(() {
                            fetchCartQuantity(userID);
                          });
                        },
                      );
                    },
                  ),
                )

              ],
            ),
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
                      // fetchCartQuantities(userId);
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

}