import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Screens/profileScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../BrandCategory/brandCategory.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';
import 'Screens/categoryScreen.dart';
import 'Screens/homeScreen.dart';
import 'package:http/http.dart' as http;
import 'Screens/order_screen.dart';
import 'Screens/wishlist_screen.dart';


class BottomNavScreen extends StatefulWidget {
  const BottomNavScreen({super.key});

  @override
  State<BottomNavScreen> createState() => _BottomNavScreenState();
}

class _BottomNavScreenState extends State<BottomNavScreen> {
  int _currentIndex = 0;
  int _brandIconIndex = 0;
  bool _showBrandText = true;
  Timer? _timer;
  List _brandsList = [];
  bool _isDisposed = false;

  int branchId = 0;
  String branchName  = "";


  final List<Widget> _screens = [
    HomeScreen(),
    CategoryScreen(),
    OrderScreen(),
    ProfileScreen(),
  ];

  final List<String> _iconPaths = [
    'assets/svg/home.svg',
    'assets/svg/category_aa.svg',
    'assets/svg/order.svg',
    'assets/svg/profile.svg',
  ];

  @override
  void initState() {
    super.initState();

    fetchLocation();
    SystemChrome.setSystemUIOverlayStyle( SystemUiOverlayStyle(
      statusBarColor: AppColors.primaryColor,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _timer = Timer.periodic(Duration(seconds: 3), (timer) {
      if (!_isDisposed && mounted) {
        setState(() {
          _showBrandText = !_showBrandText;
          if (!_showBrandText && _brandsList.isNotEmpty) {
            _brandIconIndex = (_brandIconIndex + 1) % _brandsList.length;
          }
        });
      }
    });
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

      await  _fetchBrands();
    }
  }


  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
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
              _brandsList = data;
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


  Widget _buildNavIcon(String asset, int index) {
    return SvgPicture.asset(
      asset,
      color: _currentIndex == index
          ? AppColors.primaryColor // Active icon color
          : AppColors.secondaryTextColor, // Inactive icon color
      width: 27.w,
      height: 27.h,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            alignment: Alignment.topCenter,
            children: [
          Container(
            height: 65.h,
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1), // shadow ka color
                  blurRadius: 6, // shadow ka spread
                  offset: Offset(0, -3), // negative Y ka matlab upar shadow
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildBottomButton(0),
                _buildBottomButton(1),
                SizedBox(width: 70.w), // Space for the center button
                _buildBottomButton(2),
                _buildBottomButton(3),
              ],
            ),
          ),


          // Indicator for selected item
          AnimatedPositioned(
            duration: Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            left: _calculateIndicatorPosition(),
            child: Container(
              width: 50.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: AppColors.primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(10.r),
                  bottomRight: Radius.circular(10.r),
                ),
              ),
            ),
          ),

          Positioned(
            top: 5.h,
            child: GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context)=>BrandCategory()));
              },
              child: Container(
                height: 48.h,
                width: 48.w,
                padding: EdgeInsets.all(1.5.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Colors.green, Colors.yellow.shade100],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: Duration(milliseconds: 500),
                      transitionBuilder: (child, animation) =>
                          FadeTransition(opacity: animation, child: child),
                      child: _showBrandText
                          ? Padding(
                        key: ValueKey('text'),
                        padding: const EdgeInsets.all(4.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(height: 2.h),
                            Text(
                              "Shop \nby ",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.jost(
                                fontSize: 8.sp,
                                fontWeight: FontWeight.w500,
                                height: 1.1,
                              ),
                            ),
                            Text(
                              "BRAND",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.jost(
                                fontSize: 9.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                          : _brandsList.isNotEmpty &&
                          _brandsList[_brandIconIndex]['brand_image'] !=
                              null
                          ? Padding(
                        key: ValueKey('image_${_brandIconIndex}'),
                        padding: const EdgeInsets.all(3.0),
                        child: ClipOval(
                          child: Image.network(
                            ApiConstants.BASE_URL +
                                "/brand_api/${_brandsList[_brandIconIndex]['brand_image']}",
                            width: 40.w,
                            height: 44.h,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 40.w,
                                height: 44.h,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.image_not_supported,
                                  size: 20.sp,
                                  color: Colors.grey,
                                ),
                              );
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 40.w,
                                height: 44.h,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: 20.w,
                                    height: 20.h,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        )
                        ,
                      )
                          : SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            ),
          ),
            ],
          );
        },
      ),
    );
  }

  double _calculateIndicatorPosition() {
    final double screenWidth = MediaQuery.of(context).size.width;
    final double indicatorWidth = 50.w;
    final double centerButtonWidth = 70.w;

    // Calculate the width of each navigation item (equal spacing) for the four buttons
    // There are 4 buttons, and one space taken by the center button.
    final double itemRegionWidth = (screenWidth - centerButtonWidth) / 4;

    double targetCenter = 0.0;

    switch (_currentIndex) {
      case 0: // Home
        targetCenter = itemRegionWidth / 2;
        break;
      case 1: // Category
        targetCenter = itemRegionWidth + (itemRegionWidth / 2);
        break;
      case 2: // Order
      // After the center button, the offset shifts.
        targetCenter = (itemRegionWidth * 2) + centerButtonWidth + (itemRegionWidth / 2);
        break;
      case 3: // Profile
        targetCenter = (itemRegionWidth * 3) + centerButtonWidth + (itemRegionWidth / 2);
        break;
      default:
        targetCenter = 0.0; // Should not happen with current logic
    }

    // Adjust for the indicator's own width to center it
    return targetCenter - (indicatorWidth / 2);
  }

  Widget _buildBottomButton(int index) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      child: Container(
        // Calculate width based on available space (screen width minus center button)
        width: (MediaQuery.of(context).size.width - 70.w) / 4, // 70.w is the center button width
        padding: EdgeInsets.symmetric(vertical: 12.h),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildNavIcon(_iconPaths[index], index),
          ],
        ),
      ),
    );
  }
}