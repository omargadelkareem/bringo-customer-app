// lib/features/home/home_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/core/services/adress_services.dart';
import 'package:bringo/core/services/home_service.dart';
import 'package:bringo/core/services/location_service.dart';
import 'package:bringo/core/widgets/app_skeleton.dart';
import 'package:bringo/features/cart/cart_manager.dart';
import 'package:bringo/features/cart/cart_screen.dart';
import 'package:bringo/features/home/category_stores_screen.dart';
import 'package:bringo/features/notifications/notifications_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HomeService homeService = HomeService();
  final GetStorage box = GetStorage();

  StreamSubscription<List<Map<String, dynamic>>>? _categoriesSubscription;
  StreamSubscription<DatabaseEvent>? _storesSubscription;

  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _stores = const [];
  List<Map<String, dynamic>> _newestStores = const [];
  List<Map<String, dynamic>> _nearbyStores = const [];

  bool _categoriesLoading = true;
  bool _storesLoading = true;
  bool isLoadingLocation = true;
  String locationText = 'جاري تحديد موقعك...';

  static const List<String> _bannerImages = [
    'assets/images/bringo_res.png',
    'assets/images/bringo_banner.png',
    'assets/images/bringo_res.png',
  ];

  @override
  void initState() {
    super.initState();

    _categoriesSubscription = homeService.getCategories().listen((items) {
      if (!mounted) return;
      setState(() {
        _categories = _getCategories(items);
        _categoriesLoading = false;
      });
    }, onError: (_) {
      if (mounted) setState(() => _categoriesLoading = false);
    });

    _storesSubscription = FirebaseDatabase.instance.ref('stores').onValue.listen(
      (event) {
        final stores = _parseStores(event.snapshot.value);
        if (!mounted) return;
        setState(() {
          _stores = stores;
          _storesLoading = false;
          _rebuildStoreCaches();
        });
      },
      onError: (_) {
        if (mounted) setState(() => _storesLoading = false);
      },
    );

    _loadLocation();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    for (final asset in _bannerImages.toSet()) {
      precacheImage(AssetImage(asset), context);
    }
  }

  @override
  void dispose() {
    _categoriesSubscription?.cancel();
    _storesSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    if (!mounted) return;
    setState(() {
      locationText = 'جاري تحديد موقعك...';
      isLoadingLocation = true;
    });

    try {
      var location = await LocationService()
          .getCurrentLocation()
          .timeout(const Duration(seconds: 12));

      if (location == null ||
          location.latitude == null ||
          location.longitude == null) {
        await Future.delayed(const Duration(milliseconds: 450));
        location = await LocationService()
            .getCurrentLocation()
            .timeout(const Duration(seconds: 12));
      }

      if (!mounted) return;
      if (location == null ||
          location.latitude == null ||
          location.longitude == null) {
        _finishLocationWithFallback();
        return;
      }

      final latitude = location.latitude!;
      final longitude = location.longitude!;
      String areaName = '';

      try {
        areaName = await AddressService.getAreaName(latitude, longitude)
            .timeout(const Duration(seconds: 10));
      } catch (_) {}

      final cleanArea = areaName.trim();
      final finalLocation = cleanArea.isNotEmpty &&
              cleanArea != 'موقعك الحالي' &&
              cleanArea != 'غير معروف'
          ? cleanArea
          : 'موقعك الحالي';

      await box.write('currentLocationName', finalLocation);
      await box.write('currentLatitude', latitude);
      await box.write('currentLongitude', longitude);

      if (!mounted) return;
      setState(() {
        locationText = finalLocation;
        isLoadingLocation = false;
        _rebuildStoreCaches();
      });
    } on TimeoutException {
      _finishLocationWithFallback();
    } catch (_) {
      _finishLocationWithFallback();
    }
  }

  void _finishLocationWithFallback() {
    if (!mounted) return;
    final cached = box.read('currentLocationName')?.toString().trim() ?? '';
    setState(() {
      isLoadingLocation = false;
      locationText = cached.isNotEmpty ? cached : 'اضغط لتحديد موقعك';
      _rebuildStoreCaches();
    });
  }

  void _rebuildStoreCaches() {
    if (_stores.isEmpty) {
      _newestStores = const [];
      _nearbyStores = const [];
      return;
    }

    final newest = _stores.map(Map<String, dynamic>.from).toList()
      ..sort((a, b) => NumberHelper.toInt(b['createdAt'])
          .compareTo(NumberHelper.toInt(a['createdAt'])));
    _newestStores = newest.take(10).toList(growable: false);

    final userLat = double.tryParse(box.read('currentLatitude')?.toString() ?? '');
    final userLng = double.tryParse(box.read('currentLongitude')?.toString() ?? '');
    final nearby = _stores.map(Map<String, dynamic>.from).toList();

    if (userLat != null && userLng != null) {
      for (final store in nearby) {
        final lat = _storeLatitude(store);
        final lng = _storeLongitude(store);
        if (lat != null && lng != null) {
          store['_distanceKm'] = _distanceKm(userLat, userLng, lat, lng);
        }
      }
      nearby.sort((a, b) {
        final aDistance =
            double.tryParse(a['_distanceKm']?.toString() ?? '') ?? double.infinity;
        final bDistance =
            double.tryParse(b['_distanceKm']?.toString() ?? '') ?? double.infinity;
        return aDistance.compareTo(bDistance);
      });
    }

    _nearbyStores = nearby.take(10).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        cacheExtent: 650,
        slivers: [
          SliverToBoxAdapter(child: RepaintBoundary(child: _appBar())),
          SliverToBoxAdapter(child: SizedBox(height: 12.h)),
          const SliverToBoxAdapter(
            child: RepaintBoundary(
              child: _HomeBannerCarousel(images: _bannerImages),
            ),
          ),
          SliverToBoxAdapter(child: SizedBox(height: 26.h)),
          SliverToBoxAdapter(child: _sectionTitle('شوف أقسامنا')),
          SliverToBoxAdapter(child: SizedBox(height: 14.h)),
          SliverToBoxAdapter(child: RepaintBoundary(child: _categoriesSection())),
          SliverToBoxAdapter(child: SizedBox(height: 28.h)),
          SliverToBoxAdapter(child: _sectionTitle('جديد على Bringo')),
          SliverToBoxAdapter(child: SizedBox(height: 14.h)),
          SliverToBoxAdapter(child: RepaintBoundary(child: _newStoresSection())),
          SliverToBoxAdapter(child: SizedBox(height: 28.h)),
          SliverToBoxAdapter(child: _sectionTitle('متاجر بالقرب منك')),
          SliverToBoxAdapter(child: SizedBox(height: 14.h)),
          SliverToBoxAdapter(child: RepaintBoundary(child: _nearbyStoresSection())),
          SliverToBoxAdapter(child: SizedBox(height: 120.h)),
        ],
      ),
    );
  }

  Widget _appBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(18.r),
          bottomRight: Radius.circular(18.r),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14.w, 8.h, 14.w, 10.h),
          child: Row(
            children: [
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref('notifications').onValue,
                builder: (context, snapshot) {
                  int unreadCount = 0;
                  final value = snapshot.data?.snapshot.value;
                  final currentUserId =
                      (box.read('userId') ?? box.read('uid') ?? box.read('id'))
                          ?.toString();
                  if (value is Map) {
                    for (final entry in value.values) {
                      if (entry is! Map) continue;
                      final notificationUserId =
                          (entry['userId'] ?? entry['customerId'])?.toString();
                      final belongsToUser = notificationUserId == null ||
                          notificationUserId.isEmpty ||
                          currentUserId == null ||
                          notificationUserId == currentUserId;
                      final isUnread = entry['isRead'] != true && entry['read'] != true;
                      if (belongsToUser && isUnread) unreadCount++;
                    }
                  }
                  return _appBarIcon(
                    icon: Icons.notifications_none_rounded,
                    badgeCount: unreadCount,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                    ),
                  );
                },
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: InkWell(
                  onTap: isLoadingLocation ? null : _loadLocation,
                  borderRadius: BorderRadius.circular(12.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 3.h),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'التوصيل إلى',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Icon(Icons.keyboard_arrow_down_rounded,
                                color: AppColors.accent, size: 18.sp),
                            SizedBox(width: 3.w),
                            if (isLoadingLocation) ...[
                              SizedBox(
                                width: 13.w,
                                height: 13.w,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 1.8,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 6.w),
                            ],
                            Flexible(
                              child: Text(
                                locationText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            SizedBox(width: 4.w),
                            Icon(Icons.location_on_rounded,
                                color: AppColors.accent, size: 17.sp),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              _appBarIcon(icon: Icons.search_rounded, onTap: () {}),
              SizedBox(width: 6.w),
              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: CartManager.cartNotifier,
                builder: (context, cartItems, _) {
                  final count = cartItems.fold<int>(
                    0,
                    (sum, item) =>
                        sum + (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1),
                  );
                  return _appBarIcon(
                    icon: Icons.shopping_cart_outlined,
                    badgeCount: count,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const CartScreen()),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appBarIcon({
    required IconData icon,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(11.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11.r),
        child: SizedBox(
          width: 38.w,
          height: 38.w,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(child: Icon(icon, color: Colors.white, size: 21.sp)),
              if (badgeCount > 0)
                Positioned(
                  top: 1.h,
                  right: 1.w,
                  child: Container(
                    constraints: BoxConstraints(minWidth: 17.w, minHeight: 17.w),
                    padding: EdgeInsets.symmetric(horizontal: 4.w),
                    decoration: const BoxDecoration(
                      color: Color(0xFFDDFB8A),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: TextStyle(
                        color: const Color(0xFF174746),
                        fontSize: 8.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          title,
          style: TextStyle(
            color: AppColors.dark,
            fontSize: 16.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }

  Widget _categoriesSection() {
    if (_categoriesLoading) return _categoriesShimmer();
    if (_categories.isEmpty) return _emptyText('لا توجد أقسام متاحة حاليًا');
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _categories.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: .62,
        ),
        itemBuilder: (_, index) {
          final item = _categories[index];
          return _CategoryItem(
            title: item['name']?.toString() ?? '',
            image: item['image']?.toString() ?? '',
            onTap: () => _openCategory(item),
          );
        },
      ),
    );
  }

  Widget _newStoresSection() {
    if (_storesLoading) return _storesShimmer();
    if (_newestStores.isEmpty) return _emptyText('لا توجد متاجر جديدة حاليًا');
    return _horizontalStores(_newestStores, showDistance: false);
  }

  Widget _nearbyStoresSection() {
    if (_storesLoading) return _storesShimmer();
    if (_nearbyStores.isEmpty) return _emptyText('لا توجد متاجر قريبة حاليًا');
    return _horizontalStores(_nearbyStores, showDistance: true);
  }

  Widget _horizontalStores(List<Map<String, dynamic>> stores,
      {required bool showDistance}) {
    return SizedBox(
      height: 228.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        itemCount: stores.length,
        separatorBuilder: (_, __) => SizedBox(width: 14.w),
        itemBuilder: (_, index) => RepaintBoundary(
          child: _StoreCard(
            store: stores[index],
            showDistance: showDistance,
            onTap: () => _openStore(stores[index]),
          ),
        ),
      ),
    );
  }

  Widget _storesShimmer() {
    return SizedBox(
      height: 228.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3,
        separatorBuilder: (_, __) => SizedBox(width: 14.w),
        itemBuilder: (_, __) => AppSkeleton(
          child: Container(
            width: 250.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoriesShimmer() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      child: GridView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 8,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: 10.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: .62,
        ),
        itemBuilder: (_, __) => AppSkeleton(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyText(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 26.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22.r),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getCategories(List<Map<String, dynamic>> source) {
    String normalize(String value) => value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ');

    final hiddenNames = <String>{
      'بقاله', 'البقاله', 'البان والجبن', 'الالبان والجبن', 'البان وجبن',
      'مخبوزات', 'المخبوزات', 'منظفات', 'المنظفات', 'عطاره', 'العطاره',
      'عسل', 'العسل', 'عسل ومربي', 'عسل ومنتجات طبيعيه',
      'العسل ومنتجات طبيعيه', 'مخللات', 'المخللات', 'مشروبات',
      'المشروبات', 'سناكس', 'وجبات سريعه', 'مجمدات', 'المجمدات',
    }.map(normalize).toSet();

    const hiddenIds = <String>{
      'grocery', 'dairy', 'bakery', 'cleaning', 'spices', 'honey',
      'pickles', 'drinks', 'beverages', 'snacks', 'fast_food', 'fastfood',
      'frozen',
    };

    final visible = source.where((category) {
      if (category['isActive'] == false) return false;
      final id = category['id']?.toString().trim().toLowerCase() ?? '';
      final name = normalize(category['name']?.toString() ?? '');
      return !hiddenIds.contains(id) && !hiddenNames.contains(name);
    }).map(Map<String, dynamic>.from).toList();

    visible.sort((a, b) =>
        NumberHelper.toInt(a['sort']).compareTo(NumberHelper.toInt(b['sort'])));
    return visible;
  }

  List<Map<String, dynamic>> _parseStores(dynamic value) {
    if (value == null || value is! Map) return [];
    final stores = <Map<String, dynamic>>[];
    Map<dynamic, dynamic>.from(value).forEach((key, raw) {
      if (raw is! Map) return;
      final store = Map<String, dynamic>.from(raw);
      store['id'] = store['id']?.toString().trim().isNotEmpty == true
          ? store['id'].toString()
          : key.toString();
      if (store['isActive'] != false) stores.add(store);
    });
    return stores;
  }

  void _openCategory(Map<String, dynamic> item) {
    final id = item['id']?.toString().trim().toLowerCase() ?? '';
    final name = item['name']?.toString().trim() ?? '';
    final normalized = _normalize(name);

    String? storeType;
    if (id == 'restaurants' || id == 'restaurant' || normalized.contains('مطعم')) {
      storeType = 'restaurant';
    } else if (id == 'supermarket' || id == 'grocery_store' || id == 'grocery' ||
        normalized.contains('سوبر ماركت') || normalized.contains('سوبرماركت')) {
      storeType = 'supermarket';
    } else {
      storeType = _resolveStoreType(id, normalized);
    }

    if (storeType != null) {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CategoryStoresScreen(
          storeType: storeType!,
          title: name.isEmpty ? 'المتاجر' : name,
        ),
      ));
      return;
    }

    context.push(AppRoutes.categoryProducts,
        extra: {'categoryId': id, 'categoryName': name});
  }

  String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ');

  String? _resolveStoreType(String id, String name) {
    const byId = <String, String>{
      'pharmacy': 'pharmacy', 'pharmacies': 'pharmacy',
      'vegetables': 'vegetables', 'fruits': 'vegetables',
      'vegetables_fruits': 'vegetables', 'beauty': 'beauty',
      'cosmetics': 'beauty', 'meat': 'meat', 'butcher': 'meat',
      'bakery': 'bakery', 'bakeries': 'bakery', 'fish': 'fish',
      'seafood': 'fish', 'market': 'market',
    };
    if (byId.containsKey(id)) return byId[id];
    if (name.contains('صيدلي')) return 'pharmacy';
    if (name.contains('خضار') || name.contains('خضروات') ||
        name.contains('فاكه') || name.contains('فواكه')) return 'vegetables';
    if (name.contains('تجميل') || name.contains('عنايه شخصيه')) return 'beauty';
    if (name.contains('لحوم') || name.contains('دواجن')) return 'meat';
    if (name.contains('مخبز') || name.contains('مخابز') || name.contains('حلويات')) {
      return 'bakery';
    }
    if (name.contains('اسماك') || name.contains('مأكولات بحريه')) return 'fish';
    return null;
  }

  void _openStore(Map<String, dynamic> store) {
    final type = store['type']?.toString().toLowerCase() ?? '';
    if (type == 'restaurant') {
      context.push(AppRoutes.restaurantDetails, extra: store);
    } else if (type == 'supermarket' || type == 'grocery') {
      context.push(AppRoutes.supermarket);
    } else {
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => StoreProductsScreen(store: store),
      ));
    }
  }

  double? _storeLatitude(Map<String, dynamic> store) => double.tryParse(
      (store['latitude'] ?? store['lat'] ?? store['location']?['latitude'] ??
                  store['location']?['lat'])
              ?.toString() ??
          '');

  double? _storeLongitude(Map<String, dynamic> store) => double.tryParse(
      (store['longitude'] ?? store['lng'] ?? store['location']?['longitude'] ??
                  store['location']?['lng'])
              ?.toString() ??
          '');

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) * math.cos(_rad(lat2)) *
            math.sin(dLon / 2) * math.sin(dLon / 2);
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  double _rad(double value) => value * math.pi / 180;
}

class _HomeBannerCarousel extends StatefulWidget {
  final List<String> images;
  const _HomeBannerCarousel({required this.images});

  @override
  State<_HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<_HomeBannerCarousel> {
  late final PageController _controller;
  final ValueNotifier<int> _page = ValueNotifier<int>(0);
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .90);
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_controller.hasClients || widget.images.length < 2) return;
      final next = (_page.value + 1) % widget.images.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 142.h,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            allowImplicitScrolling: true,
            physics: const PageScrollPhysics(),
            onPageChanged: (index) {
              _page.value = index;
              _startTimer();
            },
            itemBuilder: (_, index) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 5.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16.r),
                child: Image.asset(
                  widget.images[index],
                  width: double.infinity,
                  height: 142.h,
                  fit: BoxFit.cover,
                  filterQuality: FilterQuality.low,
                  gaplessPlayback: true,
                  cacheWidth: 900,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 9.h),
        ValueListenableBuilder<int>(
          valueListenable: _page,
          builder: (_, page, __) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (index) {
              final active = page == index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: active ? 20.w : 7.w,
                height: 7.h,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(.28),
                  borderRadius: BorderRadius.circular(20.r),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String title;
  final String image;
  final VoidCallback onTap;
  const _CategoryItem({required this.title, required this.image, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20.r),
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 92.w,
            height: 92.w,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20.r),
              child: _SmartImage(
                image: image,
                fit: BoxFit.cover,
                icon: Icons.category_rounded,
              ),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 8.sp,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final bool showDistance;
  final VoidCallback onTap;
  const _StoreCard({required this.store, required this.showDistance, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString() ?? 'متجر Bringo';
    final image = (store['coverImage'] ?? store['image'])?.toString() ?? '';
    final rating = double.tryParse(store['rating']?.toString() ?? '0') ?? 0;
    final deliveryTime = store['deliveryTime']?.toString().trim().isNotEmpty == true
        ? store['deliveryTime'].toString()
        : '25 - 35 دقيقة';
    final deliveryFee = double.tryParse(store['deliveryFee']?.toString() ?? '0') ?? 0;
    final distance = double.tryParse(store['_distanceKm']?.toString() ?? '');

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24.r),
      child: Container(
        width: 250.w,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.04),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(19.r),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _SmartImage(image: image, fit: BoxFit.cover, icon: Icons.storefront_rounded),
                    Positioned(
                      top: 9.h,
                      right: 9.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 5.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(.94),
                          borderRadius: BorderRadius.circular(14.r),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.star_rounded,
                                color: const Color(0xFFFFB800), size: 15.sp),
                            SizedBox(width: 3.w),
                            Text(
                              rating > 0 ? rating.toStringAsFixed(1) : 'جديد',
                              style: TextStyle(
                                color: AppColors.dark,
                                fontSize: 10.5.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),
            Text(name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: AppColors.dark, fontSize: 15.sp, fontWeight: FontWeight.w900)),
            SizedBox(height: 4.h),
            Text(_typeLabel(store['type']?.toString() ?? ''),
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 11.sp, fontWeight: FontWeight.w700)),
            SizedBox(height: 8.h),
            Row(
              children: [
                if (showDistance && distance != null) ...[
                  _Info(icon: Icons.near_me_rounded, text: '${distance.toStringAsFixed(1)} كم'),
                  SizedBox(width: 6.w),
                ],
                _Info(
                  icon: Icons.delivery_dining_rounded,
                  text: deliveryFee <= 0 ? 'توصيل مجاني' : '${deliveryFee.toStringAsFixed(0)} ج',
                ),
                const Spacer(),
                _Info(icon: Icons.schedule_rounded, text: deliveryTime),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _typeLabel(String value) {
    switch (value.toLowerCase()) {
      case 'restaurant': return 'مطعم';
      case 'supermarket':
      case 'grocery': return 'سوبر ماركت';
      case 'pharmacy': return 'صيدلية';
      default: return 'متجر';
    }
  }
}

class _Info extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Info({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary, size: 13.sp),
          SizedBox(width: 3.w),
          Text(text,
              style: TextStyle(
                  color: Colors.grey.shade700, fontSize: 9.5.sp, fontWeight: FontWeight.w800)),
        ],
      );
}

class _SmartImage extends StatelessWidget {
  final String image;
  final BoxFit fit;
  final IconData icon;
  const _SmartImage({required this.image, required this.fit, required this.icon});

  @override
  Widget build(BuildContext context) {
    final clean = image.trim();
    if (clean.isEmpty) return _fallback();

    if (clean.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(clean.split(',').last),
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          filterQuality: FilterQuality.low,
          cacheWidth: 700,
        );
      } catch (_) {
        return _fallback();
      }
    }

    if (clean.startsWith('http')) {
      return Image.network(
        clean,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        cacheWidth: 700,
        loadingBuilder: (context, child, progress) => progress == null ? child : _fallback(),
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    try {
      return Image.memory(
        base64Decode(clean),
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        gaplessPlayback: true,
        filterQuality: FilterQuality.low,
        cacheWidth: 700,
      );
    } catch (_) {
      return _fallback();
    }
  }

  Widget _fallback() => Container(
        color: const Color(0xFFFFF7FB),
        padding: EdgeInsets.all(12.w),
        child: Image.asset(
          'assets/images/bringo.png',
          fit: BoxFit.contain,
          filterQuality: FilterQuality.low,
          errorBuilder: (_, __, ___) => Center(
            child: Icon(icon, color: AppColors.primary.withOpacity(.45), size: 38.sp),
          ),
        ),
      );
}

class NumberHelper {
  static int toInt(dynamic value) => int.tryParse(value?.toString() ?? '0') ?? 0;
}
