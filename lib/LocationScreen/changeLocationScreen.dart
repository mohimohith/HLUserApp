import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../utils/colors.dart';
import 'marker_utils.dart';

class ChangeLocationScreen extends StatefulWidget {
  final Function(double, double, String) onLocationSelected;

  const ChangeLocationScreen({
    Key? key,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  State<ChangeLocationScreen> createState() => _ChangeLocationScreenState();
}

class _ChangeLocationScreenState extends State<ChangeLocationScreen> {
  final TextEditingController _searchController = TextEditingController();
  GoogleMapController? _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = "";
  bool _isLoading = false;
  Set<Marker> _markers = {};
  Set<Circle> _circles = {};
  bool _isSearching = false;

  // Default location
  LatLng _currentLatLng = const LatLng(28.634138, 75.385826);

  BitmapDescriptor? customIcon;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLocationService();
    });
    _getCurrentLocation();
  }

  Future<void> _checkInitialLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      await _showLocationServiceDialog();
    }
  }

  Future<bool> _checkAndRequestLocationService() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      // Show custom dialog to enable location
      bool? shouldOpenSettings = await _showLocationServiceDialog();

      if (shouldOpenSettings == true) {
        await Geolocator.openLocationSettings();
        // Check again after user might have enabled
        await Future.delayed(Duration(seconds: 2));
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
      }
    }

    return serviceEnabled;
  }

  Future<bool?> _showLocationServiceDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.r),
          ),
          title: Column(
            children: [
              Icon(
                Icons.location_off,
                color: AppColors.warningColor,
                size: 40.h,
              ),
              SizedBox(height: 10.h),
              Text(
                "Location Required",
                style: GoogleFonts.jost(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "To select your location on map, please enable location services:",
                textAlign: TextAlign.center,
                style: GoogleFonts.jost(
                  fontSize: 14.sp,
                  color: AppColors.hintTextColor,
                ),
              ),
              SizedBox(height: 20.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: AppColors.backgroundColor,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  children: [
                    _buildStepRow("1. Tap 'Open Settings'", Icons.settings),
                    SizedBox(height: 8.h),
                    _buildStepRow("2. Go to Location", Icons.location_on),
                    SizedBox(height: 8.h),
                    _buildStepRow("3. Enable Location", Icons.toggle_on),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                "Cancel",
                style: GoogleFonts.jost(
                  color: AppColors.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
              ),
              child: Text(
                "Open Settings",
                style: GoogleFonts.jost(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStepRow(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryColor, size: 18.w),
        SizedBox(width: 10.w),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.jost(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _getCurrentLocation() async {
    // First check if location service is enabled
    bool serviceEnabled = await _checkAndRequestLocationService();

    if (!serviceEnabled) {
      return; // Return if user didn't enable location
    }

    setState(() => _isLoading = true);

    try {
      LocationPermission permission;

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

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
        _selectedLocation = _currentLatLng;
      });

      // Get address from coordinates
      await _getAddressFromLatLng(_currentLatLng);

      // Update map to show current location
      _updateMap();

    } catch (e) {
      _showSnackBar("Error getting location: $e", AppColors.errorColor);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _getAddressFromLatLng(LatLng latLng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
          latLng.latitude,
          latLng.longitude
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];

        // Build complete address with proper pin code
        String address = _buildCompleteAddress(place);
        String pinCode = place.postalCode ?? "";

        setState(() {
          _selectedAddress = address;
          _searchController.text = address;
        });

        print("Selected Location: ${latLng.latitude}, ${latLng.longitude}");
        print("Address: $address");
        print("Pin Code: $pinCode");
      }
    } catch (e) {
      _showSnackBar("Error getting address: $e", AppColors.errorColor);
    }
  }

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

  void _updateMap() {
    if (_mapController != null && _selectedLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedLocation!, 15),
      );

      setState(() {
        _markers = {
          Marker(
            markerId: const MarkerId('selected_location'),
            position: _selectedLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            infoWindow: InfoWindow(
              title: 'Selected Location',
              snippet: 'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
            ),
          ),
        };

        // REMOVED: Shop marker and delivery range circle
        _circles = {};
      });
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    _updateMap();
  }

  void _onMapTapped(LatLng latLng) async {
    // Check if location service is enabled before allowing manual selection
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      bool? shouldEnable = await _showLocationServiceDialog();
      if (shouldEnable == true) {
        await Geolocator.openLocationSettings();
        return;
      }
    }

    setState(() {
      _selectedLocation = latLng;
    });
    _getAddressFromLatLng(latLng);
    _updateMap();
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

  void _saveLocation() {
    if (_selectedLocation != null && _selectedAddress.isNotEmpty) {
      // Ensure we have the latest address data
      if (_searchController.text != _selectedAddress) {
        _selectedAddress = _searchController.text;
      }

      widget.onLocationSelected(
          _selectedLocation!.latitude,
          _selectedLocation!.longitude,
          _selectedAddress
      );

      print("Saved Location - Lat: ${_selectedLocation!.latitude}, Lng: ${_selectedLocation!.longitude}");
      print("Saved Address: $_selectedAddress");

      Navigator.pop(context);
      _showSnackBar("Location updated successfully!", AppColors.successColor);
    } else {
      _showSnackBar("Please select a location first.", AppColors.warningColor);
    }
  }

  // Function to get location suggestions
  Future<List<Placemark>> getLocationSuggestions(String query) async {
    if (query.isEmpty) return [];

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isEmpty) return [];

      List<Placemark> placemarks = await placemarkFromCoordinates(
        locations.first.latitude,
        locations.first.longitude,
      );

      return placemarks;
    } catch (e) {
      return [];
    }
  }

  // Function to handle search location
  Future<void> _checkSearchLocation(String query) async {
    if (query.isEmpty) return;

    setState(() {
      _isSearching = true;
    });

    try {
      List<Location> locations = await locationFromAddress(query);
      if (locations.isNotEmpty) {
        Location loc = locations.first;
        LatLng searchedLocation = LatLng(loc.latitude, loc.longitude);

        // Update map to show searched location
        setState(() {
          _selectedLocation = searchedLocation;
        });

        // Get address from the searched location (this will get the correct pin code)
        await _getAddressFromLatLng(searchedLocation);

        // Update the map
        _updateMap();
      } else {
        _showSnackBar("Location not found. Please try a different query.", AppColors.errorColor);
      }
    } catch (e) {
      _showSnackBar("Error searching for location.", AppColors.errorColor);
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  // Improved address selection from autocomplete
  Future<void> _onPlacemarkSelected(Placemark selection) async {
    try {
      // Get coordinates from the selected placemark
      List<Location> locations = await locationFromAddress(
          "${selection.name ?? ''} ${selection.street ?? ''} ${selection.locality ?? ''} ${selection.administrativeArea ?? ''} ${selection.country ?? ''}"
      );

      if (locations.isNotEmpty) {
        Location loc = locations.first;
        LatLng selectedLatLng = LatLng(loc.latitude, loc.longitude);

        setState(() {
          _selectedLocation = selectedLatLng;
        });

        // Get complete address with pin code
        await _getAddressFromLatLng(selectedLatLng);
        _updateMap();
      }
    } catch (e) {
      _showSnackBar("Error selecting location.", AppColors.errorColor);
    }
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

          // Search Bar with Autocomplete
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Autocomplete<Placemark>(
              displayStringForOption: (Placemark option) {
                return _buildCompleteAddress(option);
              },
              optionsBuilder: (TextEditingValue textEditingValue) async {
                if (textEditingValue.text.isEmpty) {
                  return const Iterable<Placemark>.empty();
                }
                if (textEditingValue.text.length < 3) {
                  return const Iterable<Placemark>.empty();
                }
                return await getLocationSuggestions(textEditingValue.text);
              },
              onSelected: _onPlacemarkSelected,
              fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    decoration: InputDecoration(
                      hintText: 'Search for area, street name...',
                      hintStyle: GoogleFonts.jost(
                        color: Colors.grey,
                        fontSize: 16.sp,
                      ),
                      prefixIcon: Padding(
                        padding: EdgeInsets.all(12.w),
                        child: SvgPicture.asset(
                          'assets/svg/search.svg',
                          width: 18.w,
                          height: 18.h,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onSubmitted: (value) async {
                      await _checkSearchLocation(value);
                    },
                  ),
                );
              },
              optionsViewBuilder: (BuildContext context, Function(Placemark) onSelected, Iterable<Placemark> options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 4.0,
                    child: Container(
                      constraints: BoxConstraints(maxHeight: 200.h),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: options.length,
                        shrinkWrap: true,
                        itemBuilder: (BuildContext context, int index) {
                          final Placemark suggestion = options.elementAt(index);
                          return ListTile(
                            leading: Icon(Icons.location_on, color: AppColors.primaryColor),
                            title: Text(
                              suggestion.street ?? suggestion.locality ?? suggestion.name ?? "",
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(
                              "${suggestion.locality ?? ""}, ${suggestion.administrativeArea ?? ""} ${suggestion.postalCode ?? ""}",
                              style: GoogleFonts.poppins(),
                            ),
                            onTap: () {
                              onSelected(suggestion);
                            },
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: 17.h),

          // REMOVED: Location Status (3km validation)

          // Map
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _currentLatLng,
                    zoom: 15,
                  ),
                  markers: _markers,
                  circles: _circles,
                  onTap: _onMapTapped,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                ),

                // Current Location Button
                Positioned(
                  bottom: 20.h,
                  right: 20.w,
                  child: FloatingActionButton(
                    onPressed: () async {
                      // Check location service before getting location
                      bool serviceEnabled = await _checkAndRequestLocationService();
                      if (serviceEnabled) {
                        _getCurrentLocation();
                      }
                    },
                    backgroundColor: Colors.white,
                    mini: true,
                    child: Icon(
                      Icons.my_location,
                      color: AppColors.primaryColor,
                      size: 20.sp,
                    ),
                  ),
                ),

                if (_isLoading || _isSearching)
                  const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),

          // Confirm Button
          Padding(
            padding: EdgeInsets.all(16.w),
            child: GestureDetector(
              onTap: _saveLocation,
              child: Container(
                height: 45.h,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(30.r),
                ),
                child: Center(
                  child: Text(
                    "Confirm Location",
                    style: GoogleFonts.jost(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryTextColor,
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

  Widget _buildAppBar() {
    return Container(
      width: double.infinity,
      height: 60.h,
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            offset: const Offset(0, 4),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding:  EdgeInsets.only(top: 14.h),
        child: Row(
          children: [
            SizedBox(width: 16.w),
            InkWell(
              onTap: () => Navigator.pop(context),
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
                    child: Icon(
                        Icons.arrow_back_ios,
                        color: AppColors.iconColor,
                        size: 15.sp
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Text(
              "Change Location",
              style: GoogleFonts.jost(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            const Spacer(),
            SizedBox(width: 20.w),
          ],
        ),
      ),
    );
  }
}