import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../LocationScreen/changeLocationScreen.dart';
import '../utils/api_constants.dart';
import '../utils/colors.dart';

class DeliveryAddressScreen extends StatefulWidget {
  const DeliveryAddressScreen({super.key});

  @override
  State<DeliveryAddressScreen> createState() => _DeliveryAddressScreenState();
}

class _DeliveryAddressScreenState extends State<DeliveryAddressScreen> {
  String userEmail = "";
  String userName = "";
  String userID = "";
  String selectedAddressId = "";

  List<dynamic> addressList = [];
  bool isLoading = false;
  bool isAddingAddress = false;
  bool isEditing = false;
  String? editingAddressId;

  String fullAddress = "";
  String userPinCode = "";
  String userArea = "";
  String userCity = "";
  String landmark = "";
  double? currentLat;
  double? currentLng;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController fullAddressController = TextEditingController();
  final TextEditingController pinCodeController = TextEditingController();
  final TextEditingController landmarkController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchUserData();
    fetchLocation();
    _getSelectedAddressId();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    fullAddressController.dispose();
    pinCodeController.dispose();
    landmarkController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      // Check permissions
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar("Location services are disabled.", AppColors.warningColor);
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permissions are denied.", AppColors.warningColor);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar("Location permissions are permanently denied.", AppColors.warningColor);
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _saveLocationData(
          position.latitude,
          position.longitude,
          position.latitude,
          position.longitude
      );

    } catch (e) {
      _showSnackBar("Error getting location: $e", AppColors.errorColor);
    }
  }

  // NEW METHOD: Save location data with proper address resolution
  Future<void> _saveLocationData(double lat, double lng, double? selectedLat, double? selectedLng) async {
    try {
      // Get address from coordinates
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        String address = _buildCompleteAddress(place);

        setState(() {
          currentLat = selectedLat ?? lat;
          currentLng = selectedLng ?? lng;
          fullAddress = address;
          userPinCode = place.postalCode ?? "";
          userArea = place.locality ?? "";
          userCity = place.administrativeArea ?? "";
        });

        // Save address details to shared preferences
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('current_lat', currentLat!);
        await prefs.setDouble('current_lng', currentLng!);
        await prefs.setString('user_address', address);
        await prefs.setString('user_pincode', userPinCode);
        await prefs.setString('user_area', userArea);
        await prefs.setString('user_city', userCity);

        // Update text controllers
        fullAddressController.text = address;
        pinCodeController.text = userPinCode;

        print("Location Saved - Lat: $currentLat, Lng: $currentLng");
        print("Pin Code: $userPinCode");
        print("Address: $address");
      }
    } catch (e) {
      _showSnackBar("Error saving location data: $e", AppColors.errorColor);
    }
  }

  // NEW METHOD: Build complete address with pin code
  String _buildCompleteAddress(Placemark place) {
    List<String> addressParts = [];

    if (place.street?.isNotEmpty == true) addressParts.add(place.street!);
    if (place.subLocality?.isNotEmpty == true) addressParts.add(place.subLocality!);
    if (place.locality?.isNotEmpty == true) addressParts.add(place.locality!);
    if (place.administrativeArea?.isNotEmpty == true) addressParts.add(place.administrativeArea!);
    if (place.postalCode?.isNotEmpty == true) addressParts.add(place.postalCode!);
    if (place.country?.isNotEmpty == true) addressParts.add(place.country!);

    return addressParts.join(", ");
  }

  Future<void> _getSelectedAddressId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? savedAddressId = prefs.getString('selected_address_id');
    if (savedAddressId != null) {
      setState(() {
        selectedAddressId = savedAddressId;
      });
    }
  }

  Future<void> fetchLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? uLocation = prefs.getString('user_address');
    String? uPinCode = prefs.getString('user_pincode');
    String? uArea = prefs.getString('user_area');
    String? uCity = prefs.getString('user_city');
    String? uLandmark = prefs.getString('user_landmark');
    double? uLat = prefs.getDouble('current_lat');
    double? uLng = prefs.getDouble('current_lng');

    if (uLocation != null) {
      setState(() {
        fullAddress = uLocation;
        userPinCode = uPinCode ?? "";
        userArea = uArea ?? "";
        userCity = uCity ?? "";
        landmark = uLandmark ?? "";
        currentLat = uLat;
        currentLng = uLng;
      });

      // Update text controllers
      fullAddressController.text = uLocation;
      pinCodeController.text = uPinCode ?? "";
    }
  }

  // REMOVED: 3km radius validation

  // UPDATED METHOD: Auto-fill address fields from SharedPreferences
  Future<void> _autoFillAddressFields() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Get values from SharedPreferences
    String? savedFullAddress = prefs.getString('user_address');
    String? savedPinCode = prefs.getString('user_pincode');
    String? savedLandmark = prefs.getString('user_landmark');
    double? savedLat = prefs.getDouble('current_lat');
    double? savedLng = prefs.getDouble('current_lng');

    // Auto-fill the text fields if values exist
    if (savedFullAddress != null && savedFullAddress.isNotEmpty) {
      fullAddressController.text = savedFullAddress;
    }

    if (savedPinCode != null && savedPinCode.isNotEmpty) {
      pinCodeController.text = savedPinCode;
    }

    if (savedLandmark != null && savedLandmark.isNotEmpty) {
      landmarkController.text = savedLandmark;
    }

    // Update current coordinates
    if (savedLat != null && savedLng != null) {
      setState(() {
        currentLat = savedLat;
        currentLng = savedLng;
      });
    }
  }

  Future<void> _addOrUpdateAddress() async {
    // Basic validation
    if (nameController.text.isEmpty ||
        phoneController.text.isEmpty ||
        fullAddressController.text.isEmpty ||
        pinCodeController.text.isEmpty ||
        landmarkController.text.isEmpty) {
      _showSnackBar("Please fill all the fields!", AppColors.warningColor);
      return;
    }

    // Check if user ID is available
    if (userID.isEmpty) {
      _showSnackBar("User not logged in or data not fetched.", AppColors.errorColor);
      return;
    }

    // Validate that coordinates are available
    if (currentLat == null || currentLng == null) {
      _showSnackBar("Please select a location first.", AppColors.warningColor);
      return;
    }

    setState(() {
      isAddingAddress = true;
    });

    try {
      final apiUrl = isEditing ? ApiConstants.UPDATE_ADDRESS : ApiConstants.ADD_ADDRESS;

      final body = {
        "user_id": userID,
        "name": nameController.text.trim(),
        "phone": phoneController.text.trim(),
        "full_address": fullAddressController.text.trim(),
        "pin_code": pinCodeController.text.trim(),
        "landmark": landmarkController.text.trim(),
        "lat_long": currentLat!.toString()+","+currentLng!.toString(),
      };

      // Add address_id if editing
      if (isEditing && editingAddressId != null) {
        body["address_id"] = editingAddressId!;
      }

      final res = await http.post(Uri.parse(apiUrl), body: body);

      if (res.statusCode == 200) {
        final response = jsonDecode(res.body);
        if (response["success"] == "true" || response["status"] == "success") {
          _showSnackBar(
            isEditing ? "Address Updated Successfully! ✅" : "Address Added Successfully! ✅",
            AppColors.successColor,
          );
          _resetForm();
          fetchAddresses(); // Refresh addresses
          Navigator.pop(context); // Close the bottom sheet
        } else {
          _showSnackBar(response["message"] ?? "An unknown error occurred.", AppColors.errorColor);
        }
      } else {
        _showSnackBar("Server Error: ${res.statusCode}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Network error: $e", AppColors.errorColor);
    } finally {
      setState(() {
        isAddingAddress = false;
      });
    }
  }

  Future<void> _deleteAddress(String addressId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.DELETE_ADDRESS),
        body: {"id": addressId},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);

        if (jsonData["success"] == "true") {
          _showSnackBar("Address deleted successfully", AppColors.successColor);
          // If the deleted address was the selected one, clear the selection
          if (selectedAddressId == addressId) {
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.remove('selected_address_id');
            await prefs.remove('selected_address_full');
            setState(() {
              selectedAddressId = "";
            });
          }
          fetchAddresses(); // List refresh
        } else {
          _showSnackBar(
            jsonData["message"] ?? "Failed to delete address",
            AppColors.errorColor,
          );
        }
      } else {
        _showSnackBar(
          "Server error: ${response.statusCode}",
          AppColors.errorColor,
        );
      }
    } catch (e) {
      _showSnackBar(
        "Error deleting address: $e",
        AppColors.errorColor,
      );
    }
  }

  void _showDeleteConfirmation(String addressId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Confirm Delete", style: GoogleFonts.poppins()),
        content: Text("Are you sure you want to delete this address?", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel", style: GoogleFonts.poppins(color: AppColors.primaryColor)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteAddress(addressId);
            },
            child: Text("Delete", style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
      ),
    );
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

  void _resetForm() {
    nameController.clear();
    phoneController.clear();
    fullAddressController.clear();
    pinCodeController.clear();
    landmarkController.clear();
    setState(() {
      isEditing = false;
      editingAddressId = null;
    });
  }

  Future<void> fetchAddresses() async {
    if (userID.isEmpty) return;

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.VIEW_ADDRESS),
        body: {"user_id": userID},
      );

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        if (jsonData["status"] == "success") {
          setState(() {
            addressList = jsonData["data"];
          });
        } else {
          setState(() {
            addressList = [];
          });
          _showSnackBar(jsonData["message"] ?? "No addresses found.", AppColors.warningColor);
        }
      } else {
        _showSnackBar("Server error: ${response.statusCode}", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Error fetching addresses: $e", AppColors.errorColor);
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> fetchUserData() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? user_ID = prefs.getString('user_id');
    if (user_ID != null) {
      setState(() => userID = user_ID);
      await fetchAddresses();
    }
  }

  void _editAddress(Map<String, dynamic> address) {
    setState(() {
      isEditing = true;
      editingAddressId = address["id"].toString();
      nameController.text = address["name"] ?? "";
      phoneController.text = address["phone"] ?? "";
      fullAddressController.text = address["full_address"] ?? "";
      pinCodeController.text = address["pin_code"] ?? "";
      landmarkController.text = address["landmark"] ?? "";

      // Also set the coordinates from the address
      if (address["latitude"] != null && address["longitude"] != null) {
        currentLat = double.tryParse(address["latitude"].toString());
        currentLng = double.tryParse(address["longitude"].toString());
      }
    });
    _showAddAddressModal();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: Column(
        children: [
          SizedBox(height: 17.h),

          _buildAppBar(),
          SizedBox(height: 17.h),

          // REMOVED: Location Status Card (3km validation)

          // Add New Address Button
          InkWell(
            onTap: () {
              _resetForm();
              _showAddAddressModal();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.asset(
                  'assets/svg/add.svg',
                  width: 18.w,
                  height: 18.h,
                  color: AppColors.searchBorderHome,
                ),
                SizedBox(width: 10.w),
                Text(
                  'Add New Address',
                  style: GoogleFonts.jost(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.sp,
                    color: AppColors.searchBorderHome,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 17.h),

          // Address List
          Expanded(
            child: isLoading
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
                : addressList.isEmpty
                ? Center(
              child: Text(
                "No addresses found.",
                style: GoogleFonts.poppins(),
              ),
            )
                : ListView.builder(
              itemCount: addressList.length,
              padding: EdgeInsets.zero,
              itemBuilder: (context, index) {
                final address = addressList[index];
                final isSelected = selectedAddressId == address["id"].toString();

                return GestureDetector(
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('selected_address_id', address["id"].toString());
                    await prefs.setString('selected_address_full', address["full_address"] ?? "");

                    setState(() {
                      selectedAddressId = address["id"].toString();
                    });

                    _showSnackBar("Address Selected ✅", AppColors.successColor);
                  },
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                    child: Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(
                          color: isSelected ? AppColors.primaryColor : AppColors.lineColor,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                address["name"] ?? "Name Not Available",
                                style: GoogleFonts.jost(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14.sp,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: () => _editAddress(address),
                                    child: Icon(
                                      Icons.edit,
                                      size: 18.sp,
                                      color: AppColors.primaryColor,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  GestureDetector(
                                    onTap: () => _showDeleteConfirmation(address["id"].toString()),
                                    child: Icon(
                                      Icons.delete,
                                      size: 18.sp,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            "${address["full_address"] ?? ""}, Landmark: ${address["landmark"] ?? ""}, Pin: ${address["pin_code"] ?? ""}",
                            style: GoogleFonts.jost(fontSize: 12.sp),
                          ),
                          SizedBox(height: 5.h),
                          Text(
                            "Phone: ${address["phone"] ?? "Not available"}",
                            style: GoogleFonts.jost(
                              fontSize: 12.sp,
                              color: Colors.grey,
                            ),
                          ),
                          if (isSelected)
                            SizedBox(height: 5.h),
                          if (isSelected)
                            Row(
                              children: [
                                Icon(Icons.check_circle, size: 14.sp, color: AppColors.primaryColor),
                                SizedBox(width: 5.w),
                                Text(
                                  "Selected Address",
                                  style: GoogleFonts.jost(
                                    fontSize: 12.sp,
                                    color: AppColors.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
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
        padding:  EdgeInsets.only(top: 10.h),
        child: Row(
          children: [
            SizedBox(width: 16.w),
            InkWell(
              onTap: () => Navigator.pop(context),
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
            SizedBox(width: 16.w),
            Text(
              "Delivery Address",
              style: GoogleFonts.jost(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            Spacer(),
            SizedBox(width: 20.w),
          ],
        ),
      ),
    );
  }

  void _showAddAddressModal() {
    // Auto-fill address fields when showing the modal
    _autoFillAddressFields();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isEditing ? "Edit Address" : "Add New Address",
                style: GoogleFonts.jost(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 16.h),
              _buildTextField(
                controller: nameController,
                icon: 'assets/svg/l_user.svg',
                hint: 'Name',
              ),
              SizedBox(height: 12.h),
              _buildTextField(
                controller: phoneController,
                icon: 'assets/svg/phone.svg',
                hint: 'Mobile no.',
                keyboardType: TextInputType.phone,
              ),
              SizedBox(height: 12.h),
              // Full Address field is now read-only
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: fullAddressController,
                  readOnly: true, // Disable editing
                  decoration: InputDecoration(
                    hintStyle: GoogleFonts.jost(
                      color: Colors.grey,
                      fontSize: 16.sp,
                    ),
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: SvgPicture.asset('assets/svg/l_location.svg', width: 18.w, height: 18.h,color: AppColors.primaryColor,),
                    ),
                    hintText: 'Full Address',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              // Pin Code field is now read-only
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: TextFormField(
                  controller: pinCodeController,
                  readOnly: true, // Disable editing
                  decoration: InputDecoration(
                    hintStyle: GoogleFonts.jost(
                      color: Colors.grey,
                      fontSize: 16.sp,
                    ),
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: SvgPicture.asset('assets/svg/pincode.svg', width: 18.w, height: 18.h,color: AppColors.primaryColor,),
                    ),
                    hintText: 'Pin code',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10.r),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              _buildTextField(
                controller: landmarkController,
                icon: 'assets/svg/landmark.svg',
                hint: 'Landmark',
              ),
              SizedBox(height: 12.h),

              // Change Location Button in Bottom Sheet
              GestureDetector(
                onTap: () {
                  Navigator.pop(context); // Close the bottom sheet first
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChangeLocationScreen(
                        onLocationSelected: (lat, lng, address) async {
                          // Save the selected location with proper address resolution
                          await _saveLocationData(lat, lng, lat, lng);

                          // Show the bottom sheet again with updated address
                          _showAddAddressModal();
                        },
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: AppColors.primaryColor, width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        'assets/svg/location.svg',
                        width: 18.w,
                        height: 18.h,
                        color: AppColors.primaryColor,
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        'Change Location on Map',
                        style: GoogleFonts.jost(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.sp,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),

              // REMOVED: Location status in modal (3km validation)

              GestureDetector(
                onTap: isAddingAddress ? null : _addOrUpdateAddress,
                child: Container(
                  height: 45.h,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor,
                    borderRadius: BorderRadius.circular(30.r),
                  ),
                  child: Center(
                    child: isAddingAddress
                        ? CircularProgressIndicator(color: Colors.black)
                        : Text(
                      isEditing ? "Update" : "Save",
                      style: GoogleFonts.jost(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 10.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String icon,
    String? hint,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? Colors.grey.shade100 : Colors.white,
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        readOnly: readOnly,
        decoration: InputDecoration(
          hintStyle: GoogleFonts.jost(
            color: Colors.grey,
            fontSize: 16.sp,
          ),
          prefixIcon: Padding(
            padding: EdgeInsets.all(12.w),
            child: SvgPicture.asset(icon, width: 18.w, height: 18.h,color: AppColors.primaryColor,),
          ),
          hintText: hint,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}