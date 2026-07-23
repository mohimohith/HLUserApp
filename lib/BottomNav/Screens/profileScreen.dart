// ProfileScreen.dart
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexa_mart/BottomNav/Screens/wishlist_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../../Auth/edit_profile.dart';
import '../../Auth/loginScreen.dart';
import '../../Coupon/coupon_screen.dart';
import '../../DeliveryAddress/delivery_address_screen.dart';
import '../../Help/help_screen.dart';
import '../../ProfileScreen/about_screen.dart';
import '../../ProfileScreen/privacy_policy.dart';
import '../../ProfileScreen/return_policy.dart';
import '../../ProfileScreen/terms_condition.dart';
import '../../Provider/language_provider.dart';
import '../../compat/app_state.dart';
import '../../data/repositories/repositories.dart';
import '../../utils/colors.dart';
import 'order_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String userEmail = "";
  String userName = "";
  String userId = "";
  bool isLoading = true;
  bool hasProfileData = false;

  @override
  void initState() {
    super.initState();
    fetchUserData();
  }


  String getText(String english, String telugu) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    return languageProvider.getText(english, telugu);
  }

  // Show language selection popup - UPDATED
  void showLanguageSelectionDialog() {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => LanguageSelectionDialog(
        currentLanguage: languageProvider.selectedLanguage,
        onLanguageSelected: (language) async {
          await languageProvider.setLanguage(language);
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                languageProvider.getText(
                    "Language changed to $language",
                    "భాష $language కి మార్చబడింది"
                ),
                style: GoogleFonts.jost(),
              ),
              backgroundColor: AppColors.primaryColor,
            ),
          );
        },
      ),
    );
  }

  Future<void> fetchUserData() async {
    setState(() => isLoading = true);
    userId = AppState.userId;
    if (userId.isNotEmpty) {
      await fetchUserDetails(userId);
    }
    setState(() => isLoading = false);
  }

  Future<void> fetchUserDetails(String userId) async {
    try {
      final user = await Repos.auth.me();
      setState(() {
        userName = (user['name'] ?? '').toString();
        userEmail = (user['email'] ?? '').toString();
        hasProfileData = userName.isNotEmpty;
      });
    } catch (e) {
      debugPrint("Error fetching user details: $e");
    }
  }

  void showCompleteProfileBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => CompleteProfileForm(
        userId: userId,
        getText: getText,
        onProfileUpdated: (String name, String email) {
          setState(() {
            userName = name;
            userEmail = email;
            hasProfileData = name.isNotEmpty && email.isNotEmpty;
          });
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Future<void> logoutUser() async {
    await Repos.auth.logout();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
    );
  }

  void showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
        title: Text(
          getText("Logout", "లాగ్అవుట్"),
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18.sp),
        ),
        content: Text(
          getText("Are you sure you want to logout?", "మీరు ఖచ్చితంగా లాగ్అవుట్ చేయాలనుకుంటున్నారా?"),
          style: GoogleFonts.poppins(fontSize: 14.sp),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              getText("Cancel", "రద్దు చేయండి"),
              style: TextStyle(color: AppColors.hintTextColor, fontSize: 14.sp),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              logoutUser();
            },
            child: Text(
              getText("Logout", "లాగ్అవుట్"),
              style: TextStyle(color: Colors.red, fontSize: 14.sp),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);

    return Scaffold(
      backgroundColor: Colors.white,
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
          : RefreshIndicator(
            onRefresh: fetchUserData,
            child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 50.h),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 25.r,
                    backgroundColor: AppColors.primaryColor,
                    child: SvgPicture.asset('assets/svg/profile.svg',
                        color: AppColors.primaryTextColor,
                        width: 25.w, height: 25.h),
                  ),
                  SizedBox(width: 10.w),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasProfileData)
                        InkWell(
                          child: Row(
                            children: [
                              Text(userName, style: GoogleFonts.jost(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w600
                              )),
                              SizedBox(width: 2.w),
                              Icon(Icons.edit, size: 18.sp, color: AppColors.primaryColor)
                            ],
                          ),
                          onTap: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditProfile(
                                  userId: userId,
                                  email: userEmail,
                                  fullName: userName,
                                ),
                              ),
                            );

                            // Agar user ne update kiya h to profile refresh karo
                            if (result != null) {
                              setState(() {
                                userName = result["name"];
                                userEmail = result["email"];
                              });
                            }
                          },
                        )
                      else
                        InkWell(
                          child: Row(
                            children: [
                              Text(
                                  getText("Complete Profile", "ప్రొఫైల్ పూర్తి చేయండి"),
                                  style: GoogleFonts.jost(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.red
                                  )),
                              SizedBox(width: 2.w),
                              Icon(Icons.edit, size: 18.sp, color: Colors.red)
                            ],
                          ),
                          onTap: showCompleteProfileBottomSheet,
                        ),

                      if (hasProfileData)
                        Text(userEmail, style: GoogleFonts.jost(
                          fontWeight: FontWeight.w400,
                        ))
                      else
                        Text(
                            getText("Tap to complete your profile", "మీ ప్రొఫైల్ పూర్తి చేయడానికి టాప్ చేయండి"),
                            style: GoogleFonts.jost(
                                fontWeight: FontWeight.w400,
                                fontSize: 12.sp,
                                color: Colors.grey
                            ))
                    ],
                  )
                ],
              ),
            ),
            SizedBox(height: 20.h),
            Container(color: Colors.grey.withOpacity(0.5), height: 0.5),
            Padding(
              padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 25.h),
              child: Column(
                  children: [
                    // Order
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderScreen())),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/p_order.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText('Orders', 'ఆర్డర్లు'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 17.sp)
                        ],
                      ),
                    ),
                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    // Delivery Address
                    SizedBox(height: 20.w),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => DeliveryAddressScreen())),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/p_location.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText(' Delivery Address', ' డెలివరీ చిరునామా'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 17.sp)
                        ],
                      ),
                    ),
                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    // Coupon
                    SizedBox(height: 20.w),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => CouponScreen())),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/p_coupon.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText('Coupon', 'కూపన్'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 17.sp)
                        ],
                      ),
                    ),

                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    // WishList
                    SizedBox(height: 20.w),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => WishlistScreen())),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/wishlist.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText('WishList', 'ఇష్టాల జాబితా'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 17.sp)
                        ],
                      ),
                    ),

                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    // Language
                    SizedBox(height: 20.w),
                    InkWell(
                      onTap: showLanguageSelectionDialog,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/p_language.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText('Language', 'భాష'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Row(
                            children: [
                              Text(
                                languageProvider.selectedLanguage == "English"
                                    ? getText("English", "ఇంగ్లీష్")
                                    : getText("Telugu", "తెలుగు"),
                                style: GoogleFonts.jost(
                                  fontSize: 14.sp,
                                  color: Colors.grey[600],
                                ),
                              ),
                              SizedBox(width: 5.w),
                              Icon(Icons.arrow_forward_ios, size: 17.sp)
                            ],
                          )
                        ],
                      ),
                    ),

                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    // Help
                    SizedBox(height: 20.w),
                    InkWell(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => HelpScreen())),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/p_help.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText(' Help', ' సహాయం'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 17.sp)
                        ],
                      ),
                    ),
                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    // About
                    SizedBox(height: 20.w),
                    InkWell(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>AboutScreen()));
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/p_about.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText(' About', ' గురించి'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 17.sp)
                        ],
                      ),
                    ),
                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    // Terms & Condition
                    SizedBox(height: 20.w),
                    InkWell(
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>TermsCondition()));
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/p_term_condition.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText(' Terms & Condition', ' నియమాలు & షరతులు'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 17.sp)
                        ],
                      ),
                    ),
                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    // Privacy Policy
                    SizedBox(height: 20.w),
                    InkWell(
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>PrivacyPolicy()));
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/p_privacy_policy.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText(' Privacy Policy', ' గోప్యతా విధానం'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 17.sp)
                        ],
                      ),
                    ),
                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    // Return Policy
                    SizedBox(height: 20.w),
                    InkWell(
                      onTap: (){
                        Navigator.push(context, MaterialPageRoute(builder: (context)=>ReturnPolicy()));
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: 16.h),
                          SvgPicture.asset('assets/svg/p_return_policy.svg', height: 18.h, width: 18.w),
                          SizedBox(width: 10.w),
                          Text(
                            getText(' Shipping Policy', ' షిప్పింగ్ విధానం'),
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              fontSize: 16.sp,
                            ),
                          ),
                          Spacer(),
                          Icon(Icons.arrow_forward_ios, size: 17.sp)
                        ],
                      ),
                    ),
                    SizedBox(height: 15.w),
                    Container(color: Colors.grey.withOpacity(0.5), height: 0.7),

                    SizedBox(height: 30.w),
                    InkWell(
                      onTap: showLogoutDialog,
                      child: Container(
                        width: double.infinity,
                        height: 39.h,
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            SvgPicture.asset('assets/svg/p_logout.svg', color: AppColors.iconColor),
                            SizedBox(width: 10.w),
                            Text(
                              getText('Log out', 'లాగ్అవుట్'),
                              style: GoogleFonts.jost(
                                fontSize: 14.sp,
                                color: AppColors.primaryTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 30.w),
                  ]
              ),
            )
          ],
        ),
      ),
    ),
  );
  }
}

// Language Selection Dialog Widget - UPDATED
class LanguageSelectionDialog extends StatefulWidget {
  final String currentLanguage;
  final Function(String) onLanguageSelected;

  const LanguageSelectionDialog({
    Key? key,
    required this.currentLanguage,
    required this.onLanguageSelected,
  }) : super(key: key);

  @override
  _LanguageSelectionDialogState createState() => _LanguageSelectionDialogState();
}

class _LanguageSelectionDialogState extends State<LanguageSelectionDialog> {
  late String _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = widget.currentLanguage;
  }

  @override
  Widget build(BuildContext context) {
    final languageProvider = Provider.of<LanguageProvider>(context, listen: true);

    // Helper function for text
    String getText(String english, String telugu) {
      return languageProvider.getText(english, telugu);
    }

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getText("Select Language", "భాషను ఎంచుకోండి"),
              style: GoogleFonts.jost(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20.h),

            // English Option
            InkWell(
              onTap: () {
                setState(() {
                  _selectedLanguage = "English";
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 15.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: _selectedLanguage == "English"
                        ? AppColors.primaryColor
                        : Colors.grey[300]!,
                    width: _selectedLanguage == "English" ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio(
                      value: "English",
                      groupValue: _selectedLanguage,
                      onChanged: (value) {
                        setState(() {
                          _selectedLanguage = value.toString();
                        });
                      },
                      activeColor: AppColors.primaryColor,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      getText("English", "ఇంగ్లీష్"),
                      style: GoogleFonts.jost(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 15.h),

            // Telugu Option
            InkWell(
              onTap: () {
                setState(() {
                  _selectedLanguage = "Telugu";
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 15.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(
                    color: _selectedLanguage == "Telugu"
                        ? AppColors.primaryColor
                        : Colors.grey[300]!,
                    width: _selectedLanguage == "Telugu" ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Radio(
                      value: "Telugu",
                      groupValue: _selectedLanguage,
                      onChanged: (value) {
                        setState(() {
                          _selectedLanguage = value.toString();
                        });
                      },
                      activeColor: AppColors.primaryColor,
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      getText("Telugu", "తెలుగు"),
                      style: GoogleFonts.jost(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 25.h),

            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        side: BorderSide(color: Colors.grey[300]!),
                      ),
                    ),
                    child: Text(
                      getText("Cancel", "రద్దు చేయండి"),
                      style: GoogleFonts.jost(
                        fontSize: 16.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 15.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      widget.onLanguageSelected(_selectedLanguage);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      padding: EdgeInsets.symmetric(vertical: 12.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      getText("Apply", "వర్తింపజేయండి"),
                      style: GoogleFonts.jost(
                        fontSize: 16.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Complete Profile Form in Bottom Sheet - UPDATED
class CompleteProfileForm extends StatefulWidget {
  final String userId;
  final void Function(String name, String email) onProfileUpdated;
  final String Function(String, String) getText;

  const CompleteProfileForm({
    Key? key,
    required this.userId,
    required this.onProfileUpdated,
    required this.getText,
  }) : super(key: key);

  @override
  _CompleteProfileFormState createState() => _CompleteProfileFormState();
}

class _CompleteProfileFormState extends State<CompleteProfileForm> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  bool _isSubmitting = false;

  // Helper function for text - use the passed callback from parent widget
  String getText(String english, String telugu) {
    return widget.getText(english, telugu);
  }

  Future<bool> insertUser(String name, String email) async {
    try {
      await Repos.auth.updateProfile(name: name, email: email);
      return true;
    } catch (e) {
      debugPrint("Error updating profile: $e");
      return false;
    }
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isSubmitting = true);

      bool success = await insertUser(
        _nameController.text.trim(),
        _emailController.text.trim(),
      );

      setState(() => _isSubmitting = false);

      if (success) {
        widget.onProfileUpdated(
          _nameController.text.trim(),
          _emailController.text.trim(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(getText(
                  "Failed to update profile. Please try again.",
                  "ప్రొఫైల్ నవీకరించడంలో విఫలమైంది. దయచేసి మళ్లీ ప్రయత్నించండి."
              )),
            )
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
          left: 20.w,
          right: 20.w,
          top: 20.h
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40.w,
                height: 5.h,
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10)
                ),
              ),
            ),
            SizedBox(height: 20.h),
            Text(
              getText("Complete Your Profile", "మీ ప్రొఫైల్ పూర్తి చేయండి"),
              style: GoogleFonts.jost(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 15.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: getText("Full Name", "పూర్తి పేరు"),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return getText(
                      'Please enter your name',
                      'దయచేసి మీ పేరును నమోదు చేయండి'
                  );
                }
                return null;
              },
            ),
            SizedBox(height: 15.h),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: getText("Email Address", "ఇమెయిల్ చిరునామా"),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return getText(
                      'Please enter your email',
                      'దయచేసి మీ ఇమెయిల్ నమోదు చేయండి'
                  );
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                  return getText(
                      'Please enter a valid email',
                      'దయచేసి సరైన ఇమెయిల్ నమోదు చేయండి'
                  );
                }
                return null;
              },
            ),
            SizedBox(height: 15.h),

            SizedBox(height: 20.h),
            _isSubmitting
                ? Center(child: CircularProgressIndicator(color: AppColors.primaryColor))
                : SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  padding: EdgeInsets.symmetric(vertical: 15.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  getText("Save Profile", "ప్రొఫైల్ సేవ్ చేయండి"),
                  style: GoogleFonts.jost(
                      fontSize: 16.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w600
                  ),
                ),
              ),
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }
}