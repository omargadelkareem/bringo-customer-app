import 'package:bringo/core/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Color _bg = Colors.white;
  static const Color _ink = Color(0xFF182322);
  static const Color _muted = Color(0xFF7B8381);
  static const Color _line = Color(0xFFEEEEEC);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(
              Icons.arrow_forward_ios_rounded,
              color: _ink,
              size: 19.sp,
            ),
          ),
          title: Text(
            'الإشعارات',
            style: TextStyle(
              color: _ink,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1.h),
            child: const Divider(height: 1, thickness: 1, color: _line),
          ),
        ),
        body: SafeArea(
          top: false,
          child: _emptyState(),
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
              size: 48.sp,
            ),
            SizedBox(height: 14.h),
            Text(
              'لا توجد إشعارات',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'أي تحديث يخص طلباتك هيظهر هنا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12.sp,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
