import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../ProductDetailScreen/product_details_screen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import '../utils/responsive_helper.dart';
import '../Provider/cart_provider.dart';
import '../Provider/language_provider.dart';

class SpProduct extends StatefulWidget {
  final Map<String, dynamic> product;
  final String userId;
  final int branchId; // ✅ ADD
  final VoidCallback? onCartUpdated;
  final VoidCallback? onWishlistUpdated;
  final VoidCallback? onCategoryBack;

  const SpProduct({
    Key? key,
    required this.product,
    required this.userId,
    required this.branchId,
    this.onCartUpdated,
    this.onWishlistUpdated,
    this.onCategoryBack,

  }) : super(key: key);

  @override
  State<SpProduct> createState() => _SpProductState();
}

class _SpProductState extends State<SpProduct> {
  String deliveryTime = '17 MIN';
  bool isLoading = false;
  bool isWishlisted = false;
  bool isWishlistLoading = false;

  @override
  void initState() {
    super.initState();
    // Delivery time is now read from CartProvider in didChangeDependencies
    // Wishlist check is deferred — only checked when heart icon is tapped
  }

  // Helper method to get product name based on selected language
  String getProductName(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final String englishName = widget.product['name'] ?? '';
    final String teluguName = widget.product['name_telugu'] ?? '';

    if (languageProvider.selectedLanguage == "Telugu" && teluguName.isNotEmpty) {
      return teluguName;
    } else {
      return englishName.isNotEmpty ? englishName : "Product Name";
    }
  }

  // Helper method to get text
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  Future<void> checkWishlistStatus() async {
    if (widget.userId.isEmpty) return;

    setState(() {
      isWishlistLoading = true;
    });

    try {
      final url = Uri.parse('${ApiConstants.CHECK_WISHLIST}?user_id=${widget.userId}&product_id=${widget.product['id']}');
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success']) {
        setState(() {
          isWishlisted = data['is_wishlisted'] ?? false;
        });
      }
    } catch (e) {
      print('Error checking wishlist status: $e');
    } finally {
      setState(() {
        isWishlistLoading = false;
      });
    }
  }

  Future<void> toggleWishlist(BuildContext context) async {
    if (widget.userId.isEmpty) {
      Fluttertoast.showToast(
        msg: getText(
            context,
            "Please login to add to wishlist",
            "విష్లిస్ట్‌కి జోడించడానికి దయచేసి లాగిన్ అవ్వండి"
        ),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
      return;
    }

    setState(() {
      isWishlistLoading = true;
    });

    try {
      final url = Uri.parse(isWishlisted ? ApiConstants.REMOVE_FROM_WISHLIST : ApiConstants.ADD_TO_WISHLIST);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId,
          'product_id': widget.product['id'],
        }),
      );

      final data = json.decode(response.body);
      if (data['success']) {
        setState(() {
          isWishlisted = !isWishlisted;
        });
        widget.onWishlistUpdated?.call();

        Fluttertoast.showToast(
          msg: isWishlisted
              ? getText(context, "Added to wishlist", "విష్లిస్ట్‌కి జోడించబడింది")
              : getText(context, "Removed from wishlist", "విష్లిస్ట్ నుండి తీసివేయబడింది"),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: isWishlisted ? Colors.green : Colors.orange,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error toggling wishlist: $e');
      Fluttertoast.showToast(
        msg: getText(context, "Something went wrong", "ఏదో తప్పు జరిగింది"),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isWishlistLoading = false;
      });
    }
  }

  Future<void> fetchDeliveryTime() async {
    try {
      print("Branch ID inside fetchDeliveryTime: ${widget.branchId}");

      final url = Uri.parse(
          ApiConstants.DELIVERY_TIME + "?branch_id=${widget.branchId}"
      );

      print("API HIT URL: $url");

      final response = await http.get(url);
      final data = json.decode(response.body);

      print("API RESPONSE: $data");

      if (data['success']) {
        setState(() {
          deliveryTime = data['data']['time'].toString();
        });
      } else {
        setState(() {
          deliveryTime = 'No time found';
        });
      }

    } catch (e) {
      print("ERROR IN fetchDeliveryTime: $e");

      setState(() {
        deliveryTime = 'Error fetching time';
      });
    }
  }



  // Helper method to show toast message
  void _showToastMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: 2),
        backgroundColor: AppColors.errorColor,
      ),
    );
  }

  Future<void> addToCart(BuildContext context, int variantId, String imageUrl) async {
    setState(() {
      isLoading = true;
    });

    try {
      final productId = widget.product['id'].toString();

      final url = Uri.parse(ApiConstants.ADD_TO_CART);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': widget.userId.toString(),
          'product_id': productId,
          'variant_id': variantId.toString(),
          'quantity': 1,
          'image_url': imageUrl,
          'branch_id' : widget.branchId.toString(),
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);

        cartProvider.updateCartQuantities(
          widget.userId,
          productId,
          variantId.toString(),
          1,
          data['cart_id'] ?? 0,
        );

        widget.onCartUpdated?.call();
        setState(() {});

        Fluttertoast.showToast(
          msg: getText(context, "Added to cart", "కార్ట్‌కి జోడించబడింది"),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
        );
      } else {
        Fluttertoast.showToast(
          msg: data['message'] ?? getText(context, "Failed to add to cart", "కార్ట్‌కి జోడించడం విఫలమైంది"),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('❌ Error adding to cart: $e');
      Fluttertoast.showToast(
        msg: getText(context, "Something went wrong", "ఏదో తప్పు జరిగింది"),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Read delivery time from CartProvider (set by HomeScreen once)
    // to avoid N duplicate API calls from every SpProduct
    final providerTime = cartProvider.deliveryTime;
    if (providerTime.isNotEmpty && deliveryTime == '17 MIN') {
      setState(() {
        deliveryTime = providerTime;
      });
    }
    // Fallback: fetch once if provider doesn't have it yet
    if (providerTime.isEmpty && deliveryTime == '17 MIN') {
      fetchDeliveryTime();
    }
  }

  Future<void> updateQuantity(BuildContext context, int variantId, int newQuantity) async {
    setState(() {
      isLoading = true;
    });

    try {
      final variants = widget.product['variants'] as List;
      final variant = variants.firstWhere(
            (v) => int.tryParse(v['id']?.toString() ?? '0') == variantId,
        orElse: () => null,
      );

      if (variant != null) {
        final stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
        if (newQuantity > stock) {
          _showToastMessage(
            context,
            getText(
                context,
                'Only $stock items available in stock',
                '$stock ఐటమ్లు మాత్రమే స్టాక్‌లో అందుబాటులో ఉన్నాయి'
            ),
          );
          return;
        }
      }

      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final productId = widget.product['id'].toString();

      int cartId = cartProvider.getCartId(widget.userId, productId, variantId.toString());

      if (cartId == 0) {
        cartId = await _findCartIdDirectly(widget.userId, productId, variantId.toString());

        if (cartId == 0) {
          print("⚠️ Cart item not found in server either");
          Fluttertoast.showToast(
            msg: getText(
                context,
                "Cart item not found. Please add it again.",
                "కార్ట్ ఐటం కనుగొనబడలేదు. దయచేసి మళ్లీ జోడించండి."
            ),
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            backgroundColor: Colors.red,
            textColor: Colors.white,
          );
          return;
        }
      }

      final url = Uri.parse(ApiConstants.UPDATE_QUANTITY);
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'id': cartId, 'quantity': newQuantity}),
      );

      final data = json.decode(response.body);
      if (data['success']) {
        _refreshCartData(context);
        cartProvider.updateCartQuantities(
          widget.userId,
          productId,
          variantId.toString(),
          newQuantity,
          cartId,
        );
        widget.onCartUpdated?.call();
        setState(() {});
      } else {
        print("⚠️ Update quantity API failed: ${data['message']}");
        Fluttertoast.showToast(
          msg: getText(context, "Failed to update quantity", "పరిమాణం నవీకరించడం విఫలమైంది"),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error updating quantity: $e');
      Fluttertoast.showToast(
        msg: getText(context, "Network error. Please try again.", "నెట్‌వర్క్ లోపం. దయచేసి మళ్లీ ప్రయత్నించండి."),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<int> _findCartIdDirectly(String userId, String productId, String variantId) async {
    try {
      final url = Uri.parse('${ApiConstants.GET_CART_ITEMS}?user_id=$userId');
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success']) {
        final cartItems = List<Map<String, dynamic>>.from(data['cart'] ?? []);

        for (var item in cartItems) {
          final itemProductId = item['product_id'].toString();
          final itemVariantId = item['variant_id'].toString();

          if (itemProductId == productId && itemVariantId == variantId) {
            return item['id'] as int;
          }
        }
      }
    } catch (e) {
      print('Error finding cart ID directly: $e');
    }

    return 0;
  }

  void _refreshCartData(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    cartProvider.refreshCartData(widget.userId,widget.branchId).then((_) {
      setState(() {});
    });
  }

  Future<void> removeFromCart(BuildContext context, int variantId) async {
    setState(() {
      isLoading = true;
    });

    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      final cartId = cartProvider.getCartId(widget.userId, widget.product['id'].toString(), variantId.toString());

      final url = Uri.parse('${ApiConstants.REMOVE_CART_ITEM}?id=$cartId');
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['success']) {
        cartProvider.removeCartItem(widget.userId, widget.product['id'].toString(), variantId.toString());
        widget.onCartUpdated?.call();
        setState(() {});

        Fluttertoast.showToast(
          msg: getText(context, "Removed from cart", "కార్ట్ నుండి తీసివేయబడింది"),
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.orange,
          textColor: Colors.white,
        );
      }
    } catch (e) {
      print('Error removing from cart: $e');
      Fluttertoast.showToast(
        msg: getText(context, "Error removing from cart", "కార్ట్ నుండి తీసివేయడంలో లోపం"),
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showVariantBottomSheet(BuildContext context, List variants) {
    final productName = getProductName(context);
    final productImage =
    (widget.product['images'] != null && widget.product['images'].isNotEmpty)
        ? widget.product['images'][0]
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) {

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final cartProvider = Provider.of<CartProvider>(context);

              void _localAddToCart(int variantId) async {
                final imageUrl = ApiConstants.BASE_URL + '/product_api_project/$productImage';
                await addToCart(context, variantId, imageUrl);
                setModalState(() {});
              }

              void _localUpdateQuantity(int variantId, int newQty) async {
                await updateQuantity(context, variantId, newQty);
                setModalState(() {});
              }

              void _localRemoveFromCart(int variantId) async {
                await removeFromCart(context, variantId);
                setModalState(() {});
              }

              return Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(left: 15.w),
                      child: Text(
                        productName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.jost(
                          fontWeight: FontWeight.w500,
                          color: AppColors.primaryTextColor,
                          fontSize: 14.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Flexible(
                      fit: FlexFit.loose,
                      child: ListView.builder(
                        shrinkWrap: true,
                        physics: ClampingScrollPhysics(),
                        itemCount: variants.length,
                        itemBuilder: (context, index) {
                          final variant = variants[index];
                          final variantName = variant['name'] ?? 'N/A';

                          final variantPrice = double.tryParse(variant['price']?.toString() ?? '0') ?? 0;
                          final stock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
                          final variantSellingPrice = double.tryParse(variant['selling_price']?.toString() ?? '0') ?? 0;

                          final discountPercentage = variantPrice > 0
                              ? ((variantPrice - variantSellingPrice) / variantPrice * 100).round()
                              : 0;

                          final variantId = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;
                          final quantity = cartProvider.getQuantity(
                            widget.userId,
                            widget.product['id'].toString(),
                            variantId.toString(),
                          );

                          final isOutOfStock = stock <= 0;

                          return Padding(
                            padding: EdgeInsets.only(left: 10.w, right: 10.w),
                            child: Container(
                              margin: EdgeInsets.only(bottom: 10.h),
                              decoration: BoxDecoration(
                                color: AppColors.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              padding: EdgeInsets.all(8.w),
                              child: Stack(
                                children: [
                                  Row(
                                    children: [
                                      Stack(
                                        children: [
                                          Container(
                                            width: 50.h,
                                            height: 50.h,
                                            decoration: BoxDecoration(
                                              color: AppColors.backgroundColor,
                                              borderRadius: BorderRadius.circular(10.r),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.1),
                                                  blurRadius: 0.1,
                                                ),
                                              ],
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(12.r),
                                              child: Center(
                                                child: Image.network(
                                                  ApiConstants.BASE_URL +
                                                      '/product_api_project/${widget.product['images'][0]}',
                                                  width: ResponsiveHelper.getResponsiveWidth(context,
                                                    mobile: 40.w,
                                                    tablet: 50.w,
                                                    desktop: 60.w,
                                                  ),
                                                  height: ResponsiveHelper.getResponsiveHeight(context,
                                                    mobile: 40.h,
                                                    tablet: 50.h,
                                                    desktop: 60.h,
                                                  ),
                                                  fit: BoxFit.contain,
                                                  errorBuilder: (_, __, ___) =>
                                                      Icon(Icons.image, size: ResponsiveHelper.getResponsiveFontSize(context,
                                                        mobile: 24.sp,
                                                        tablet: 28.sp,
                                                        desktop: 32.sp,
                                                      )),
                                                ),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            child: Container(
                                              padding: EdgeInsets.symmetric(horizontal: 3.w, vertical: 2.h),
                                              decoration: BoxDecoration(
                                                color: AppColors.secondaryColor,
                                                borderRadius: BorderRadius.only(
                                                  bottomRight: Radius.circular(10.r),
                                                  topLeft: Radius.circular(10.r),
                                                ),
                                              ),
                                              child: Text(
                                                '$discountPercentage%\n${getText(context, "OFF", "ఆఫ్")}',
                                                style: GoogleFonts.jost(
                                                  fontSize: ResponsiveHelper.getResponsiveFontSize(context,
                                                    mobile: 5.sp,
                                                    tablet: 6.sp,
                                                    desktop: 7.sp,
                                                  ),
                                                  color: AppColors.primaryTextColor,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Text(
                                          variantName,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,

                                        ),
                                      ),
                                      LayoutBuilder(
                                        builder: (context, constraints) {
                                          if (isOutOfStock) {
                                            return Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: Colors.grey.withOpacity(0.3),
                                                borderRadius: BorderRadius.circular(6.r),
                                              ),
                                              child: Text(
                                                getText(context, 'Out of Stock', 'స్టాక్ లేదు'),
                                                style: GoogleFonts.jost(
                                                  fontSize: 12.sp,
                                                  color: Colors.grey[700],
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            );
                                          } else if (constraints.maxWidth > 200) {
                                            return Row(
                                              children: [
                                                Text(
                                                  '₹${variantSellingPrice.toStringAsFixed(0)}',
                                                  style: GoogleFonts.jost(
                                                      fontWeight: FontWeight.w600, fontSize: 15.sp),
                                                ),
                                                if (discountPercentage > 0) ...[
                                                  SizedBox(width: 5.w),
                                                  Text(
                                                    '₹${variantPrice.toStringAsFixed(0)}',
                                                    style: GoogleFonts.plusJakartaSans(
                                                      fontWeight: FontWeight.normal,
                                                      fontSize: 12.sp,
                                                      decoration: TextDecoration.lineThrough,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ],
                                                SizedBox(width: 10.w),
                                                _buildCartControl(
                                                  context,
                                                  quantity,
                                                  variantId,
                                                  stock,
                                                  _localRemoveFromCart,
                                                  _localUpdateQuantity,
                                                  _localAddToCart,
                                                ),
                                              ],
                                            );
                                          } else {
                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.end,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      '₹${variantSellingPrice.toStringAsFixed(0)}',
                                                      style: GoogleFonts.jost(
                                                          fontWeight: FontWeight.w600, fontSize: 15.sp),
                                                    ),
                                                    if (discountPercentage > 0) ...[
                                                      SizedBox(width: 5.w),
                                                      Text(
                                                        '₹${variantPrice.toStringAsFixed(0)}',
                                                        style: GoogleFonts.plusJakartaSans(
                                                          fontWeight: FontWeight.normal,
                                                          fontSize: 12.sp,
                                                          decoration: TextDecoration.lineThrough,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                SizedBox(height: 5.h),
                                                _buildCartControl(
                                                  context,
                                                  quantity,
                                                  variantId,
                                                  stock,
                                                  _localRemoveFromCart,
                                                  _localUpdateQuantity,
                                                  _localAddToCart,
                                                ),
                                              ],
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                  if (isOutOfStock)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.7),
                                          borderRadius: BorderRadius.circular(20.r),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 10.h),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCartControl(
      BuildContext context,
      int quantity,
      int variantId,
      int stock,
      Function(int) removeFromCart,
      Function(int, int) updateQuantity,
      Function(int) addToCart) {
    final decoration = BoxDecoration(
      color: AppColors.primaryColor,
      borderRadius: BorderRadius.circular(7.r),
    );

    final textStyle = GoogleFonts.jost(
      fontWeight: FontWeight.w500,
      fontSize: 14.sp,
      color: AppColors.primaryTextColor,
    );

    if (quantity > 0) {
      return Container(
        decoration: decoration,
        height: 24.h,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SizedBox(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16.sp,
                    icon: Icon(
                      quantity == 1 ? Icons.delete : Icons.remove,
                      color: AppColors.primaryTextColor,
                    ),
                    onPressed: () {
                      if (quantity == 1) {
                        removeFromCart(variantId);
                      } else {
                        updateQuantity(variantId, quantity - 1);
                      }
                    },
                  ),
                  Text(
                    quantity.toString(),
                    style: textStyle,
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 16.sp,
                    icon: Icon(Icons.add, color: AppColors.primaryTextColor),
                    onPressed: () {
                      if (quantity + 1 > stock) {
                        _showToastMessage(context, getText(
                            context,
                            'Only $stock items available in stock',
                            '$stock ఐటమ్లు మాత్రమే స్టాక్‌లో అందుబాటులో ఉన్నాయి'
                        ));
                      } else {
                        updateQuantity(variantId, quantity + 1);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        ),
      );
    } else {
      return GestureDetector(
        onTap: () {
          if (stock <= 0) {
            _showToastMessage(context, getText(context, 'Product is out of stock', 'ఉత్పత్తి స్టాక్లో లేదు'));
          } else {
            addToCart(variantId);
          }
        },
        child: Container(
          decoration: decoration,
          height: 24.h,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 10.w),
            child: Center(
              child: Text(
                getText(context, 'Add to Cart', 'కార్ట్‌కి జోడించండి'),
                style: GoogleFonts.jost(
                  color: AppColors.primaryTextColor,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            final productName = getProductName(context);
            final productImage =
            (widget.product['images'] != null && widget.product['images'].isNotEmpty)
                ? widget.product['images'][0]
                : null;

            final variants = widget.product['variants'] as List?;
            final Map<String, dynamic>? firstVariant =
            (variants != null && variants.isNotEmpty) ? variants[0] : null;

            final variantName = firstVariant?['name'] ?? 'N/A';
            final variantPrice = double.tryParse(firstVariant?['price']?.toString() ?? '0') ?? 0;
            final stock = int.tryParse(firstVariant?['stock']?.toString() ?? '0') ?? 0;
            final variantSellingPrice =
                double.tryParse(firstVariant?['selling_price']?.toString() ?? '0') ?? 0;

            final discountPercentage = variantPrice > 0
                ? ((variantPrice - variantSellingPrice) / variantPrice * 100).round()
                : 0;

            final int? firstVariantId =
                int.tryParse(firstVariant?['id']?.toString() ?? '0') ?? 0;

            final productQuantity = cartProvider.getProductTotalQuantity(
                widget.userId, widget.product['id'].toString());

            final allOutOfStock = variants != null &&
                variants.isNotEmpty &&
                variants.every((variant) =>
                (int.tryParse(variant['stock']?.toString() ?? '0') ?? 0) <= 0);

            return SizedBox(

              child: InkWell(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Image container
                      Container(
                        width: 200.h,
                        height: 100.h,
                        margin: EdgeInsets.only(top: 0.h),
                        child: Stack(
                          children: [
                            Container(
                              width: 200.h,
                              height: 100.h,
                              decoration: BoxDecoration(
                                color: AppColors.backgroundColor,
                                borderRadius: BorderRadius.circular(10.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12.r),
                                child: Center(
                                  child: Image.network(
                                    ApiConstants.BASE_URL +
                                        '/product_api_project/$productImage',
                                    width: 80.w,
                                    height: 80.h,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Image.asset(
                                      "assets/images/placeholder_product_card.png",
                                      width: 80.w,
                                      height: 80.h,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 0,
                              left: 0,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 6.w, vertical: 2.h),
                                decoration: BoxDecoration(
                                  color: AppColors.secondaryColor,
                                  borderRadius: BorderRadius.only(
                                    bottomRight: Radius.circular(10.r),
                                    topLeft: Radius.circular(10.r),
                                  ),
                                ),
                                child: Text(
                                  '$discountPercentage%\n${getText(context, "OFF", "ఆఫ్")}',
                                  style: GoogleFonts.jost(
                                    fontSize: 8.sp,
                                    color: AppColors.primaryTextColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 7,
                              child: GestureDetector(
                                onTap: () {
                                  if (!isWishlistLoading) {
                                    toggleWishlist(context);
                                  }
                                },
                                child: isWishlistLoading
                                    ? SizedBox(
                                  width: ResponsiveHelper.getResponsiveWidth(context,
                                    mobile: 14.w,
                                    tablet: 16.w,
                                    desktop: 18.w,
                                  ),
                                  height: ResponsiveHelper.getResponsiveHeight(context,
                                    mobile: 14.h,
                                    tablet: 16.h,
                                    desktop: 18.h,
                                  ),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                    AlwaysStoppedAnimation<Color>(
                                        AppColors.primaryColor),
                                  ),
                                )
                                    : SvgPicture.asset(
                                  isWishlisted
                                      ? 'assets/svg/wishlist_red.svg'
                                      : 'assets/svg/fev.svg',
                                  width: ResponsiveHelper.getResponsiveWidth(context,
                                    mobile: 14.w,
                                    tablet: 16.w,
                                    desktop: 18.w,
                                  ),
                                ),
                              ),
                            ),


                          ],
                        ),
                      ),
                      SizedBox(height: 6.h),

                      Padding(
                        padding:  EdgeInsets.only(left: 8.w,right: 8.w),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [

                            // Variant and delivery time
                            Container(
                              height: 20.h,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Flexible(
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: 80.w),
                                      decoration: BoxDecoration(
                                        color: AppColors.gray,
                                        borderRadius: BorderRadius.circular(10.r),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 5.w, vertical: 1.h),
                                      child: Text(
                                        variantName,
                                        style: GoogleFonts.jost(
                                          fontSize: 10.sp,
                                          color: AppColors.secondaryTextColor,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  SvgPicture.asset('assets/svg/time.svg',
                                    height: ResponsiveHelper.getResponsiveHeight(context,
                                      mobile: 10.h,
                                      tablet: 12.h,
                                      desktop: 14.h,
                                    ),
                                  ),
                                  Flexible(
                                    child: Text(
                                      deliveryTime == "1"
                                          ? getText(context, " close", " మూసివేయండి")
                                          : formatDeliveryTime(deliveryTime).toUpperCase(),
                                      style: GoogleFonts.jost(
                                        fontSize: 10.sp,
                                        color: AppColors.secondaryTextColor,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Product name
                            Container(

                              width: 110.w,
                              padding: EdgeInsets.symmetric(horizontal: 1.w),
                              child: Text(
                                productName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.jost(
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ),

                            // Price
                            Container(
                              height: 18.h,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  Text(
                                    '₹${variantSellingPrice.toStringAsFixed(0)}',
                                    style: GoogleFonts.dmSans(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15.sp,
                                    ),
                                  ),
                                  if (discountPercentage > 0) ...[
                                    SizedBox(width: 6.w),
                                    Text(
                                      '₹${variantPrice.toStringAsFixed(0)}',
                                      style: GoogleFonts.dmSans(
                                        fontWeight: FontWeight.normal,
                                        fontSize: 12.sp,
                                        decoration: TextDecoration.lineThrough,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),




                          ],
                        ),
                      ),

                      // Cart button
                      Container(
                        height: 30.h,
                        width: 120.w,
                        padding: EdgeInsets.symmetric(horizontal: 0.w, vertical: 4.h),
                        child: allOutOfStock
                            ? _buildOutOfStockButton(context)
                            : _buildMainCartButton(context, variants, firstVariantId, stock),
                      ),


                      
                    ],
                  ),
                ),
                onTap: () async {
                  if (allOutOfStock) return;

                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          ProductDetailsScreen(product: widget.product),
                    ),
                  );

                  if (widget.onCategoryBack != null) {
                    widget.onCategoryBack!();
                  }
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMainCartButton(BuildContext context, List? variants, int? variantId, int stock) {
    final productImage =
    (widget.product['images'] != null && widget.product['images'].isNotEmpty)
        ? widget.product['images'][0]
        : null;

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        final productQuantity = cartProvider.getProductTotalQuantity(widget.userId, widget.product['id'].toString());

        if (productQuantity > 0) {
          return Container(
            width: double.infinity,
            height: 24.h,
            decoration: BoxDecoration(
              color: AppColors.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7.r),
            ),
            child: Container(
              height: 24.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.secondaryColor, AppColors.primaryColor],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.circular(7.r),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(maxWidth: 30.w),
                    icon: Icon(
                      productQuantity == 1 ? Icons.delete : Icons.remove,
                      size: ResponsiveHelper.getResponsiveFontSize(context,
                        mobile: 16.sp,
                        tablet: 18.sp,
                        desktop: 20.sp,
                      ),
                      color: AppColors.primaryTextColor,
                    ),
                    onPressed: () {
                      if (productQuantity == 1) {
                        final variants = widget.product['variants'] as List;
                        for (var variant in variants) {
                          final variantId = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;
                          final quantity = cartProvider
                              .getQuantity(widget.userId, widget.product['id'].toString(), variantId.toString());

                          if (quantity > 0) {
                            removeFromCart(context, variantId);
                            break;
                          }
                        }
                      } else {
                        final variants = widget.product['variants'] as List;
                        for (var variant in variants) {
                          final variantId = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;
                          final quantity = cartProvider
                              .getQuantity(widget.userId, widget.product['id'].toString(), variantId.toString());

                          if (quantity > 0) {
                            updateQuantity(context, variantId, quantity - 1);
                            break;
                          }
                        }
                      }
                    },
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        productQuantity.toString(),
                        style: GoogleFonts.jost(
                          fontWeight: FontWeight.w500,
                          fontSize: 14.sp,
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: BoxConstraints(maxWidth: 30.w),
                    icon: Icon(
                      Icons.add,
                      size: ResponsiveHelper.getResponsiveFontSize(context,
                        mobile: 16.sp,
                        tablet: 18.sp,
                        desktop: 20.sp,
                      ),
                      color: AppColors.primaryTextColor,
                    ),
                    onPressed: () {
                      final variants = widget.product['variants'] as List;
                      for (var variant in variants) {
                        final variantId = int.tryParse(variant['id']?.toString() ?? '0') ?? 0;
                        final quantity = cartProvider
                            .getQuantity(widget.userId, widget.product['id'].toString(), variantId.toString());

                        if (quantity > 0) {
                          final variantStock = int.tryParse(variant['stock']?.toString() ?? '0') ?? 0;
                          if (quantity + 1 > variantStock) {
                            _showToastMessage(context, getText(
                                context,
                                'Only $variantStock items available in stock',
                                '$variantStock ఐటమ్లు మాత్రమే స్టాక్‌లో అందుబాటులో ఉన్నాయి'
                            ));
                          } else {
                            updateQuantity(context, variantId, quantity + 1);
                          }
                          break;
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          );
        } else {
          return GestureDetector(
            onTap: () {
              if ((variants?.length ?? 0) > 1) {
                _showVariantBottomSheet(context, variants!);
              } else if (variantId != null) {
                if (stock <= 0) {
                  _showToastMessage(context, getText(context, 'Product is out of stock', 'ఉత్పత్తి స్టాక్లో లేదు'));
                } else {
                  final imageUrl = ApiConstants.BASE_URL +
                      '/product_api_project/$productImage';
                  addToCart(context, variantId, imageUrl);
                }
              }
            },
            child: Container(
              width: double.infinity,
              height: 24.h,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.secondaryColor, AppColors.primaryColor],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.circular(7.r),
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        (variants?.length ?? 0) > 1
                            ? '${variants?.length} ${getText(context, "Options", "ఎంపికలు")}'
                            : getText(context, 'Add to Cart', 'కార్ట్‌కి జోడించండి'),
                        style: GoogleFonts.jost(
                          color: AppColors.primaryTextColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12.sp,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                    if ((variants?.length ?? 0) > 1)
                      Padding(
                        padding: EdgeInsets.only(left: 4.w),
                        child: Icon(Icons.keyboard_arrow_down,
                            size: 18.sp, color: AppColors.primaryTextColor),
                      ),
                  ],
                ),
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildOutOfStockButton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 24.h,
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.3),
        borderRadius: BorderRadius.circular(7.r),
      ),
      child: Center(
        child: Text(
          getText(context, 'Out of Stock', 'స్టాక్ లేదు'),
          style: GoogleFonts.jost(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 12.sp,
          ),
        ),
      ),
    );
  }

  String formatDeliveryTime(String input) {
    input = input.replaceAll(' ', '');
    final match = RegExp(r'^(\d+)([a-zA-Z]+)').firstMatch(input);

    if (match != null) {
      final number = match.group(1) ?? '';
      final unit = match.group(2)?.substring(0, 3).toUpperCase() ?? '';
      return '$number $unit';
    } else {
      return input.substring(0, input.length.clamp(0, 6)).toUpperCase();
    }
  }
}