import 'package:bringo/core/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/routing/app_router.dart';

class BringoApp extends StatelessWidget {
  const BringoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, child) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: 'Bringo',
          routerConfig: AppRouter.router,
          theme: ThemeData(
            scaffoldBackgroundColor: AppColors.white,
            primaryColor: AppColors.primary,
            textTheme: GoogleFonts.cairoTextTheme(),
            colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.primary,
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: AppColors.white,
              elevation: 0,
              centerTitle: true,
              iconTheme: IconThemeData(color: AppColors.dark),
            ),
          ),
        );
      },
    );
  }
}
