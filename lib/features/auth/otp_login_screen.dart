import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/network/api_exception.dart';
import '../../data/repositories/repositories.dart';
import '../shell/app_shell.dart';

/// Modern phone + OTP login against the new backend.
///
/// Step 1 collects the mobile number and requests an OTP; step 2 verifies it
/// (auto-registering first-time customers). On success the session is persisted
/// and the active branch resolved before entering the app shell.
class OtpLoginScreen extends StatefulWidget {
  const OtpLoginScreen({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<OtpLoginScreen> createState() => _OtpLoginScreenState();
}

class _OtpLoginScreenState extends State<OtpLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  bool _otpSent = false;
  bool _busy = false;
  String? _error;
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
      } else if (mounted) {
        setState(() => _resendIn--);
      }
    });
  }

  Future<void> _requestOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length != 10) {
      setState(() => _error = 'Enter a valid 10-digit mobile number');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final devCode = await Repos.auth.requestOtp(phone);
      if (!mounted) return;
      setState(() {
        _otpSent = true;
        if (devCode != null) _otpCtrl.text = devCode; // dev convenience
      });
      _startResendCountdown();
      if (devCode != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Dev OTP: $devCode')),
        );
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpCtrl.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the OTP you received');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Repos.auth.verifyOtp(
        phone: _phoneCtrl.text.trim(),
        code: code,
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
      );
      // Make sure a branch is selected before the home screen loads.
      await Repos.branches.resolveActiveBranch();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AppShell()),
        (_) => false,
      );
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: OtpLoginScreen._primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.storefront_rounded,
                    color: OtpLoginScreen._primary, size: 34),
              ),
              const SizedBox(height: 24),
              Text(
                _otpSent ? 'Verify your number' : 'Welcome to NexaMart',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                _otpSent
                    ? 'Enter the OTP sent to +91 ${_phoneCtrl.text}'
                    : 'Login or sign up with your mobile number',
                style: const TextStyle(fontSize: 14, color: Color(0xff777777)),
              ),
              const SizedBox(height: 32),
              if (!_otpSent) ..._phoneStep() else ..._otpStep(),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!,
                    style: const TextStyle(color: Color(0xffE53E3E), fontSize: 13)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _phoneStep() => [
        _FieldShell(
          child: Row(
            children: [
              const Text('+91  ',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  maxLength: 10,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    counterText: '',
                    border: InputBorder.none,
                    hintText: 'Mobile number',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(
          label: 'Send OTP',
          busy: _busy,
          onTap: _requestOtp,
        ),
      ];

  List<Widget> _otpStep() => [
        _FieldShell(
          child: TextField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            maxLength: 8,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              hintText: 'Enter OTP',
            ),
          ),
        ),
        const SizedBox(height: 12),
        _FieldShell(
          child: TextField(
            controller: _nameCtrl,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Your name (optional)',
            ),
          ),
        ),
        const SizedBox(height: 24),
        _PrimaryButton(label: 'Verify & Continue', busy: _busy, onTap: _verifyOtp),
        const SizedBox(height: 12),
        Center(
          child: _resendIn > 0
              ? Text('Resend OTP in $_resendIn s',
                  style: const TextStyle(color: Color(0xff999999), fontSize: 13))
              : TextButton(
                  onPressed: _busy ? null : _requestOtp,
                  child: const Text('Resend OTP',
                      style: TextStyle(color: OtpLoginScreen._primary)),
                ),
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _otpSent = false;
              _error = null;
              _otpCtrl.clear();
            }),
            child: const Text('Change number',
                style: TextStyle(color: Color(0xff777777))),
          ),
        ),
      ];
}

class _FieldShell extends StatelessWidget {
  const _FieldShell({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xffF6F2FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xffEADBF2)),
      ),
      child: child,
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onTap, this.busy = false});
  final String label;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: OtpLoginScreen._primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: busy
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Text(label,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
