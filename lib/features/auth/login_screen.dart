import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/core/services/auth_db_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthDbService authService = AuthDbService();

  bool isLoading = false;
  bool obscurePassword = true;

  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF164846);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color background = Color(0xFFF7FAF8);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);

  Future<void> login() async {
    FocusScope.of(context).unfocus();

    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      showMessage('اكتب رقم الهاتف وكلمة المرور');
      return;
    }

    if (phone.length < 10) {
      showMessage('تأكد من رقم الهاتف');
      return;
    }

    try {
      setState(() => isLoading = true);

      await authService.login(
        phone: phone,
        password: password,
      );

      if (!mounted) return;

      context.go(AppRoutes.mainLayout);
    } catch (e) {
      showMessage(
        e.toString().replaceAll('Exception:', '').trim(),
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.right,
          ),
          backgroundColor: darkTeal,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
        ),
      );
  }

  @override
  void dispose() {
    phoneController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      body: Stack(
        children: [
          // Decorative background
          Positioned(
            top: -90.h,
            left: -80.w,
            child: Container(
              width: 230.w,
              height: 230.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lime.withOpacity(.18),
              ),
            ),
          ),

          Positioned(
            right: -100.w,
            top: 170.h,
            child: Container(
              width: 210.w,
              height: 210.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: teal.withOpacity(.045),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                22.w,
                20.h,
                22.w,
                30.h,
              ),
              child: Column(
                children: [
                  _brandHeader(),
                  SizedBox(height: 34.h),
                  _welcomeSection(),
                  SizedBox(height: 30.h),
                  _loginForm(),
                  SizedBox(height: 25.h),
                  _createAccount(),
                  SizedBox(height: 30.h),
                  _footer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BRAND
  // ─────────────────────────────────────────────

  Widget _brandHeader() {
    return Column(
      children: [
        SizedBox(height: 12.h),
        const _BringoLogo(),
        SizedBox(height: 14.h),
        Text(
          'Bringo',
          style: TextStyle(
            color: darkTeal,
            fontSize: 34.sp,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -.8,
          ),
        ),
        SizedBox(height: 9.h),
        Text(
          'كل اللي تحتاجه .. نوصله لك',
          style: TextStyle(
            color: textGrey,
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 25.h),
        _servicesRow(),
      ],
    );
  }

  Widget _servicesRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _service(
          Icons.storefront_outlined,
          'متاجر',
        ),
        SizedBox(width: 22.w),
        _service(
          Icons.medication_outlined,
          'صيدليات',
        ),
        SizedBox(width: 22.w),
        _service(
          Icons.restaurant_outlined,
          'مطاعم',
        ),
        SizedBox(width: 22.w),
        _service(
          Icons.shopping_cart_outlined,
          'سوبر ماركت',
        ),
      ],
    );
  }

  Widget _service(IconData icon, String title) {
    return Column(
      children: [
        Container(
          width: 43.w,
          height: 43.w,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(
              color: teal.withOpacity(.09),
            ),
          ),
          child: Icon(
            icon,
            size: 20.sp,
            color: teal,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          title,
          style: TextStyle(
            fontSize: 9.5.sp,
            color: textGrey,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // WELCOME
  // ─────────────────────────────────────────────

  Widget _welcomeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'اهلا بيك  ',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: textDark,
            fontSize: 26.sp,
            height: 1.25,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 7.h),
        Text(
          'سجل دخولك واطلب احتياجاتك من الأماكن اللي بتحبها.',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: textGrey,
            fontSize: 13.sp,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────
  // LOGIN
  // ─────────────────────────────────────────────

  Widget _loginForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _fieldTitle('رقم الهاتف'),
        SizedBox(height: 8.h),
        _input(
          controller: phoneController,
          hint: '01xxxxxxxxx',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        SizedBox(height: 19.h),
        _fieldTitle('كلمة المرور'),
        SizedBox(height: 8.h),
        _input(
          controller: passwordController,
          hint: 'أدخل كلمة المرور',
          icon: Icons.lock_outline_rounded,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!isLoading) login();
          },
          suffix: IconButton(
            splashRadius: 20.r,
            onPressed: () {
              setState(() {
                obscurePassword = !obscurePassword;
              });
            },
            icon: Icon(
              obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: const Color(0xFF87928F),
              size: 21.sp,
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'تسجيل الدخول إلى حسابك',
            style: TextStyle(
              color: teal,
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: 25.h),
        _loginButton(),
      ],
    );
  }

  Widget _fieldTitle(String title) {
    return Text(
      title,
      textAlign: TextAlign.right,
      style: TextStyle(
        color: textDark,
        fontSize: 12.5.sp,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  Widget _input({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onSubmitted,
    Widget? suffix,
  }) {
    return Container(
      height: 58.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: const Color(0xFFE3E9E7),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        inputFormatters: inputFormatters,
        onSubmitted: onSubmitted,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: textDark,
          fontSize: 14.sp,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: const Color(0xFFADB5B3),
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 15.w,
            vertical: 17.h,
          ),
          prefixIcon: suffix,
          suffixIcon: Padding(
            padding: EdgeInsets.symmetric(horizontal: 13.w),
            child: Icon(
              icon,
              color: teal,
              size: 22.sp,
            ),
          ),
          prefixIconConstraints: BoxConstraints(
            minWidth: 48.w,
          ),
          suffixIconConstraints: BoxConstraints(
            minWidth: 48.w,
          ),
        ),
      ),
    );
  }

  Widget _loginButton() {
    return SizedBox(
      width: double.infinity,
      height: 58.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : login,
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          disabledBackgroundColor: teal.withOpacity(.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17.r),
          ),
        ),
        child: isLoading
            ? SizedBox(
                width: 23.w,
                height: 23.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                children: [
                  Container(
                    width: 42.w,
                    height: 42.w,
                    decoration: const BoxDecoration(
                      color: lime,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.arrow_back_rounded,
                      color: darkTeal,
                      size: 22.sp,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'تسجيل الدخول',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  SizedBox(width: 42.w),
                ],
              ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // REGISTER
  // ─────────────────────────────────────────────

  Widget _createAccount() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.rtl,
      children: [
        Text(
          'ليس لديك حساب؟',
          style: TextStyle(
            color: textGrey,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextButton(
          onPressed: () => context.push(AppRoutes.register),
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'إنشاء حساب جديد',
            style: TextStyle(
              color: teal,
              fontSize: 12.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _footer() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 5.w,
          height: 5.w,
          decoration: const BoxDecoration(
            color: lime,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 7.w),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// BRINGO TEMPORARY VECTOR LOGO
// Replace only this widget with Image.asset when logo PNG is ready.
// ─────────────────────────────────────────────

class _BringoLogo extends StatelessWidget {
  const _BringoLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88.w,
      height: 88.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 20.w,
            top: 8.h,
            child: Container(
              width: 24.w,
              height: 65.h,
              decoration: BoxDecoration(
                color: _LoginScreenState.teal,
                borderRadius: BorderRadius.circular(15.r),
              ),
            ),
          ),
          Positioned(
            right: 9.w,
            bottom: 9.h,
            child: Container(
              width: 58.w,
              height: 58.w,
              decoration: const BoxDecoration(
                color: _LoginScreenState.teal,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: 27.w,
            bottom: 18.h,
            child: Transform.rotate(
              angle: -.60,
              child: Container(
                width: 43.w,
                height: 25.h,
                decoration: BoxDecoration(
                  color: _LoginScreenState.lime,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30.r),
                    bottomRight: Radius.circular(30.r),
                    topRight: Radius.circular(9.r),
                    bottomLeft: Radius.circular(9.r),
                  ),
                  border: Border.all(
                    color: Colors.white,
                    width: 6.w,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
