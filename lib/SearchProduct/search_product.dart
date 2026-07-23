import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../BottomNav/Screens/cartScreen.dart';
import '../Provider/cart_provider.dart';
import '../CustomWidgets/product_card.dart';
import '../compat/app_state.dart';
import '../compat/legacy_adapters.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';

class SearchProduct extends StatefulWidget {
  final String? category_name; // category name optional
  const SearchProduct({super.key, this.category_name});

  @override
  State<SearchProduct> createState() => _SearchProductState();
}

class _SearchProductState extends State<SearchProduct> {
  TextEditingController searchController = TextEditingController();
  List products = [];
  bool isLoading = false;
  String currentSearchTerm = "";
  bool hasSearched = false;

  bool _isLoadingProducts = false;
  List<Map<String, dynamic>> cartList = [];

  String userEmail = "";
  String userName = "";
  String userID = "";


  // Voice recognition variables
  stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  String _recognizedText = '';

  String branchId = '';
  String branchName  = "";



  @override
  void initState() {
    super.initState();
    fetchLocation();
    fetchUserData();
    _initializeSpeech();
  }


  Future<void> fetchLocation() async {
    setState(() {
      branchId = AppState.branchIdOrEmpty;
      branchName = AppState.branchName ?? "";
    });
    await fetchProducts();
  }


  // Initialize speech to text
  void _initializeSpeech() async {
    bool available = await _speech.initialize(
      onStatus: (status) {
        print('Speech status: $status');
        if (status == 'done') {
          setState(() {
            _isListening = false;
          });
        }
      },
      onError: (errorNotification) {
        print('Speech error: $errorNotification');
        setState(() {
          _isListening = false;
        });
      },
    );

    if (!available) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice search not available on this device')),
      );
    }
  }

  // Start listening for voice input
  void _startListening() async {
    if (!_speech.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice search not available')),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _recognizedText = '';
    });

    _speech.listen(
      onResult: (result) {
        setState(() {
          _recognizedText = result.recognizedWords;
          if (result.finalResult) {
            searchController.text = _recognizedText;
            fetchProducts(search: _recognizedText);
            _isListening = false;
          }
        });
      },
      listenFor: Duration(seconds: 10),
      pauseFor: Duration(seconds: 5),
      partialResults: true,
      localeId: 'en_US',
    );
  }

  // Stop listening
  void _stopListening() {
    _speech.stop();
    setState(() {
      _isListening = false;
    });
  }

  Future<void> fetchProducts({String search = ""}) async {
    setState(() {
      isLoading = true;
      currentSearchTerm = search;
      hasSearched = true;
    });
    try {
      final res = await Repos.products.list(
          branchId: branchId,
          search: search.isEmpty ? null : search,
          page: 1, limit: 20);
      setState(() => products = LegacyAdapters.products(res.items));
    } catch (e) {
      debugPrint("Error searching products: $e");
    }
    setState(() => isLoading = false);
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
      if (branchId.isEmpty) return;
      final cart = await Repos.cart.getCart(branchId);
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

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
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

              // ✅ Top Custom AppBar with Search Bar
              buildAppBar(),

              SizedBox(height: 10.h),

              // ✅ Showing Results Text
              if (hasSearched && currentSearchTerm.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: RichText(
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: "Showing Results for ",
                            style: GoogleFonts.jost(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.hintTextColor,
                            ),
                          ),
                          TextSpan(
                            text: '"$currentSearchTerm"',
                            style: GoogleFonts.jost(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              SizedBox(height: 10.h),

              // ✅ Products Grid or No Results
              if (products.isNotEmpty)
                Expanded(child: buildSection(products)),

              if (hasSearched && products.isEmpty && !isLoading)
                Expanded(
                  child: Center(
                    child: Text(
                      "No products found",
                      style: GoogleFonts.jost(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                        color: AppColors.hintTextColor,
                      ),
                    ),
                  ),
                ),

              if (isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),

          // Voice listening overlay
          if (_isListening)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.7),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mic,
                        size: 64.sp,
                        color: Colors.white,
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        "Listening...",
                        style: GoogleFonts.jost(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        _recognizedText,
                        style: GoogleFonts.jost(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 30.h),
                      ElevatedButton(
                        onPressed: _stopListening,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(
                            horizontal: 30.w,
                            vertical: 15.h,
                          ),
                        ),
                        child: Text(
                          "Stop Listening",
                          style: GoogleFonts.jost(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ✅ Floating Cart Button (Only show if cartList is not empty)
          if (cartProvider.getTotalCartItems(userID) > 0 && !_isListening)
            AnimatedPositioned(
              duration: Duration(milliseconds: 300),
              curve: Curves.slowMiddle,
              bottom: cartProvider.getTotalCartItems(userID) > 0 ? 16.h : -50.h,
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
                      // fetchCartQuantities(userId); // agar zarurat ho toh yaha call karna
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
            )

        ],
      ),
    );
  }

  /// ✅ Custom Header with Search Bar
  Widget buildAppBar() {
    return Container(
      width: double.infinity,
      height: 110.h,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
      ),
      child: Column(
        children: [
          SizedBox(height: 17.h),

          Padding(
            padding:  EdgeInsets.only(top: 6.h),
            child: Row(
              children: [
                SizedBox(width: 13.w),

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
                Spacer(),

                Text('Search', style: GoogleFonts.jost(
                  fontWeight: FontWeight.w500,
                  fontSize: 16.sp,
                )),
                Spacer(),

                SizedBox(width: 40.w),
              ],
            ),
          ),

          SizedBox(height: 20.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Container(
              width: double.infinity,
              height: 40.h,
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: AppColors.lineColor, width: 1.5),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10.w),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 20.sp, color: AppColors.hintTextColor),
                  SizedBox(width: 6.w),

                  /// ✅ Expanded TextField with Animated Placeholder
                  Expanded(
                    child: Stack(
                      alignment: Alignment.centerLeft,
                      children: [
                        // ✅ Animated Hint (visible only when empty)
                        if (searchController.text.isEmpty)
                          IgnorePointer(
                            child: AnimatedTextKit(
                              repeatForever: true,
                              pause: Duration(milliseconds: 2000),
                              animatedTexts: [
                                TyperAnimatedText("Search for Grocery",
                                    textStyle: GoogleFonts.jost(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.hintTextColor),
                                    speed: Duration(milliseconds: 80)),
                                TyperAnimatedText("Search for Beauty",
                                    textStyle: GoogleFonts.jost(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.hintTextColor),
                                    speed: Duration(milliseconds: 80)),
                                TyperAnimatedText("Search for Snacks",
                                    textStyle: GoogleFonts.jost(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w400,
                                        color: AppColors.hintTextColor),
                                    speed: Duration(milliseconds: 80)),
                              ],
                            ),
                          ),

                        // ✅ TextField
                        Padding(
                          padding:  EdgeInsets.only(top: 8.h),
                          child: TextField(
                            controller: searchController,
                            textInputAction: TextInputAction.search,
                            style: GoogleFonts.jost(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: Colors.black,
                            ),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.only(bottom: 8.h),
                            ),
                            onChanged: (value) {
                              setState(() {}); // update clear button
                            },
                            onSubmitted: (value) {
                              fetchProducts(search: value);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  /// ✅ Mic / Clear button
                  if (searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        searchController.clear();
                        fetchProducts();
                        setState(() {});
                      },
                      child: Icon(Icons.close, size: 18.sp, color: Colors.grey),
                    )
                  else
                    GestureDetector(
                      onTap: _startListening,
                      child: Icon(
                        Icons.mic,
                        size: 20.sp,
                        color: _isListening ? AppColors.primaryColor : AppColors.hintTextColor,
                      ),
                    ),
                ],
              ),
            ),
          )
        ],
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