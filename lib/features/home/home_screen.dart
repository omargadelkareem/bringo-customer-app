// lib/features/home/home_screen.dart

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/core/services/adress_services.dart';
import 'package:bringo/core/services/home_service.dart';
import 'package:bringo/core/services/location_service.dart';
import 'package:bringo/core/services/notification_service.dart';
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
  final NotificationService notificationService = NotificationService();
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

  String get _currentUserId =>
      (box.read('userId') ?? box.read('uid') ?? box.read('id'))
          ?.toString()
          .trim() ??
      '';

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
              _notificationButton(),
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

  Widget _notificationButton() {
    final userId = _currentUserId;
    if (userId.isEmpty) {
      return _appBarIcon(
        icon: Icons.notifications_none_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ),
      );
    }

    return StreamBuilder<int>(
      stream: notificationService.watchUnreadCount(userId),
      initialData: 0,
      builder: (context, snapshot) => _appBarIcon(
        icon: Icons.notifications_none_rounded,
        badgeCount: snapshot.data ?? 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
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
      height: 196.h,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        itemCount: stores.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (_, index) {
          final store = stores[index];
          return _StoreCard(
            store: store,
            distanceKm: showDistance
                ? double.tryParse(store['_distanceKm']?.toString() ?? '')
                : null,
            onTap: () => _openStore(store),
          );
        },
      ),
    );
  }

  Widget _emptyText(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 18.h),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
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
        itemBuilder: (_, __) => Column(
          children: [
            AppSkeleton.circle(size: 62.w),
            SizedBox(height: 8.h),
            AppSkeleton.box(width: 54.w, height: 9.h, radius: 5.r),
          ],
        ),
      ),
    );
  }

  Widget _storesShimmer() {
    return SizedBox(
      height: 196.h,
      child: ListView.separated(
        reverse: true,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        itemCount: 3,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (_, __) => Container(
          width: 220.w,
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: const Color(0xFFE8ECEA)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppSkeleton.box(width: double.infinity, height: 112.h, radius: 12.r),
              SizedBox(height: 10.h),
              AppSkeleton.box(width: 120.w, height: 11.h, radius: 5.r),
              SizedBox(height: 8.h),
              AppSkeleton.box(width: 80.w, height: 8.h, radius: 5.r),
            ],
          ),
        ),
      ),
    );
  }

  void _openCategory(Map<String, dynamic> item) {
    final type = (item['type'] ?? item['storeType'] ?? item['slug'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final id = (item['id'] ?? item['firebaseKey'] ?? '').toString().trim();
    final name = item['name']?.toString().trim() ?? '';
    final storeType = type.isNotEmpty ? type : id;
    if (storeType.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryStoresScreen(
          storeType: storeType,
          title: name.isNotEmpty ? name : 'المتاجر',
        ),
      ),
    );
  }

  void _openStore(Map<String, dynamic> store) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StoreProductsScreen(store: store)),
    );
  }

  List<Map<String, dynamic>> _getCategories(List<Map<String, dynamic>> items) {
    final result = items.where((item) => item['isActive'] != false).toList();
    result.sort((a, b) {
      final aSort = NumberHelper.toInt(a['sort']);
      final bSort = NumberHelper.toInt(b['sort']);
      return aSort.compareTo(bSort);
    });
    return result;
  }

  List<Map<String, dynamic>> _parseStores(dynamic value) {
    if (value is! Map) return [];
    final result = <Map<String, dynamic>>[];
    Map<dynamic, dynamic>.from(value).forEach((key, raw) {
      if (raw is! Map) return;
      final store = Map<String, dynamic>.from(raw);
      if (store['isActive'] == false) return;
      store['firebaseKey'] = key.toString();
      store['id'] = store['id']?.toString().trim().isNotEmpty == true
          ? store['id'].toString()
          : key.toString();
      result.add(store);
    });
    return result;
  }

  double? _storeLatitude(Map<String, dynamic> store) {
    return NumberHelper.toDouble(
      store['latitude'] ?? store['lat'] ?? store['location']?['latitude'],
    );
  }

  double? _storeLongitude(Map<String, dynamic> store) {
    return NumberHelper.toDouble(
      store['longitude'] ?? store['lng'] ?? store['location']?['longitude'],
    );
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    double toRad(double degree) => degree * math.pi / 180;
    final dLat = toRad(lat2 - lat1);
    final dLon = toRad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(toRad(lat1)) *
            math.cos(toRad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

class _HomeBannerCarousel extends StatefulWidget {
  final List<String> images;
  const _HomeBannerCarousel({required this.images});

  @override
  State<_HomeBannerCarousel> createState() => _HomeBannerCarouselState();
}

class _HomeBannerCarouselState extends State<_HomeBannerCarousel> {
  late final PageController _controller;
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: .91);
    if (widget.images.length > 1) {
      _timer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted || !_controller.hasClients) return;
        final next = (_index + 1) % widget.images.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 380),
          curve: Curves.easeOutCubic,
        );
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        SizedBox(
          height: 148.h,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (_, index) => Padding(
              padding: EdgeInsets.symmetric(horizontal: 4.w),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.r),
                child: Image.asset(
                  widget.images[index],
                  fit: BoxFit.cover,
                  cacheWidth: 900,
                  errorBuilder: (_, __, ___) => Container(
                    color: AppColors.primary,
                    alignment: Alignment.center,
                    child: Text(
                      'Bringo',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        if (widget.images.length > 1) ...[
          SizedBox(height: 9.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.images.length, (index) {
              final selected = index == _index;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                margin: EdgeInsets.symmetric(horizontal: 3.w),
                width: selected ? 16.w : 6.w,
                height: 6.w,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : const Color(0xFFD8DEDC),
                  borderRadius: BorderRadius.circular(20.r),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final String title;
  final String image;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.title,
    required this.image,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(7.w),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F3),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(11.r),
                child: _AdaptiveImage(
                  value: image,
                  fallbackIcon: Icons.category_outlined,
                ),
              ),
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 10.5.sp,
              height: 1.25,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final double? distanceKm;
  final VoidCallback onTap;

  const _StoreCard({
    required this.store,
    required this.distanceKm,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString().trim().isNotEmpty == true
        ? store['name'].toString()
        : 'متجر';
    final image = (store['coverImage'] ?? store['image'] ?? '').toString();
    final rating = NumberHelper.toDouble(store['rating']);
    final deliveryTime = store['deliveryTime']?.toString().trim() ?? '';
    final subtitle = store['tags']?.toString().trim().isNotEmpty == true
        ? store['tags'].toString()
        : store['address']?.toString() ?? '';

    return SizedBox(
      width: 220.w,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16.r),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: const Color(0xFFE8ECEA)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(15.r)),
                  child: SizedBox(
                    width: double.infinity,
                    height: 112.h,
                    child: _AdaptiveImage(
                      value: image,
                      fallbackIcon: Icons.storefront_rounded,
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(10.w, 8.h, 10.w, 8.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.dark,
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (rating != null) ...[
                              SizedBox(width: 5.w),
                              Icon(Icons.star_rounded,
                                  color: const Color(0xFFFFB800), size: 14.sp),
                              SizedBox(width: 2.w),
                              Text(
                                rating.toStringAsFixed(1),
                                style: TextStyle(
                                  color: AppColors.dark,
                                  fontSize: 9.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (subtitle.isNotEmpty) ...[
                          SizedBox(height: 3.h),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Row(
                          children: [
                            if (deliveryTime.isNotEmpty) ...[
                              Icon(Icons.schedule_rounded,
                                  size: 12.sp, color: AppColors.textSecondary),
                              SizedBox(width: 3.w),
                              Flexible(
                                child: Text(
                                  deliveryTime,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 8.5.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (distanceKm != null) ...[
                              SizedBox(width: 8.w),
                              Text(
                                '${distanceKm!.toStringAsFixed(1)} كم',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 8.5.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
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

class _AdaptiveImage extends StatelessWidget {
  final String value;
  final IconData fallbackIcon;

  const _AdaptiveImage({required this.value, required this.fallbackIcon});

  @override
  Widget build(BuildContext context) {
    final image = value.trim();
    if (image.isEmpty) return _placeholder();
    if (image.startsWith('http')) {
      return Image.network(
        image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (image.startsWith('assets/')) {
      return Image.asset(
        image,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    try {
      final clean = image.startsWith('data:image') ? image.split(',').last : image;
      return Image.memory(
        base64Decode(clean),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0F3F1),
      alignment: Alignment.center,
      child: Icon(fallbackIcon, color: AppColors.primary, size: 30.sp),
    );
  }
}

class NumberHelper {
  static int toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
