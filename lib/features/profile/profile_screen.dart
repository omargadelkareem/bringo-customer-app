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
  static const _dark = Color(0xFF153F3B);
  static const _ink = Color(0xFF1B302D);
  static const _muted = Color(0xFF81908C);
  static const _canvas = Color(0xFFF6F8F6);
  static const _lime = Color(0xFFDDFB8A);

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final accountName = box.read('accountName')?.toString().trim() ?? '';
    final legacyName = box.read('userName')?.toString().trim() ?? '';
    final phone = box.read('accountPhone')?.toString().trim() ?? '';
    final name = accountName.isNotEmpty ? accountName : legacyName.isNotEmpty ? legacyName : 'عميل برينجو';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _canvas,
        body: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(bottom: 110.h),
            children: [
              _hero(context, name, phone),
              SizedBox(height: 22.h),
              _quickActions(context),
              SizedBox(height: 28.h),
              _sectionTitle('إدارة الحساب'),
              _group(context, [
                _ProfileItem(Icons.person_outline_rounded, 'المعلومات الشخصية', 'تعديل بيانات حسابك', const PersonalInfoScreen()),
                _ProfileItem(Icons.location_on_outlined, 'عناويني', 'عناوين التوصيل المحفوظة', const AddressesScreen()),
              ]),
              SizedBox(height: 24.h),
              _sectionTitle('طلباتي'),
              _group(context, [
                _ProfileItem(Icons.receipt_long_outlined, 'سجل الطلبات', 'تابع طلباتك السابقة والحالية', const MyOrdersScreen()),
              ]),
              SizedBox(height: 24.h),
              _sectionTitle('المساعدة والمعلومات'),
              _group(context, [
                _ProfileItem(Icons.support_agent_rounded, 'مركز المساعدة', 'إحنا هنا علشان نساعدك', const SupportScreen()),
                _ProfileItem(Icons.shield_outlined, 'سياسة الخصوصية', 'إزاي بنحافظ على بياناتك', const PrivacyPolicyScreen()),
                _ProfileItem(Icons.article_outlined, 'الشروط والأحكام', 'تعرف على شروط استخدام برينجو', const TermsAndConditionsScreen()),
                _ProfileItem(Icons.info_outline_rounded, 'عن برينجو', 'اعرف أكتر عن التطبيق', const AboutBringoScreen()),
              ]),
              SizedBox(height: 22.h),
              _logoutTile(context),
              SizedBox(height: 24.h),
              Center(child: Text('Bringo  •  v1.0.0',
                  style: TextStyle(fontSize: 10.sp, color: _muted, fontWeight: FontWeight.w600))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hero(BuildContext context, String name, String phone) {
    return Container(
      margin: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
      decoration: BoxDecoration(
        color: _dark,
        borderRadius: BorderRadius.circular(26.r),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26.r),
        child: Stack(children: [
          Positioned(left: -38.w, top: -75.h, child: Container(
            width: 185.w, height: 185.w,
            decoration: BoxDecoration(shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withOpacity(.07), width: 34.w)),
          )),
          Positioned(left: 15.w, bottom: -75.h, child: Container(
            width: 155.w, height: 155.w,
            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(.035)),
          )),
          Padding(
            padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 22.h),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('حسابي', style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900)),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.1),
                      borderRadius: BorderRadius.circular(30.r)),
                  child: Text('Bringo', style: TextStyle(color: _lime, fontSize: 12.sp, fontWeight: FontWeight.w900)),
                ),
              ]),
              SizedBox(height: 27.h),
              Row(children: [
                Container(
                  width: 66.w, height: 66.w,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(.12),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withOpacity(.2))),
                  child: Icon(Icons.person_rounded, size: 35.sp, color: _lime),
                ),
                SizedBox(width: 14.w),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('أهلاً بيك 👋', style: TextStyle(color: const Color(0xFFBFD4CD), fontSize: 11.sp)),
                  SizedBox(height: 5.h),
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white, fontSize: 19.sp, fontWeight: FontWeight.w900)),
                  if (phone.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(phone, textDirection: TextDirection.ltr,
                        style: TextStyle(color: const Color(0xFFCDDED7), fontSize: 11.sp)),
                  ],
                ])),
              ]),
              SizedBox(height: 22.h),
              Material(
                color: _lime,
                borderRadius: BorderRadius.circular(13.r),
                child: InkWell(
                  borderRadius: BorderRadius.circular(13.r),
                  onTap: () => _open(context, const PersonalInfoScreen()),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.edit_outlined, size: 17.sp, color: _dark),
                      SizedBox(width: 8.w),
                      Text('تعديل الملف الشخصي',
                          style: TextStyle(fontSize: 12.sp, color: _dark, fontWeight: FontWeight.w900)),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _quickActions(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: Row(children: [
      Expanded(child: _shortcut(context, Icons.receipt_long_rounded, 'طلباتي', const MyOrdersScreen())),
      SizedBox(width: 11.w),
      Expanded(child: _shortcut(context, Icons.location_on_rounded, 'عناويني', const AddressesScreen())),
      SizedBox(width: 11.w),
      Expanded(child: _shortcut(context, Icons.headset_mic_rounded, 'المساعدة', const SupportScreen())),
    ]),
  );

  Widget _shortcut(BuildContext context, IconData icon, String title, Widget page) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18.r),
    child: InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: () => _open(context, page),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 5.w),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(18.r),
          border: Border.all(color: const Color(0xFFE7EDE9))),
        child: Column(children: [
          Container(width: 44.w, height: 44.w,
            decoration: BoxDecoration(color: const Color(0xFFECF5F0),
              borderRadius: BorderRadius.circular(14.r)),
            child: Icon(icon, color: AppColors.primary, size: 23.sp)),
          SizedBox(height: 10.h),
          Text(title, style: TextStyle(color: _ink, fontSize: 11.5.sp, fontWeight: FontWeight.w800)),
        ]),
      ),
    ),
  );

  Widget _sectionTitle(String title) => Padding(
    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 12.h),
    child: Text(title, style: TextStyle(fontSize: 14.sp, color: _ink, fontWeight: FontWeight.w900)),
  );

  Widget _group(BuildContext context, List<_ProfileItem> items) => Container(
    margin: EdgeInsets.symmetric(horizontal: 16.w),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r),
      border: Border.all(color: const Color(0xFFE8EEEA))),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: Column(children: [
        for (var i = 0; i < items.length; i++) ...[
          _tile(context, items[i]),
          if (i < items.length - 1)
            Padding(padding: EdgeInsets.only(right: 66.w, left: 16.w),
              child: const Divider(height: 1, color: Color(0xFFF0F2F0))),
        ],
      ]),
    ),
  );

  Widget _tile(BuildContext context, _ProfileItem item) => Material(
    color: Colors.white,
    child: InkWell(
      onTap: () => _open(context, item.page),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 15.w, vertical: 13.h),
        child: Row(children: [
          Container(width: 43.w, height: 43.w,
            decoration: BoxDecoration(color: const Color(0xFFF0F6F2),
              borderRadius: BorderRadius.circular(13.r)),
            child: Icon(item.icon, color: AppColors.primary, size: 22.sp)),
          SizedBox(width: 12.w),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item.title, style: TextStyle(color: _ink, fontSize: 12.5.sp, fontWeight: FontWeight.w800)),
            SizedBox(height: 3.h),
            Text(item.subtitle, style: TextStyle(color: _muted, fontSize: 10.sp)),
          ])),
          Icon(Icons.chevron_left_rounded, color: const Color(0xFF9DABA5), size: 23.sp),
        ]),
      ),
    ),
  );

  Widget _logoutTile(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: 16.w),
    child: Material(
      color: const Color(0xFFFFF3F1),
      borderRadius: BorderRadius.circular(17.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(17.r),
        onTap: () => _confirmLogout(context),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 17.w, vertical: 16.h),
          child: Row(children: [
            Icon(Icons.logout_rounded, color: const Color(0xFFC34E45), size: 22.sp),
            SizedBox(width: 12.w),
            Expanded(child: Text('تسجيل الخروج',
              style: TextStyle(color: const Color(0xFFC34E45), fontSize: 13.sp, fontWeight: FontWeight.w900))),
            Icon(Icons.chevron_left_rounded, color: const Color(0xFFC34E45)),
          ]),
        ),
      ),
    ),
  );

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        padding: EdgeInsets.fromLTRB(22.w, 14.h, 22.w, 24.h),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(26.r))),
        child: SafeArea(
          top: false,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 38.w, height: 4.h, decoration: BoxDecoration(color: const Color(0xFFD8DEDD), borderRadius: BorderRadius.circular(20.r))),
            SizedBox(height: 22.h),
            Text('تسجيل الخروج؟', style: TextStyle(color: const Color(0xFF172323), fontSize: 19.sp, fontWeight: FontWeight.w900)),
            SizedBox(height: 7.h),
            Text('هل أنت متأكد أنك تريد تسجيل الخروج من حسابك؟', textAlign: TextAlign.center, style: TextStyle(color: const Color(0xFF7B8584), fontSize: 12.5.sp, height: 1.5)),
            SizedBox(height: 22.h),
            SizedBox(width: double.infinity, height: 50.h, child: ElevatedButton(
              onPressed: () => Navigator.pop(sheetContext, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD94A4A), foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))),
              child: Text('تسجيل الخروج', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w800)),
            )),
            SizedBox(height: 8.h),
            SizedBox(width: double.infinity, height: 48.h, child: TextButton(
              onPressed: () => Navigator.pop(sheetContext, false),
              child: Text('إلغاء', style: TextStyle(color: const Color(0xFF52605F), fontSize: 13.sp, fontWeight: FontWeight.w700)),
            )),
          ]),
        ),
      ),
    );

    if (confirm != true) return;
    await box.erase();
    if (context.mounted) context.go('/login');
  }
}

class _ProfileItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget page;
  const _ProfileItem(this.icon, this.title, this.subtitle, this.page);
}
