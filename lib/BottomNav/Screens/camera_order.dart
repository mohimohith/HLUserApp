import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../DeliveryAddress/delivery_address_screen.dart';
import '../../utils/api_constants.dart';
import '../../utils/colors.dart';
import '../bottomNavScreen.dart';
import '../../Provider/language_provider.dart';

class CameraOrder extends StatefulWidget {
  const CameraOrder({super.key});

  @override
  State<CameraOrder> createState() => _CameraOrderState();
}

class _CameraOrderState extends State<CameraOrder>
    with TickerProviderStateMixin {

  String userIdFromPrefs = "";
  String userIdFromAPI = "";
  int branchId = 0;
  bool isLoading = true;
  List<dynamic> orders = [];
  bool isUploading = false;

  int _resetCounter = 0;

  // IMPORTANT: Changed from address to location_id
  String location_id = ""; // This will store the selected address ID
  String selectedAddress = ""; // This will store the full address for display

  // New variables for image selection
  final List<_OrderImageData> _selectedImages = [];

  // Form controllers
  TextEditingController otherDetailsController = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
    _tabController.addListener(_handleTabChange);
    _loadSelectedAddress();
  }

  // Helper method to get text based on language
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }


  Future<void> _initializeData() async {
    await fetchBranch();
    await fetchUserData();
  }

  void _handleTabChange() {
    print("Tab changed to index: ${_tabController.index}");

    if (_tabController.index == 1) {
      if (userIdFromAPI.isNotEmpty && branchId > 0) {
        fetchOrders();
      } else {
        print("Cannot fetch: userIdFromAPI=$userIdFromAPI, branchId=$branchId");
      }
    }
  }

  Future<void> fetchBranch() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      int bId = prefs.getInt('selected_branch_id') ?? 0;
      print("Fetched branch ID: $bId");

      setState(() {
        branchId = bId;
      });
    } catch (e) {
      print("Error fetching branch: $e");
    }
  }

  Future<void> fetchUserData() async {
    setState(() => isLoading = true);
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userIDFromStorage = prefs.getString('user_id');

      print("User ID from SharedPreferences: $userIDFromStorage");

      if (userIDFromStorage != null && userIDFromStorage.isNotEmpty) {
        setState(() {
          userIdFromPrefs = userIDFromStorage;
        });

        // Get actual user ID from API
        await fetchUserDetailsFromAPI(userIDFromStorage);
      } else {
        print("No user ID found in SharedPreferences");
      }
    } catch (e) {
      print("Error fetching user data: $e");
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchUserDetailsFromAPI(String prefUserId) async {
    try {
      final url = Uri.parse("${ApiConstants.BASE_URL}/auth/get_user.php?userId=$prefUserId");
      print("Fetching user details from: $url");

      final response = await http.get(url);

      print("User API Response status: ${response.statusCode}");
      print("User API Response body: ${response.body}");

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data["status"] == "success") {
          // Get the actual user ID from API response
          String actualUserId = data["user"]["id"]?.toString() ?? "";

          print("Actual User ID from API: $actualUserId");

          setState(() {
            userIdFromAPI = actualUserId;
          });

          print("User ID for database operations set to: $userIdFromAPI");
        } else {
          print("API status not success: ${data['message']}");
        }
      }
    } catch (e) {
      print("Error fetching user details: $e");
    }
  }

  // Load selected address from SharedPreferences
  Future<void> _loadSelectedAddress() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      location_id = prefs.getString('selected_address_id') ?? "";
      selectedAddress = prefs.getString('selected_address_full') ?? "";
    });
    print("Loaded Address - ID: $location_id, Address: $selectedAddress");
  }

  // ================= SELECT IMAGE =================
  Future<void> _selectImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (image == null) return;

    final bytes = await image.readAsBytes();

    setState(() {
      _selectedImages.add(
        _OrderImageData(
          file: image,
          base64: base64Encode(bytes),
          fileName: image.name.split('/').last,
        ),
      );
    });
  }

  // ================= CLEAR SELECTED IMAGE =================
  void _clearSelectedImage(int index) {
    if (index < 0 || index >= _selectedImages.length) return;

    setState(() {
      _selectedImages.removeAt(index);
    });
    print("Selected image removed at index: $index");
  }

  // ================= PLACE ORDER =================
  Future<void> _placeOrder() async {
    // 1. Address Validation
    if (location_id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorColor,
          content: Text(getText(context, "Please select a delivery address first", "దయచేసి మొదట డెలివరీ చిరునామాను ఎంచుకోండి")),
        ),
      );
      return;
    }

    // 2. Image Validation
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorColor,
          content: Text(getText(context, "Please select at least one image", "దయచేసి కనీసం ఒక చిత్రాన్ని ఎంచుకోండి")),
        ),
      );
      return;
    }

    // 3. User ID Validation
    if (userIdFromAPI.isEmpty) {
      await fetchUserDetailsFromAPI(userIdFromPrefs);
      if (userIdFromAPI.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.errorColor,
            content: Text(getText(context, "User information not loaded", "వినియోగదారు సమాచారం లోడ్ చేయబడలేదు")),
          ),
        );
        return;
      }
    }

    setState(() => isUploading = true);

    try {
      for (final image in _selectedImages) {
        final Map<String, dynamic> requestBody = {
          "branch_id": branchId,
          "user_id": int.parse(userIdFromAPI),
          "location_id": location_id,
          "date_time": DateFormat('dd-MM-yyyy hh:mm a').format(DateTime.now()),
          "image_data": image.base64,
          "file_name": image.fileName,
        };

        final response = await http.post(
          Uri.parse("${ApiConstants.BASE_URL}/image_order/save_order.php"),
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
          },
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 30));

        if (response.statusCode == 200) {
          print("RAW RESPONSE: ${response.body}");

          final result = json.decode(response.body);

          print("SUCCESS VALUE: ${result['success']}");
          print("SUCCESS TYPE: ${result['success'].runtimeType}");

          if (!(result['success'] == true || result['success'] == 1 || result['success'] == "true")) {
            print("ORDER FAILED: ${result['message']}");
            throw Exception(result['message'] ?? "Server error");
          }
        } else {
          throw Exception("Status code: ${response.statusCode}");
        }
      }

      if (!mounted) return;

      print("Order Place");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.successColor,
          content: Text(getText(context, "Order placed successfully!", "ఆర్డర్ విజయవంతంగా ఉంచబడింది!")),
          duration: const Duration(seconds: 2),
        ),
      );

      setState(() {
        _selectedImages.clear();
        otherDetailsController.clear();
        _resetCounter++;
      });

      fetchOrders();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorColor,
          content: Text("${getText(context, "Error", "లోపం")}: ${e.toString()}"),
        ),
      );
    } finally {
      if (mounted) setState(() => isUploading = false);
    }
  }

  // ================= FETCH ORDERS =================
  Future<void> fetchOrders() async {
    if (branchId == 0 || userIdFromAPI.isEmpty) {
      print("Cannot fetch orders: Branch ID = $branchId, User ID = $userIdFromAPI");
      return;
    }

    setState(() => isLoading = true);

    try {
      final url = Uri.parse(
          "${ApiConstants.BASE_URL}/image_order/get_orders.php?branch_id=$branchId&user_id=$userIdFromAPI");

      print("=== FETCHING ORDERS ===");
      print("URL: $url");
      print("Using User ID: $userIdFromAPI (from API)");

      final response = await http.get(
        url,
        headers: {
          "Accept": "application/json",
        },
      ).timeout(Duration(seconds: 30));

      print("Response status code: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        try {
          final data = json.decode(response.body);

          if (data["success"] == true) {
            print("Success! Found ${data['count']} orders");

            setState(() {
              orders = data["orders"] ?? [];
            });

            print("Orders loaded: ${orders.length}");
          } else {
            print("API Error: ${data['message']}");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: AppColors.errorColor,
                content: Text("${getText(context, "Error", "లోపం")}: ${data['message']}"),
                duration: Duration(seconds: 2),
              ),
            );
          }
        } catch (e) {
          print("JSON Decode Error: $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.errorColor,
              content: Text(getText(context, "Invalid response format", "చెల్లని ప్రతిస్పందన ఫార్మాట్")),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        print("HTTP Error: Status code ${response.statusCode}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.errorColor,
            content: Text("${getText(context, "Server error", "సర్వర్ లోపం")}: ${response.statusCode}"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print("Error fetching orders: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.errorColor,
          content: Text("${getText(context, "Network error", "నెట్‌వర్క్ లోపం")}: ${e.toString()}"),
          duration: Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() => isLoading = false);
    }
  }

  // ================= DISPOSE =================
  @override
  void dispose() {
    _tabController.removeListener(_handleTabChange);
    _tabController.dispose();
    otherDetailsController.dispose();
    super.dispose();
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: 17.h),

          // ================= HEADER =================
          Container(
            width: double.infinity,
            height: 65.h,
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
                children: [
                  SizedBox(width: 16.w),
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BottomNavScreen(),
                        ),
                      );
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
                          child: Icon(
                            Icons.arrow_back_ios,
                            size: 15.sp,
                            color: AppColors.iconColor,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Consumer<LanguageProvider>(
                    builder: (context, languageProvider, child) {
                      return Text(
                        getText(context, "Camera Order", "కెమెరా ఆర్డర్"),
                        style: GoogleFonts.jost(
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      );
                    },
                  ),
                  Spacer(),
                ],
              ),
            ),
          ),

          SizedBox(height: 8.h),

          // ================= TABS =================
          _Tabs(tabController: _tabController, context: context),

          SizedBox(height: 8.h),

          // ================= TAB SCREENS =================
          Expanded(
            child: Builder(
              builder: (context) => TabBarView(
                controller: _tabController,
                children: [
                  NewOrderScreen(
                    key: Key('new_order_$_resetCounter'), // यहाँ key update करें
                    selectedImages: _selectedImages,
                    onSelectImage: _selectImage,
                    onClearImage: _clearSelectedImage,
                    onPlaceOrder: _placeOrder,
                    isUploading: isUploading,
                    otherDetailsController: otherDetailsController,
                    userIdFromAPI: userIdFromAPI,
                    location_id: location_id,
                    selectedAddress: selectedAddress,
                    onAddressSelect: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => DeliveryAddressScreen()),
                      );
                      await _loadSelectedAddress();
                    },
                  ),
                  MyOrderScreen(
                    orders: orders,
                    isLoading: isLoading,
                    onRefresh: fetchOrders,
                    getStatusColor: _getStatusColor,
                    userIdFromAPI: userIdFromAPI,
                  ),
                ],
              ),
            ),
          ),

        ],
      ),
    );
  }

  // ================= STATUS COLOR =================
  Color _getStatusColor(String status) {
    final statusLower = status.toLowerCase();
    if (statusLower.contains('delivered') ||
        statusLower.contains('completed')) {
      return Colors.green;
    } else if (statusLower.contains('cancelled') ||
        statusLower.contains('canceled')) {
      return Colors.red;
    } else if (statusLower.contains('processing') ||
        statusLower.contains('shipped')) {
      return Colors.orange;
    } else {
      return AppColors.primaryColor;
    }
  }
}

class _OrderImageData {
  final XFile file;
  final String base64;
  final String fileName;

  const _OrderImageData({
    required this.file,
    required this.base64,
    required this.fileName,
  });
}

// ================= NEW ORDER SCREEN =================
class NewOrderScreen extends StatefulWidget {
  final List<_OrderImageData> selectedImages;
  final VoidCallback onSelectImage;
  final void Function(int index) onClearImage;
  final VoidCallback onPlaceOrder;
  final bool isUploading;
  final TextEditingController otherDetailsController;
  final String userIdFromAPI;
  final String location_id;
  final String selectedAddress;
  final Future<void> Function() onAddressSelect;

  const NewOrderScreen({
    super.key,
    required this.selectedImages,
    required this.onSelectImage,
    required this.onClearImage,
    required this.onPlaceOrder,
    required this.isUploading,
    required this.otherDetailsController,
    required this.userIdFromAPI,
    required this.location_id,
    required this.selectedAddress,
    required this.onAddressSelect,
  });

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {

  @override
  void initState() {
    super.initState();
    print("=== NewOrderScreen INIT ===");
    print("Selected Images: ${widget.selectedImages.length}");
  }

  @override
  void didUpdateWidget(NewOrderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    print("=== NewOrderScreen UPDATE ===");
    print("Old Images Count: ${oldWidget.selectedImages.length}");
    print("New Images Count: ${widget.selectedImages.length}");
  }

  // Helper method to get text based on language
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  @override
  Widget build(BuildContext context) {
    print("=== NewOrderScreen BUILD ===");
    print("Selected Images in build: ${widget.selectedImages.length}");
    print("Key: ${widget.key}");

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.selectedImages.isEmpty)
            Column(
              children: [
                Icon(
                  Icons.camera_alt,
                  size: 80.sp,
                  color: AppColors.primaryColor.withOpacity(0.7),
                ),
                SizedBox(height: 20.h),
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, child) {
                    return Text(
                      getText(context, "Upload Your Order Images", "మీ ఆర్డర్ చిత్రాలను అప్‌లోడ్ చేయండి"),
                      style: GoogleFonts.jost(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.secondaryTextColor,
                      ),
                    );
                  },
                ),
                SizedBox(height: 10.h),
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, child) {
                    return Text(
                      getText(context, "Please select your delivery address and add one or more images", "దయచేసి మీ డెలివరీ చిరునామాను ఎంచుకుని ఒకటి లేదా అంతకంటే ఎక్కువ చిత్రాలను జోడించండి"),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jost(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w400,
                        color: AppColors.hintTextColor,
                      ),
                    );
                  },
                ),
                SizedBox(height: 24.h),
              ],
            ),

          // ================= IMAGE GRID =================
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(14.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(
                color: AppColors.primaryColor.withOpacity(0.18),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, child) {
                    return Text(
                      getText(context, "Upload Order Images", "ఆర్డర్ చిత్రాలను అప్‌లోడ్ చేయండి"),
                      style: GoogleFonts.jost(
                        fontSize: 16.sp,
                        color: AppColors.secondaryTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
                SizedBox(height: 6.h),
                Consumer<LanguageProvider>(
                  builder: (context, languageProvider, child) {
                    return Text(
                      getText(context, "Tap the + box to keep adding more images", "మరిన్ని చిత్రాలను జోడించడానికి + బాక్స్‌పై ట్యాప్ చేయండి"),
                      style: GoogleFonts.jost(
                        fontSize: 12.sp,
                        color: AppColors.hintTextColor,
                      ),
                    );
                  },
                ),
                SizedBox(height: 14.h),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.selectedImages.length + 1,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12.w,
                    mainAxisSpacing: 12.h,
                    childAspectRatio: 1,
                  ),
                  itemBuilder: (context, index) {
                    if (index == widget.selectedImages.length) {
                      return GestureDetector(
                        onTap: widget.onSelectImage,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primaryColor.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: AppColors.primaryColor.withOpacity(0.35),
                              style: BorderStyle.solid,
                              width: 1.2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: EdgeInsets.all(10.w),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 22.sp,
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                getText(context, "Add Image", "చిత్రాన్ని జోడించండి"),
                                textAlign: TextAlign.center,
                                style: GoogleFonts.jost(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final image = widget.selectedImages[index];

                    return Stack(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14.r),
                            border: Border.all(
                              color: AppColors.primaryColor.withOpacity(0.18),
                            ),
                            color: AppColors.gray.withOpacity(0.08),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14.r),
                            child: Image.file(
                              File(image.file.path),
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              errorBuilder: (context, error, stackTrace) => Center(
                                child: Icon(
                                  Icons.broken_image,
                                  size: 36.sp,
                                  color: AppColors.hintTextColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6.w,
                          right: 6.w,
                          child: GestureDetector(
                            onTap: () => widget.onClearImage(index),
                            child: Container(
                              padding: EdgeInsets.all(5.w),
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 16.sp,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                if (widget.selectedImages.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Text(
                    "${widget.selectedImages.length} ${getText(context, "image(s) selected", "చిత్రం(లు) ఎంచుకోబడ్డాయి")}",
                    style: GoogleFonts.jost(
                      fontSize: 13.sp,
                      color: AppColors.primaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: 20.h),

          // ================= ADDRESS SELECTION CARD =================
          GestureDetector(
            onTap: widget.onAddressSelect,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(
                  color: widget.location_id.isNotEmpty
                      ? AppColors.primaryColor
                      : AppColors.hintTextColor.withOpacity(0.3),
                  width: widget.location_id.isNotEmpty ? 2 : 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.location_on,
                    color: widget.location_id.isNotEmpty
                        ? AppColors.primaryColor
                        : AppColors.hintTextColor,
                    size: 24.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer<LanguageProvider>(
                          builder: (context, languageProvider, child) {
                            return Text(
                              getText(context, "Delivery Address", "డెలివరీ చిరునామా"),
                              style: GoogleFonts.jost(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                                color: widget.location_id.isNotEmpty
                                    ? Colors.black87
                                    : AppColors.hintTextColor,
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          widget.location_id.isNotEmpty
                              ? (widget.selectedAddress.isNotEmpty
                              ? widget.selectedAddress
                              : "${getText(context, "Address selected (ID:", "చిరునామా ఎంచుకోబడింది (ID:")} ${widget.location_id})")
                              : getText(context, "Tap to select delivery address", "డెలివరీ చిరునామాను ఎంచుకోవడానికి ట్యాప్ చేయండి"),
                          style: GoogleFonts.jost(
                            fontSize: 13.sp,
                            color: widget.location_id.isNotEmpty
                                ? Colors.grey[700]
                                : AppColors.hintTextColor,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16.sp,
                    color: AppColors.primaryColor,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return Text(
                getText(context, "Select from your saved addresses or add a new one", "మీ సేవ్ చేసిన చిరునామాల నుండి ఎంచుకోండి లేదా కొత్తదాన్ని జోడించండి"),
                textAlign: TextAlign.center,
                style: GoogleFonts.jost(
                  fontSize: 12.sp,
                  color: AppColors.hintTextColor,
                ),
              );
            },
          ),
          SizedBox(height: 20.h),

          // ================= PLACE ORDER BUTTON =================
          if (widget.selectedImages.isNotEmpty)
            Column(
              children: [
                if (widget.isUploading)
                  Column(
                    children: [
                      CircularProgressIndicator(
                        color: AppColors.primaryColor,
                      ),
                      SizedBox(height: 20.h),
                      Consumer<LanguageProvider>(
                        builder: (context, languageProvider, child) {
                          return Text(
                            getText(context, "Placing Order...", "ఆర్డర్ ప్లేస్ అవుతోంది..."),
                            style: GoogleFonts.jost(
                              fontSize: 14.sp,
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          );
                        },
                      ),
                    ],
                  )
                else
                  Column(
                    children: [
                      ElevatedButton(
                        onPressed: widget.location_id.isNotEmpty && widget.userIdFromAPI.isNotEmpty
                            ? widget.onPlaceOrder
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: widget.location_id.isNotEmpty && widget.userIdFromAPI.isNotEmpty
                              ? AppColors.successColor
                              : AppColors.gray,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 40.w,
                            vertical: 16.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 4,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle, size: 20.sp),
                            SizedBox(width: 10.w),
                            Consumer<LanguageProvider>(
                              builder: (context, languageProvider, child) {
                                return Text(
                                  getText(context, "Place Order", "ఆర్డర్ చేయండి"),
                                  style: GoogleFonts.jost(
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 12.h),
                      OutlinedButton(
                        onPressed: widget.onSelectImage,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: AppColors.primaryColor),
                          padding: EdgeInsets.symmetric(
                            horizontal: 30.w,
                            vertical: 12.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.refresh, size: 18.sp, color: AppColors.primaryColor),
                            SizedBox(width: 8.w),
                            Consumer<LanguageProvider>(
                              builder: (context, languageProvider, child) {
                                return Text(
                                  getText(context, "Add More Images", "మరిన్ని చిత్రాలను జోడించండి"),
                                  style: GoogleFonts.jost(
                                    fontSize: 14.sp,
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                // Show warnings
                SizedBox(height: 12.h),
                if (widget.userIdFromAPI.isEmpty)
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info, color: AppColors.warningColor, size: 16.sp),
                        SizedBox(width: 8.w),
                        Consumer<LanguageProvider>(
                          builder: (context, languageProvider, child) {
                            return Text(
                              getText(context, "User information loading...", "వినియోగదారు సమాచారం లోడ్ అవుతోంది..."),
                              style: GoogleFonts.jost(
                                fontSize: 12.sp,
                                color: AppColors.warningColor,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                if (widget.location_id.isEmpty)
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: AppColors.warningColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.location_off, color: AppColors.warningColor, size: 16.sp),
                        SizedBox(width: 8.w),
                        Consumer<LanguageProvider>(
                          builder: (context, languageProvider, child) {
                            return Text(
                              getText(context, "Please select a delivery address", "దయచేసి డెలివరీ చిరునామాను ఎంచుకోండి"),
                              style: GoogleFonts.jost(
                                fontSize: 12.sp,
                                color: AppColors.warningColor,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          SizedBox(height: 20.h),
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return Text(
                getText(context, "Supported formats: JPG, PNG • Max size: 5MB", "సహాయక ఫార్మాట్లు: JPG, PNG • గరిష్ట పరిమాణం: 5MB"),
                style: GoogleFonts.jost(
                  fontSize: 12.sp,
                  color: AppColors.hintTextColor,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ================= TAB BAR =================
class _Tabs extends StatelessWidget {
  const _Tabs({required this.tabController, required this.context});

  final TabController tabController;
  final BuildContext context;

  // Helper method to get text based on language
  String getText(String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: TabBar(
        controller: tabController,
        isScrollable: false,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(
            width: 3.w,
            color: AppColors.primaryColor,
          ),
        ),
        labelColor: Colors.black,
        unselectedLabelColor: Colors.black54,
        tabs: [
          Tab(
            child: Text(
              getText('New Order', 'కొత్త ఆర్డర్'),
              style: GoogleFonts.jost(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Tab(
            child: Text(
              getText('My Order', 'నా ఆర్డర్'),
              style: GoogleFonts.jost(
                fontSize: 16.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= MY ORDER SCREEN =================
class MyOrderScreen extends StatefulWidget {
  final List<dynamic> orders;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Color Function(String) getStatusColor;
  final String userIdFromAPI;

  const MyOrderScreen({
    super.key,
    required this.orders,
    required this.isLoading,
    required this.onRefresh,
    required this.getStatusColor,
    required this.userIdFromAPI,
  });

  @override
  State<MyOrderScreen> createState() => _MyOrderScreenState();
}

class _MyOrderScreenState extends State<MyOrderScreen> {
  // Helper method to get text based on language
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  @override
  Widget build(BuildContext context) {
    print("MyOrderScreen building with ${widget.orders.length} orders");

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primaryColor,
      child: widget.isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: AppColors.primaryColor,
            ),
            SizedBox(height: 16.h),
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                return Text(
                  getText(context, "Loading orders...", "ఆర్డర్లు లోడ్ అవుతున్నాయి..."),
                  style: GoogleFonts.jost(
                    fontSize: 14.sp,
                    color: AppColors.primaryColor,
                  ),
                );
              },
            ),
            if (widget.userIdFromAPI.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Text(
                  "User ID: ${widget.userIdFromAPI}",
                  style: GoogleFonts.jost(
                    fontSize: 12.sp,
                    color: AppColors.hintTextColor,
                  ),
                ),
              ),
          ],
        ),
      )
          : widget.orders.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inbox,
              size: 80.sp,
              color: AppColors.hintTextColor.withOpacity(0.5),
            ),
            SizedBox(height: 16.h),
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                return Text(
                  getText(context, "No Orders Found", "ఆర్డర్లు కనుగొనబడలేదు"),
                  style: GoogleFonts.jost(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w500,
                    color: AppColors.hintTextColor,
                  ),
                );
              },
            ),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: widget.onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.iconColor,
              ),
              child: Consumer<LanguageProvider>(
                builder: (context, languageProvider, child) {
                  return Text(getText(context, "Refresh", "రిఫ్రెష్"));
                },
              ),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: widget.orders.length,
        itemBuilder: (context, index) {
          final order = widget.orders[index];
          print("Building order card #${order['id']}");
          return _OrderCard(
            order: order,
            getStatusColor: widget.getStatusColor,
          );
        },
      ),
    );
  }
}

// ================= ORDER CARD =================
class _OrderCard extends StatelessWidget {
  final dynamic order;
  final Color Function(String) getStatusColor;

  const _OrderCard({
    required this.order,
    required this.getStatusColor,
  });

  // Helper method to get text based on language
  String getText(BuildContext context, String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);
    return languageProvider.selectedLanguage == "Telugu" ? telugu : english;
  }

  @override
  Widget build(BuildContext context) {
    final dateTime = DateTime.parse(order['created_at']);
    final formattedDate = "${dateTime.day}/${dateTime.month}/${dateTime.year}";
    final formattedTime = "${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";

    // Get user details
    final userDetails = order['user_details'] ?? {};
    final userName = userDetails['name'] ?? 'N/A';
    final userPhone = userDetails['phone'] ?? 'N/A';

    // Get recipient details from delivery_address table
    final recipientDetails = order['recipient_details'] ?? {};
    final recipientName = recipientDetails['name'] ?? 'N/A';
    final recipientPhone = recipientDetails['phone'] ?? 'N/A';
    final deliveryAddress = recipientDetails['address'] ?? '';
    final landmark = recipientDetails['landmark'] ?? '';
    final pinCode = recipientDetails['pin_code'] ?? '';

    final locationId = order['location_id'] ?? '';
    final fullAddress = order['full_address'] ?? '';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Order Image
          if (order['image_base64'] != null && order['image_base64'].isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12.r),
                topRight: Radius.circular(12.r),
              ),
              child: Image.memory(
                base64Decode(order['image_base64'].split(',').last),
                height: 180.h,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 180.h,
                  color: AppColors.gray,
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      color: AppColors.hintTextColor,
                      size: 40.sp,
                    ),
                  ),
                ),
              ),
            ),

          // Order Details
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Order #${order['order_id'] ?? order['id']}",
                            style: GoogleFonts.jost(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryTextColor,
                            ),
                          ),

                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: getStatusColor(order['status'])
                            .withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20.r),
                        border: Border.all(
                          color: getStatusColor(order['status']),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        order['status'].toUpperCase(),
                        style: GoogleFonts.jost(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: getStatusColor(order['status']),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),

                // Recipient Info
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Consumer<LanguageProvider>(
                      builder: (context, languageProvider, child) {
                        return Text(
                          getText(context, "Delivery Information", "డెలివరీ సమాచారం"),
                          style: GoogleFonts.jost(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryTextColor,
                          ),
                        );
                      },
                    ),

                    // Name
                    SizedBox(height: 8.h,),
                    Row(
                      children: [
                        Consumer<LanguageProvider>(
                          builder: (context, languageProvider, child) {
                            return Text(
                              "${getText(context, "Name", "పేరు")}:",
                              style: GoogleFonts.jost(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryTextColor,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 6.w,),
                        Text(
                          recipientName,
                          style: GoogleFonts.jost(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.hintTextColor,
                          ),
                        ),
                      ],
                    ),

                    // Phone
                    SizedBox(height: 2.h,),
                    Row(
                      children: [
                        Consumer<LanguageProvider>(
                          builder: (context, languageProvider, child) {
                            return Text(
                              "${getText(context, "Phone", "ఫోన్")}:",
                              style: GoogleFonts.jost(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryTextColor,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 6.w,),
                        Text(
                          recipientPhone,
                          style: GoogleFonts.jost(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.hintTextColor,
                          ),
                        ),
                      ],
                    ),

                    // Address
                    SizedBox(height: 2.h,),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Consumer<LanguageProvider>(
                          builder: (context, languageProvider, child) {
                            return Text(
                              "${getText(context, "Address", "చిరునామా")}:",
                              style: GoogleFonts.jost(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryTextColor,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            fullAddress,
                            softWrap: true,
                            overflow: TextOverflow.visible,
                            style: GoogleFonts.jost(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w400,
                              color: AppColors.hintTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    // Order Date
                    SizedBox(height: 2.h,),
                    Row(
                      children: [
                        Consumer<LanguageProvider>(
                          builder: (context, languageProvider, child) {
                            return Text(
                              "${getText(context, "Order Date", "ఆర్డర్ తేదీ")}:",
                              style: GoogleFonts.jost(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryTextColor,
                              ),
                            );
                          },
                        ),
                        SizedBox(width: 6.w,),
                        Text(
                          formattedDate,
                          style: GoogleFonts.jost(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w400,
                            color: AppColors.hintTextColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
              ],
            ),
          ),
        ],
      ),
    );
  }
}