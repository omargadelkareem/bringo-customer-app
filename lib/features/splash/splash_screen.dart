import 'dart:async';

import 'package:bringo/core/routing/app_routes.dart';
import 'package:get_storage/get_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final GetStorage _box = GetStorage();

  @override
  void initState() {
    super.initState();

    Timer(const Duration(seconds: 2), () {
      if (!mounted) return;

      final seenOnboarding = _box.read('onboardingCompleted') == true;
      context.go(seenOnboarding ? AppRoutes.mainLayout : AppRoutes.onboarding);
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
