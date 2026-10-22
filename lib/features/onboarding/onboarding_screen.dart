import 'package:bringo/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color background = Color(0xFFF7FAF8);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);

  final PageController _controller = PageController();

  int _currentPage = 0;

  final List<_OnboardingData> pages = const [
    _OnboardingData(
      image: 'assets/images/on2.png',
      smallTitle: 'من مدينتك إلى بابك',
      title: 'كل مدينتك..\nفي تطبيق واحد',
      description:
          'مطاعمك، السوبر ماركت، الصيدليات والمتاجر اللي بتحبها أقرب ليك من أي وقت.',
    ),
    _OnboardingData(
      image: 'assets/images/on1.png',
      smallTitle: 'Bringo يوصلها',
      title: 'اطلب..\nوسيب الباقي علينا',
      description:
          'اختار اللي محتاجه، وإحنا نهتم بتجهيز طلبك وتوصيله لحد بابك.',
    ),
    _OnboardingData(
      image: 'assets/images/on3.png',
      smallTitle: 'متابعة واضحة',
      title: 'طلبك\nقدام عينك',
      description: 'تابع حالة طلبك من لحظة تأكيده لحد ما يوصل إليك.',
    ),
  ];

  bool get isLastPage => _currentPage == pages.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _skip() {
    HapticFeedback.lightImpact();
    context.go(AppRoutes.login);
  }

  Future<void> _next() async {
    HapticFeedback.selectionClick();

    if (isLastPage) {
      context.go(AppRoutes.login);
      return;
    }

    await _controller.nextPage(
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return _OnboardingPage(
                      data: pages[index],
                      isActive: _currentPage == index,
                    );
                  },
                ),
              ),
              _bottomArea(),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        12.h,
        20.w,
        4.h,
      ),
      child: Row(
        textDirection: TextDirection.ltr,
        children: [
          Row(
            children: [
              const _BringoMark(size: 34),
              SizedBox(width: 7.w),
              Text(
                'Bringo',
                style: TextStyle(
                  color: darkTeal,
                  fontSize: 20.sp,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: isLastPage ? 0 : 1,
            child: IgnorePointer(
              ignoring: isLastPage,
              child: TextButton(
                onPressed: _skip,
                style: TextButton.styleFrom(
                  foregroundColor: darkTeal,
                  padding: EdgeInsets.symmetric(
                    horizontal: 8.w,
                    vertical: 5.h,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  'تخطي',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // BOTTOM
  // ─────────────────────────────────────────────

  Widget _bottomArea() {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20.w,
        6.h,
        20.w,
        18.h,
      ),
      child: Column(
        children: [
          _indicators(),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            height: 58.h,
            child: ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: teal,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18.r),
                ),
              ),
              child: Row(
                textDirection: TextDirection.ltr,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 42.w,
                    height: 42.w,
                    decoration: const BoxDecoration(
                      color: lime,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isLastPage
                          ? Icons.check_rounded
                          : Icons.arrow_back_rounded,
                      color: darkTeal,
                      size: 22.sp,
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: Text(
                        isLastPage ? 'يلا نبدأ' : 'التالي',
                        key: ValueKey(isLastPage),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 42.w),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _indicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.ltr,
      children: List.generate(
        pages.length,
        (index) {
          final active = _currentPage == index;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            margin: EdgeInsets.symmetric(horizontal: 4.w),
            width: active ? 25.w : 7.w,
            height: 7.h,
            decoration: BoxDecoration(
              color: active ? lime : teal.withOpacity(.15),
              borderRadius: BorderRadius.circular(20.r),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────

class _OnboardingPage extends StatelessWidget {
  final _OnboardingData data;
  final bool isActive;

  const _OnboardingPage({
    required this.data,
    required this.isActive,
  });

  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color textGrey = Color(0xFF77817F);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final visualHeight = (constraints.maxHeight * .60).clamp(300.0, 480.0);

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: 18.w),
          child: Column(
            children: [
              SizedBox(height: 6.h),
              Expanded(
                child: Center(
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 550),
                    curve: Curves.easeOutCubic,
                    scale: isActive ? 1 : .96,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 350),
                      opacity: isActive ? 1 : .75,
                      child: _heroVisual(
                        visualHeight.toDouble(),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              AnimatedSlide(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                offset: isActive ? Offset.zero : const Offset(0, .08),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 420),
                  opacity: isActive ? 1 : 0,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 18.w,
                            height: 3.h,
                            decoration: BoxDecoration(
                              color: lime,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                          ),
                          SizedBox(width: 7.w),
                          Text(
                            data.smallTitle,
                            style: TextStyle(
                              color: teal,
                              fontSize: 10.5.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(width: 7.w),
                          Container(
                            width: 18.w,
                            height: 3.h,
                            decoration: BoxDecoration(
                              color: lime,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        data.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 28.sp,
                          height: 1.17,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -.4,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                        ),
                        child: Text(
                          data.description,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textGrey,
                            fontSize: 12.5.sp,
                            height: 1.65,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8.h),
            ],
          ),
        );
      },
    );
  }

  Widget _heroVisual(double height) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxHeight: height,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32.r),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32.r),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFEAF6F3),
                    Color(0xFFF7FAF8),
                  ],
                ),
              ),
            ),
          ),

          // Decorative glow
          Positioned(
            top: 20.h,
            right: -25.w,
            child: Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: lime.withOpacity(.18),
              ),
            ),
          ),

          Positioned(
            left: -35.w,
            bottom: 15.h,
            child: Container(
              width: 130.w,
              height: 130.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: teal.withOpacity(.07),
              ),
            ),
          ),

          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.all(5.w),
              child: Image.asset(
                data.image,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) {
                  return _fallback();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallback() {
    return Center(
      child: Container(
        width: 160.w,
        height: 160.w,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: teal.withOpacity(.08),
          ),
        ),
        child: Icon(
          Icons.delivery_dining_rounded,
          size: 72.sp,
          color: teal,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// LOGO
// ─────────────────────────────────────────────

class _BringoMark extends StatelessWidget {
  final double size;

  const _BringoMark({
    this.size = 34,
  });

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF1F5A59);
    const lime = Color(0xFFDDFB8A);

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
                color: teal,
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
                color: teal,
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
                  color: lime,
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

// ─────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────

class _OnboardingData {
  final String image;
  final String smallTitle;
  final String title;
  final String description;

  const _OnboardingData({
    required this.image,
    required this.smallTitle,
    required this.title,
    required this.description,
  });
}
