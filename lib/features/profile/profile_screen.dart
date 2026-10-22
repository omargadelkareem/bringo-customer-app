import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/features/orders/my_orders_screen.dart';
import 'package:bringo/features/profile/profile_pages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends StatelessWidget {
  ProfileScreen({super.key});

  final GetStorage box = GetStorage();

  @override
  Widget build(BuildContext context) {
    final name = box.read('userName')?.toString().trim() ?? '';
    final phone = box.read('phone')?.toString().trim() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.only(bottom: 110.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _topBar(),
              SizedBox(height: 10.h),
              _profileHeader(
                context,
                name.isEmpty ? 'عميل Bringo' : name,
                phone,
              ),
              SizedBox(height: 28.h),
              _sectionLabel('الحساب'),
              _menuGroup(
                context,
                items: [
                  const _ProfileItem(
                    icon: Icons.person_outline_rounded,
                    title: 'بياناتي الشخصية',
                    page: PersonalInfoScreen(),
                  ),
                  const _ProfileItem(
                    icon: Icons.location_on_outlined,
                    title: 'عناويني',
                    page: AddressesScreen(),
                  ),
                ],
              ),
              SizedBox(height: 26.h),
              _sectionLabel('الطلبات والتوصيل'),
              _menuGroup(
                context,
                items: [
                  const _ProfileItem(
                    icon: Icons.receipt_long_outlined,
                    title: 'طلباتي',
                    page: MyOrdersScreen(),
                  ),
                ],
              ),
              SizedBox(height: 26.h),
              _sectionLabel('المساعدة'),
              _menuGroup(
                context,
                items: [
                  const _ProfileItem(
                    icon: Icons.headset_mic_outlined,
                    title: 'الدعم والمساعدة',
                    page: SupportScreen(),
                  ),
                  const _ProfileItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'سياسة الخصوصية',
                    page: PrivacyPolicyScreen(),
                  ),
                  const _ProfileItem(
                    icon: Icons.description_outlined,
                    title: 'الشروط والأحكام',
                    page: TermsAndConditionsScreen(),
                  ),
                  const _ProfileItem(
                    icon: Icons.info_outline_rounded,
                    title: 'عن Bringo',
                    page: AboutBringoScreen(),
                  ),
                ],
              ),
              SizedBox(height: 30.h),
              _logout(context),
              SizedBox(height: 22.h),
              Center(
                child: Text(
                  'Bringo  •  v1.0.0',
                  style: TextStyle(
                    color: const Color(0xFF98A3A3),
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 18.h, 20.w, 8.h),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'حسابي',
          style: TextStyle(
            color: const Color(0xFF172323),
            fontSize: 24.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _profileHeader(
    BuildContext context,
    String name,
    String phone,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 68.w,
            height: 68.w,
            decoration: BoxDecoration(
              color: const Color(0xFFE8F2F0),
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withOpacity(.10),
              ),
            ),
            child: Icon(
              Icons.person_rounded,
              color: AppColors.primary,
              size: 34.sp,
            ),
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFF172323),
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (phone.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    phone,
                    textDirection: TextDirection.ltr,
                    style: TextStyle(
                      color: const Color(0xFF788383),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: 8.h),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PersonalInfoScreen(),
                      ),
                    );
                  },
                  child: Text(
                    'تعديل الحساب',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
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

  Widget _sectionLabel(String title) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 10.h),
      child: Text(
        title,
        textAlign: TextAlign.right,
        style: TextStyle(
          color: const Color(0xFF7D8988),
          fontSize: 11.5.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _menuGroup(
    BuildContext context, {
    required List<_ProfileItem> items,
  }) {
    return Container(
      color: Colors.white,
      child: Column(
        children: List.generate(items.length, (index) {
          final item = items[index];

          return Column(
            children: [
              _menuItem(
                context,
                icon: item.icon,
                title: item.title,
                page: item.page,
              ),
              if (index != items.length - 1)
                Padding(
                  padding: EdgeInsets.only(
                    right: 68.w,
                    left: 20.w,
                  ),
                  child: const Divider(
                    height: 1,
                    thickness: .7,
                    color: Color(0xFFEDF0EF),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _menuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required Widget page,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => page),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 17.h,
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                icon,
                color: AppColors.primary,
                size: 23.sp,
              ),
              SizedBox(width: 15.w),
              Expanded(
                child: Text(
                  title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: const Color(0xFF263130),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              Icon(
                Icons.arrow_back_ios_new_rounded,
                color: const Color(0xFFB6BDBC),
                size: 14.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _logout(BuildContext context) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () => _confirmLogout(context),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20.w,
            vertical: 18.h,
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                Icons.logout_rounded,
                color: const Color(0xFFD94A4A),
                size: 22.sp,
              ),
              SizedBox(width: 15.w),
              Expanded(
                child: Text(
                  'تسجيل الخروج',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: const Color(0xFFD94A4A),
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          padding: EdgeInsets.fromLTRB(
            22.w,
            14.h,
            22.w,
            24.h,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(26.r),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8DEDD),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
                SizedBox(height: 22.h),
                Text(
                  'تسجيل الخروج؟',
                  style: TextStyle(
                    color: const Color(0xFF172323),
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7.h),
                Text(
                  'هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xFF7B8584),
                    fontSize: 12.5.sp,
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 22.h),
                SizedBox(
                  width: double.infinity,
                  height: 50.h,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(sheetContext, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD94A4A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                    ),
                    child: Text(
                      'تسجيل الخروج',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                SizedBox(
                  width: double.infinity,
                  height: 48.h,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(sheetContext, false);
                    },
                    child: Text(
                      'إلغاء',
                      style: TextStyle(
                        color: const Color(0xFF52605F),
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirm != true) return;

    await box.erase();

    if (context.mounted) {
      context.go('/login');
    }
  }
}

class _ProfileItem {
  final IconData icon;
  final String title;
  final Widget page;

  const _ProfileItem({
    required this.icon,
    required this.title,
    required this.page,
  });
}
