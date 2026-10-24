import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/features/cart/cart_manager.dart';
import 'package:bringo/features/cart/cart_screen.dart';
import 'package:bringo/features/home/home_screen.dart';
import 'package:bringo/features/orders/my_orders_screen.dart';
import 'package:bringo/features/profile/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int currentIndex = 0;
  bool _welcomeVisible = true;
  final GetStorage _box = GetStorage();

  final List<Widget> pages = [
    const HomeScreen(),
    const CartScreen(),
    const MyOrdersScreen(),
    ProfileScreen(),
  ];

  String get _customerName {
    final value = _box.read('accountName');
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty && text != 'null') return text.split(' ').first;

    // Backward compatibility for sessions created before accountName existed.
    final legacy = _box.read('userName')?.toString().trim() ?? '';
    if (legacy.isNotEmpty && legacy != 'null') return legacy.split(' ').first;
    return 'بيك';
  }

  void changeTab(int index) {
    if (currentIndex == index) return;
    setState(() {
      currentIndex = index;
      if (index == 0) _welcomeVisible = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F8),
      body: Stack(
        children: [
          IndexedStack(index: currentIndex, children: pages),
          if (currentIndex == 0 && _welcomeVisible)
            Positioned(
              top: MediaQuery.of(context).padding.top + 66.h,
              right: 14.w,
              left: 14.w,
              child: _WelcomeBanner(
                name: _customerName,
                onClose: () => setState(() => _welcomeVisible = false),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  Widget _buildBottomNavigation() {
    return ValueListenableBuilder<List<Map<String, dynamic>>>(
      valueListenable: CartManager.cartNotifier,
      builder: (context, cartItems, _) {
        final int cartCount = cartItems.fold<int>(0, (sum, item) => sum + (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1));
        return Container(
          decoration: BoxDecoration(
            color: AppColors.primary,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(.10), blurRadius: 20, offset: const Offset(0, -5))],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 68.h,
              child: Row(children: [
                Expanded(child: _NavItem(icon: Icons.home_rounded, title: 'الرئيسية', active: currentIndex == 0, onTap: () => changeTab(0))),
                Expanded(child: _NavItem(icon: Icons.shopping_bag_outlined, activeIcon: Icons.shopping_bag_rounded, title: 'السلة', active: currentIndex == 1, badgeCount: cartCount, onTap: () => changeTab(1))),
                Expanded(child: _NavItem(icon: Icons.receipt_long_outlined, activeIcon: Icons.receipt_long_rounded, title: 'طلباتي', active: currentIndex == 2, onTap: () => changeTab(2))),
                Expanded(child: _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, title: 'حسابي', active: currentIndex == 3, onTap: () => changeTab(3))),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class _WelcomeBanner extends StatelessWidget {
  final String name;
  final VoidCallback onClose;
  const _WelcomeBanner({required this.name, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final greeting = name == 'بيك' ? 'أهلاً بيك في Bringo' : 'أهلاً يا $name 👋';
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: EdgeInsets.fromLTRB(14.w, 12.h, 12.w, 12.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: AppColors.primary.withOpacity(.14)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.09), blurRadius: 18, offset: const Offset(0, 6))],
        ),
        child: Row(children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(13.r)),
            child: const Icon(Icons.delivery_dining_rounded, color: AppColors.primary),
          ),
          SizedBox(width: 11.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text(greeting, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900, color: AppColors.dark)),
              SizedBox(height: 3.h),
              Text('اطلب اللي محتاجه وإحنا نوصله لحد عندك', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5.sp, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
            ]),
          ),
          IconButton(onPressed: onClose, visualDensity: VisualDensity.compact, icon: Icon(Icons.close_rounded, size: 19.sp, color: AppColors.textSecondary)),
        ]),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData? activeIcon;
  final String title;
  final bool active;
  final VoidCallback onTap;
  final int badgeCount;

  const _NavItem({required this.icon, this.activeIcon, required this.title, required this.active, required this.onTap, this.badgeCount = 0});

  @override
  Widget build(BuildContext context) {
    const Color activeColor = Color(0xFFDDFB8A);
    final Color itemColor = active ? activeColor : Colors.white.withOpacity(.72);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: Colors.white.withOpacity(.06),
        highlightColor: Colors.transparent,
        child: SizedBox.expand(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                width: active ? 42.w : 36.w,
                height: 31.h,
                decoration: BoxDecoration(color: active ? activeColor.withOpacity(.14) : Colors.transparent, borderRadius: BorderRadius.circular(20.r)),
                alignment: Alignment.center,
                child: AnimatedSwitcher(duration: const Duration(milliseconds: 160), child: Icon(active ? (activeIcon ?? icon) : icon, key: ValueKey(active), color: itemColor, size: active ? 23.sp : 22.sp)),
              ),
              if (badgeCount > 0)
                Positioned(
                  top: -5.h,
                  right: -5.w,
                  child: Container(
                    constraints: BoxConstraints(minWidth: 17.w, minHeight: 17.w),
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20.r), border: Border.all(color: AppColors.primary, width: 1.5)),
                    alignment: Alignment.center,
                    child: Text(badgeCount > 99 ? '99+' : badgeCount.toString(), style: TextStyle(color: AppColors.primary, fontSize: 8.5.sp, fontWeight: FontWeight.w900, height: 1.1)),
                  ),
                ),
            ]),
            SizedBox(height: 3.h),
            AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 180), style: TextStyle(color: itemColor, fontSize: active ? 10.5.sp : 9.5.sp, fontWeight: active ? FontWeight.w900 : FontWeight.w600), child: Text(title)),
            SizedBox(height: 3.h),
            AnimatedContainer(duration: const Duration(milliseconds: 180), width: active ? 18.w : 0, height: 2.5.h, decoration: BoxDecoration(color: activeColor, borderRadius: BorderRadius.circular(20.r))),
          ]),
        ),
      ),
    );
  }
}
