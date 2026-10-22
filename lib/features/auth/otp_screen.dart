import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const Color _bg = Color(0xFFF7FAF8);
  static const Color _ink = Color(0xFF182322);
  static const Color _muted = Color(0xFF77817F);
  static const Color _line = Color(0xFFE4EAE8);
  static const Color _lime = Color(0xFFDDFB8A);

  final controllers = List.generate(4, (_) => TextEditingController());
  final nodes = List.generate(4, (_) => FocusNode());

  @override
  void dispose() {
    for (final controller in controllers) {
      controller.dispose();
    }
    for (final node in nodes) {
      node.dispose();
    }
    super.dispose();
  }

  bool get _complete => controllers.every((e) => e.text.trim().isNotEmpty);

  void _verify() {
    FocusScope.of(context).unfocus();
    if (!_complete) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('اكتب كود التحقق كاملًا', textAlign: TextAlign.right),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
          ),
        );
      return;
    }
    HapticFeedback.mediumImpact();
    context.go(AppRoutes.mainLayout);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _bg,
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 30.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => Navigator.maybePop(context),
                    borderRadius: BorderRadius.circular(50.r),
                    child: Container(
                      width: 44.w,
                      height: 44.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _line),
                      ),
                      child: Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 21.sp),
                    ),
                  ),
                ),
                SizedBox(height: 32.h),
                Center(
                  child: Container(
                    width: 88.w,
                    height: 88.w,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(28.r),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(.16),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.phone_android_rounded, color: Colors.white, size: 38.sp),
                        Positioned(
                          left: 12.w,
                          top: 12.h,
                          child: Container(
                            width: 20.w,
                            height: 20.w,
                            decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
                            child: Icon(Icons.check_rounded, color: AppColors.primary, size: 13.sp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 27.h),
                Text(
                  'تأكيد رقم الهاتف',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _ink, fontSize: 25.sp, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 8.h),
                Text(
                  'اكتب كود التحقق المكوّن من 4 أرقام\nاللي اتبعت على رقمك',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _muted, fontSize: 12.5.sp, height: 1.65, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 34.h),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (index) {
                      return Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5.w),
                        child: SizedBox(
                          width: 62.w,
                          height: 66.h,
                          child: TextField(
                            controller: controllers[index],
                            focusNode: nodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            maxLength: 1,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            style: TextStyle(color: _ink, fontSize: 23.sp, fontWeight: FontWeight.w900),
                            onChanged: (value) {
                              setState(() {});
                              if (value.isNotEmpty && index < nodes.length - 1) {
                                nodes[index + 1].requestFocus();
                              } else if (value.isEmpty && index > 0) {
                                nodes[index - 1].requestFocus();
                              }
                            },
                            decoration: InputDecoration(
                              counterText: '',
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.zero,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18.r),
                                borderSide: BorderSide(color: controllers[index].text.isEmpty ? _line : AppColors.primary, width: controllers[index].text.isEmpty ? 1 : 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(18.r),
                                borderSide: const BorderSide(color: AppColors.primary, width: 1.7),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                SizedBox(height: 31.h),
                SizedBox(
                  height: 56.h,
                  child: ElevatedButton(
                    onPressed: _verify,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('تأكيد ومتابعة', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)),
                        SizedBox(width: 10.w),
                        Container(
                          width: 31.w,
                          height: 31.w,
                          decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle),
                          child: Icon(Icons.arrow_back_rounded, color: AppColors.primary, size: 18.sp),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('ماوصلكش الكود؟', style: TextStyle(color: _muted, fontSize: 12.sp, fontWeight: FontWeight.w600)),
                    TextButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            SnackBar(
                              content: const Text('تم طلب إرسال كود جديد', textAlign: TextAlign.right),
                              behavior: SnackBarBehavior.floating,
                              backgroundColor: AppColors.primary,
                            ),
                          );
                      },
                      child: Text('إعادة الإرسال', style: TextStyle(color: AppColors.primary, fontSize: 12.sp, fontWeight: FontWeight.w900)),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                Container(
                  padding: EdgeInsets.all(15.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3F2),
                    borderRadius: BorderRadius.circular(17.r),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline_rounded, color: AppColors.primary, size: 20.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          'الكود ده لحماية حسابك. متشاركهوش مع أي شخص.',
                          style: TextStyle(color: _muted, fontSize: 10.5.sp, height: 1.5, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
