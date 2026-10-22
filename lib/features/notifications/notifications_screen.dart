import 'package:bringo/core/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      appBar: AppBar(
        title: const Text('الإشعارات'),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.dark,
        elevation: 0,
      ),
      body: Center(
        child: Text(
          'لا توجد إشعارات حالياً',
          style: TextStyle(
            fontSize: 16.sp,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
