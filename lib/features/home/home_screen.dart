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

import 'package:bringo/features/home/category_stores_screen.dart';
import 'package:bringo/features/cart/cart_manager.dart';
import 'package:bringo/features/cart/cart_screen.dart';

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

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  final GetStorage box = GetStorage();

  String locationText = 'جاري تحديد موقعك...';

  bool isLoadingLocation = true;

  Timer? _searchDebounce;

  final PageController _bannerController = PageController(viewportFraction: .90);

  int _currentBanner = 0;

  Timer? _bannerTimer;
  Timer? _scrollStopTimer;
  bool _showFloatingHeader = false;

  final List<String> _bannerImages = [

    'assets/images/bringo_res.png',

    'assets/images/bringo_banner.png',

    'assets/images/bringo_res.png',

  ];

  StreamSubscription<List<Map<String, dynamic>>>? _categoriesSubscription;

  List<Map<String, dynamic>> _categories = const [];

  bool _categoriesLoading = true;

  late final Stream<List<Map<String, dynamic>>> _productsStream;

  late final Stream<List<Map<String, dynamic>>> _bannersStream;

  StreamSubscription<DatabaseEvent>? _storesSubscription;

  List<Map<String, dynamic>> _stores = const [];

  bool _storesLoading = true;

  @override

  void initState() {

    super.initState();

    _startBannerAutoPlay();

    // احتفظ بنفس الـ streams طوال عمر الشاشة حتى لا تبدأ القراءة من Firebase

    // من جديد مع كل setState (مثل تحديث الموقع أو الكتابة في البحث).

    // الأقسام تبدأ أولًا، وباقي أجزاء الصفحة تعمل باستقلال عنها.

    _categoriesSubscription = homeService.getCategories().listen((items) {

      if (!mounted) return;

      setState(() {

        _categories = _getCategories(items);

        _categoriesLoading = false;

      });

    }, onError: (_) {

      if (!mounted) return;

      setState(() => _categoriesLoading = false);

    });

    _productsStream = homeService.getProducts();

    _bannersStream = homeService.getBanners();

    _storesSubscription =

        FirebaseDatabase.instance.ref('stores').onValue.listen((event) {

      final stores = _parseStores(event.snapshot.value);

      if (!mounted) return;

      setState(() {

        _stores = stores;

        _storesLoading = false;

      });

    }, onError: (_) {

      if (!mounted) return;

      setState(() => _storesLoading = false);

    });

    locationText = 'جاري تحديد موقعك...';

    isLoadingLocation = true;

    _loadLocation();

  }

  void _startBannerAutoPlay() {

    _bannerTimer?.cancel();

    _bannerTimer = Timer.periodic(

      const Duration(seconds: 3),

      (_) {

        if (!mounted || !_bannerController.hasClients) return;

        int nextPage = _currentBanner + 1;

        if (nextPage >= _bannerImages.length) {

          nextPage = 0;

        }

        _bannerController.animateToPage(

          nextPage,

          duration: const Duration(milliseconds: 280),

          curve: Curves.easeOutCubic,

        );

      },

    );

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

      // بعض الأجهزة ترجع null في أول محاولة بعد تفعيل خدمة الموقع/الصلاحية.
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

      } catch (_) {

        areaName = '';

      }

      if (!mounted) return;

      final cleanArea = areaName.trim();

      final finalLocation = cleanArea.isNotEmpty &&

              cleanArea != 'موقعك الحالي' &&

              cleanArea != 'غير معروف'

          ? cleanArea

          : 'موقعك الحالي (${latitude.toStringAsFixed(3)}, ${longitude.toStringAsFixed(3)})';

      await box.write('currentLocationName', finalLocation);

      await box.write('currentLatitude', latitude);

      await box.write('currentLongitude', longitude);

      if (!mounted) return;

      setState(() {

        locationText = finalLocation;

        isLoadingLocation = false;

      });

    } on TimeoutException {

      _finishLocationWithFallback();

    } catch (_) {

      _finishLocationWithFallback();

    }

  }

  void _finishLocationWithFallback() {

    if (!mounted) return;

    final cachedLocation =
        box.read('currentLocationName')?.toString().trim() ?? '';
    final cachedLat = box.read('currentLatitude');
    final cachedLng = box.read('currentLongitude');

    setState(() {
      isLoadingLocation = false;
      if (cachedLocation.isNotEmpty) {
        locationText = cachedLocation;
      } else if (cachedLat != null && cachedLng != null) {
        locationText = 'موقعك الحالي';
      } else {
        locationText = 'اضغط لتحديد موقعك';
      }
    });

  }

  @override

  void dispose() {

    _searchDebounce?.cancel();

    _categoriesSubscription?.cancel();

    _storesSubscription?.cancel();

    searchController.dispose();

    _bannerTimer?.cancel();

    _bannerController.dispose();

    super.dispose();

  }

  void _onSearchChanged(String value) {

    _searchDebounce?.cancel();

    _searchDebounce = Timer(const Duration(milliseconds: 350), () {

      if (!mounted) return;

      final nextQuery = value.trim();

      if (nextQuery == searchQuery) return;

      setState(() => searchQuery = nextQuery);

    });

  }

  List<Map<String, dynamic>> _getCategories(

    List<Map<String, dynamic>> firebaseCategories,

  ) {

    final source = firebaseCategories;

    String normalize(String value) {

      return value

          .trim()

          .toLowerCase()

          .replaceAll('أ', 'ا')

          .replaceAll('إ', 'ا')

          .replaceAll('آ', 'ا')

          .replaceAll('ة', 'ه')

          .replaceAll('ى', 'ي')

          .replaceAll('ؤ', 'و')

          .replaceAll('ئ', 'ي')

          .replaceAll(RegExp(r'\s+'), ' ');

    }

    final hiddenSupermarketNames = <String>{

      'بقاله',

      'البقاله',

      'البان والجبن',

      'الالبان والجبن',

      'البان وجبن',

      'مخبوزات',

      'المخبوزات',

      'منظفات',

      'المنظفات',

      'عطاره',

      'العطاره',

      'عسل',

      'العسل',

      'عسل ومربي',

      'عسل ومنتجات طبيعيه',

      'العسل ومنتجات طبيعيه',

      'مخللات',

      'المخللات',

      'مشروبات',

      'المشروبات',

      'سناكس',

      'وجبات سريعه',

      'مجمدات',

      'المجمدات',

    }.map(normalize).toSet();

    final hiddenSupermarketIds = <String>{

      'grocery',

      'dairy',

      'bakery',

      'cleaning',

      'spices',

      'honey',

      'pickles',

      'drinks',

      'beverages',

      'snacks',

      'fast_food',

      'fastfood',

      'frozen',

    };

    final visible = source.where((category) {

      if (category['isActive'] == false) return false;

      final id = category['id']?.toString().trim().toLowerCase() ?? '';

      final name = normalize(

        category['name']?.toString() ?? '',

      );

      if (hiddenSupermarketIds.contains(id)) {

        return false;

      }

      if (hiddenSupermarketNames.contains(name)) {

        return false;

      }

      return true;

    }).map((category) {

      return Map<String, dynamic>.from(category);

    }).toList();

    visible.sort(

      (a, b) => NumberHelper.toInt(a['sort']).compareTo(

        NumberHelper.toInt(b['sort']),

      ),

    );

    return visible;

  }

  Widget _productsShimmer() {

    return SizedBox(

      height: 250.h,

      child: ListView.separated(

        padding: EdgeInsets.symmetric(horizontal: 18.w),

        scrollDirection: Axis.horizontal,

        reverse: true,

        physics: const NeverScrollableScrollPhysics(),

        itemCount: 3,

        separatorBuilder: (_, __) => SizedBox(width: 14.w),

        itemBuilder: (_, __) {

          return AppSkeleton(

            child: Container(

              width: 172.w,

              padding: EdgeInsets.all(10.w),

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius: BorderRadius.circular(22.r),

              ),

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.end,

                children: [

                  Expanded(

                    child: Container(

                      width: double.infinity,

                      decoration: BoxDecoration(

                        color: Colors.white,

                        borderRadius: BorderRadius.circular(18.r),

                      ),

                    ),

                  ),

                  SizedBox(height: 10.h),

                  Container(

                    width: 70.w,

                    height: 9.h,

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius: BorderRadius.circular(12.r),

                    ),

                  ),

                  SizedBox(height: 7.h),

                  Container(

                    width: double.infinity,

                    height: 13.h,

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius: BorderRadius.circular(12.r),

                    ),

                  ),

                  SizedBox(height: 7.h),

                  Container(

                    width: 110.w,

                    height: 13.h,

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius: BorderRadius.circular(12.r),

                    ),

                  ),

                  SizedBox(height: 12.h),

                  Row(

                    children: [

                      Container(

                        width: 36.w,

                        height: 36.w,

                        decoration: const BoxDecoration(

                          color: Colors.white,

                          shape: BoxShape.circle,

                        ),

                      ),

                      const Spacer(),

                      Container(

                        width: 70.w,

                        height: 15.h,

                        decoration: BoxDecoration(

                          color: Colors.white,

                          borderRadius: BorderRadius.circular(12.r),

                        ),

                      ),

                    ],

                  ),

                ],

              ),

            ),

          );

        },

      ),

    );

  }

  Widget _errorBox(String text) {

    return Container(

      width: double.infinity,

      padding: EdgeInsets.symmetric(

        horizontal: 18.w,

        vertical: 24.h,

      ),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(22.r),

        border: Border.all(

          color: Colors.red.withOpacity(.12),

        ),

      ),

      child: Column(

        children: [

          Icon(

            Icons.cloud_off_rounded,

            color: Colors.grey.shade500,

            size: 38.sp,

          ),

          SizedBox(height: 10.h),

          Text(

            text,

            textAlign: TextAlign.center,

            style: TextStyle(

              color: Colors.grey.shade700,

              fontSize: 13.sp,

              fontWeight: FontWeight.w700,

            ),

          ),

        ],

      ),

    );

  }

  Widget _categoriesShimmer() {

    return SizedBox(

      height: 132.h,

      child: ListView.separated(

        padding: EdgeInsets.symmetric(horizontal: 18.w),

        scrollDirection: Axis.horizontal,

        reverse: true,

        physics: const NeverScrollableScrollPhysics(),

        itemCount: 4,

        separatorBuilder: (_, __) => SizedBox(width: 12.w),

        itemBuilder: (_, __) {

          return SizedBox(

            width: 96.w,

            child: Column(

              children: [

                AppSkeleton(

                  child: Container(

                    width: 92.w,

                    height: 92.w,

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius: BorderRadius.circular(20.r),

                    ),

                  ),

                ),

                SizedBox(height: 8.h),

                AppSkeleton(

                  child: Container(

                    width: 62.w,

                    height: 11.h,

                    decoration: BoxDecoration(

                      color: Colors.white,

                      borderRadius: BorderRadius.circular(12.r),

                    ),

                  ),

                ),

              ],

            ),

          );

        },

      ),

    );

  }

  void _openCategory(Map<String, dynamic> item) {

    final id = item['id']?.toString().trim().toLowerCase() ?? '';

    final name = item['name']?.toString().trim() ?? '';

    final normalizedName = _normalizeStoreCategoryName(name);

    // ============================================

    // Restaurants

    // ============================================

    if (id == 'restaurants' ||

        id == 'restaurant' ||

        normalizedName.contains('مطاعم') ||

        normalizedName.contains('مطعم')) {

      Navigator.of(context).push(

        MaterialPageRoute(

          builder: (_) => CategoryStoresScreen(

            storeType: 'restaurant',

            title: name.isEmpty ? 'المطاعم' : name,

          ),

        ),

      );

      return;

    }

    // ============================================

    // Supermarket

    // ============================================

    if (id == 'supermarket' ||

        id == 'grocery_store' ||

        id == 'grocery' ||

        normalizedName.contains('سوبر ماركت') ||

        normalizedName.contains('سوبرماركت')) {

      Navigator.of(context).push(

        MaterialPageRoute(

          builder: (_) => CategoryStoresScreen(

            storeType: 'supermarket',

            title: name.isEmpty ? 'سوبر ماركت' : name,

          ),

        ),

      );

      return;

    }

    // ============================================

    // Other store categories

    // ============================================

    final storeType = _resolveStoreType(

      id: id,

      normalizedName: normalizedName,

    );

    if (storeType != null) {

      Navigator.of(context).push(

        MaterialPageRoute(

          builder: (_) => CategoryStoresScreen(

            storeType: storeType,

            title: name.isEmpty ? 'المتاجر' : name,

          ),

        ),

      );

      return;

    }

    // ============================================

    // Normal product category fallback

    // ============================================

    context.push(

      AppRoutes.categoryProducts,

      extra: {

        'categoryId': id,

        'categoryName': name,

      },

    );

  }

  String _normalizeStoreCategoryName(String value) {

    return value

        .trim()

        .toLowerCase()

        .replaceAll('أ', 'ا')

        .replaceAll('إ', 'ا')

        .replaceAll('آ', 'ا')

        .replaceAll('ة', 'ه')

        .replaceAll('ى', 'ي')

        .replaceAll('ؤ', 'و')

        .replaceAll('ئ', 'ي')

        .replaceAll(RegExp(r'\s+'), ' ');

  }

  String? _resolveStoreType({

    required String id,

    required String normalizedName,

  }) {

    const typesById = <String, String>{

      'pharmacy': 'pharmacy',

      'pharmacies': 'pharmacy',

      'vegetables': 'vegetables',

      'fruits': 'vegetables',

      'vegetables_fruits': 'vegetables',

      'beauty': 'beauty',

      'cosmetics': 'beauty',

      'meat': 'meat',

      'butcher': 'meat',

      'bakery': 'bakery',

      'bakeries': 'bakery',

      'fish': 'fish',

      'seafood': 'fish',

      'market': 'market',

    };

    if (typesById.containsKey(id)) return typesById[id];

    if (normalizedName.contains('صيدلي')) return 'pharmacy';

    if (normalizedName.contains('خضار') ||

        normalizedName.contains('خضروات') ||

        normalizedName.contains('فاكه') ||

        normalizedName.contains('فواكه') ||

        normalizedName.contains('فواكه وخضروات') ||

        normalizedName.contains('خضروات وفواكه')) {

      return 'vegetables';

    }

    if (normalizedName.contains('تجميل') ||

        normalizedName.contains('عنايه شخصيه')) {

      return 'beauty';

    }

    if (normalizedName.contains('لحوم') || normalizedName.contains('دواجن')) {

      return 'meat';

    }

    if (normalizedName.contains('مخبز') ||

        normalizedName.contains('مخابز') ||

        normalizedName.contains('حلويات')) {

      return 'bakery';

    }

    if (normalizedName.contains('اسماك') ||

        normalizedName.contains('مأكولات بحريه')) {

      return 'fish';

    }

    return null;

  }

  Widget _categoriesGrid(List<Map<String, dynamic>> categories) {

    // أربعة في السطر الأول، ولو كانت الأقسام 7 يظهر ثلاثة في السطر الثاني.

    return Padding(

      padding: EdgeInsets.symmetric(horizontal: 18.w),

      child: GridView.builder(

        padding: EdgeInsets.zero,

        shrinkWrap: true,

        physics: const NeverScrollableScrollPhysics(),

        itemCount: categories.length,

        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(

          crossAxisCount: 4,

          crossAxisSpacing: 10.w,

          mainAxisSpacing: 12.h,

          childAspectRatio: .62,

        ),

        itemBuilder: (_, index) {

          final item = categories[index];

          return _CategoryItem(

            title: item['name']?.toString() ?? '',

            image: item['image']?.toString() ?? '',

            icon: Icons.category_rounded,

            onTap: () => _openCategory(item),

          );

        },

      ),

    );

  }

  Widget _newStoresSection() {

    if (_storesLoading) return _storesShimmer();

    final stores = _stores.map(Map<String, dynamic>.from).toList()

      ..sort(

        (a, b) => NumberHelper.toInt(b['createdAt'])

            .compareTo(NumberHelper.toInt(a['createdAt'])),

      );

    final newest = stores.take(10).toList();

    if (newest.isEmpty) return _emptyText('لا توجد متاجر جديدة حاليًا');

    return _horizontalStores(newest, showDistance: false);

  }

  Widget _nearbyStoresSection() {

    if (_storesLoading) return _storesShimmer();

    final userLat = double.tryParse(

      box.read('currentLatitude')?.toString() ?? '',

    );

    final userLng = double.tryParse(

      box.read('currentLongitude')?.toString() ?? '',

    );

    final stores = _stores.map(Map<String, dynamic>.from).toList();

    for (final store in stores) {

      final lat = _storeLatitude(store);

      final lng = _storeLongitude(store);

      if (userLat != null && userLng != null && lat != null && lng != null) {

        store['_distanceKm'] = _distanceKm(userLat, userLng, lat, lng);

      }

    }

    stores.sort((a, b) {

      final aDistance = double.tryParse(a['_distanceKm']?.toString() ?? '') ??

          double.infinity;

      final bDistance = double.tryParse(b['_distanceKm']?.toString() ?? '') ??

          double.infinity;

      return aDistance.compareTo(bDistance);

    });

    final nearby = stores.take(10).toList();

    if (nearby.isEmpty) {

      return _emptyText('لا توجد متاجر قريبة حاليًا');

    }

    return _horizontalStores(nearby, showDistance: true);

  }

  List<Map<String, dynamic>> _parseStores(dynamic value) {

    if (value == null || value is! Map) return [];

    final stores = <Map<String, dynamic>>[];

    Map<dynamic, dynamic>.from(value).forEach((key, value) {

      if (value is! Map) return;

      final store = Map<String, dynamic>.from(value);

      store['id'] = store['id']?.toString().trim().isNotEmpty == true

          ? store['id'].toString()

          : key.toString();

      if (store['isActive'] != false) {

        stores.add(store);

      }

    });

    return stores;

  }

  double? _storeLatitude(Map<String, dynamic> store) {

    return double.tryParse(

      (store['latitude'] ??

                  store['lat'] ??

                  store['location']?['latitude'] ??

                  store['location']?['lat'])

              ?.toString() ??

          '',

    );

  }

  double? _storeLongitude(Map<String, dynamic> store) {

    return double.tryParse(

      (store['longitude'] ??

                  store['lng'] ??

                  store['location']?['longitude'] ??

                  store['location']?['lng'])

              ?.toString() ??

          '',

    );

  }

  double _distanceKm(

    double lat1,

    double lon1,

    double lat2,

    double lon2,

  ) {

    const earthRadius = 6371.0;

    final dLat = _degreesToRadians(lat2 - lat1);

    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +

        math.cos(_degreesToRadians(lat1)) *

            math.cos(_degreesToRadians(lat2)) *

            math.sin(dLon / 2) *

            math.sin(dLon / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;

  }

  double _degreesToRadians(double degrees) {

    return degrees * math.pi / 180;

  }

  Widget _horizontalStores(

    List<Map<String, dynamic>> stores, {

    required bool showDistance,

  }) {

    return SizedBox(

      height: 228.h,

      child: ListView.separated(

        padding: EdgeInsets.symmetric(horizontal: 18.w),

        scrollDirection: Axis.horizontal,

        reverse: true,

        physics: const BouncingScrollPhysics(),

        itemCount: stores.length,

        separatorBuilder: (_, __) => SizedBox(width: 14.w),

        itemBuilder: (_, index) {

          final store = stores[index];

          return _StoreCard(

            store: store,

            showDistance: showDistance,

            onTap: () => _openStore(store),

          );

        },

      ),

    );

  }

  void _openStore(Map<String, dynamic> store) {

    final type = store['type']?.toString().toLowerCase() ?? '';

    if (type == 'restaurant') {

      context.push(

        AppRoutes.restaurantDetails,

        extra: store,

      );

      return;

    }

    if (type == 'supermarket' || type == 'grocery') {

      context.push(AppRoutes.supermarket);

      return;

    }

    Navigator.of(context).push(

      MaterialPageRoute(

        builder: (_) => StoreProductsScreen(

          store: store,

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

        reverse: true,

        physics: const NeverScrollableScrollPhysics(),

        itemCount: 3,

        separatorBuilder: (_, __) => SizedBox(width: 14.w),

        itemBuilder: (_, __) {

          return AppSkeleton(

            child: Container(

              width: 250.w,

              decoration: BoxDecoration(

                color: Colors.white,

                borderRadius: BorderRadius.circular(24.r),

              ),

            ),

          );

        },

      ),

    );

  }

  bool _handleHomeScroll(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification &&
        notification.metrics.pixels > 80) {
      if (!_showFloatingHeader && mounted) {
        setState(() => _showFloatingHeader = true);
      }

      _scrollStopTimer?.cancel();
      _scrollStopTimer = Timer(const Duration(milliseconds: 650), () {
        if (mounted && _showFloatingHeader) {
          setState(() => _showFloatingHeader = false);
        }
      });
    }

    if (notification.metrics.pixels <= 80 && _showFloatingHeader) {
      _scrollStopTimer?.cancel();
      if (mounted) {
        setState(() => _showFloatingHeader = false);
      }
    }

    return false;
  }

  @override

  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: _handleHomeScroll,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [

          // AppBar يظهر فورًا

          SliverToBoxAdapter(

            child: _pinkAppBar(),

          ),

          SliverToBoxAdapter(

            child: SizedBox(height: 12.h),

          ),

          // البانر له StreamBuilder خاص به

          SliverToBoxAdapter(

            child: _bannersCarousel(),

          ),

          SliverToBoxAdapter(

            child: SizedBox(height: 26.h),

          ),

          // نتائج البحث

          if (searchQuery.isNotEmpty) ...[

            SliverToBoxAdapter(

              child: _sectionTitle('نتائج البحث'),

            ),

            SliverToBoxAdapter(

              child: SizedBox(height: 14.h),

            ),

            SliverToBoxAdapter(child: _searchResults()),

            SliverToBoxAdapter(

              child: SizedBox(height: 26.h),

            ),

          ],

          // هذا أول مصدر بيانات أساسي مستقل؛ لا ينتظر المنتجات أو المتاجر.

          SliverToBoxAdapter(

            child: _sectionTitle(' شوف اقسامنا '),

          ),

          SliverToBoxAdapter(

            child: SizedBox(height: 14.h),

          ),

          SliverToBoxAdapter(child: _categoriesSection()),

          SliverToBoxAdapter(

            child: SizedBox(height: 28.h),

          ),

          SliverToBoxAdapter(

            child: _sectionTitle('جديد على Bringo'),

          ),

          SliverToBoxAdapter(

            child: SizedBox(height: 14.h),

          ),

          SliverToBoxAdapter(

            child: _newStoresSection(),

          ),

          SliverToBoxAdapter(

            child: SizedBox(height: 28.h),

          ),

          SliverToBoxAdapter(

            child: _sectionTitle('متاجر بالقرب منك'),

          ),

          SliverToBoxAdapter(

            child: SizedBox(height: 14.h),

          ),

          SliverToBoxAdapter(

            child: _nearbyStoresSection(),

          ),

          SliverToBoxAdapter(

            child: SizedBox(height: 28.h),

          ),

          // المنتجات لا تظهر في الرئيسية؛ كل قسم يفتح المتاجر الخاصة به.

          SliverToBoxAdapter(

            child: SizedBox(height: 120.h),

          ),
              ],
            ),
          ),
          if (_showFloatingHeader)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _pinkAppBar(),
            ),
        ],
      ),
    );
  }

  Widget _categoriesSection() {

    if (_categoriesLoading) return _categoriesShimmer();

    if (_categories.isEmpty) {

      return Padding(

        padding: EdgeInsets.symmetric(horizontal: 18.w),

        child: _emptyText('لا توجد أقسام متاحة حاليًا'),

      );

    }

    return _categoriesGrid(_categories);

  }

  Widget _searchResults() {

    return StreamBuilder<List<Map<String, dynamic>>>(

      stream: _productsStream,

      builder: (context, snapshot) {

        final loading = snapshot.connectionState == ConnectionState.waiting &&

            !snapshot.hasData;

        if (loading) return _productsShimmer();

        final q = searchQuery.toLowerCase();

        final results = (snapshot.data ?? []).where((product) {

          final name = product['name']?.toString().toLowerCase() ?? '';

          final brand = product['brand']?.toString().toLowerCase() ?? '';

          return product['isAvailable'] != false &&

              (name.contains(q) || brand.contains(q));

        }).toList();

        return Padding(

          padding: EdgeInsets.symmetric(horizontal: 18.w),

          child: results.isEmpty

              ? _emptyText('لا توجد منتجات مطابقة')

              : _horizontalProducts(results),

        );

      },

    );

  }

  Widget _bannersCarousel() {

    return Column(

      children: [

        SizedBox(

          height: 142.h,

          child: PageView.builder(

            controller: _bannerController,

            itemCount: _bannerImages.length,

            physics: const BouncingScrollPhysics(),

            onPageChanged: (index) {

              setState(() {

                _currentBanner = index;

              });

              // يبدأ حساب الـ 4 ثواني من جديد

              // بعد ما المستخدم يحرك الـ banner بنفسه

              _startBannerAutoPlay();

            },

            itemBuilder: (context, index) {

              return Padding(

                padding: EdgeInsets.symmetric(horizontal: 5.w),

                child: ClipRRect(

                  borderRadius: BorderRadius.circular(16.r),

                  child: Image.asset(

                    _bannerImages[index],

                    width: double.infinity,

                    height: 142.h,

                    fit: BoxFit.cover,

                  ),

                ),

              );

            },

          ),

        ),

        SizedBox(height: 9.h),

        // Indicators

        Row(

          mainAxisAlignment: MainAxisAlignment.center,

          children: List.generate(

            _bannerImages.length,

            (index) {

              final bool active = _currentBanner == index;

              return AnimatedContainer(

                duration: const Duration(milliseconds: 250),

                margin: EdgeInsets.symmetric(horizontal: 3.w),

                width: active ? 20.w : 7.w,

                height: 7.h,

                decoration: BoxDecoration(

                  color: active ? AppColors.primary : AppColors.primary,

                  borderRadius: BorderRadius.circular(20.r),

                ),

              );

            },

          ),

        ),

      ],

    );

  }

  Widget _pinkAppBar() {

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

              // =========================

              // Support

              // =========================

              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance.ref('notifications').onValue,
                builder: (context, snapshot) {
                  int unreadCount = 0;
                  final value = snapshot.data?.snapshot.value;
                  if (value is Map) {
                    final currentUserId =
                        (box.read('userId') ?? box.read('uid') ?? box.read('id'))
                            ?.toString();
                    for (final entry in value.values) {
                      if (entry is! Map) continue;
                      final notificationUserId =
                          (entry['userId'] ?? entry['customerId'])?.toString();
                      final belongsToUser = notificationUserId == null ||
                          notificationUserId.isEmpty ||
                          currentUserId == null ||
                          notificationUserId == currentUserId;
                      final isUnread =
                          entry['isRead'] != true && entry['read'] != true;
                      if (belongsToUser && isUnread) unreadCount++;
                    }
                  }

                  return _appBarIcon(
                    icon: Icons.notifications_none_rounded,
                    badgeCount: unreadCount,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                  );
                },
              ),

              SizedBox(width: 8.w),

              // =========================

              // Location

              // =========================

              Expanded(

                child: InkWell(

                  onTap: isLoadingLocation ? null : _loadLocation,

                  borderRadius: BorderRadius.circular(12.r),

                  child: Padding(

                    padding: EdgeInsets.symmetric(

                      horizontal: 6.w,

                      vertical: 3.h,

                    ),

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

                            Icon(

                              Icons.keyboard_arrow_down_rounded,

                              color: AppColors.accent,

                              size: 18.sp,

                            ),

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

                            Icon(

                              Icons.location_on_rounded,

                              color: AppColors.accent,

                              size: 17.sp,

                            ),

                          ],

                        ),

                      ],

                    ),

                  ),

                ),

              ),

              SizedBox(width: 8.w),

              // =========================

              // Search Icon

              // =========================

              _appBarIcon(

                icon: Icons.search_rounded,

                onTap: () {

                  // هنربطها بصفحة البحث بعدين

                },

              ),

              SizedBox(width: 6.w),

              // =========================

              // Cart

              // =========================

              ValueListenableBuilder<List<Map<String, dynamic>>>(
                valueListenable: CartManager.cartNotifier,
                builder: (context, cartItems, _) {
                  final cartCount = cartItems.fold<int>(
                    0,
                    (sum, item) =>
                        sum +
                        (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1),
                  );

                  return _appBarIcon(
                    icon: Icons.shopping_cart_outlined,
                    badgeCount: cartCount,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const CartScreen(),
                        ),
                      );
                    },
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
              Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 21.sp,
                ),
              ),
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

  Widget _bannersSlider() {

    return StreamBuilder<List<Map<String, dynamic>>>(

      stream: _bannersStream,

      builder: (context, snapshot) {

        final bool loading =

            snapshot.connectionState == ConnectionState.waiting &&

                !snapshot.hasData;

        if (loading) {

          return Padding(

            padding: EdgeInsets.symmetric(horizontal: 18.w),

            child: AppSkeleton(

              child: Container(

                height: 155.h,

                width: double.infinity,

                decoration: BoxDecoration(

                  color: Colors.white,

                  borderRadius: BorderRadius.circular(14.r),

                ),

              ),

            ),

          );

        }

        final banners = snapshot.data ?? [];

        if (banners.isEmpty) {

          return Padding(

            padding: EdgeInsets.symmetric(horizontal: 18.w),

            child: _promoBanner(),

          );

        }

        return SizedBox(

          height: 155.h,

          child: PageView.builder(

            reverse: true,

            itemCount: banners.length,

            itemBuilder: (_, index) {

              final item = banners[index];

              return Padding(

                padding: EdgeInsets.symmetric(horizontal: 18.w),

                child: _bannerCard(

                  title: item['title']?.toString() ?? '',

                  subtitle: item['subtitle']?.toString() ?? '',

                  badge: item['badge']?.toString() ?? '',

                  image: item['image']?.toString() ?? '',

                ),

              );

            },

          ),

        );

      },

    );

  }

  Widget _bannerCard({

    required String title,

    required String subtitle,

    required String badge,

    required String image,

  }) {

    return ClipRRect(

      borderRadius: BorderRadius.circular(14.r),

      child: Stack(

        children: [

          Positioned.fill(

            child: image.isEmpty

                ? _promoBanner()

                : _SmartImage(

                    image: image,

                    fit: BoxFit.cover,

                    icon: Icons.local_offer_rounded,

                  ),

          ),

          if (title.isNotEmpty || subtitle.isNotEmpty)

            Positioned(

              right: 18.w,

              top: 18.h,

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.end,

                children: [

                  if (badge.isNotEmpty)

                    Text(

                      badge,

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 13.sp,

                        fontWeight: FontWeight.w900,

                      ),

                    ),

                  Text(

                    title,

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 21.sp,

                      fontWeight: FontWeight.w900,

                    ),

                  ),

                  Text(

                    subtitle,

                    style: TextStyle(

                      color: Colors.white,

                      fontSize: 12.sp,

                      fontWeight: FontWeight.w700,

                    ),

                  ),

                ],

              ),

            ),

        ],

      ),

    );

  }

  Widget _promoBanner() {

    return const Image(image: AssetImage("assets/images/bringo_banner.png"));

  }

  Widget _sectionTitle(String title, {bool timer = false}) {

    return Padding(

      padding: EdgeInsets.symmetric(horizontal: 18.w),

      child: Align(

        alignment: Alignment.centerRight,

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.end,

          children: [

            Text(

              title,

              style: TextStyle(

                color: AppColors.dark,

                fontSize: 16.sp,

                fontWeight: FontWeight.w900,

              ),

            ),

            if (timer)

              Container(

                margin: EdgeInsets.only(top: 6.h),

                padding: EdgeInsets.symmetric(

                  horizontal: 12.w,

                  vertical: 5.h,

                ),

                decoration: BoxDecoration(

                  color: AppColors.softPink,

                  borderRadius: BorderRadius.circular(18.r),

                ),

                child: Text(

                  'عروض مختارة لفترة محدودة',

                  style: TextStyle(

                    color: AppColors.primary,

                    fontSize: 11.sp,

                    fontWeight: FontWeight.w900,

                  ),

                ),

              ),

          ],

        ),

      ),

    );

  }

  Widget _horizontalProducts(List<Map<String, dynamic>> items) {

    return SizedBox(

      height: 250.h,

      child: ListView.separated(

        scrollDirection: Axis.horizontal,

        reverse: true,

        physics: const BouncingScrollPhysics(),

        itemCount: items.length,

        separatorBuilder: (_, __) => SizedBox(width: 14.w),

        itemBuilder: (_, index) {

          final item = items[index];

          return InkWell(

            onTap: () {

              context.push(AppRoutes.productDetails, extra: item);

            },

            child: _ProductCard(

              name: item['name']?.toString() ?? '',

              brand: item['brand']?.toString() ?? '',

              price: item['price']?.toString() ?? '0',

              oldPrice: item['oldPrice']?.toString() ?? '',

              image: item['image']?.toString() ?? '',

            ),

          );

        },

      ),

    );

  }

  Widget _emptyText(String text) {

    return Container(

      width: double.infinity,

      padding: EdgeInsets.symmetric(vertical: 26.h),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(22.r),

      ),

      child: Center(

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

}

class _CategoryItem extends StatelessWidget {

  final String title;

  final String image;

  final IconData icon;

  final VoidCallback onTap;

  const _CategoryItem({

    required this.title,

    required this.image,

    required this.icon,

    required this.onTap,

  });

  @override

  Widget build(BuildContext context) {

    return SizedBox(

      width: 96.w,

      child: InkWell(

        borderRadius: BorderRadius.circular(20.r),

        onTap: onTap,

        child: Column(

          children: [

            SizedBox(

              width: 92.w,

              height: 92.w,

              child: ClipRRect(

                borderRadius: BorderRadius.circular(20.r),

                child: Container(

                  decoration: BoxDecoration(

                    color: Colors.white,

                    borderRadius: BorderRadius.circular(20.r),

                    boxShadow: [

                      BoxShadow(

                        color: Colors.black.withOpacity(.05),

                        blurRadius: 16,

                        offset: const Offset(0, 7),

                      ),

                    ],

                  ),

                  child: _SmartImage(

                    image: image,

                    fit: BoxFit.cover,

                    icon: icon,

                  ),

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

      ),

    );

  }

}

class _StoreCard extends StatelessWidget {

  final Map<String, dynamic> store;

  final bool showDistance;

  final VoidCallback onTap;

  const _StoreCard({

    required this.store,

    required this.showDistance,

    required this.onTap,

  });

  @override

  Widget build(BuildContext context) {

    final name = store['name']?.toString() ?? 'متجر Bringo';

    final image = (store['coverImage'] ?? store['image'])?.toString() ?? '';

    final type = _typeLabel(store['type']?.toString() ?? '');

    final rating = double.tryParse(store['rating']?.toString() ?? '0') ?? 0;

    final deliveryTime =

        store['deliveryTime']?.toString().trim().isNotEmpty == true

            ? store['deliveryTime'].toString()

            : '25 - 35 دقيقة';

    final deliveryFee =

        double.tryParse(store['deliveryFee']?.toString() ?? '0') ?? 0;

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

              color: Colors.black.withOpacity(.05),

              blurRadius: 18,

              offset: const Offset(0, 8),

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

                    _SmartImage(

                      image: image,

                      fit: BoxFit.cover,

                      icon: Icons.storefront_rounded,

                    ),

                    Positioned(

                      top: 9.h,

                      right: 9.w,

                      child: Container(

                        padding: EdgeInsets.symmetric(

                          horizontal: 9.w,

                          vertical: 5.h,

                        ),

                        decoration: BoxDecoration(

                          color: Colors.white.withOpacity(.94),

                          borderRadius: BorderRadius.circular(14.r),

                        ),

                        child: Row(

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            Icon(

                              Icons.star_rounded,

                              color: const Color(0xFFFFB800),

                              size: 15.sp,

                            ),

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

            Text(

              name,

              maxLines: 1,

              overflow: TextOverflow.ellipsis,

              style: TextStyle(

                color: AppColors.dark,

                fontSize: 15.sp,

                fontWeight: FontWeight.w900,

              ),

            ),

            SizedBox(height: 4.h),

            Text(

              type,

              maxLines: 1,

              overflow: TextOverflow.ellipsis,

              style: TextStyle(

                color: Colors.grey.shade600,

                fontSize: 11.sp,

                fontWeight: FontWeight.w700,

              ),

            ),

            SizedBox(height: 8.h),

            Row(

              children: [

                if (showDistance && distance != null)

                  _StoreInfoChip(

                    icon: Icons.near_me_rounded,

                    text: '${distance.toStringAsFixed(1)} كم',

                  ),

                if (showDistance && distance != null) SizedBox(width: 6.w),

                _StoreInfoChip(

                  icon: Icons.delivery_dining_rounded,

                  text: deliveryFee <= 0

                      ? 'توصيل مجاني'

                      : '${deliveryFee.toStringAsFixed(0)} ج',

                ),

                const Spacer(),

                _StoreInfoChip(

                  icon: Icons.schedule_rounded,

                  text: deliveryTime,

                ),

              ],

            ),

          ],

        ),

      ),

    );

  }

  static String _typeLabel(String value) {

    switch (value.toLowerCase()) {

      case 'restaurant':

        return 'مطعم';

      case 'supermarket':

      case 'grocery':

        return 'سوبر ماركت';

      case 'pharmacy':

        return 'صيدلية';

      default:

        return 'متجر';

    }

  }

}

class _StoreInfoChip extends StatelessWidget {

  final IconData icon;

  final String text;

  const _StoreInfoChip({

    required this.icon,

    required this.text,

  });

  @override

  Widget build(BuildContext context) {

    return Row(

      mainAxisSize: MainAxisSize.min,

      children: [

        Icon(

          icon,

          color: AppColors.primary,

          size: 13.sp,

        ),

        SizedBox(width: 3.w),

        Text(

          text,

          style: TextStyle(

            color: Colors.grey.shade700,

            fontSize: 9.5.sp,

            fontWeight: FontWeight.w800,

          ),

        ),

      ],

    );

  }

}

class _ProductCard extends StatelessWidget {

  final String name;

  final String brand;

  final String price;

  final String oldPrice;

  final String image;

  const _ProductCard({

    required this.name,

    required this.brand,

    required this.price,

    required this.oldPrice,

    required this.image,

  });

  @override

  Widget build(BuildContext context) {

    final bool hasOldPrice = oldPrice.trim().isNotEmpty && oldPrice != '0';

    return Container(

      width: 172.w,

      padding: EdgeInsets.all(10.w),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(22.r),

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(.05),

            blurRadius: 16,

            offset: const Offset(0, 7),

          ),

        ],

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.end,

        children: [

          Expanded(

            child: ClipRRect(

              borderRadius: BorderRadius.circular(18.r),

              child: _SmartImage(

                image: image,

                fit: BoxFit.cover,

                icon: Icons.shopping_bag_rounded,

              ),

            ),

          ),

          SizedBox(height: 8.h),

          Text(

            brand,

            maxLines: 1,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(

              color: Colors.grey.shade600,

              fontSize: 10.5.sp,

              fontWeight: FontWeight.w600,

            ),

          ),

          SizedBox(height: 3.h),

          Text(

            name,

            textAlign: TextAlign.right,

            maxLines: 2,

            overflow: TextOverflow.ellipsis,

            style: TextStyle(

              color: AppColors.dark,

              fontSize: 12.5.sp,

              height: 1.25,

              fontWeight: FontWeight.w900,

            ),

          ),

          SizedBox(height: 8.h),

          Row(

            children: [

              Container(

                width: 36.w,

                height: 36.w,

                decoration: const BoxDecoration(

                  color: AppColors.primary,

                  shape: BoxShape.circle,

                ),

                child: Icon(Icons.add, color: Colors.white, size: 22.sp),

              ),

              const Spacer(),

              Column(

                crossAxisAlignment: CrossAxisAlignment.end,

                children: [

                  Text(

                    '$price جنيه',

                    style: TextStyle(

                      color: AppColors.primary,

                      fontSize: 14.sp,

                      fontWeight: FontWeight.w900,

                    ),

                  ),

                  if (hasOldPrice)

                    Text(

                      '$oldPrice جنيه',

                      style: TextStyle(

                        color: Colors.grey,

                        fontSize: 10.sp,

                        decoration: TextDecoration.lineThrough,

                      ),

                    ),

                ],

              ),

            ],

          ),

        ],

      ),

    );

  }

}

class _SmartImage extends StatelessWidget {

  final String image;

  final BoxFit fit;

  final IconData icon;

  const _SmartImage({

    required this.image,

    required this.fit,

    required this.icon,

  });

  @override

  Widget build(BuildContext context) {

    final cleanImage = image.trim();

    if (cleanImage.isEmpty) return _fallback();

    if (cleanImage.startsWith('data:image')) {

      try {

        final base64String = cleanImage.split(',').last;

        final bytes = base64Decode(base64String);

        return Image.memory(

          bytes,

          fit: fit,

          width: double.infinity,

          height: double.infinity,

          gaplessPlayback: true,

        );

      } catch (_) {

        return _fallback();

      }

    }

    if (cleanImage.startsWith('http')) {

      return Image.network(

        cleanImage,

        fit: fit,

        width: double.infinity,

        height: double.infinity,

        gaplessPlayback: true,

        loadingBuilder: (context, child, progress) {

          if (progress == null) return child;

          return _fallback();

        },

        errorBuilder: (_, __, ___) => _fallback(),

      );

    }

    try {

      final bytes = base64Decode(cleanImage);

      return Image.memory(

        bytes,

        fit: fit,

        width: double.infinity,

        height: double.infinity,

        gaplessPlayback: true,

      );

    } catch (_) {

      return _fallback();

    }

  }

  Widget _fallback() {

    return Container(

      width: double.infinity,

      height: double.infinity,

      color: const Color(0xFFFFF7FB),

      padding: EdgeInsets.all(12.w),

      child: Image.asset(

        'assets/images/bringo.png',

        fit: BoxFit.contain,

        errorBuilder: (_, __, ___) => Center(

          child: Icon(

            icon,

            color: AppColors.primary.withOpacity(.45),

            size: 38.sp,

          ),

        ),

      ),

    );

  }

}

class NumberHelper {

  static int toInt(dynamic value) {

    return int.tryParse(value?.toString() ?? '0') ?? 0;

  }

}