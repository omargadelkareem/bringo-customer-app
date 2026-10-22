import 'package:bringo/core/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const Color _bg = Color(0xFFF7FAF8);
  static const Color _ink = Color(0xFF182322);
  static const Color _muted = Color(0xFF77817F);
  static const Color _line = Color(0xFFE4EAE8);
  static const Color _lime = Color(0xFFDDFB8A);

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        appBar: AppBar(
          toolbarHeight: 70.h,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: _bg,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leadingWidth: 66.w,
          leading: Padding(
            padding: EdgeInsets.only(right: 16.w),
            child: Center(
              child: InkWell(
                onTap: () => Navigator.maybePop(context),
                borderRadius: BorderRadius.circular(50.r),
                child: Container(
                  width: 42.w,
                  height: 42.w,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: _line),
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                    size: 21.sp,
                  ),
                ),
              ),
            ),
          ),
          title: Text(
            'الإشعارات',
            style: TextStyle(
              color: _ink,
              fontSize: 19.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 36.h),
            children: [
              _hero(),
              SizedBox(height: 28.h),
              Text(
                'آخر التحديثات',
                style: TextStyle(
                  color: _ink,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 12.h),
              _emptyState(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(26.r),
      ),
      child: Stack(
        children: [
          Positioned(
            left: -55.w,
            top: -65.h,
            child: Container(
              width: 170.w,
              height: 170.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _lime.withOpacity(.08),
              ),
            ),
          ),
          Positioned(
            right: -65.w,
            bottom: -85.h,
            child: Container(
              width: 190.w,
              height: 190.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: _lime.withOpacity(.12),
                  width: 22.w,
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(21.w),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'كل جديد يوصلك هنا',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 7.h),
                      Text(
                        'حالة طلباتك، عروض المتاجر وأهم تحديثات Bringo في مكان واحد.',
                        style: TextStyle(
                          color: Colors.white.withOpacity(.78),
                          fontSize: 11.5.sp,
                          height: 1.6,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Container(
                  width: 62.w,
                  height: 62.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(.10),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: _lime,
                    size: 31.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 42.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          Container(
            width: 82.w,
            height: 82.w,
            decoration: const BoxDecoration(
              color: Color(0xFFEAF3F2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: AppColors.primary,
              size: 38.sp,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            'أنت متابع كل حاجة',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ink,
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            'مفيش إشعارات جديدة دلوقتي. أول ما يحصل تحديث في طلبك أو يكون فيه حاجة مهمة هتظهر هنا.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _muted,
              fontSize: 12.sp,
              height: 1.65,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
