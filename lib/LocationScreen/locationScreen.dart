import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:nexa_mart/utils/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../BottomNav/bottomNavScreen.dart';
import '../CustomWidgets/customButton.dart';
import '../utils/colors.dart';

class LocationScreen extends StatefulWidget {
  final bool isFromHomeScreen;

  const LocationScreen({super.key, this.isFromHomeScreen = false});

  @override
  State<LocationScreen> createState() => _LocationScreenState();
}

class _LocationScreenState extends State<LocationScreen> {

  bool? isServiceAvailable;
  GoogleMapController? _mapController;
  final TextEditingController _searchController = TextEditingController();
  final Completer<GoogleMapController> _controller = Completer();
  FocusNode _searchFocusNode = FocusNode();

  List<Branch> branches = [];
  Branch? nearestBranch;
  double? distanceToNearestBranch;

  LatLng? userLatLng;
  String? userAddress;
  bool _isSearching = false;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _isLoading = true;
  bool _fetchingBranches = false;
  bool _isManualMode = false;
  bool _skipAutoNavigate = false;

  // Autocomplete variables
  List<Placemark> _searchSuggestions = [];
  bool _showAutocomplete = false;

  // Saved location variables
  bool _showSavedLocation = false;
  Map<String, dynamic>? _savedLocation;
  LatLng? _savedLocationLatLng;
  String? _savedLocationAddress;

  @override
  void initState() {
    super.initState();

    _searchFocusNode.addListener(() {
      if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty) {
        _getLocationSuggestions(_searchController.text);
      }
    });

    if (widget.isFromHomeScreen) {
      _isManualMode = true;
      _skipAutoNavigate = true;
      _fetchBranchesAndSetupMap();
    } else {
      _fetchBranchesAndCheckLocation();
    }
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();
    super.dispose();
  }

  // Check for saved location when service is not available
  Future<void> _checkForSavedLocation() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    // Check if we have saved location data
    double? savedLat = prefs.getDouble("saved_lat");
    double? savedLng = prefs.getDouble("saved_lng");
    String? savedAddress = prefs.getString("saved_address");
    int? savedBranchId = prefs.getInt("saved_branch_id");
    String? savedBranchName = prefs.getString("saved_branch_name");

    if (savedLat != null && savedLng != null && savedBranchId != null && savedAddress != null && savedAddress.isNotEmpty) {
      // Check if saved location is still in service area
      bool isStillInService = false;
      Branch? savedBranch;

      for (var branch in branches) {
        if (branch.branchId == savedBranchId) {
          savedBranch = branch;
          double distance = Geolocator.distanceBetween(
            branch.location.latitude,
            branch.location.longitude,
            savedLat,
            savedLng,
          );

          if (distance <= branch.location.radius) {
            isStillInService = true;
            break;
          }
        }
      }

      if (isStillInService && savedBranch != null) {
        setState(() {
          _savedLocation = {
            'lat': savedLat,
            'lng': savedLng,
            'address': savedAddress,
            'branchId': savedBranchId,
            'branchName': savedBranchName,
          };
          _savedLocationLatLng = LatLng(savedLat, savedLng);
          _savedLocationAddress = savedAddress;
          _showSavedLocation = true;
        });
      }
    }
  }

  // Save location when service is available
  Future<void> _saveLocation() async {
    if (nearestBranch != null && userLatLng != null && userAddress != null && userAddress!.isNotEmpty) {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Extract area and city from address for display
      String area = "";
      String city = "";

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          userLatLng!.latitude,
          userLatLng!.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          area = place.subLocality ?? place.street ?? place.name ?? "";
          city = place.locality ?? place.administrativeArea ?? "";
        }
      } catch (e) {
        debugPrint("Error extracting placemarks: $e");
      }

      // Save location details
      await prefs.setString("user_area_h", area);
      await prefs.setString("user_city_h", city);
      await prefs.setDouble("user_lat", userLatLng!.latitude);
      await prefs.setDouble("user_lng", userLatLng!.longitude);

      // Save for saved location
      await prefs.setString("saved_address", userAddress!);
      await prefs.setDouble("saved_lat", userLatLng!.latitude);
      await prefs.setDouble("saved_lng", userLatLng!.longitude);
      await prefs.setInt("saved_branch_id", nearestBranch!.branchId);
      await prefs.setString("saved_branch_name", nearestBranch!.branchName);

      debugPrint("Location saved: ${userAddress}");
    }
  }

  // Use saved location
  Future<void> _useSavedLocation() async {
    if (_savedLocation != null) {
      SharedPreferences prefs = await SharedPreferences.getInstance();

      // Extract area and city from saved address
      String area = "";
      String city = "";

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          _savedLocation!['lat'],
          _savedLocation!['lng'],
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          area = place.subLocality ?? place.street ?? place.name ?? "";
          city = place.locality ?? place.administrativeArea ?? "";
        }
      } catch (e) {
        debugPrint("Error extracting placemarks from saved location: $e");
        // Fallback: try to parse from address string
        if (_savedLocationAddress != null) {
          List<String> addressParts = _savedLocationAddress!.split(',');
          if (addressParts.length > 1) {
            area = addressParts[0].trim();
            city = addressParts.length > 1 ? addressParts[1].trim() : "";
          }
        }
      }

      // Set the saved location as current
      await prefs.setString("user_area_h", area.isNotEmpty ? area : "Saved Location");
      await prefs.setString("user_city_h", city.isNotEmpty ? city : "");
      await prefs.setDouble("user_lat", _savedLocation!['lat']);
      await prefs.setDouble("user_lng", _savedLocation!['lng']);
      await prefs.setInt("selected_branch_id", _savedLocation!['branchId']);
      await prefs.setString("selected_branch_name", _savedLocation!['branchName']);

      // Navigate to home
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const BottomNavScreen()),
      );
    }
  }

  Future<void> _fetchBranchesAndSetupMap() async {
    setState(() {
      _fetchingBranches = true;
    });

    try {
      await _fetchBranches();
      await _getUserLocationForMap();
    } catch (e) {
      debugPrint("Error in manual mode: $e");
    } finally {
      setState(() {
        _fetchingBranches = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _getUserLocationForMap() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception("Location fetch timeout");
      });

      setState(() {
        userLatLng = LatLng(position.latitude, position.longitude);
      });

      _updateMapLocation(userLatLng!);

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          String completeAddress =
              "${place.street ?? place.name ?? ''}, ${place.subLocality ?? ''}, "
              "${place.locality ?? ''}, ${place.administrativeArea ?? ''}, "
              "${place.country ?? ''}";

          // Clean up the address
          completeAddress = completeAddress
              .replaceAll(', ,', ',')
              .replaceAll(' ,', ',')
              .trim();

          while (completeAddress.endsWith(',')) {
            completeAddress = completeAddress.substring(0, completeAddress.length - 1).trim();
          }

          setState(() {
            userAddress = completeAddress;
          });
        }
      } catch (e) {
        debugPrint("Address fetch failed: $e");
      }

      _checkServiceAreaWithoutNavigation(position);

    } catch (e) {
      debugPrint("Error getting location for map: $e");
    }
  }

  Future<void> _checkServiceAreaWithoutNavigation(Position position) async {
    for (var branch in branches) {
      double distanceInMeters = Geolocator.distanceBetween(
        branch.location.latitude,
        branch.location.longitude,
        position.latitude,
        position.longitude,
      );

      if (distanceInMeters <= branch.location.radius) {
        setState(() {
          nearestBranch = branch;
          distanceToNearestBranch = distanceInMeters / 1000;
          isServiceAvailable = true;
        });
        return;
      }
    }

    setState(() {
      isServiceAvailable = false;
      nearestBranch = null;
      distanceToNearestBranch = null;
    });
  }

  Future<void> _fetchBranchesAndCheckLocation() async {
    setState(() {
      _fetchingBranches = true;
    });

    try {
      await _fetchBranches();

      if (branches.isNotEmpty) {
        await _checkServiceAvailability();
      } else {
        setState(() {
          isServiceAvailable = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching branches: $e");
      setState(() {
        isServiceAvailable = false;
      });
    } finally {
      setState(() {
        _fetchingBranches = false;
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.VIEW_BRANCH));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['success'] == true) {
          setState(() {
            branches = (data['data'] as List)
                .map((branch) => Branch.fromJson(branch))
                .toList();
          });
          _setupMapCircles();
        } else {
          throw Exception('Failed to fetch branches: ${data['message']}');
        }
      } else {
        throw Exception('HTTP error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint("Branch fetch error: $e");
      rethrow;
    }
  }

  void _setupMapCircles() {
    _circles = Set<Circle>.from(branches.map((branch) {
      return Circle(
        circleId: CircleId("branch_${branch.branchId}"),
        center: LatLng(branch.location.latitude, branch.location.longitude),
        radius: branch.location.radius.toDouble(),
        fillColor: AppColors.primaryColor.withOpacity(0.2),
        strokeColor: AppColors.primaryColor,
        strokeWidth: 2,
      );
    }));
  }

  Future<void> _checkServiceAvailability() async {
    setState(() => isServiceAvailable = null);
    try {
      bool serviceEnabled;
      LocationPermission permission;

      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => isServiceAvailable = false);
        await _checkForSavedLocation(); // Check for saved location when service not enabled
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => isServiceAvailable = false);
          await _checkForSavedLocation(); // Check for saved location when permission denied
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => isServiceAvailable = false);
        await _checkForSavedLocation(); // Check for saved location when permission denied forever
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 10), onTimeout: () {
        throw Exception("Location fetch timeout");
      });

      setState(() {
        userLatLng = LatLng(position.latitude, position.longitude);
      });

      _updateMapLocation(userLatLng!);

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;

          String completeAddress =
              "${place.street ?? place.name ?? ''}, ${place.subLocality ?? ''}, "
              "${place.locality ?? ''}, ${place.administrativeArea ?? ''}, "
              "${place.country ?? ''}";

          // Clean up the address
          completeAddress = completeAddress
              .replaceAll(', ,', ',')
              .replaceAll(' ,', ',')
              .trim();

          while (completeAddress.endsWith(',')) {
            completeAddress = completeAddress.substring(0, completeAddress.length - 1).trim();
          }

          String area = place.subLocality ?? place.street ?? place.name ?? "";
          String city = place.locality ?? "";

          setState(() {
            userAddress = completeAddress;
          });

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("user_area_h", area);
          await prefs.setString("user_city_h", city);
          await prefs.setDouble("user_lat", position.latitude);
          await prefs.setDouble("user_lng", position.longitude);
        }
      } catch (e) {
        debugPrint("Address fetch failed: $e");
      }

      Branch? serviceableBranch;
      double? minDistance;

      for (var branch in branches) {
        double distanceInMeters = Geolocator.distanceBetween(
          branch.location.latitude,
          branch.location.longitude,
          position.latitude,
          position.longitude,
        );

        if (distanceInMeters <= branch.location.radius) {
          if (serviceableBranch == null || distanceInMeters < minDistance!) {
            serviceableBranch = branch;
            minDistance = distanceInMeters;
          }
        }
      }

      if (serviceableBranch != null) {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt("selected_branch_id", serviceableBranch.branchId);
        await prefs.setString("selected_branch_name", serviceableBranch.branchName);

        setState(() {
          nearestBranch = serviceableBranch;
          distanceToNearestBranch = minDistance! / 1000;
          isServiceAvailable = true;
        });

        // Save the location when service is available
        await _saveLocation();

        if (!_isManualMode && !_skipAutoNavigate) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const BottomNavScreen()),
          );
        }
      } else {
        setState(() {
          isServiceAvailable = false;
        });

        // Check if we have a saved location to show
        await _checkForSavedLocation();
      }
    } catch (e) {
      debugPrint("Error in location check: $e");
      setState(() => isServiceAvailable = false);
      await _checkForSavedLocation(); // Check for saved location on error
    }
  }

  Future<void> _updateMapLocation(LatLng location) async {
    Set<Marker> branchMarkers = Set<Marker>.from(branches.map((branch) {
      return Marker(
        markerId: MarkerId("branch_${branch.branchId}"),
        position: LatLng(branch.location.latitude, branch.location.longitude),
        infoWindow: InfoWindow(title: branch.branchName),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
      );
    }));

    setState(() {
      _markers = branchMarkers.union({
        Marker(
          markerId: const MarkerId("user"),
          position: location,
          infoWindow: const InfoWindow(title: "You"),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      });
    });

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 14,
        ),
      ),
    );
  }

  // Get location suggestions for autocomplete
  Future<void> _getLocationSuggestions(String query) async {
    if (query.isEmpty || query.length < 3) {
      setState(() {
        _searchSuggestions = [];
        _showAutocomplete = false;
      });
      return;
    }

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isEmpty) {
        setState(() {
          _searchSuggestions = [];
          _showAutocomplete = false;
        });
        return;
      }

      List<Placemark> placemarks = await placemarkFromCoordinates(
        locations.first.latitude,
        locations.first.longitude,
      );

      setState(() {
        _searchSuggestions = placemarks;
        _showAutocomplete = true;
      });
    } catch (e) {
      setState(() {
        _searchSuggestions = [];
        _showAutocomplete = false;
      });
    }
  }

  Future<void> _checkSearchLocation(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
      _showAutocomplete = false;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        LatLng searchedLocation = LatLng(loc.latitude, loc.longitude);

        _updateMapLocation(searchedLocation);

        List<Placemark> placemarks = await placemarkFromCoordinates(
          loc.latitude,
          loc.longitude,
        );

        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;

          String completeAddress =
              "${place.street ?? place.name ?? ''}, ${place.subLocality ?? ''}, "
              "${place.locality ?? ''}, ${place.administrativeArea ?? ''}, "
              "${place.country ?? ''}";

          // Clean up the address
          completeAddress = completeAddress
              .replaceAll(', ,', ',')
              .replaceAll(' ,', ',')
              .trim();

          while (completeAddress.endsWith(',')) {
            completeAddress = completeAddress.substring(0, completeAddress.length - 1).trim();
          }

          String area = place.subLocality ?? place.street ?? place.name ?? "";
          String city = place.locality ?? "";

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setString("user_area_h", area);
          await prefs.setString("user_city_h", city);
          await prefs.setDouble("user_lat", loc.latitude);
          await prefs.setDouble("user_lng", loc.longitude);

          setState(() {
            userAddress = completeAddress;
            userLatLng = searchedLocation;
          });
        }

        Branch? serviceableBranch;
        double? minDistance;

        for (var branch in branches) {
          double distanceInMeters = Geolocator.distanceBetween(
            branch.location.latitude,
            branch.location.longitude,
            loc.latitude,
            loc.longitude,
          );

          if (distanceInMeters <= branch.location.radius) {
            if (serviceableBranch == null || distanceInMeters < minDistance!) {
              serviceableBranch = branch;
              minDistance = distanceInMeters;
            }
          }
        }

        if (serviceableBranch != null) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setInt("selected_branch_id", serviceableBranch.branchId);
          await prefs.setString("selected_branch_name", serviceableBranch.branchName);

          setState(() {
            nearestBranch = serviceableBranch;
            distanceToNearestBranch = minDistance! / 1000;
            isServiceAvailable = true;
            _showSavedLocation = false; // Hide saved location if service is available
          });

          // Save the new location
          await _saveLocation();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Location found in service area of ${serviceableBranch.branchName}!"),
              backgroundColor: AppColors.successColor,
            ),
          );
        } else {
          setState(() {
            isServiceAvailable = false;
            nearestBranch = null;
            distanceToNearestBranch = null;
          });

          double distanceInKm = minDistance != null ? minDistance! / 1000 : 0;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Sorry, this location is outside our service area (${distanceInKm.toStringAsFixed(2)} km away from nearest branch)."),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location not found. Please try a different query."),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error searching for location."),
          backgroundColor: AppColors.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Saved Location Card Widget
  Widget _buildSavedLocationCard() {
    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history, color: AppColors.primaryColor, size: 18.w),
                  SizedBox(width: 8.w),
                  Text(
                    "Previously Used Location",
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: AppColors.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  "Service Available",
                  style: GoogleFonts.poppins(
                    fontSize: 10.sp,
                    color: AppColors.successColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          if (_savedLocationAddress != null)
            Text(
              _savedLocationAddress!,
              style: GoogleFonts.poppins(
                fontSize: 12.sp,
                color: AppColors.hintTextColor,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _savedLocation?['branchName'] ?? "",
                style: GoogleFonts.poppins(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryColor,
                ),
              ),
              ElevatedButton(
                onPressed: _useSavedLocation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                ),
                child: Text(
                  "Use This",
                  style: GoogleFonts.poppins(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Service Available UI with Autocomplete Search
  Widget _buildServiceAvailableUI() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: userLatLng ?? (branches.isNotEmpty
                ? LatLng(branches.first.location.latitude, branches.first.location.longitude)
                : const LatLng(0, 0)),
            zoom: 14,
          ),
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
            _mapController = controller;
          },
          circles: _circles,
          markers: _markers,
        ),

        // Search with Autocomplete Container
        Positioned(
          top: 50.h,
          left: 20.w,
          right: 20.w,
          child: Column(
            children: [
              // Main Container
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.check_circle, color: AppColors.successColor, size: 20.w),
                        SizedBox(width: 8.w),
                        Text(
                          "Service Available!",
                          style: GoogleFonts.poppins(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: AppColors.successColor,
                          ),
                        ),
                        if (_isManualMode) ...[
                          SizedBox(width: 8.w),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Text(
                              "Change Location",
                              style: GoogleFonts.poppins(
                                fontSize: 10.sp,
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    SizedBox(height: 10.h),
                    if (nearestBranch != null)
                      Text(
                        "📍 ${nearestBranch!.branchName}",
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          color: AppColors.primaryTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    if (userAddress != null)
                      Text(
                        userAddress!,
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: AppColors.hintTextColor,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    SizedBox(height: 10.h),

                    // Search Field with Autocomplete
                    Stack(
                      children: [
                        TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          decoration: InputDecoration(
                            hintText: "Search for different location...",
                            hintStyle: GoogleFonts.poppins(fontSize: 12.sp),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8.r),
                              borderSide: BorderSide(color: AppColors.primaryColor),
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                            suffixIcon: IconButton(
                              icon: Icon(Icons.search, size: 20.w),
                              onPressed: () => _checkSearchLocation(_searchController.text),
                            ),
                          ),
                          onChanged: (value) {
                            _getLocationSuggestions(value);
                          },
                          onSubmitted: (value) => _checkSearchLocation(value),
                        ),

                        // Autocomplete Suggestions
                        if (_showAutocomplete && _searchSuggestions.isNotEmpty)
                          Positioned(
                            top: 50.h,
                            left: 0,
                            right: 0,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              constraints: BoxConstraints(maxHeight: 200.h),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                itemCount: _searchSuggestions.length,
                                shrinkWrap: true,
                                itemBuilder: (BuildContext context, int index) {
                                  final Placemark suggestion = _searchSuggestions[index];
                                  return ListTile(
                                    leading: Icon(Icons.location_on, color: AppColors.primaryColor, size: 20.w),
                                    title: Text(
                                      suggestion.street ?? suggestion.name ?? "",
                                      style: GoogleFonts.poppins(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    subtitle: Text(
                                      "${suggestion.locality ?? ""}, ${suggestion.administrativeArea ?? ""}",
                                      style: GoogleFonts.poppins(
                                        fontSize: 10.sp,
                                        color: AppColors.hintTextColor,
                                      ),
                                    ),
                                    onTap: () {
                                      String address = "${suggestion.street ?? suggestion.name ?? ""}, ${suggestion.locality ?? ""}";
                                      _searchController.text = address;
                                      setState(() {
                                        _showAutocomplete = false;
                                      });
                                      _checkSearchLocation(address);
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Close autocomplete when tapping outside
              if (_showAutocomplete && _searchSuggestions.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showAutocomplete = false;
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    height: MediaQuery.of(context).size.height,
                  ),
                ),
            ],
          ),
        ),

        // Bottom Buttons
        Positioned(
          bottom: 30.h,
          left: 20.w,
          right: 20.w,
          child: Column(
            children: [
              if (_showSavedLocation && !_isManualMode)
                _buildSavedLocationCard(),

              if (_isManualMode)
                Container(
                  margin: EdgeInsets.only(bottom: 10.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Current Service Area",
                            style: GoogleFonts.poppins(
                              fontSize: 12.sp,
                              color: AppColors.hintTextColor,
                            ),
                          ),
                          Text(
                            nearestBranch?.branchName ?? "Not set",
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryTextColor,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        "${distanceToNearestBranch?.toStringAsFixed(2) ?? "0.00"} km",
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              CustomButton(
                text: _isManualMode ? "Confirm & Go to Home" : "Continue",
                onPressed: () {
                  if (nearestBranch != null) {
                    SharedPreferences.getInstance().then((prefs) {
                      prefs.setInt("selected_branch_id", nearestBranch!.branchId);
                      prefs.setString("selected_branch_name", nearestBranch!.branchName);
                    });
                  }
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const BottomNavScreen(),
                    ),
                  );
                },
              ),
              if (_isManualMode)
                TextButton(
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _showAutocomplete = false;
                    });
                    _fetchBranchesAndCheckLocation();
                  },
                  child: Text(
                    "Use Current Location",
                    style: GoogleFonts.poppins(
                      fontSize: 14.sp,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: _isLoading || _fetchingBranches
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
            SizedBox(height: 20.h),
            Text(
              _fetchingBranches ? "Fetching branches..." : "Loading...",
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: AppColors.primaryTextColor,
              ),
            ),
          ],
        ),
      )
          : isServiceAvailable == null
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
            ),
            SizedBox(height: 20.h),
            Text(
              "Checking service availability...",
              style: GoogleFonts.poppins(
                fontSize: 16.sp,
                color: AppColors.primaryTextColor,
              ),
            ),
          ],
        ),
      )
          : isServiceAvailable == true
          ? _buildServiceAvailableUI()
          : _buildServiceNotAvailableUI(),
    );
  }

  // Service Not Available UI
  Widget _buildServiceNotAvailableUI() {
    return Stack(
      children: [
        GoogleMap(
          initialCameraPosition: CameraPosition(
            target: branches.isNotEmpty
                ? LatLng(branches.first.location.latitude, branches.first.location.longitude)
                : const LatLng(0, 0),
            zoom: 12,
          ),
          onMapCreated: (GoogleMapController controller) {
            _controller.complete(controller);
          },
          circles: _circles,
          markers: _markers.isNotEmpty ? _markers : {
            if (branches.isNotEmpty)
              Marker(
                markerId: const MarkerId("default_branch"),
                position: LatLng(branches.first.location.latitude, branches.first.location.longitude),
                infoWindow: InfoWindow(title: branches.first.branchName),
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
              ),
          },
        ),

        // Service Not Available Bottom Sheet with Saved Location
        DraggableScrollableSheet(
          initialChildSize: _showSavedLocation ? 0.7 : 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (BuildContext context, ScrollController scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: AppColors.backgroundColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20.r),
                  topRight: Radius.circular(20.r),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                controller: scrollController,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 20.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40.w,
                        height: 5.h,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(3.r),
                        ),
                      ),
                    ),
                    SizedBox(height: 20.h),

                    // Show Saved Location Card if available
                    if (_showSavedLocation) ...[
                      _buildSavedLocationCard(),
                      SizedBox(height: 20.h),
                      Divider(
                        color: Colors.grey.shade300,
                        thickness: 1,
                      ),
                      SizedBox(height: 20.h),
                    ],

                    Center(
                      child: Column(
                        children: [
                          Icon(
                            Icons.location_off,
                            size: 40.w,
                            color: AppColors.errorColor,
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            "Service Not Available",
                            style: GoogleFonts.poppins(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: AppColors.errorColor,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            "We're not currently serving your location. Please try a different address within our service area.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                              color: AppColors.hintTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: 16.h),

                    // Search with Autocomplete for Service Not Available
                    Column(
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: "Enter location or pincode",
                            labelStyle: GoogleFonts.poppins(),
                            hintText: "Search for area, street, pincode...",
                            hintStyle: GoogleFonts.poppins(),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: AppColors.primaryColor),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: AppColors.primaryColor.withOpacity(0.5)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                              borderSide: BorderSide(color: AppColors.primaryColor, width: 2),
                            ),
                            prefixIcon: Icon(Icons.search, color: AppColors.primaryColor),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          onChanged: (value) {
                            _getLocationSuggestions(value);
                          },
                          onSubmitted: (value) => _checkSearchLocation(value),
                        ),

                        // Autocomplete Suggestions
                        if (_showAutocomplete && _searchSuggestions.isNotEmpty)
                          Container(
                            margin: EdgeInsets.only(top: 5.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8.r),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 5,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            constraints: BoxConstraints(maxHeight: 150.h),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _searchSuggestions.length,
                              shrinkWrap: true,
                              itemBuilder: (BuildContext context, int index) {
                                final Placemark suggestion = _searchSuggestions[index];
                                return ListTile(
                                  leading: Icon(Icons.location_on, color: AppColors.primaryColor, size: 18.w),
                                  title: Text(
                                    suggestion.street ?? suggestion.name ?? "",
                                    style: GoogleFonts.poppins(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "${suggestion.locality ?? ""}, ${suggestion.administrativeArea ?? ""}",
                                    style: GoogleFonts.poppins(
                                      fontSize: 10.sp,
                                      color: AppColors.hintTextColor,
                                    ),
                                  ),
                                  onTap: () {
                                    String address = "${suggestion.street ?? suggestion.name ?? ""}, ${suggestion.locality ?? ""}";
                                    _searchController.text = address;
                                    setState(() {
                                      _showAutocomplete = false;
                                    });
                                    _checkSearchLocation(address);
                                  },
                                );
                              },
                            ),
                          ),
                      ],
                    ),

                    SizedBox(height: 20.h),
                    CustomButton(
                      text: "Check This Location",
                      onPressed: () {
                        _checkSearchLocation(_searchController.text);
                      },
                    ),
                    SizedBox(height: 16.h),
                    TextButton(
                      onPressed: _fetchBranchesAndCheckLocation,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh, size: 20.w, color: AppColors.primaryColor),
                          SizedBox(width: 8.w),
                          Text(
                            "Retry with Current Location",
                            style: GoogleFonts.poppins(
                              fontSize: 14.sp,
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      "Our Service Areas",
                      style: GoogleFonts.poppins(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    ...branches.map((branch) => ListTile(
                      leading: Icon(Icons.store, color: AppColors.primaryColor),
                      title: Text(
                        branch.branchName,
                        style: GoogleFonts.poppins(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        "${branch.location.areaName} (${(branch.location.radius / 1000).toStringAsFixed(1)} km radius)",
                        style: GoogleFonts.poppins(
                          fontSize: 12.sp,
                          color: AppColors.hintTextColor,
                        ),
                      ),
                    )).toList(),
                    SizedBox(height: 20.h),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

// Model classes for branch data
class Branch {
  final int branchId;
  final String branchName;
  final String managerName;
  final String mobileNumber;
  final String email;
  final String dateTime;
  final BranchLocation location;

  Branch({
    required this.branchId,
    required this.branchName,
    required this.managerName,
    required this.mobileNumber,
    required this.email,
    required this.dateTime,
    required this.location,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      branchId: int.parse(json['branch_id'].toString()),
      branchName: json['branch_name'] ?? '',
      managerName: json['manager_name'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      email: json['email'] ?? '',
      dateTime: json['date_time'] ?? '',
      location: BranchLocation.fromJson(json['location']),
    );
  }
}

class BranchLocation {
  final int locationId;
  final String areaName;
  final String fullAddress;
  final double latitude;
  final double longitude;
  final int radius;

  BranchLocation({
    required this.locationId,
    required this.areaName,
    required this.fullAddress,
    required this.latitude,
    required this.longitude,
    required this.radius,
  });

  factory BranchLocation.fromJson(Map<String, dynamic> json) {
    return BranchLocation(
      locationId: int.parse(json['location_id'].toString()),
      areaName: json['area_name'] ?? '',
      fullAddress: json['full_address'] ?? '',
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      radius: int.parse(json['radius'].toString()),
    );
  }
}