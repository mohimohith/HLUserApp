import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../ProfileScreen/privacy_policy.dart';
import '../ProfileScreen/terms_condition.dart';
import '../BottomNav/bottomNavScreen.dart';
import '../compat/app_state.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';

/// Exact legacy login UI, wired to the new backend's server-side OTP flow
/// (`/auth/otp/request` + `/auth/otp/verify`). With OTP_PROVIDER=widget the
/// backend drives the MSG91 OTP Widget (WhatsApp channel, 4-digit code), so the
/// length here matches the widget config.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const int _otpLength = 4;

  bool isLoading = false;
  bool isOtpSent = false;
  bool isMobileNumberValid = false;

  int _secondsRemaining = 59;
  Timer? _timer;
  String? savedPhone;

  TextEditingController mobileNumberController = TextEditingController();

  List<FocusNode> focusNodes = List.generate(_otpLength, (_) => FocusNode());
  List<TextEditingController> otpControllers =
      List.generate(_otpLength, (_) => TextEditingController());

  @override
  void initState() {
    super.initState();
    mobileNumberController.addListener(_validateMobileNumber);
  }

  @override
  void dispose() {
    _timer?.cancel();
    mobileNumberController.removeListener(_validateMobileNumber);
    mobileNumberController.dispose();
    for (var controller in otpControllers) {
      controller.dispose();
    }
    for (var node in focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _validateMobileNumber() {
    final text = mobileNumberController.text.trim();
    setState(() {
      isMobileNumberValid =
          text.length == 10 && RegExp(r'^[0-9]+$').hasMatch(text);
    });
  }

  void startTimer() {
    _timer?.cancel();
    _secondsRemaining = 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> sendOTP() async {
    if (!isMobileNumberValid) {
      showError("Please enter valid mobile number");
      return;
    }
    setState(() => isLoading = true);
    try {
      final phone = mobileNumberController.text.trim();
      final devCode = await Repos.auth.requestOtp(phone);
      setState(() {
        isLoading = false;
        isOtpSent = true;
        savedPhone = phone;
      });
      startTimer();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            devCode != null ? "OTP sent (dev: $devCode)" : "OTP Sent Successfully",
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.successColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      showError("Failed to send OTP");
    }
  }

  Future<void> verifyOTP() async {
    final otp = otpControllers.map((e) => e.text).join();
    if (otp.length != _otpLength) {
      showError("Please enter $_otpLength digit OTP");
      return;
    }
    setState(() => isLoading = true);
    try {
      await Repos.auth.verifyOtp(phone: savedPhone!, code: otp);

      // Resolve the branch to serve before entering the shell.
      try {
        final branch = await Repos.branches.resolveActiveBranch();
        AppState.setBranch(branch?.id);
      } catch (_) {}

      setState(() => isLoading = false);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const BottomNavScreen()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Login Successful",
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: AppColors.primaryColor,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => isLoading = false);
      showError("Invalid OTP");
    }
  }

  void resendOTP() {
    if (_secondsRemaining == 0) sendOTP();
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.jost()),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildOtpBox(int index) {
    final screenWidth = MediaQuery.of(context).size.width;
    final boxSize = screenWidth * 0.12;
    return Container(
      width: boxSize.clamp(40.0, 60.0),
      height: boxSize.clamp(40.0, 60.0),
      decoration: BoxDecoration(
        color: AppColors.gray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: otpControllers[index].text.isNotEmpty
              ? AppColors.primaryColor
              : AppColors.hintTextColor.withOpacity(0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: TextField(
          controller: otpControllers[index],
          focusNode: focusNodes[index],
          keyboardType: TextInputType.number,
          maxLength: 1,
          textAlign: TextAlign.center,
          style: GoogleFonts.jost(
            fontSize: screenWidth * 0.05,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryTextColor,
          ),
          decoration: const InputDecoration(
            counterText: '',
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: (value) {
            setState(() {});
            if (value.length == 1 && index < _otpLength - 1) {
              FocusScope.of(context).requestFocus(focusNodes[index + 1]);
            }
            if (value.isEmpty && index > 0) {
              FocusScope.of(context).requestFocus(focusNodes[index - 1]);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primaryColor.withOpacity(0.3),
              AppColors.backgroundColor,
            ],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width * 0.06),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: MediaQuery.of(context).size.height * 0.24),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: MediaQuery.of(context).size.width * 0.35,
                        height: MediaQuery.of(context).size.width * 0.35,
                        constraints: const BoxConstraints(
                          minWidth: 120,
                          maxWidth: 200,
                          minHeight: 120,
                          maxHeight: 200,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primaryColor.withOpacity(0.3),
                              blurRadius: 15,
                              spreadRadius: 2,
                              offset: const Offset(0, 5),
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
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                    ],
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                Center(
                  child: Text(
                    isOtpSent ? 'Verify OTP' : 'Welcome',
                    style: GoogleFonts.jost(
                      fontSize: MediaQuery.of(context).size.width * 0.06,
                      fontWeight: FontWeight.w600,
                      color: AppColors.secondaryTextColor,
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.01),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.05),
                    child: Text(
                      isOtpSent
                          ? 'Enter the $_otpLength-digit code sent to ${mobileNumberController.text}'
                          : 'Enter your mobile number to continue',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.jost(
                        color: AppColors.hintTextColor,
                        fontSize: MediaQuery.of(context).size.width * 0.038,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.04),
                if (!isOtpSent)
                  Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height * 0.065,
                    constraints: const BoxConstraints(minHeight: 50, maxHeight: 70),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.hintTextColor.withOpacity(0.2),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: MediaQuery.of(context).size.width * 0.04),
                      child: Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: MediaQuery.of(context).size.width * 0.025,
                              vertical: MediaQuery.of(context).size.height * 0.008,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '+91',
                              style: GoogleFonts.jost(
                                color: AppColors.primaryColor,
                                fontSize: MediaQuery.of(context).size.width * 0.04,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(width: MediaQuery.of(context).size.width * 0.03),
                          Expanded(
                            child: TextField(
                              controller: mobileNumberController,
                              keyboardType: TextInputType.phone,
                              style: GoogleFonts.jost(
                                fontSize: MediaQuery.of(context).size.width * 0.04,
                                fontWeight: FontWeight.w500,
                                color: AppColors.secondaryTextColor,
                              ),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: 'Enter your mobile number',
                                hintStyle: GoogleFonts.jost(
                                  color: AppColors.hintTextColor,
                                  fontSize: MediaQuery.of(context).size.width * 0.04,
                                ),
                              ),
                            ),
                          ),
                          if (mobileNumberController.text.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.clear,
                                size: MediaQuery.of(context).size.width * 0.05,
                                color: AppColors.hintTextColor,
                              ),
                              onPressed: () {
                                setState(() => mobileNumberController.clear());
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                if (isOtpSent)
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: MediaQuery.of(context).size.width * 0.03),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(
                            _otpLength,
                            (index) => _buildOtpBox(index),
                          ),
                        ),
                      ),
                      SizedBox(height: MediaQuery.of(context).size.height * 0.02),
                      Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          Text(
                            'Didn\'t receive the code? ',
                            style: GoogleFonts.jost(
                              color: AppColors.hintTextColor,
                              fontSize: MediaQuery.of(context).size.width * 0.035,
                            ),
                          ),
                          GestureDetector(
                            onTap: _secondsRemaining == 0 ? resendOTP : null,
                            child: Text(
                              _secondsRemaining > 0
                                  ? 'Resend in $_secondsRemaining s'
                                  : 'Resend OTP',
                              style: GoogleFonts.jost(
                                color: _secondsRemaining > 0
                                    ? AppColors.hintTextColor
                                    : AppColors.primaryColor,
                                fontWeight: FontWeight.w600,
                                fontSize: MediaQuery.of(context).size.width * 0.035,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.035),
                SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.06,
                  child: ElevatedButton(
                    onPressed: isLoading || (!isOtpSent && !isMobileNumberValid)
                        ? null
                        : () {
                            if (!isOtpSent) {
                              sendOTP();
                            } else {
                              verifyOTP();
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.secondaryTextColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 3,
                      shadowColor: AppColors.primaryColor.withOpacity(0.4),
                      disabledBackgroundColor:
                          AppColors.primaryColor.withOpacity(0.5),
                      disabledForegroundColor:
                          AppColors.secondaryTextColor.withOpacity(0.7),
                    ),
                    child: isLoading
                        ? SizedBox(
                            width: MediaQuery.of(context).size.width * 0.055,
                            height: MediaQuery.of(context).size.width * 0.055,
                            child: const CircularProgressIndicator(
                              color: AppColors.secondaryTextColor,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            isOtpSent ? 'Verify & Continue' : 'Continue',
                            style: GoogleFonts.jost(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryTextColor,
                              fontSize: MediaQuery.of(context).size.width * 0.04,
                            ),
                          ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.025),
                if (isOtpSent)
                  Center(
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          isOtpSent = false;
                          _timer?.cancel();
                          for (var controller in otpControllers) {
                            controller.clear();
                          }
                        });
                      },
                      child: Text(
                        'Change Mobile Number',
                        style: GoogleFonts.jost(
                          color: AppColors.primaryColor,
                          fontSize: MediaQuery.of(context).size.width * 0.035,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.width * 0.08),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: GoogleFonts.jost(
                          color: AppColors.hintTextColor,
                          fontSize: MediaQuery.of(context).size.width * 0.03,
                        ),
                        children: [
                          const TextSpan(
                              text: 'By continuing, you agree to our\n'),
                          TextSpan(
                            text: 'Terms of Service',
                            style: const TextStyle(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => TermsCondition(),
                                  ),
                                );
                              },
                          ),
                          const TextSpan(text: ' and '),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: const TextStyle(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PrivacyPolicy(),
                                  ),
                                );
                              },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).size.height * 0.08),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
