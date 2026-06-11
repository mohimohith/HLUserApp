import 'dart:convert';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:nexa_mart/CustomWidgets/sp_product.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../LocationScreen/locationScreen.dart';
import '../../utils/responsive_helper.dart';
import '../../BrandCategory/brand_view_screen.dart';
import '../../CategoryViewScreen/categoryViewScreen.dart';
import '../../CategoryViewScreen/main_category_view.dart';
import '../../Provider/cart_provider.dart';
import '../../Provider/language_provider.dart';
import '../../CustomWidgets/main_category_with_subcategories.dart';
import '../../SearchProduct/search_product.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import 'cartScreen.dart';
import 'profileScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Scroll controller for detecting scroll direction
  final ScrollController _scrollController = ScrollController();
  bool _showStickySearchBar = false;
  double _scrollPosition = 0;

  // Data variables
  String deliveryTime = '15 minutes';
  String userId = "";
  bool _isLoading = true;

  // Popup state variables
  bool _showMiddleBannerPopup = false;
  bool _middleBannerShown = false;

  // Lists for various data
  List _topCategoryList = [];
  List _ocationCategoryList = [];
  List _offerBannerList = [];
  List _categoryList = [];
  List _brandList = [];
  List _sliderList = [];
  List<Map<String, dynamic>> _couponList = [];

  // Category position lists
  List<dynamic> mainFirstCategoryList = [];
  List<dynamic> mainSecondCategoryList = [];
  List<dynamic> mainThirdCategoryList = [];
  List<dynamic> mainFourthCategoryList = [];

  List<Map<String, dynamic>> cartList = [];

  // Section lists (ID के आधार पर)
  List<Map<String, dynamic>> _sectionList = []; // Store all sections from API
  Map<int, String> _sectionEnglishNames = {}; // Store section ID -> English Name mapping
  Map<int, String> _sectionTeluguNames = {}; // Store section ID -> Telugu Name mapping
  Map<int, List<dynamic>> _sectionProducts = {}; // Store section ID -> Products mapping
  Map<int, bool> _sectionLoading = {}; // Store section loading states
  List<Map<String, dynamic>> _defaultSections = []; // Sections 1-6
  List<Map<String, dynamic>> _extraSections = []; // Sections beyond 6

  // Special Categories and Products
  List<dynamic> _specialCategoryList = [];
  Map<String, List<dynamic>> _specialCategoryProducts = {};
  bool _isLoadingSpecialCategories = false;




  // Banner images
  String? bannerImage;
  String? discount_bannerImage;
  String? home_bannerImage;
  String? bottom_bannerImage;
  String? middle_bannerImage;

  String userLocation = "";
  String userPinCode = "";
  String userArea = "";
  String userCity = "";

  int branchId = 0;
  String branchName = "";

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_scrollListener);
    fetchLocation();

    // Set timers for popups
    Future.delayed(Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _showMiddleBannerPopup = true;
        });
      }
    });
  }

  // Helper method to get text based on language
  String getText(String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  // Get Section Name based on language
  String getSectionName(Map<String, dynamic> section) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);

    if (languageProvider.selectedLanguage == "Telugu") {
      String teluguName = section['name_telugu']?.toString() ?? '';
      if (teluguName.trim().isNotEmpty) {
        return teluguName;
      }
    }

    return section['section_name']?.toString() ?? 'Section';
  }

  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userID = prefs.getString('user_id');
    if (userID != null) {
      setState(() => userId = userID);
      await fetchCartQuantity(userID);
    }
  }

  Future<void> fetchLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? uArea = prefs.getString('user_area_h');
    String? uCity = prefs.getString('user_city_h');
    int bId = prefs.getInt('selected_branch_id') ?? 0;
    String? bName = prefs.getString('selected_branch_name');

    if ((uArea != null && uArea.trim().isNotEmpty) ||
        (uCity != null && uCity.trim().isNotEmpty)) {
      setState(() {
        userArea = uArea ?? "";
        userCity = uCity ?? "";
        branchId = bId;
        branchName = bName ?? "";
      });

      await _loadAllData();
    }
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);

    try {
      // Step 1 — Load Home Banner FIRST
      await fetchHomeBannerImage();
      _fetchCategories();
      _toCategoryList();
      fetchAllCategoryPositions();
      _fetchOfferBanners();

      // Step 2 — Critical user + delivery info
      await Future.wait([
        fetchUserData(),
        fetchDeliveryTime(),
      ]);

      // Step 3 — Fetch Sections FIRST
      await _fetchSections();

      // Step 4 — Main UI data
      await Future.wait([

        _fetchSlider(),

      ]);

      // Step 5 — Special blocks
      await _fetchSpecialCategories();


      // Step 6 — Background loading (non-blocking)
      Future.wait([


        fetchOccasionBannerImage(),
        _oCationCategoryList(),
        fetchDiscountBannerImage(),
        fetchBottomBannerImage(),
        fetchMiddleBannerImage(),
        _fetchCoupons(),
        _fetchBrands(),
      ]).catchError((e) {
        debugPrint("Background loading error: $e");
      });

    } catch (e) {
      _showSnackBar("Error loading data: $e", AppColors.errorColor);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Fetch Sections from API
  Future<void> _fetchSections() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.VIEW_SECTION}?branch_id=$branchId'),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          List<Map<String, dynamic>> sections = List<Map<String, dynamic>>.from(decoded['data']);

          setState(() {
            _sectionList = sections;

            // Separate default sections (1-6) and extra sections
            _defaultSections = [];
            _extraSections = [];

            for (var section in sections) {
              int sectionId = int.tryParse(section['id'].toString()) ?? 0;

              // Store names
              _sectionEnglishNames[sectionId] = section['section_name']?.toString() ?? '';
              _sectionTeluguNames[sectionId] = section['name_telugu']?.toString() ?? '';
              _sectionLoading[sectionId] = false;

              // Separate sections
              if (sectionId >= 1 && sectionId <= 6) {
                _defaultSections.add(section);
              } else {
                _extraSections.add(section);
              }
            }
          });

          // Fetch products for default sections (1-6) first
          await _fetchProductsForDefaultSections();

          // Then fetch products for extra sections
          await _fetchProductsForExtraSections();
        }
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
    }
  }

  // Fetch products for default sections (1-6)
  Future<void> _fetchProductsForDefaultSections() async {
    for (var section in _defaultSections) {
      int sectionId = int.tryParse(section['id'].toString()) ?? 0;

      setState(() {
        _sectionLoading[sectionId] = true;
      });

      await _fetchProductsForSection(sectionId);

      setState(() {
        _sectionLoading[sectionId] = false;
      });
    }
  }

  // Fetch products for extra sections (beyond 6)
  Future<void> _fetchProductsForExtraSections() async {
    for (var section in _extraSections) {
      int sectionId = int.tryParse(section['id'].toString()) ?? 0;

      setState(() {
        _sectionLoading[sectionId] = true;
      });

      await _fetchProductsForSection(sectionId);

      setState(() {
        _sectionLoading[sectionId] = false;
      });
    }
  }

  Future<void> _fetchProductsForSection(int sectionId) async {
    try {
      final url = Uri.parse(
        "${ApiConstants.VIEW_PRODUCT_BY_SECTION}?type=$sectionId&page=1&limit=10&branch_id=$branchId",
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);

        debugPrint("Section $sectionId API response: $body");

        if (body['success'] == true) {
          setState(() {
            _sectionProducts[sectionId] = body['products'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching products for section $sectionId: $e");
      setState(() {
        _sectionProducts[sectionId] = [];
      });
    }
  }

  // Build Section by Section Object
  Widget _buildSection(Map<String, dynamic> section) {
    int sectionId = int.tryParse(section['id'].toString()) ?? 0;
    String sectionName = getSectionName(section);
    List<dynamic> products = _sectionProducts[sectionId] ?? [];
    bool isLoading = _sectionLoading[sectionId] ?? false;
    bool hasImage = section['section_image'] != null &&
        section['section_image'].toString().isNotEmpty;

    // Agar loading hai ya products nahi hai to dikhaye nahi
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (products.isEmpty) {
      return SizedBox();
    }

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.h,),
          if (!hasImage)
            Row(
              children: [
                SizedBox(width: 8.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 15.w, top: 10.h, bottom: 20.h),
                    child: Text(
                      sectionName,
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(
                    "${ApiConstants.BASE_URL}/section_api/${section['section_image']}"),
                fit: BoxFit.cover,
              ),
            ),
            child: products.isNotEmpty
                ? Column(
              children: [
                SizedBox(
                  height: hasImage ? 70.h : 0.h,
                ),
                SizedBox(
                  height: 200.h,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        products.length,   // 👈 limit hata di
                            (index) {
                          final product = products[index];
                          return Padding(
                            padding: EdgeInsets.only(left: 16.w),
                            child: SizedBox(
                              width: 140.w,
                              child: SpProduct(
                                product: product,
                                userId: userId.toString(),
                                branchId: branchId,
                                onCartUpdated: () {
                                  fetchCartQuantity(userId);
                                },
                                onCategoryBack: () {
                                  setState(() {
                                    fetchCartQuantity(userId);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    )
                    ,
                  ),
                ),
                SizedBox(height: 13.h,)

              ],
            )
                : SizedBox(),
          ),

          SizedBox(height: 20.h,),
        ],
      ),
    );
  }

  // Build Extra Sections (beyond 6)
  Widget _buildExtraSections() {
    if (_extraSections.isEmpty) {
      return SizedBox();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 10.h),
        ..._extraSections.map((section) {
          return _buildSection(section);
        }).toList(),
      ],
    );
  }



  // Fetch Special Categories
  Future<void> _fetchSpecialCategories() async {
    setState(() => _isLoadingSpecialCategories = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.VIEW_SPECIAL_CATEGORY}?branch_id=$branchId'),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['success'] == true) {
          List<dynamic> categories = jsonResponse['data']['special_categories'] ?? [];

          setState(() {
            _specialCategoryList = categories;
          });

          for (var category in categories) {
            await _fetchProductsForSpecialCategory(category);
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching special categories: $e");
    } finally {
      setState(() => _isLoadingSpecialCategories = false);
    }
  }

  // Fetch Products for a Special Category
  Future<void> _fetchProductsForSpecialCategory(Map<String, dynamic> category) async {
    try {
      final categoryId = category['id'].toString();

      final response = await http.post(
        Uri.parse(ApiConstants.SPECIAL_CATEGORY_PRODUCTS),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'get_products',
          'special_category_id': categoryId,
          'branch_id': branchId,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          setState(() {
            _specialCategoryProducts[categoryId] = data['products'] ?? [];
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching products for special category: $e");
    }
  }

  // Build Special Category Section at specific positions
  Widget _buildSpecialCategoryAtPosition(int positionIndex) {
    if (_specialCategoryList.length <= positionIndex) {
      return SizedBox();
    }

    var category = _specialCategoryList[positionIndex];
    String categoryId = category['id'].toString();
    String categoryName = category['name'] ?? 'Special Category';
    String? bannerImage = category['banner_image']?.toString();
    List<dynamic> products = _specialCategoryProducts[categoryId] ?? [];

    bool hasBanner = bannerImage != null && bannerImage.trim().isNotEmpty;

    if (products.isEmpty) {
      return SizedBox();
    }

    return Container(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          SizedBox(height: 20.h,),
          if (!hasBanner)
            Row(
              children: [
                SizedBox(width: 8.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 15.w, top: 10.h),
                    child: Text(
                      categoryName,
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                  ),
                ),
                if (products.isNotEmpty)
                  Text(
                    '${products.length} Products',
                    style: GoogleFonts.poppins(
                      fontSize: 12.sp,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
              ],
            ),

          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(ApiConstants.BASE_URL+"/special_category/"+category['banner_image'].toString()),
                fit: BoxFit.cover,
              ),
            ),
            child: products.isNotEmpty
                ? Column(
              children: [
                SizedBox(
                  height: hasBanner ? 70.h : 20.h,
                ),
                SizedBox(
                  height: 210.h,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(
                        products.length > 6 ? 6 : products.length,
                            (index) {
                          final product = products[index];
                          return Padding(
                            padding: EdgeInsets.only(left: 16.w,bottom: 14.h),
                            child: SizedBox(
                              width: 140.w,

                              child: SpProduct(
                                product: product,
                                userId: userId.toString(),
                                branchId: branchId,
                                onCartUpdated: () {
                                  fetchCartQuantity(userId);
                                },
                                onCategoryBack: () {
                                  setState(() {
                                    fetchCartQuantity(userId);
                                  });
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                )
              ],
            )
                : SizedBox(),
          ),

        ],
      ),
    );
  }



  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    final double currentScroll = _scrollController.offset;

    if (currentScroll > 100 && currentScroll > _scrollPosition) {
      if (!_showStickySearchBar) {
        setState(() {
          _showStickySearchBar = true;
        });
      }
    } else if (currentScroll <= 100 || currentScroll < _scrollPosition) {
      if (_showStickySearchBar) {
        setState(() {
          _showStickySearchBar = false;
        });
      }
    }

    _scrollPosition = currentScroll;
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

  // Data fetching methods
  Future<void> fetchAllCategoryPositions() async {
    await Future.wait([
      fetchCategoryByPosition("first"),
      fetchCategoryByPosition("second"),
      fetchCategoryByPosition("third"),
      fetchCategoryByPosition("fourth"),
    ]);
  }

  Future<void> fetchCategoryByPosition(String position) async {
    final url = Uri.parse("${ApiConstants.GET_MAIN_CATEGORY_WITH_POSITION}?position=$position&branch_id=$branchId");

    try {
      print("Fetching $position categories from: $url");

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);

        if (decoded['status'] == true) {
          setState(() {
            switch (position) {
              case 'first':
                mainFirstCategoryList = decoded['categories'] ?? [];
                break;
              case 'second':
                mainSecondCategoryList = decoded['categories'] ?? [];
                break;
              case 'third':
                mainThirdCategoryList = decoded['categories'] ?? [];
                break;
              case 'fourth':
                mainFourthCategoryList = decoded['categories'] ?? [];
                break;
            }
          });
        } else {
          print("API returned false status: ${decoded['message']}");
        }
      } else {
        print("HTTP Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching $position categories: $e");
    }
  }

  Future<void> fetchDeliveryTime() async {
    try {

      final response = await http.get(
        Uri.parse(ApiConstants.DELIVERY_TIME + "?branch_id=$branchId"),
      );



      final data = json.decode(response.body);

      if (data['success']) {
        final time = data['data']['time'].toString();
        setState(() {
          deliveryTime = time;
        });
        // Store in CartProvider so ProductCard can read it without duplicate API calls
        Provider.of<CartProvider>(context, listen: false).setDeliveryTime(time);
      } else {
        setState(() {
          deliveryTime = 'Not found';
        });
      }

    } catch (e) {
      // print("ERROR IN fetchDeliveryTime: $e");

      setState(() {
        // deliveryTime = 'Error fetching time';
      });
    }
  }


  Future<void> _fetchCategories() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString('cached_categories');
      int? cacheTime = prefs.getInt('categories_cache_time');

      if (cachedData != null && cacheTime != null &&
          DateTime.now().millisecondsSinceEpoch - cacheTime < 1800000) {
        setState(() => _categoryList = jsonDecode(cachedData));
        return;
      }

      final response = await http.get(Uri.parse('${ApiConstants.MAIN_VIEW_CATEGORY}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() => _categoryList = data);

        await prefs.setString('cached_categories', response.body);
        await prefs.setInt('categories_cache_time', DateTime.now().millisecondsSinceEpoch);
      }
    } catch (e) {
      debugPrint("Error fetching categories: $e");
    }
  }

  Future<void> _toCategoryList() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.VIEW_TOP_CATEGORY}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() => _topCategoryList = jsonResponse['data']['offer_banners']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching top categories: $e");
    }
  }

  Future<void> _oCationCategoryList() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.VIEW_OCCASION_CATEGORY}?branch_id=$branchId'));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['success'] == true) {
          final data = jsonResponse['data'] ?? {};
          final banners = data['offer_banners'] ?? [];

          if (mounted) {
            setState(() {
              _ocationCategoryList = List.from(banners);
            });
          }
        } else {
          debugPrint("API Success false: ${jsonResponse['message']}");
        }
      } else {
        debugPrint("API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching top occasion category: $e");
    }
  }

  Future<void> _fetchBrands() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.VIEW_BRAND}?branch_id=$branchId'));

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);

        if (jsonResponse['success'] == true) {
          final List<dynamic> data = jsonResponse['data'];

          if (mounted) {
            setState(() {
              _brandList = data;
            });
          }
        } else {
          debugPrint("No brand found");
        }
      } else {
        debugPrint('Failed to load brands. Status Code: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error while fetching brands: $e');
    }
  }

  Future<void> _fetchOfferBanners() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.OFFER_BANNER}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() => _offerBannerList = jsonResponse['data']['offer_banners']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching offer banners: $e");
    }
  }

  Future<void> fetchOccasionBannerImage() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.OCCASION_BANNER}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() => bannerImage = data['data']['banner_image']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching occasion banner: $e");
    }
  }

  // Discount banner
  Future<void> fetchDiscountBannerImage() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.DISCOUTN_BANNER}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() => discount_bannerImage = data['data']['banner_image']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching discount banner: $e");
    }
  }

  // Home banner
  Future<void> fetchHomeBannerImage() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.HOME_BANNER}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() => home_bannerImage = data['data']['banner_image']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching home banner: $e");
    }
  }

  // Middle Banner
  Future<void> fetchMiddleBannerImage() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.MIDDLE_BANNER}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() => middle_bannerImage = data['data']['banner_image']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching middle banner: $e");
    }
  }

  // Bottom Banner
  Future<void> fetchBottomBannerImage() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.BOTTOM_BANNER}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          setState(() => bottom_bannerImage = data['data']['banner_image']);
        }
      }
    } catch (e) {
      debugPrint("Error fetching bottom banner: $e");
    }
  }

  Future<void> _fetchSlider() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? cachedData = prefs.getString('cached_slider');
      int? cacheTime = prefs.getInt('slider_cache_time');

      if (cachedData != null && cacheTime != null &&
          DateTime.now().millisecondsSinceEpoch - cacheTime < 900000) {
        final jsonResponse = jsonDecode(cachedData);
        if (jsonResponse['success'] == true) {
          setState(() => _sliderList = jsonResponse['data']['offer_banners']);
          return;
        }
      }

      final response = await http.get(Uri.parse('${ApiConstants.VIEW_SLIDER}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['success'] == true) {
          setState(() => _sliderList = jsonResponse['data']['offer_banners']);

          await prefs.setString('cached_slider', response.body);
          await prefs.setInt('slider_cache_time', DateTime.now().millisecondsSinceEpoch);
        }
      }
    } catch (e) {
      debugPrint("Error fetching slider: $e");
    }
  }

  Future<void> _fetchCoupons() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.VIEW_COUPON}?branch_id=$branchId'));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true && decoded['data'] is List) {
          setState(() => _couponList = List<Map<String, dynamic>>.from(decoded['data']));
        }
      }
    } catch (e) {
      debugPrint("Error fetching coupons: $e");
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins(color: Colors.white)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // Helper method to format delivery time
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

  // Close middle banner popup
  void _closeMiddleBannerPopup() {
    setState(() {
      _showMiddleBannerPopup = false;
    });

    Future.delayed(Duration(seconds: 1), () {
      if (mounted && bottom_bannerImage != null && bottom_bannerImage!.isNotEmpty) {
        _showBottomBannerBottomSheet();
      }
    });
  }

  // Show bottom banner as bottom sheet
  void _showBottomBannerBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      builder: (context) => _buildBottomSheet(),
    );
  }

  // Bottom Sheet Widget
  Widget _buildBottomSheet() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20.r),
          topRight: Radius.circular(20.r),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: EdgeInsets.symmetric(horizontal: 0.w),
            width: double.infinity,
            height: 180.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12.r),
              color: Colors.grey[200],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: Image.network(
                ApiConstants.BASE_URL + '/bottom_banner/' + bottom_bannerImage.toString(),
                fit: BoxFit.fill,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error, size: 50.sp, color: Colors.grey),
                        SizedBox(height: 10.h),
                        Text(
                          getText('Unable to load image', 'ఇమేజ్ లోడ్ చేయడం సాధ్యం కాలేదు'),
                          style: GoogleFonts.jost(fontSize: 14.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);
    final languageProvider = Provider.of<LanguageProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Stack(
        children: [
          // RefreshIndicator wraps only the scrollable content
          RefreshIndicator(
            onRefresh: _loadAllData,
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                // Main content
                SliverList(
                  delegate: SliverChildListDelegate([
                    // Header Section
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          image: NetworkImage(
                            ApiConstants.BASE_URL + '/home_banner/' + home_bannerImage.toString(),
                          ),
                          fit: BoxFit.fill,
                        ),
                      ),
                      child: Column(
                        children: [
                          Column(
                            children: [
                              Padding(
                                padding: ResponsiveHelper.getResponsivePadding(context,
                                  mobile: EdgeInsets.only(top: 35.h, left: 20.w, right: 20.w),
                                  tablet: EdgeInsets.only(top: 45.h, left: 30.w, right: 30.w),
                                  desktop: EdgeInsets.only(top: 55.h, left: 40.w, right: 40.w),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Location Column
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          deliveryTime == "1"
                                              ? getText("Store is closed", "స్టోర్ మూసివేయబడింది")
                                              : getText('Deliver in', 'లోపల రవాణా చేయండి'),
                                          style: GoogleFonts.jost(
                                            color: AppColors.primaryTextColor,
                                            fontWeight: FontWeight.w400,
                                            fontSize: ResponsiveHelper.getResponsiveFontSize(context,
                                              mobile: 12.sp,
                                              tablet: 14.sp,
                                              desktop: 16.sp,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          deliveryTime == "1"
                                              ? getText("Opening Soon", "త్వరలో తెరుస్తుంది")
                                              : formatDeliveryTime(deliveryTime),
                                          style: GoogleFonts.leagueSpartan(
                                            color: AppColors.primaryTextColor,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16.sp,
                                          ),
                                        ),
                                        InkWell(
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.backgroundColor,
                                              borderRadius: BorderRadius.circular(20.r),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 3.h),
                                              child: Row(
                                                children: [
                                                  SvgPicture.asset(
                                                    'assets/svg/h_location.svg',
                                                    height: 10.h,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  if (userArea != null && userArea.toString().trim().isNotEmpty) ...[
                                                    Text(
                                                      "${userArea.toString()}, ",
                                                      style: GoogleFonts.jost(
                                                        fontSize: 12.sp,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                  Text(
                                                    userCity,
                                                    style: GoogleFonts.jost(
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          onTap: () {
                                            Navigator.push(context, MaterialPageRoute(builder: (context) => LocationScreen(isFromHomeScreen: true)));
                                          },
                                        ),
                                      ],
                                    ),
                                    Spacer(),
                                    Padding(
                                      padding: EdgeInsets.only(top: 20.h),
                                      child: InkWell(
                                        onTap: () {
                                          Navigator.push(context, MaterialPageRoute(builder: (context) => ProfileScreen()));
                                        },
                                        child: Row(
                                          children: [
                                            SizedBox(width: 8.w),
                                            SvgPicture.asset('assets/svg/h_profile.svg', width: 20.w, height: 20.h),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 8.h),
                              // Search Container
                              InkWell(
                                onTap: () async {
                                  await Navigator.push(context, MaterialPageRoute(builder: (context) => SearchProduct()));
                                  setState(() {
                                    fetchCartQuantity(userId);
                                  });
                                },
                                child: Padding(
                                  padding: ResponsiveHelper.getResponsivePadding(context,
                                    mobile: EdgeInsets.symmetric(horizontal: 20.w),
                                    tablet: EdgeInsets.symmetric(horizontal: 30.w),
                                    desktop: EdgeInsets.symmetric(horizontal: 40.w),
                                  ),
                                  child: Container(
                                    width: double.infinity,
                                    height: ResponsiveHelper.getResponsiveHeight(context,
                                      mobile: 35.h,
                                      tablet: 45.h,
                                      desktop: 50.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.backgroundColor,
                                      borderRadius: BorderRadius.circular(12.r),
                                      border: Border.all(color: AppColors.searchBorderHome, width: 1.5),
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.symmetric(vertical: 4.h, horizontal: 10.w),
                                      child: InkWell(
                                        onTap: () async {
                                          await Navigator.push(context, MaterialPageRoute(builder: (context) => SearchProduct()));
                                          setState(() {
                                            fetchCartQuantity(userId);
                                          });
                                        },
                                        child: Row(
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: [
                                            Icon(Icons.search, size: 22.sp, color: AppColors.hintTextColor),
                                            SizedBox(width: 6.w),
                                            Text(getText('Search ', 'శోధించండి '), style: GoogleFonts.jost(fontSize: 14.sp, fontWeight: FontWeight.w500)),
                                            SizedBox(
                                              width: 80.w,
                                              child: InkWell(
                                                onTap: () async {
                                                  await Navigator.push(context, MaterialPageRoute(builder: (context) => SearchProduct()));
                                                  setState(() {
                                                    fetchCartQuantity(userId);
                                                  });
                                                },
                                                child: AnimatedTextKit(
                                                  repeatForever: true,
                                                  pause: Duration(milliseconds: 2000),
                                                  animatedTexts: [
                                                    TyperAnimatedText(
                                                        getText('"Grocery"', '"కిరాణా"'),
                                                        textStyle: GoogleFonts.jost(fontSize: 14.sp, fontWeight: FontWeight.w500),
                                                        speed: Duration(milliseconds: 80)
                                                    ),
                                                    TyperAnimatedText(
                                                        getText('"Beauty"', '"బ్యూటీ"'),
                                                        textStyle: GoogleFonts.jost(fontSize: 14.sp, fontWeight: FontWeight.w500),
                                                        speed: Duration(milliseconds: 80)
                                                    ),
                                                    TyperAnimatedText(
                                                        getText('"Snacks"', '"స్నాక్స్"'),
                                                        textStyle: GoogleFonts.jost(fontSize: 14.sp, fontWeight: FontWeight.w500),
                                                        speed: Duration(milliseconds: 80)
                                                    ),
                                                  ],
                                                  isRepeatingAnimation: true,
                                                  displayFullTextOnTap: false,
                                                  stopPauseOnTap: false,
                                                ),
                                              ),
                                            ),
                                            Spacer(),
                                            Icon(Icons.mic, size: 19.sp, color: AppColors.hintTextColor),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(height: 10.h),

                              // Category List - Fixed using SingleChildScrollView
                              SizedBox(
                                height: 80.h,
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: _categoryList.map((date) {
                                      return Consumer<LanguageProvider>(
                                        builder: (context, languageProvider, child) {
                                          String displayName = date['name'] ?? '';
                                          if (languageProvider.selectedLanguage == "Telugu" &&
                                              date['name_telugu'] != null &&
                                              date['name_telugu'].toString().trim().isNotEmpty) {
                                            displayName = date['name_telugu'];
                                          }

                                          List<String> nameParts = displayName.split(" ");

                                          return GestureDetector(
                                            onTap: () async {
                                              await Navigator.push(context, MaterialPageRoute(builder: (context) => MainCategoryView(
                                                categoy_id: int.parse(date['id'].toString()),
                                                category_name: date['name'],
                                                branchID: branchId,
                                              )));

                                              setState(() {
                                                fetchCartQuantity(userId);
                                              });
                                            },
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(horizontal: 0.w * 0.85),
                                              child: Column(
                                                children: [
                                                  Container(
                                                    width: 30.w * 0.85,
                                                    height: 30.h * 0.85,
                                                    child: Image.network(
                                                      ApiConstants.BASE_URL + "/main_category/${date['image']}",
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (_, __, ___) => Image.asset(
                                                        "assets/images/placeholder_categor.png",
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 5.h),
                                                  Container(
                                                    height: 23.h,
                                                    child: Padding(
                                                      padding: EdgeInsets.symmetric(vertical: 1.h * 0.85, horizontal: 15.w * 0.85),
                                                      child: Column(
                                                        children: [
                                                          if (nameParts.length > 1)
                                                            ...[
                                                              Text(
                                                                nameParts.sublist(0, nameParts.length - 1).join(" "),
                                                                style: GoogleFonts.jost(
                                                                  fontSize: 9.3.sp * 0.85,
                                                                  color: AppColors.primaryTextColor,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                              Text(
                                                                nameParts.last,
                                                                style: GoogleFonts.jost(
                                                                  fontSize: 9.3.sp * 0.85,
                                                                  color: AppColors.primaryTextColor,
                                                                  fontWeight: FontWeight.w500,
                                                                ),
                                                              ),
                                                            ]
                                                          else
                                                            Text(
                                                              displayName,
                                                              style: GoogleFonts.jost(
                                                                fontSize: 9.3.sp * 0.85,
                                                                color: AppColors.primaryTextColor,
                                                                fontWeight: FontWeight.w500,
                                                              ),
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
                                    }).toList(),
                                  ),
                                ),
                              ),

                              Container(
                                width: double.infinity,
                                height: 0.4.h,
                                color: AppColors.backgroundColor,
                              )
                            ],
                          ),
                          SizedBox(height: 70.h,),

                          // TOP Category - Fixed using SingleChildScrollView
                          SizedBox(
                            height: ResponsiveHelper.getResponsiveHeight(context,
                              mobile: 95.h,
                              tablet: 115.h,
                              desktop: 135.h,
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _topCategoryList.map((date) {
                                  return Padding(
                                    padding: EdgeInsets.only(left: 16.w, right: 0.w),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: InkWell(
                                        child: Image.network(
                                          ApiConstants.BASE_URL + "/top_category_api/${date['banner_image']}",
                                          width: ResponsiveHelper.getResponsiveWidth(context,
                                            mobile: 87.w,
                                            tablet: 110.w,
                                            desktop: 130.w,
                                          ),
                                          height: ResponsiveHelper.getResponsiveHeight(context,
                                            mobile: 95.h,
                                            tablet: 115.h,
                                            desktop: 135.h,
                                          ),
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Image.asset(
                                            "assets/images/placeholder_top_category.png",
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                        onTap: () async {
                                          await Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => CategoryViewScreen(
                                                categoryId: int.tryParse(date['category_id'].toString()) ?? 0,
                                                subCategoryId: int.tryParse(date['subcategory_id'].toString()) ?? 0,
                                                categoryName: date['category_name'],
                                                categoryImage: date['category_image'],
                                                branchId: branchId,
                                              ),
                                            ),
                                          );
                                          setState(() {
                                            fetchCartQuantity(userId);
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          SizedBox(height: 20.h,),
                        ],
                      ),
                    ),

                    // First Category (Position = 'first') Display
                    MainCategoryWithSubCategories(
                      mainCategoryList: List<Map<String, dynamic>>.from(mainFirstCategoryList),
                      onCategoryBack: () {
                        setState(() {
                          fetchCartQuantity(userId);
                        });
                      },
                      branchId: branchId,
                    ),

                    SizedBox(height: 20.h),

                    // Offer Banners
                    if (_offerBannerList.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: List.generate(_offerBannerList.length, (index) {
                          final banner = _offerBannerList[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                child: Image.network(
                                  '${ApiConstants.BASE_URL}/offer_banner_api/${banner['banner_image']}',
                                  width: double.infinity,
                                  height: 110.h,
                                  fit: BoxFit.fill,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: double.infinity,
                                      height: 110.h,
                                      color: Colors.grey[200],
                                      child: Icon(Icons.broken_image, size: 40.sp, color: Colors.grey),
                                    );
                                  },
                                ),
                                onTap: () async {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => CategoryViewScreen(
                                        categoryId: int.tryParse(banner['category_id'].toString()) ?? 0,
                                        categoryName: banner['category_name'],
                                        categoryImage: banner['category_image'],
                                        branchId: branchId,
                                      ),
                                    ),
                                  );
                                  setState(() {
                                    fetchCartQuantity(userId);
                                  });
                                },
                              ),
                              SizedBox(height: 14.h),
                            ],
                          );
                        }),
                      ),

                    SizedBox(height: 20.h),



                    // DEFAULT SECTIONS (1-6) - First Position
                    if (_defaultSections.length >= 1)
                      _buildSection(_defaultSections[0]),


                    // Discount Banner
                    if (discount_bannerImage != null && discount_bannerImage!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.w),
                        child: Image.network(
                          ApiConstants.BASE_URL + '/discount_banner_api/' + discount_bannerImage.toString(),
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      ),

                    SizedBox(height: 15.h),
                    // Second Category
                    MainCategoryWithSubCategories(
                      mainCategoryList: List<Map<String, dynamic>>.from(mainSecondCategoryList),
                      onCategoryBack: () {
                        setState(() {
                          fetchCartQuantity(userId);
                        });
                      },
                      branchId: branchId,
                    ),


                    SizedBox(height: 15.h),
                    // Third Category
                    MainCategoryWithSubCategories(
                      mainCategoryList: List<Map<String, dynamic>>.from(mainThirdCategoryList),
                      onCategoryBack: () {
                        setState(() {
                          fetchCartQuantity(userId);
                        });
                      },
                      branchId: branchId,
                    ),



                    SizedBox(height: 15.h),

                    // Occasion Banner
                    if (bannerImage != null && bannerImage!.isNotEmpty)
                      Container(
                        height: ResponsiveHelper.getResponsiveHeight(context,
                          mobile: 170.h,
                          tablet: 200.h,
                          desktop: 230.h,
                        ),
                        width: double.infinity,
                        decoration: BoxDecoration(
                          image: DecorationImage(
                            image: NetworkImage(
                              ApiConstants.BASE_URL + '/occasion_banner_api/' + bannerImage.toString(),
                            ),
                            fit: BoxFit.cover,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(height: 70.h),
                            SizedBox(
                              height: 80.h,
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: _ocationCategoryList.map((date) {
                                    return Padding(
                                      padding: EdgeInsets.only(left: 17.w),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: InkWell(
                                          child: Image.network(
                                            ApiConstants.BASE_URL + "/occasion_category_api/${date['banner_image']}",
                                            width: 90.w,
                                            height: 80.h,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 80),
                                          ),
                                          onTap: () async {
                                            await Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) => CategoryViewScreen(
                                                  categoryId: int.tryParse(date['category_id'].toString()) ?? 0,
                                                  categoryName: date['category_name'],
                                                  categoryImage: date['category_image'],
                                                  branchId: branchId,
                                                ),
                                              ),
                                            );
                                            setState(() {
                                              fetchCartQuantity(userId);
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),


                    // Fourth Category
                    MainCategoryWithSubCategories(
                      mainCategoryList: List<Map<String, dynamic>>.from(mainFourthCategoryList),
                      onCategoryBack: () {
                        setState(() {
                          fetchCartQuantity(userId);
                        });
                      },
                      branchId: branchId,
                    ),


                    SizedBox(height: 20.h),
                    // Coupons & Offers
                    Padding(
                      padding: EdgeInsets.only(left: 16.w),
                      child: Text(
                          getText('Coupons & Offers', 'కూపన్లు & ఆఫర్లు'),
                          style: GoogleFonts.jost(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                          )
                      ),
                    ),
                    SizedBox(height: 7.h),
                    SizedBox(
                      height: 90.h,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: _couponList.map((coupon) {
                            final isPrivate = coupon['status'] == "Private";

                            if (isPrivate) {
                              return SizedBox.shrink();
                            }

                            return GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: coupon['code_name']));
                                Fluttertoast.showToast(
                                  msg: getText("Coupon code copied!", "కూపన్ కోడ్ కాపీ చేయబడింది!"),
                                  toastLength: Toast.LENGTH_SHORT,
                                  gravity: ToastGravity.BOTTOM,
                                  backgroundColor: Colors.black87,
                                  textColor: Colors.white,
                                  fontSize: 14.sp,
                                );
                              },
                              child: Container(
                                width: ResponsiveHelper.getResponsiveWidth(context,
                                  mobile: 280.w,
                                  tablet: 350.w,
                                  desktop: 400.w,
                                ),
                                margin: EdgeInsets.only(right: 8.w),
                                decoration: const BoxDecoration(
                                  image: DecorationImage(
                                    image: AssetImage('assets/images/coupons.png'),
                                    fit: BoxFit.fill,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 20.w,
                                        right: 15.w,
                                        top: 6.h,
                                        bottom: 4.h,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            getText('Coupon', 'కూపన్'),
                                            style: GoogleFonts.jost(
                                              color: AppColors.secondaryColor,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15.sp,
                                            ),
                                          ),
                                          const Spacer(),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.backgroundColor,
                                              borderRadius: BorderRadius.circular(3.r),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 2.h,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  getText('Valid ${coupon['expri_date']}', 'చెల్లుబాటు ${coupon['expri_date']}'),
                                                  style: GoogleFonts.jost(
                                                    fontSize: 10.sp,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(left: 8.w, right: 6.w),
                                      child: DottedLine(
                                        dashColor: AppColors.secondaryColor,
                                        lineThickness: 1.7,
                                      ),
                                    ),
                                    Padding(
                                      padding: EdgeInsets.only(
                                        left: 25.w,
                                        right: 20.w,
                                        top: 10.h,
                                      ),
                                      child: Row(
                                        children: [
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  SvgPicture.asset(
                                                    'assets/svg/coupon.svg',
                                                    width: 18.w,
                                                    color: AppColors.secondaryColor,
                                                  ),
                                                  SizedBox(width: 4.w),
                                                  Text(
                                                    coupon['title'] ?? '',
                                                    style: GoogleFonts.jost(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12.sp,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Text(
                                                coupon['description'] ?? '',
                                                style: GoogleFonts.jost(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const Spacer(),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: AppColors.secondaryColor.withOpacity(0.3),
                                              borderRadius: BorderRadius.circular(3.r),
                                            ),
                                            child: Padding(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 2.h,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  coupon['code_name'] ?? '',
                                                  style: GoogleFonts.jost(
                                                    fontSize: 12.sp,
                                                    color: AppColors.primaryColor,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    SizedBox(height: 15.h),



                    // DEFAULT SECTIONS (1-6) - Second Position
                    if (_defaultSections.length >= 2)
                      _buildSection(_defaultSections[1]),


                    // DEFAULT SECTIONS (1-6) - Third Position
                    if (_defaultSections.length >= 3)
                      _buildSection(_defaultSections[2]),

                    // Shop By Brand
                    if (_brandList.isNotEmpty)
                      Column(
                        children: [
                          Image.asset(
                              'assets/images/brand.png',
                              width: double.infinity,
                              height: 17.h
                          ),
                          SizedBox(
                            height: 70.h,
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: _brandList.map((brand) {
                                  return Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10.w),
                                    child: InkWell(
                                      onTap: () async {
                                        await Navigator.push(context, MaterialPageRoute(builder: (context) => BrandViewScreen(brandName: brand['brand_name'])));
                                        setState(() {
                                          fetchCartQuantity(userId);
                                        });
                                      },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Padding(
                                          padding: EdgeInsets.only(left: 16.w),
                                          child: Image.network(
                                            ApiConstants.BASE_URL + '/brand_api/' + brand['brand_image'],
                                            width: 55.w,
                                            height: 55.h,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => Icon(Icons.error, size: 40),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ],
                      ),

                    SizedBox(height: 20.h),

                    // Slider
                    if (_sliderList.isNotEmpty)
                      CarouselSlider(
                        options: CarouselOptions(
                          height: ResponsiveHelper.getResponsiveHeight(context,
                            mobile: 130.h,
                            tablet: 160.h,
                            desktop: 190.h,
                          ),
                          autoPlay: true,
                          enlargeCenterPage: false,
                          viewportFraction: 0.8,
                          aspectRatio: 16 / 9,
                          autoPlayInterval: Duration(seconds: 3),
                          enableInfiniteScroll: true,
                          scrollPhysics: BouncingScrollPhysics(),
                        ),
                        items: _sliderList.map((item) {
                          return Builder(
                            builder: (BuildContext context) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                                child: InkWell(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20.r),
                                    child: Image.network(
                                      ApiConstants.BASE_URL + '/banner_api/' + item['banner_image'],
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: 130.h,
                                      errorBuilder: (context, error, stackTrace) => Icon(Icons.error),
                                    ),
                                  ),
                                  onTap: () async {
                                    await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => CategoryViewScreen(
                                          categoryId: int.tryParse(item['category_id'].toString()) ?? 0,
                                          categoryName: item['category_name'],
                                          categoryImage: item['category_image'],
                                          branchId: branchId,
                                        ),
                                      ),
                                    );
                                    setState(() {
                                      fetchCartQuantity(userId);
                                    });
                                  },
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),



                    // DEFAULT SECTIONS (1-6) - Fourth Position
                    if (_defaultSections.length >= 4)
                      _buildSection(_defaultSections[3]),


                    // ============================================
                    // SPECIAL CATEGORY 1 - After TOP Categories
                    // ============================================
                    _buildSpecialCategoryAtPosition(0),


                    // DEFAULT SECTIONS (1-6) - Fifth Position
                    if (_defaultSections.length >= 5)
                      _buildSection(_defaultSections[4]),


                    // DEFAULT SECTIONS (1-6) - Sixth Position
                    if (_defaultSections.length >= 6)
                      _buildSection(_defaultSections[5]),




                    // ============================================
                    // SPECIAL CATEGORY 2 - After First Section
                    // ============================================
                    _buildSpecialCategoryAtPosition(1),




                    // ============================================
                    // SPECIAL CATEGORY 3 - After Second Section
                    // ============================================
                    _buildSpecialCategoryAtPosition(2),

                    SizedBox(height: 20.h),





                    // EXTRA SECTIONS (beyond 6)
                    _buildExtraSections(),


                  ]),
                ),
              ],
            ),
          ),

          // Sticky Search Bar
          AnimatedPositioned(
            duration: Duration(milliseconds: 400),
            top: _showStickySearchBar ? 0 : -87.h,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(left: 16.w, right: 16.w, top: 34.h, bottom: 12.w),
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: InkWell(
                onTap: () async {
                  await Navigator.push(context, MaterialPageRoute(builder: (context) => SearchProduct()));
                  setState(() {
                    fetchCartQuantity(userId);
                  });
                },
                child: Container(
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: AppColors.backgroundColor,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.searchBorderHome, width: 1.5),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12.w),
                    child: Row(
                      children: [
                        Icon(Icons.search,
                            size: ResponsiveHelper.getResponsiveFontSize(context,
                              mobile: 20.sp,
                              tablet: 22.sp,
                              desktop: 24.sp,
                            ),
                            color: AppColors.hintTextColor
                        ),
                        SizedBox(width: 8.w),
                        Text(
                            getText('Search products...', 'ఉత్పత్తులను శోధించండి...'),
                            style: GoogleFonts.jost(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.hintTextColor,
                            )
                        ),
                        Spacer(),
                        Icon(Icons.mic,
                            size: ResponsiveHelper.getResponsiveFontSize(context,
                              mobile: 18.sp,
                              tablet: 20.sp,
                              desktop: 22.sp,
                            ),
                            color: AppColors.hintTextColor
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          if (cartProvider.getTotalCartItems(userId) > 0)
            AnimatedPositioned(
              duration: Duration(milliseconds: 300),
              curve: Curves.slowMiddle,
              bottom: cartProvider.getTotalCartItems(userId) > 0 ? 20.h : -50.h,
              left: 110.w,
              right: 110.w,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: 300),
                opacity: cartProvider.getTotalCartItems(userId) > 0 ? 1.0 : 0.0,
                child: InkWell(
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => CartScreen()),
                    );
                    setState(() {
                      fetchCartQuantity(userId);
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
                                cartProvider.getTotalCartItems(userId).toString(),
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

          // Middle Banner Popup
          if (_showMiddleBannerPopup && middle_bannerImage != null && middle_bannerImage!.isNotEmpty)
            _buildPopupDialog(
              imageUrl: ApiConstants.BASE_URL + '/middle_banner/' + middle_bannerImage.toString(),
              onClose: _closeMiddleBannerPopup,
            ),
        ],
      ),
    );
  }

  // Popup Dialog Widget
  Widget _buildPopupDialog({
    required String imageUrl,
    required VoidCallback onClose,
  }) {
    return Container(
      color: Colors.black.withOpacity(0.7),
      child: Center(
        child: Stack(
          children: [
            Container(
              margin: EdgeInsets.symmetric(horizontal: 20.w),
              width: double.infinity,
              height: 400.h,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12.r),
                color: Colors.white,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                      child: Icon(Icons.error, size: 50.sp, color: Colors.grey),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 10.h,
              right: 30.w,
              child: GestureDetector(
                onTap: onClose,
                child: Container(
                  padding: EdgeInsets.all(6.w),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 22.sp,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}