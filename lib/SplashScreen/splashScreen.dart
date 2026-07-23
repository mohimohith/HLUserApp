import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../Auth/loginScreen.dart';
import '../BottomNav/bottomNavScreen.dart';
import '../compat/app_state.dart';
import '../core/session/session_manager.dart';
import '../data/repositories/repositories.dart';
import '../utils/colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();

    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: AppColors.primaryColor,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.primaryColor,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));

    Timer(const Duration(seconds: 3), checkLogin);
  }

  Future<void> checkLogin() async {
    final authed = SessionManager.instance.isAuthenticated.value;
    if (!authed) {
      _go(const LoginScreen());
      return;
    }

    // Resolve the branch to serve + warm the home cache so the first frame of
    // the shell has delivery-time / brand data ready.
    try {
      final branch = await Repos.branches.resolveActiveBranch();
      AppState.setBranch(branch?.id);
    } catch (_) {
      AppState.setBranch(SessionManager.instance.branchId);
    }
    _go(const BottomNavScreen());
  }

  void _go(Widget screen) {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(color: AppColors.backgroundColor),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                "assets/images/logo.png",
                width: 250,
                height: 250,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
