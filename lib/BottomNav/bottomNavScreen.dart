import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'Screens/profileScreen.dart';
import '../BrandCategory/brandCategory.dart';
import '../compat/app_state.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';
import 'Screens/categoryScreen.dart';
import 'Screens/homeScreen.dart';
import 'Screens/order_screen.dart';

/// Exact legacy bottom nav shell, wired to the new backend via [AppState] and
/// [Repos] instead of SharedPreferences + raw HTTP.
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

  String? branchId;
  String branchName = "";

  final List<Widget> _screens = const [
    HomeScreen(),
    CategoryScreen(),
    OrderScreen(),
    ProfileScreen(),
  ];

  final List<String> _iconPaths = const [
    'assets/svg/home.svg',
    'assets/svg/category_aa.svg',
    'assets/svg/order.svg',
    'assets/svg/profile.svg',
  ];

  @override
  void initState() {
    super.initState();

    branchId = AppState.branchId;
    branchName = AppState.branchName ?? '';
    _fetchBrands();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primaryColor,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
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

  @override
  void dispose() {
    _isDisposed = true;
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }

  Future<void> _fetchBrands() async {
    try {
      final id = AppState.branchIdOrEmpty;
      if (id.isEmpty) return;
      final homeData = await Repos.home.getHome(id);
      if (mounted && homeData.brands.isNotEmpty) {
        setState(() {
          _brandsList = homeData.brands.map((b) => {
            'brand_name': b.name,
            'brand_image': b.image ?? '',
          }).toList();
        });
      }
    } catch (e) {
      debugPrint('Error while fetching brands: $e');
    }
  }

  Widget _buildNavIcon(String asset, int index) {
    return SvgPicture.asset(
      asset,
      color: _currentIndex == index
          ? AppColors.primaryColor
          : AppColors.secondaryTextColor,
      width: 27.w,
      height: 27.h,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _screens[_currentIndex],
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
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 6,
                      offset: const Offset(0, -3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildBottomButton(0),
                    _buildBottomButton(1),
                    SizedBox(width: 70.w),
                    _buildBottomButton(2),
                    _buildBottomButton(3),
                  ],
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
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
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const BrandCategory()),
                    );
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
                          duration: const Duration(milliseconds: 500),
                          transitionBuilder: (child, animation) =>
                              FadeTransition(opacity: animation, child: child),
                          child: _showBrandText
                              ? Padding(
                                  key: const ValueKey('text'),
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
                                      _brandsList[_brandIconIndex]
                                              ['brand_image'] !=
                                          null
                                  ? Padding(
                                      key: ValueKey(
                                          'image_$_brandIconIndex'),
                                      padding: const EdgeInsets.all(3.0),
                                      child: ClipOval(
                                        child: Image.network(
                                          _brandsList[_brandIconIndex]
                                              ['brand_image'],
                                          width: 40.w,
                                          height: 44.h,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
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
                                          loadingBuilder: (context, child,
                                              loadingProgress) {
                                            if (loadingProgress == null)
                                              return child;
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
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      AppColors.primaryColor,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    )
                                  : const SizedBox.shrink(),
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
    final double itemRegionWidth = (screenWidth - centerButtonWidth) / 4;

    double targetCenter = 0.0;
    switch (_currentIndex) {
      case 0:
        targetCenter = itemRegionWidth / 2;
        break;
      case 1:
        targetCenter = itemRegionWidth + (itemRegionWidth / 2);
        break;
      case 2:
        targetCenter = (itemRegionWidth * 2) +
            centerButtonWidth +
            (itemRegionWidth / 2);
        break;
      case 3:
        targetCenter = (itemRegionWidth * 3) +
            centerButtonWidth +
            (itemRegionWidth / 2);
        break;
    }
    return targetCenter - (indicatorWidth / 2);
  }

  Widget _buildBottomButton(int index) {
    return GestureDetector(
      onTap: () {
        setState(() => _currentIndex = index);
      },
      child: Container(
        width: (MediaQuery.of(context).size.width - 70.w) / 4,
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
