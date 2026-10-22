import 'dart:async';

import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/core/services/auth_db_services.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthDbService _authService = AuthDbService();

  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      if (_authService.isLoggedIn) {
        context.go(AppRoutes.mainLayout);
      } else {
        context.go(AppRoutes.onboarding);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: SizedBox.expand(
        child: Image(
          image: AssetImage(
            'assets/images/splash.png',
          ),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
