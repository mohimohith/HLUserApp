import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:nexa_mart/ProfileScreen/privacy_policy.dart';
import 'package:nexa_mart/ProfileScreen/terms_condition.dart';
import 'package:nexa_mart/LocationScreen/locationScreen.dart';
import 'package:nexa_mart/utils/colors.dart';
import 'package:sendotp_flutter_sdk/sendotp_flutter_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexa_mart/utils/api_constants.dart';
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {

  // =========================================
  // MSG91 CONFIG
  // =========================================

  final String widgetId = "36656d72634a323236323436";

  final String authToken = "484139TWtWczGlZ6a04bd99P1";

  String? reqId;

  // =========================================
  // STATE VARIABLES
  // =========================================

  bool isLoading = false;
  bool isOtpSent = false;
  bool isMobileNumberValid = false;

  int _secondsRemaining = 59;

  Timer? _timer;

  String? savedPhone;

  // =========================================
  // CONTROLLERS
  // =========================================

  TextEditingController mobileNumberController =
      TextEditingController();

  List<FocusNode> focusNodes =
      List.generate(4, (_) => FocusNode());

  List<TextEditingController> otpControllers =
      List.generate(
    4,
    (_) => TextEditingController(),
  );

  // =========================================
  // INIT
  // =========================================

  @override
  void initState() {
    super.initState();

    mobileNumberController
        .addListener(_validateMobileNumber);

    initializeMSG91();
  }

  // =========================================
  // INITIALIZE MSG91
  // =========================================

  void initializeMSG91() {

    OTPWidget.initializeWidget(
      widgetId,
      authToken,
    );

    print("MSG91 Initialized");
  }

  // =========================================
  // DISPOSE
  // =========================================

  @override
  void dispose() {

    _timer?.cancel();

    mobileNumberController
        .removeListener(_validateMobileNumber);

    mobileNumberController.dispose();

    for (var controller in otpControllers) {
      controller.dispose();
    }

    for (var node in focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  // =========================================
  // VALIDATE MOBILE NUMBER
  // =========================================

  void _validateMobileNumber() {

    final text =
        mobileNumberController.text.trim();

    setState(() {

      isMobileNumberValid =
          text.length == 10 &&
              RegExp(r'^[0-9]+$')
                  .hasMatch(text);

    });
  }

  // =========================================
  // START TIMER
  // =========================================

  void startTimer() {

    _timer?.cancel();

    _secondsRemaining = 60;

    _timer = Timer.periodic(
      const Duration(seconds: 1),
          (timer) {

        if (_secondsRemaining > 0) {

          setState(() {
            _secondsRemaining--;
          });

        } else {

          timer.cancel();
        }
      },
    );
  }

  // =========================================
  // SEND OTP
  // =========================================

  Future<void> sendOTP() async {

    if (!isMobileNumberValid) {

      showError(
        "Please enter valid mobile number",
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {

      String fullPhone =
          "91${mobileNumberController.text.trim()}";

      final data = {
        "identifier": fullPhone,
      };

      print("SEND DATA:");
      print(data);

      final response =
      await OTPWidget.sendOTP(data);

     // reqId = response['reqId'];

      print("SEND OTP RESPONSE:");
      print(response);
      reqId = response?['message'];

      setState(() {
        isLoading = false;
      });

      if (response != null &&
          response['type'] == "success") {

        setState(() {

          isOtpSent = true;

          savedPhone =
              mobileNumberController.text.trim();

        });

        startTimer();

        ScaffoldMessenger.of(context)
            .showSnackBar(

          SnackBar(

            content: const Text(
              "OTP Sent Successfully",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),

            backgroundColor:
            AppColors.successColor,

            behavior:
            SnackBarBehavior.floating,

            duration:
            const Duration(seconds: 2),
          ),
        );

      } else {

        showError(
          response?['message'] ??
              "Failed to send OTP",
        );
      }

    } catch (e) {

      setState(() {
        isLoading = false;
      });

      print("SEND OTP ERROR:");
      print(e);

      showError(
        "Failed to send OTP",
      );
    }
  }

  // =========================================
  // VERIFY OTP
  // =========================================
  

  Future<void> verifyOTP() async {

  final otp =
      otpControllers.map((e) => e.text).join();

  if (otp.length != 4) {

    showError(
      "Please enter 4 digit OTP",
    );

    return;
  }

  if (reqId == null) {

    showError(
      "Request ID missing. Send OTP again.",
    );

    return;
  }

  setState(() {
    isLoading = true;
  });

  try {

    String fullPhone =
        "91${mobileNumberController.text.trim()}";

    final data = {

      "reqId": reqId,

      "otp": otp,

    };

    // =========================
    // VERIFY OTP
    // =========================
    final Map<String, dynamic>? response =
        await OTPWidget.verifyOTP(data);

    print("VERIFY RESPONSE:");
    print(response);

    // =========================
    // NULL CHECK
    // =========================

    setState(() {
    isLoading = false;
  });
  if (response != null && response["type"] == "success") {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', savedPhone!);
        await prefs.setString(
          'jwt_token',
          response["message"],
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => LocationScreen()),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Login Successful",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            backgroundColor: AppColors.primaryColor,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      } else {
        showError(response?["message"] ?? "Invalid OTP");
      }

  } catch (e) {

    setState(() {
      isLoading = false;
    });

    print(e);

    showError(
      "OTP Verification Failed",
    );
  }
}

  // =========================================
  // RESEND OTP
  // =========================================

  void resendOTP() {

    if (_secondsRemaining == 0) {
      sendOTP();
    }
  }

  // =========================================
  // SHOW ERROR
  // =========================================

  void showError(String message) {

    ScaffoldMessenger.of(context)
        .showSnackBar(

      SnackBar(

        content: Text(
          message,
          style: GoogleFonts.jost(),
        ),

        backgroundColor:
        AppColors.errorColor,

        behavior:
        SnackBarBehavior.floating,
      ),
    );
  }

  // =========================================
  // OTP BOX
  // =========================================

  Widget _buildOtpBox(int index) {

    final screenWidth =
        MediaQuery.of(context).size.width;

    final boxSize =
        screenWidth * 0.12;

    return Container(

      width:
      boxSize.clamp(45.0, 65.0),

      height:
      boxSize.clamp(45.0, 65.0),

      decoration: BoxDecoration(

        color: AppColors.gray,

        borderRadius:
        BorderRadius.circular(12),

        border: Border.all(

          color:
          otpControllers[index]
              .text
              .isNotEmpty
              ? AppColors.primaryColor
              : AppColors.hintTextColor
              .withOpacity(0.2),

          width: 1.5,
        ),

        boxShadow: [

          BoxShadow(

            color:
            Colors.black.withOpacity(0.05),

            blurRadius: 8,

            offset: const Offset(0, 2),
          ),
        ],
      ),

      child: Center(

        child: TextField(

          controller:
          otpControllers[index],

          focusNode:
          focusNodes[index],

          keyboardType:
          TextInputType.number,

          maxLength: 1,

          textAlign: TextAlign.center,

          style: GoogleFonts.jost(

            fontSize:
            screenWidth * 0.055,

            fontWeight:
            FontWeight.w600,

            color:
            AppColors.secondaryTextColor,
          ),

          decoration:
          const InputDecoration(

            counterText: '',

            border: InputBorder.none,

            isCollapsed: true,

            contentPadding:
            EdgeInsets.zero,
          ),

          onChanged: (value) {

            setState(() {});

            if (value.length == 1 &&
                index < 3) {

              FocusScope.of(context)
                  .requestFocus(
                focusNodes[index + 1],
              );
            }

            if (value.isEmpty &&
                index > 0) {

              FocusScope.of(context)
                  .requestFocus(
                focusNodes[index - 1],
              );
            }
          },
        ),
      ),
    );
  }

  // =========================================
  // UI
  // =========================================

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Container(

        width:
        MediaQuery.of(context).size.width,

        height:
        MediaQuery.of(context).size.height,

        decoration: BoxDecoration(

          gradient: LinearGradient(

            begin: Alignment.topLeft,

            end: Alignment.bottomRight,

            colors: [

              AppColors.primaryColor
                  .withOpacity(0.3),

              AppColors.backgroundColor,
            ],
          ),
        ),

        child: SingleChildScrollView(

          child: Padding(

            padding: EdgeInsets.symmetric(
              horizontal:
              MediaQuery.of(context)
                  .size
                  .width *
                  0.06,
            ),

            child: Column(

              crossAxisAlignment:
              CrossAxisAlignment.start,

              children: [

                SizedBox(
                  height:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.24,
                ),

                // =========================================
                // LOGO
                // =========================================

                Center(

                  child: Column(

                    children: [

                      Container(

                        width:
                        MediaQuery.of(context)
                            .size
                            .width *
                            0.35,

                        height:
                        MediaQuery.of(context)
                            .size
                            .width *
                            0.35,

                        constraints:
                        const BoxConstraints(

                          minWidth: 120,

                          maxWidth: 200,

                          minHeight: 120,

                          maxHeight: 200,
                        ),

                        decoration:
                        BoxDecoration(

                          color:
                          AppColors.primaryColor,

                          shape: BoxShape.circle,

                          boxShadow: [

                            BoxShadow(

                              color:
                              AppColors.primaryColor
                                  .withOpacity(0.3),

                              blurRadius: 15,

                              spreadRadius: 2,

                              offset:
                              const Offset(0, 5),
                            ),
                          ],
                        ),

                        child: ClipOval(

                          child: Image.asset(

                            "assets/images/logo.png",

                            width: 100.w,

                            height: 100.h,

                            fit: BoxFit.cover,
                          ),
                        ),
                      ),

                      SizedBox(
                        height:
                        MediaQuery.of(context)
                            .size
                            .height *
                            0.02,
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.025,
                ),

                // =========================================
                // TITLE
                // =========================================

                Center(

                  child: Text(

                    isOtpSent
                        ? 'Verify OTP'
                        : 'Welcome',

                    style: GoogleFonts.jost(

                      fontSize:
                      MediaQuery.of(context)
                          .size
                          .width *
                          0.06,

                      fontWeight:
                      FontWeight.w600,

                      color:
                      AppColors.secondaryTextColor,
                    ),
                  ),
                ),

                SizedBox(
                  height:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.01,
                ),

                Center(

                  child: Padding(

                    padding: EdgeInsets.symmetric(

                      horizontal:
                      MediaQuery.of(context)
                          .size
                          .width *
                          0.05,
                    ),

                    child: Text(

                      isOtpSent
                          ? 'Enter the 4-digit code sent to ${mobileNumberController.text}'
                          : 'Enter your mobile number to continue',

                      textAlign: TextAlign.center,

                      style: GoogleFonts.jost(

                        color:
                        AppColors.hintTextColor,

                        fontSize:
                        MediaQuery.of(context)
                            .size
                            .width *
                            0.038,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.04,
                ),

                // =========================================
                // MOBILE FIELD
                // =========================================

                if (!isOtpSent)

                  Container(

                    width: double.infinity,

                    height:
                    MediaQuery.of(context)
                        .size
                        .height *
                        0.065,

                    constraints:
                    const BoxConstraints(

                      minHeight: 50,

                      maxHeight: 70,
                    ),

                    decoration:
                    BoxDecoration(

                      color: Colors.white,

                      borderRadius:
                      BorderRadius.circular(12),

                      border: Border.all(

                        color:
                        AppColors.hintTextColor
                            .withOpacity(0.2),

                        width: 1,
                      ),

                      boxShadow: [

                        BoxShadow(

                          color:
                          Colors.black
                              .withOpacity(0.05),

                          blurRadius: 10,

                          offset:
                          const Offset(0, 4),
                        ),
                      ],
                    ),

                    child: Padding(

                      padding: EdgeInsets.symmetric(

                        horizontal:
                        MediaQuery.of(context)
                            .size
                            .width *
                            0.04,
                      ),

                      child: Row(

                        children: [

                          Container(

                            padding:
                            EdgeInsets.symmetric(

                              horizontal:
                              MediaQuery.of(context)
                                  .size
                                  .width *
                                  0.025,

                              vertical:
                              MediaQuery.of(context)
                                  .size
                                  .height *
                                  0.008,
                            ),

                            decoration:
                            BoxDecoration(

                              color:
                              AppColors.primaryColor
                                  .withOpacity(0.1),

                              borderRadius:
                              BorderRadius.circular(6),
                            ),

                            child: Text(

                              '+91',

                              style: GoogleFonts.jost(

                                color:
                                AppColors.primaryColor,

                                fontSize:
                                MediaQuery.of(context)
                                    .size
                                    .width *
                                    0.04,

                                fontWeight:
                                FontWeight.w600,
                              ),
                            ),
                          ),

                          SizedBox(
                            width:
                            MediaQuery.of(context)
                                .size
                                .width *
                                0.03,
                          ),

                          Expanded(

                            child: TextField(

                              controller:
                              mobileNumberController,

                              keyboardType:
                              TextInputType.phone,

                              style: GoogleFonts.jost(

                                fontSize:
                                MediaQuery.of(context)
                                    .size
                                    .width *
                                    0.04,

                                fontWeight:
                                FontWeight.w500,

                                color:
                                AppColors.secondaryTextColor,
                              ),

                              decoration:
                              InputDecoration(

                                border:
                                InputBorder.none,

                                hintText:
                                'Enter your mobile number',

                                hintStyle:
                                GoogleFonts.jost(

                                  color:
                                  AppColors.hintTextColor,

                                  fontSize:
                                  MediaQuery.of(context)
                                      .size
                                      .width *
                                      0.04,
                                ),
                              ),
                            ),
                          ),

                          if (mobileNumberController
                              .text
                              .isNotEmpty)

                            IconButton(

                              icon: Icon(

                                Icons.clear,

                                size:
                                MediaQuery.of(context)
                                    .size
                                    .width *
                                    0.05,

                                color:
                                AppColors.hintTextColor,
                              ),

                              onPressed: () {

                                setState(() {

                                  mobileNumberController
                                      .clear();
                                });
                              },
                            ),
                        ],
                      ),
                    ),
                  ),

                // =========================================
                // OTP BOXES
                // =========================================

                if (isOtpSent)

                  Column(

                    children: [

                      Padding(

                        padding: EdgeInsets.symmetric(

                          horizontal:
                          MediaQuery.of(context)
                              .size
                              .width *
                              0.05,
                        ),

                        child: Row(

                          mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,

                          children: List.generate(

                            4,

                                (index) =>
                                _buildOtpBox(index),
                          ),
                        ),
                      ),

                      SizedBox(
                        height:
                        MediaQuery.of(context)
                            .size
                            .height *
                            0.02,
                      ),

                      Wrap(

                        alignment:
                        WrapAlignment.center,

                        children: [

                          Text(

                            'Didn\'t receive the code? ',

                            style: GoogleFonts.jost(

                              color:
                              AppColors.hintTextColor,

                              fontSize:
                              MediaQuery.of(context)
                                  .size
                                  .width *
                                  0.035,
                            ),
                          ),

                          GestureDetector(

                            onTap:
                            _secondsRemaining == 0
                                ? resendOTP
                                : null,

                            child: Text(

                              _secondsRemaining > 0
                                  ? 'Resend in $_secondsRemaining s'
                                  : 'Resend OTP',

                              style: GoogleFonts.jost(

                                color:
                                _secondsRemaining > 0
                                    ? AppColors.hintTextColor
                                    : AppColors.primaryColor,

                                fontWeight:
                                FontWeight.w600,

                                fontSize:
                                MediaQuery.of(context)
                                    .size
                                    .width *
                                    0.035,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                SizedBox(
                  height:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.035,
                ),

                // =========================================
                // BUTTON
                // =========================================

                SizedBox(

                  width: double.infinity,

                  height:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.06,

                  child: ElevatedButton(

                    onPressed:
                    isLoading ||
                        (!isOtpSent &&
                            !isMobileNumberValid)

                        ? null

                        : () {

                      if (!isOtpSent) {

                        sendOTP();

                      } else {

                        verifyOTP();
                      }
                    },

                    style:
                    ElevatedButton.styleFrom(

                      backgroundColor:
                      AppColors.primaryColor,

                      foregroundColor:
                      AppColors.secondaryTextColor,

                      shape:
                      RoundedRectangleBorder(

                        borderRadius:
                        BorderRadius.circular(12),
                      ),

                      elevation: 3,

                      shadowColor:
                      AppColors.primaryColor
                          .withOpacity(0.4),

                      disabledBackgroundColor:
                      AppColors.primaryColor
                          .withOpacity(0.5),

                      disabledForegroundColor:
                      AppColors.secondaryTextColor
                          .withOpacity(0.7),
                    ),

                    child:
                    isLoading

                        ? SizedBox(

                      width:
                      MediaQuery.of(context)
                          .size
                          .width *
                          0.055,

                      height:
                      MediaQuery.of(context)
                          .size
                          .width *
                          0.055,

                      child:
                      CircularProgressIndicator(

                        color:
                        AppColors.secondaryTextColor,

                        strokeWidth: 2.5,
                      ),
                    )

                        : Text(

                      isOtpSent
                          ? 'Verify & Continue'
                          : 'Continue',

                      style: GoogleFonts.jost(

                        fontWeight:
                        FontWeight.w600,

                        color:
                        AppColors.primaryTextColor,

                        fontSize:
                        MediaQuery.of(context)
                            .size
                            .width *
                            0.04,
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.025,
                ),

                // =========================================
                // CHANGE NUMBER
                // =========================================

                if (isOtpSent)

                  Center(

                    child: TextButton(

                      onPressed: () {

                        setState(() {

                          isOtpSent = false;

                          _timer?.cancel();

                          for (var controller
                          in otpControllers) {

                            controller.clear();
                          }
                        });
                      },

                      child: Text(

                        'Change Mobile Number',

                        style: GoogleFonts.jost(

                          color:
                          AppColors.primaryColor,

                          fontSize:
                          MediaQuery.of(context)
                              .size
                              .width *
                              0.035,

                          fontWeight:
                          FontWeight.w500,
                        ),
                      ),
                    ),
                  ),

                SizedBox(
                  height:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.05,
                ),

                // =========================================
                // TERMS
                // =========================================

                Center(

                  child: Padding(

                    padding: EdgeInsets.symmetric(

                      horizontal:
                      MediaQuery.of(context)
                          .size
                          .width *
                          0.08,
                    ),

                    child: RichText(

                      textAlign: TextAlign.center,

                      text: TextSpan(

                        style: GoogleFonts.jost(

                          color:
                          AppColors.hintTextColor,

                          fontSize:
                          MediaQuery.of(context)
                              .size
                              .width *
                              0.03,
                        ),

                        children: [

                          const TextSpan(
                            text:
                            'By continuing, you agree to our\n',
                          ),

                          TextSpan(

                            text:
                            'Terms of Service',

                            style: TextStyle(

                              color:
                              AppColors.primaryColor,

                              fontWeight:
                              FontWeight.w500,
                            ),

                            recognizer:
                            TapGestureRecognizer()

                              ..onTap = () {

                                Navigator.push(

                                  context,

                                  MaterialPageRoute(

                                    builder: (context) =>
                                        TermsCondition(),
                                  ),
                                );
                              },
                          ),

                          const TextSpan(
                            text: ' and ',
                          ),

                          TextSpan(

                            text:
                            'Privacy Policy',

                            style: TextStyle(

                              color:
                              AppColors.primaryColor,

                              fontWeight:
                              FontWeight.w500,
                            ),

                            recognizer:
                            TapGestureRecognizer()

                              ..onTap = () {

                                Navigator.push(

                                  context,

                                  MaterialPageRoute(

                                    builder: (context) =>
                                        PrivacyPolicy(),
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                SizedBox(
                  height:
                  MediaQuery.of(context)
                      .size
                      .height *
                      0.08,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}