import 'package:flutter/material.dart';

import '../../core/session/session_manager.dart';
import '../../data/repositories/repositories.dart';
import '../auth/otp_login_screen.dart';
import 'app_shell.dart';

/// Branded launch gate. The session is already restored in `main()`; this shows
/// a brief splash, warms the active branch, then routes to the app shell (when
/// signed in) or the OTP login.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  static const Color _primary = Color(0xff960ad7);

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    final authed = SessionManager.instance.isAuthenticated.value;
    // Pre-resolve a branch so the home screen has one ready either way.
    try {
      await Repos.branches.resolveActiveBranch();
    } catch (_) {
      // Non-fatal; the home controller will retry/surface the error.
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => authed ? const AppShell() : const OtpLoginScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppGate._primary,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.storefront_rounded, color: Colors.white, size: 72),
            SizedBox(height: 16),
            Text('NexaMart',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5)),
            SizedBox(height: 24),
            SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
