import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../Provider/cart_provider.dart';
import '../../CustomWidgets/product_card.dart';
import '../../compat/app_state.dart';
import '../../compat/legacy_adapters.dart';
import '../../data/repositories/repositories.dart';
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

  String branchId = '';
  String branchName  = "";

  List<Map<String, dynamic>> cartList = [];

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchLocation();
  }


  Future<void> fetchLocation() async {
    setState(() {
      branchId = AppState.branchIdOrEmpty;
      branchName = AppState.branchName ?? "";
    });
  }

  Future<void> fetchUserData() async {
    final uid = AppState.userId;
    if (uid.isNotEmpty) {
      setState(() => userID = uid);
      await fetchCartQuantity(uid);
      fetchWishlist(uid);
    }
  }


  /// Cart quantity fetch from the server cart.
  Future<void> fetchCartQuantity(String id) async {
    try {
      final bid = AppState.branchIdOrEmpty;
      if (bid.isEmpty) return;
      final cart = await Repos.cart.getCart(bid);
      setState(() {
        cartList = cart.items.map((i) => {
          'product_id': i.productId,
          'variant_id': i.variantId ?? '',
          'quantity': i.quantity,
          'id': i.id,
        }).toList();
      });
    } catch (e) {
      setState(() => cartList = []);
    }
  }

  Future<void> fetchWishlist(String userID) async {
    if (userID.isEmpty) return;
    setState(() => isLoading = true);
    try {
      final items = await Repos.wishlist.list();
      setState(() => wishlistProducts = LegacyAdapters.products(items));
    } catch (e) {
      debugPrint('Error fetching wishlist: $e');
      setState(() => wishlistProducts = []);
    } finally {
      setState(() => isLoading = false);
    }
  }



  Future<void> removeFromWishlist(String productId) async {
    try {
      await Repos.wishlist.remove(productId);
      setState(() {
        wishlistProducts.removeWhere((item) =>
            (item['id'] ?? item['product_id']).toString() == productId);
      });
    } catch (e) {
      debugPrint('Error removing from wishlist: $e');
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
                        branchId: branchId.toString(),
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