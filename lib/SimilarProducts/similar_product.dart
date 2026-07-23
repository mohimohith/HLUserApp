import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../BottomNav/Screens/cartScreen.dart';
import '../Provider/cart_provider.dart';
import '../CustomWidgets/product_card.dart';
import '../SearchProduct/search_product.dart';
import '../compat/app_state.dart';
import '../compat/legacy_adapters.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';

class SimilarProduct extends StatefulWidget {
  final String category_id;
  final String category_name;

  SimilarProduct({
    required this.category_id,
    required this.category_name,
  });

  @override
  State<SimilarProduct> createState() => _SimilarProductState();
}

class _SimilarProductState extends State<SimilarProduct> {
  List products = [];
  bool _isLoadingProducts = false;
  List<Map<String, dynamic>> cartList = [];

  String userEmail = "";
  String userName = "";
  String userID = "";

  String branchId = '';
  String branchName  = "";



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
    await fetchAllProductsFromCategory(widget.category_id);
  }



  Future<void> fetchUserData() async {
    final uid = AppState.userId;
    if (uid.isNotEmpty) {
      setState(() => userID = uid);
      await fetchCartQuantity(uid);
    }
  }


  /// Cart quantity fetch from server cart.
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

  /// Products fetch by category.
  Future<void> fetchAllProductsFromCategory(String id) async {
    setState(() {
      _isLoadingProducts = true;
      products = [];
    });
    try {
      final res = await Repos.products.list(
          branchId: branchId.isEmpty ? AppState.branchIdOrEmpty : branchId,
          categoryId: id, page: 1, limit: 50);
      setState(() => products = LegacyAdapters.products(res.items));
    } catch (e) {
      setState(() => products = []);
    } finally {
      setState(() => _isLoadingProducts = false);
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

              // ✅ Products Grid
              if (products.isNotEmpty)
                Expanded(child: buildSection(products)),
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
              widget.category_name,
              style: GoogleFonts.jost(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
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
            branchId: branchId.toString(),

            onCartUpdated: () {
              fetchCartQuantity(userID); // ✅ Real-time update
            },
          );
        },
      ),
    );
  }
}
