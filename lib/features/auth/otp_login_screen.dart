import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/repositories.dart';
import '../shell/app_shell.dart';

/// Customer login using the backend's built-in OTP flow.
///
/// Requests a code via `/auth/otp/request` and verifies it via
/// `/auth/otp/verify`. With OTP_PROVIDER=widget the backend drives the MSG91
/// OTP Widget (WhatsApp, 4-digit); in dev (OTP_DEV_EXPOSE=true) the code is
/// returned/logged for convenience.
class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  static const Color _primary = Color(0xff960ad7);
  static const Color _hint = Color(0xff4B4A4A);

  static const int _otpLength = 4;

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _mobileCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(OtpLoginScreen._otpLength, (_) => TextEditingController());
  final List<FocusNode> _otpNodes =
      List.generate(OtpLoginScreen._otpLength, (_) => FocusNode());

  bool _loading = false;
  bool _otpSent = false;
  bool _mobileValid = false;
  int _secondsRemaining = 0;
  Timer? _timer;
  String _savedPhone = '';

  @override
  void initState() {
    super.initState();
    _mobileCtrl.addListener(_validateMobile);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _mobileCtrl.removeListener(_validateMobile);
    _mobileCtrl.dispose();
    for (final c in _otpCtrls) {
      c.dispose();
    }
    for (final n in _otpNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _validateMobile() {
    final text = _mobileCtrl.text.trim();
    final valid = text.length == 10 && RegExp(r'^[0-9]+$').hasMatch(text);
    if (valid != _mobileValid) setState(() => _mobileValid = valid);
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        t.cancel();
      }
    });
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.jost(color: Colors.white)),
        backgroundColor: const Color(0xffE53E3E),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _sendOtp() async {
    if (!_mobileValid) {
      _showError('Please enter valid mobile number');
      return;
    }
    setState(() => _loading = true);
    try {
      _savedPhone = _mobileCtrl.text.trim();
      final devCode = await Repos.auth.requestOtp(_savedPhone);
      if (!mounted) return;
      setState(() => _loading = false);

      if (devCode != null) {
        // Development mode — OTP_DEV_EXPOSE is enabled, show the code.
        _showError('Dev OTP: $devCode');
      }
      setState(() => _otpSent = true);
      _startTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('OTP Sent Successfully',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xff38A169),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _loading = false);
      _showError(e.message);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _showError('Failed to send OTP');
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((e) => e.text).join();
    if (otp.length < OtpLoginScreen._otpLength) {
      _showError('Please enter the ${OtpLoginScreen._otpLength}-digit OTP');
      return;
    }
    setState(() => _loading = true);
    try {
      await Repos.auth.verifyOtp(phone: _savedPhone, code: otp);
      await Repos.branches.resolveActiveBranch();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } on ApiException catch (e) {
      if (mounted) setState(() => _loading = false);
      _showError(e.message);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
      _showError('OTP Verification Failed');
    }
  }

  void _resendOtp() {
    if (_secondsRemaining == 0) _sendOtp();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0x4D960AD7), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: w * 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: MediaQuery.of(context).size.height * 0.18),
              // Logo
              Center(
                child: Container(
                  width: w * 0.35,
                  height: w * 0.35,
                  constraints: const BoxConstraints(
                      minWidth: 120, maxWidth: 200, minHeight: 120, maxHeight: 200),
                  decoration: BoxDecoration(
                    color: OtpLoginScreen._primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xff960ad7).withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 2,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.045),
              Center(
                child: Text(
                  _otpSent ? 'Verify OTP' : 'Welcome',
                  style: GoogleFonts.jost(
                      fontSize: w * 0.06,
                      fontWeight: FontWeight.w600,
                      color: Colors.black),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.01),
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: w * 0.05),
                  child: Text(
                    _otpSent
                        ? 'Enter the ${OtpLoginScreen._otpLength}-digit code sent to ${_mobileCtrl.text}'
                        : 'Enter your mobile number to continue',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.jost(
                        color: OtpLoginScreen._hint, fontSize: w * 0.038),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.04),
              if (!_otpSent) _mobileField(w) else _otpBoxes(w),
              SizedBox(height: MediaQuery.of(context).size.height * 0.035),
              _primaryButton(w),
              SizedBox(height: MediaQuery.of(context).size.height * 0.025),
              if (_otpSent)
                Center(
                  child: TextButton(
                    onPressed: () => setState(() {
                      _otpSent = false;
                      _timer?.cancel();
                      for (final c in _otpCtrls) {
                        c.clear();
                      }
                    }),
                    child: Text('Change Mobile Number',
                        style: GoogleFonts.jost(
                            color: OtpLoginScreen._primary,
                            fontSize: w * 0.035,
                            fontWeight: FontWeight.w500)),
                  ),
                ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.05),
              Center(
                child: Text(
                  'By continuing, you agree to our\nTerms of Service and Privacy Policy',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.jost(
                      color: OtpLoginScreen._hint, fontSize: w * 0.03),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).size.height * 0.06),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mobileField(double w) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 50, maxHeight: 70),
      height: MediaQuery.of(context).size.height * 0.065,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: OtpLoginScreen._hint.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: w * 0.04),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: w * 0.025, vertical: 6),
              decoration: BoxDecoration(
                color: OtpLoginScreen._primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('+91',
                  style: GoogleFonts.jost(
                      color: OtpLoginScreen._primary,
                      fontSize: w * 0.04,
                      fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: w * 0.03),
            Expanded(
              child: TextField(
                controller: _mobileCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: GoogleFonts.jost(
                    fontSize: w * 0.04, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  hintText: 'Enter your mobile number',
                  hintStyle: GoogleFonts.jost(
                      color: OtpLoginScreen._hint, fontSize: w * 0.04),
                ),
              ),
            ),
            if (_mobileCtrl.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.clear, size: w * 0.05, color: OtpLoginScreen._hint),
                onPressed: () => setState(() => _mobileCtrl.clear()),
              ),
          ],
        ),
      ),
    );
  }

  Widget _otpBoxes(double w) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: w * 0.05),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(OtpLoginScreen._otpLength, (i) => _otpBox(i, w)),
          ),
        ),
        SizedBox(height: MediaQuery.of(context).size.height * 0.02),
        Wrap(
          alignment: WrapAlignment.center,
          children: [
            Text("Didn't receive the code? ",
                style: GoogleFonts.jost(
                    color: OtpLoginScreen._hint, fontSize: w * 0.035)),
            GestureDetector(
              onTap: _secondsRemaining == 0 ? _resendOtp : null,
              child: Text(
                _secondsRemaining > 0 ? 'Resend in $_secondsRemaining s' : 'Resend OTP',
                style: GoogleFonts.jost(
                    color: _secondsRemaining > 0
                        ? OtpLoginScreen._hint
                        : OtpLoginScreen._primary,
                    fontWeight: FontWeight.w600,
                    fontSize: w * 0.035),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _otpBox(int index, double w) {
    final boxSize = (w * 0.12).clamp(45.0, 65.0);
    return SizedBox(
      width: boxSize,
      height: boxSize,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xffF8F4F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _otpCtrls[index].text.isNotEmpty
                ? OtpLoginScreen._primary
                : OtpLoginScreen._hint.withOpacity(0.2),
            width: 1.5,
          ),
        ),
        child: Center(
          child: TextField(
            controller: _otpCtrls[index],
            focusNode: _otpNodes[index],
            keyboardType: TextInputType.number,
            maxLength: 1,
            textAlign: TextAlign.center,
            style: GoogleFonts.jost(
                fontSize: w * 0.055, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              isCollapsed: true,
            ),
            onChanged: (value) {
              setState(() {});
              if (value.isNotEmpty && index < OtpLoginScreen._otpLength - 1) {
                FocusScope.of(context).requestFocus(_otpNodes[index + 1]);
              } else if (value.isEmpty && index > 0) {
                FocusScope.of(context).requestFocus(_otpNodes[index - 1]);
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _primaryButton(double w) {
    final disabled = _loading || (!_otpSent && !_mobileValid);
    return SizedBox(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.06,
      child: ElevatedButton(
        onPressed: disabled ? null : (_otpSent ? _verifyOtp : _sendOtp),
        style: ElevatedButton.styleFrom(
          backgroundColor: OtpLoginScreen._primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 3,
          disabledBackgroundColor: OtpLoginScreen._primary.withOpacity(0.5),
        ),
        child: _loading
            ? SizedBox(
                width: w * 0.055,
                height: w * 0.055,
                child: const CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5),
              )
            : Text(_otpSent ? 'Verify & Continue' : 'Continue',
                style: GoogleFonts.jost(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: w * 0.04)),
      ),
    );
  }
}
