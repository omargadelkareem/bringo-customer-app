import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/core/services/adress_services.dart';
import 'package:bringo/core/services/auth_db_services.dart';
import 'package:bringo/core/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final passwordController = TextEditingController();

  final AuthDbService authService = AuthDbService();

  bool isLoading = false;
  bool obscurePassword = true;

  bool isGettingLocation = false;
  bool locationDetected = false;

  String detectedAddress = '';
  double? latitude;
  double? longitude;

  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color background = Color(0xFFF7FAF8);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);
  static const Color border = Color(0xFFE2E9E7);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _detectLocation();
    });
  }

  Future<void> _detectLocation() async {
    if (isGettingLocation) return;

    setState(() {
      isGettingLocation = true;
    });

    try {
      final position = await LocationService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 18));

      if (position == null) {
        throw Exception('تعذر تحديد الموقع');
      }

      // Location package returns nullable coordinates
      final double? lat = position.latitude;
      final double? lng = position.longitude;

      // نتأكد إن الإحداثيات موجودة فعلاً
      if (lat == null || lng == null) {
        throw Exception('تعذر الحصول على إحداثيات الموقع');
      }

      // بعد الـ null check Dart عارف إنهم double
      latitude = lat;
      longitude = lng;

      final address = await AddressService.getAreaName(
        lat,
        lng,
      ).timeout(
        const Duration(seconds: 10),
      );

      if (!mounted) return;

      setState(() {
        detectedAddress = address;
        locationDetected = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        latitude = null;
        longitude = null;
        detectedAddress = '';
        locationDetected = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          isGettingLocation = false;
        });
      }
    }
  }

  Future<void> register() async {
    FocusScope.of(context).unfocus();

    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();

    if (name.isEmpty || phone.isEmpty || password.isEmpty) {
      showMessage('من فضلك املأ البيانات المطلوبة');
      return;
    }

    if (name.length < 3) {
      showMessage('اكتب الاسم بشكل صحيح');
      return;
    }

    if (!RegExp(r'^01[0125][0-9]{8}$').hasMatch(phone)) {
      showMessage('اكتب رقم هاتف مصري صحيح');
      return;
    }

    if (password.length < 6) {
      showMessage('كلمة المرور يجب ألا تقل عن 6 أحرف');
      return;
    }

    try {
      setState(() => isLoading = true);

      await authService.register(
        name: name,
        phone: phone,

        // نحافظ على نفس AuthDbService الحالي
        // بدون كسر الـregister method.
        address: locationDetected ? detectedAddress : 'يتم تحديده عند الطلب',

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
    nameController.dispose();
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
          _backgroundDecorations(),
          SafeArea(
            child: Column(
              children: [
                _topBar(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      22.w,
                      8.h,
                      22.w,
                      32.h,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _brand(),
                        SizedBox(height: 30.h),
                        _heading(),
                        SizedBox(height: 27.h),
                        _form(),
                        SizedBox(height: 22.h),
                        _locationCard(),
                        SizedBox(height: 26.h),
                        _registerButton(),
                        SizedBox(height: 21.h),
                        _loginLink(),
                        SizedBox(height: 28.h),
                        _privacyText(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _backgroundDecorations() {
    return Stack(
      children: [
        Positioned(
          top: -90.h,
          right: -90.w,
          child: Container(
            width: 220.w,
            height: 220.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: lime.withOpacity(.16),
            ),
          ),
        ),
        Positioned(
          left: -100.w,
          top: 310.h,
          child: Container(
            width: 210.w,
            height: 210.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: teal.withOpacity(.04),
            ),
          ),
        ),
      ],
    );
  }

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        12.w,
        8.h,
        12.w,
        0,
      ),
      child: Row(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(50.r),
              onTap: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go(AppRoutes.login);
                }
              },
              child: Padding(
                padding: EdgeInsets.all(10.w),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: darkTeal,
                  size: 19.sp,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brand() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Bringo',
              style: TextStyle(
                color: darkTeal,
                fontSize: 23.sp,
                height: 1,
                fontWeight: FontWeight.w900,
                letterSpacing: -.5,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              'من مدينتك إلى بابك',
              style: TextStyle(
                color: textGrey,
                fontSize: 10.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(width: 11.w),
        const _BringoMark(
          size: 54,
        ),
      ],
    );
  }

  Widget _heading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          'خلّينا نتعرف عليك',
          textAlign: TextAlign.right,
          style: TextStyle(
            color: textDark,
            fontSize: 27.sp,
            height: 1.25,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          'أنشئ حسابك في ثواني، وسيب علينا الباقي.',
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

  Widget _form() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _label('الاسم'),
        SizedBox(height: 8.h),
        _input(
          controller: nameController,
          hint: 'اسمك بالكامل',
          icon: Icons.person_outline_rounded,
          textInputAction: TextInputAction.next,
        ),
        SizedBox(height: 18.h),
        _label('رقم الهاتف'),
        SizedBox(height: 8.h),
        _input(
          controller: phoneController,
          hint: '01xxxxxxxxx',
          icon: Icons.phone_outlined,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(11),
          ],
        ),
        SizedBox(height: 18.h),
        _label('كلمة المرور'),
        SizedBox(height: 8.h),
        _input(
          controller: passwordController,
          hint: '6 أحرف على الأقل',
          icon: Icons.lock_outline_rounded,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) {
            if (!isLoading) {
              register();
            }
          },
          prefix: IconButton(
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
      ],
    );
  }

  Widget _label(String value) {
    return Text(
      value,
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
    Widget? prefix,
  }) {
    return Container(
      height: 58.h,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: border,
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
            color: const Color(0xFFAAB3B1),
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 15.w,
            vertical: 17.h,
          ),

          // في RTL: ده يظهر ناحية اليسار
          prefixIcon: prefix,

          // الأيقونة الرئيسية ناحية اليمين
          suffixIcon: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 13.w,
            ),
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

  // ───────────────────────────────────────────
  // LOCATION
  // ───────────────────────────────────────────

  Widget _locationCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: locationDetected ? const Color(0xFFEDF5F2) : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: locationDetected ? teal.withOpacity(.13) : border,
        ),
      ),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 43.w,
            height: 43.w,
            decoration: BoxDecoration(
              color: locationDetected ? teal : const Color(0xFFF0F4F2),
              shape: BoxShape.circle,
            ),
            child: isGettingLocation
                ? Padding(
                    padding: EdgeInsets.all(12.w),
                    child: const CircularProgressIndicator(
                      strokeWidth: 2,
                      color: teal,
                    ),
                  )
                : Icon(
                    locationDetected
                        ? Icons.location_on_rounded
                        : Icons.location_searching_rounded,
                    color: locationDetected ? lime : teal,
                    size: 22.sp,
                  ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  isGettingLocation
                      ? 'بنحدد موقعك...'
                      : locationDetected
                          ? 'تم تحديد موقعك'
                          : 'تحديد موقعك',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: textDark,
                    fontSize: 12.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  isGettingLocation
                      ? 'ثواني ونحدد منطقتك تلقائيًا'
                      : locationDetected
                          ? detectedAddress
                          : 'هنستخدم موقعك لتسهيل التوصيل',
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 10.5.sp,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (!isGettingLocation && !locationDetected)
            TextButton(
              onPressed: _detectLocation,
              child: Text(
                'تحديد',
                style: TextStyle(
                  color: teal,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          if (locationDetected)
            Icon(
              Icons.check_circle_rounded,
              color: teal,
              size: 21.sp,
            ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  // BUTTON
  // ───────────────────────────────────────────

  Widget _registerButton() {
    return SizedBox(
      width: double.infinity,
      height: 58.h,
      child: ElevatedButton(
        onPressed: isLoading ? null : register,
        style: ElevatedButton.styleFrom(
          backgroundColor: teal,
          disabledBackgroundColor: teal.withOpacity(.55),
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
                      'إنشاء الحساب',
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

  Widget _loginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.rtl,
      children: [
        Text(
          'لديك حساب بالفعل؟',
          style: TextStyle(
            color: textGrey,
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        TextButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(AppRoutes.login);
            }
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.symmetric(horizontal: 6.w),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'تسجيل الدخول',
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

  Widget _privacyText() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_outlined,
              color: teal.withOpacity(.75),
              size: 15.sp,
            ),
            SizedBox(width: 5.w),
            Text(
              'بياناتك وموقعك بنستخدمهم لخدمة طلباتك',
              style: TextStyle(
                color: const Color(0xFF919B99),
                fontSize: 9.5.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        SizedBox(height: 7.h),
        Text(
          'بإنشاء الحساب أنت توافق على الشروط وسياسة الخصوصية',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: const Color(0xFFA4ACAA),
            fontSize: 9.sp,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// BRINGO MARK
// نفس هوية الـ Login
// ─────────────────────────────────────────────

class _BringoMark extends StatelessWidget {
  final double size;

  const _BringoMark({
    this.size = 70,
  });

  @override
  Widget build(BuildContext context) {
    final s = size.w;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: s * .23,
            top: s * .08,
            child: Container(
              width: s * .26,
              height: s * .72,
              decoration: BoxDecoration(
                color: _RegisterScreenState.teal,
                borderRadius: BorderRadius.circular(s * .17),
              ),
            ),
          ),
          Positioned(
            right: s * .08,
            bottom: s * .08,
            child: Container(
              width: s * .65,
              height: s * .65,
              decoration: const BoxDecoration(
                color: _RegisterScreenState.teal,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: s * .30,
            bottom: s * .19,
            child: Transform.rotate(
              angle: -.60,
              child: Container(
                width: s * .49,
                height: s * .29,
                decoration: BoxDecoration(
                  color: _RegisterScreenState.lime,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(s * .30),
                    bottomRight: Radius.circular(s * .30),
                    topRight: Radius.circular(s * .10),
                    bottomLeft: Radius.circular(s * .10),
                  ),
                  border: Border.all(
                    color: Colors.white,
                    width: s * .065,
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
