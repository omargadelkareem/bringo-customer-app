import 'dart:convert';
import 'dart:math' as math;

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/core/services/home_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

/// صفحة الأقسام القديمة تم تحويلها إلى صفحة استكشاف للمتاجر.
/// أبقينا اسم CategoriesScreen كما هو حتى لا تحتاج لتعديل الـ Routes.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  final HomeService homeService = HomeService();
  final TextEditingController searchController = TextEditingController();
  final GetStorage box = GetStorage();

  String searchText = '';
  String selectedCategoryId = 'all';
  _ExploreFilter selectedFilter = _ExploreFilter.all;

  final List<Map<String, dynamic>> defaultCategories = [
    {
      'id': 'restaurants',
      'name': 'مطاعم',
      'icon': Icons.restaurant_rounded,
      'isActive': true,
      'sort': 1,
    },
    {
      'id': 'grocery',
      'name': 'سوبر ماركت',
      'icon': Icons.local_grocery_store_rounded,
      'isActive': true,
      'sort': 2,
    },
    {
      'id': 'pharmacy',
      'name': 'صيدليات',
      'icon': Icons.medical_services_rounded,
      'isActive': true,
      'sort': 3,
    },
    {
      'id': 'fruits',
      'name': 'خضروات وفواكه',
      'icon': Icons.eco_rounded,
      'isActive': true,
      'sort': 4,
    },
    {
      'id': 'bakery',
      'name': 'مخبوزات',
      'icon': Icons.bakery_dining_rounded,
      'isActive': true,
      'sort': 5,
    },
    {
      'id': 'beauty',
      'name': 'تجميل وعناية',
      'icon': Icons.face_retouching_natural_rounded,
      'isActive': true,
      'sort': 6,
    },
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _categories(
    List<Map<String, dynamic>> firebaseCategories,
  ) {
    final source = firebaseCategories.isNotEmpty
        ? firebaseCategories
        : defaultCategories;

    final result = source
        .where((item) => item['isActive'] != false)
        .map((item) => Map<String, dynamic>.from(item))
        .toList();

    result.sort(
      (a, b) => _toInt(a['sort']).compareTo(_toInt(b['sort'])),
    );

    return result;
  }

  List<Map<String, dynamic>> _parseStores(dynamic value) {
    if (value == null || value is! Map) return [];

    final stores = <Map<String, dynamic>>[];

    Map<dynamic, dynamic>.from(value).forEach((key, rawValue) {
      if (rawValue is! Map) return;

      final store = Map<String, dynamic>.from(rawValue);
      store['id'] = _firstText([store['id'], key]);

      if (store['isActive'] == false || store['status'] == 'disabled') return;

      final lat = _storeLatitude(store);
      final lng = _storeLongitude(store);
      final userLat = double.tryParse(
        box.read('currentLatitude')?.toString() ?? '',
      );
      final userLng = double.tryParse(
        box.read('currentLongitude')?.toString() ?? '',
      );

      if (lat != null && lng != null && userLat != null && userLng != null) {
        store['_distanceKm'] = _distanceKm(userLat, userLng, lat, lng);
      }

      stores.add(store);
    });

    return stores;
  }

  List<Map<String, dynamic>> _filterAndSortStores(
    List<Map<String, dynamic>> stores,
  ) {
    final query = searchText.trim().toLowerCase();

    final filtered = stores.where((store) {
      final name = _firstText([
        store['name'],
        store['storeName'],
        store['title'],
      ]).toLowerCase();

      final type = _firstText([
        store['type'],
        store['storeType'],
        store['categoryId'],
        store['category'],
      ]).toLowerCase();

      final categoryName = _firstText([
        store['categoryName'],
        store['typeName'],
        store['description'],
      ]).toLowerCase();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          type.contains(query) ||
          categoryName.contains(query);

      final matchesCategory = selectedCategoryId == 'all' ||
          _matchesCategory(store, selectedCategoryId);

      final matchesFilter = switch (selectedFilter) {
        _ExploreFilter.offers => _hasOffer(store),
        _ExploreFilter.openNow => _isOpen(store),
        _ExploreFilter.all ||
        _ExploreFilter.nearby ||
        _ExploreFilter.topRated ||
        _ExploreFilter.fastest ||
        _ExploreFilter.newest => true,
      };

      return matchesSearch && matchesCategory && matchesFilter;
    }).map((e) => Map<String, dynamic>.from(e)).toList();

    filtered.sort((a, b) {
      switch (selectedFilter) {
        case _ExploreFilter.nearby:
          return _distance(a).compareTo(_distance(b));
        case _ExploreFilter.topRated:
          return _rating(b).compareTo(_rating(a));
        case _ExploreFilter.fastest:
          return _deliveryMinutes(a).compareTo(_deliveryMinutes(b));
        case _ExploreFilter.newest:
          return _toInt(b['createdAt']).compareTo(_toInt(a['createdAt']));
        case _ExploreFilter.offers:
          return _discountValue(b).compareTo(_discountValue(a));
        case _ExploreFilter.openNow:
        case _ExploreFilter.all:
          final aFeatured = a['isFeatured'] == true ? 1 : 0;
          final bFeatured = b['isFeatured'] == true ? 1 : 0;
          if (aFeatured != bFeatured) return bFeatured.compareTo(aFeatured);
          return _rating(b).compareTo(_rating(a));
      }
    });

    return filtered;
  }

  bool _matchesCategory(Map<String, dynamic> store, String categoryId) {
    final values = [
      store['type'],
      store['storeType'],
      store['categoryId'],
      store['category'],
    ].map((e) => e?.toString().toLowerCase().trim() ?? '').toList();

    final selected = categoryId.toLowerCase().trim();

    if (selected == 'restaurants') {
      return values.any((v) => v == 'restaurant' || v == 'restaurants');
    }

    if (selected == 'grocery') {
      return values.any(
        (v) => v == 'grocery' || v == 'supermarket' || v == 'market',
      );
    }

    return values.contains(selected);
  }

  void _openStore(Map<String, dynamic> store) {
    final type = _firstText([
      store['type'],
      store['storeType'],
      store['categoryId'],
    ]).toLowerCase();

    if (type == 'restaurant' || type == 'restaurants') {
      context.push(AppRoutes.restaurants);
      return;
    }

    if (type == 'supermarket' || type == 'grocery' || type == 'market') {
      context.push(AppRoutes.supermarket);
      return;
    }

    context.push(
      AppRoutes.categoryProducts,
      extra: {
        'categoryId': type,
        'categoryName': _firstText([
          store['name'],
          store['storeName'],
          'المتجر',
        ]),
        'storeId': store['id']?.toString() ?? '',
        'storeName': _firstText([store['name'], store['storeName']]),
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      body: SafeArea(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: homeService.getCategories(),
          builder: (context, categorySnapshot) {
            final categories = _categories(categorySnapshot.data ?? []);

            return StreamBuilder<DatabaseEvent>(
              stream: FirebaseDatabase.instance.ref('stores').onValue,
              builder: (context, storeSnapshot) {
                final loading = storeSnapshot.connectionState ==
                        ConnectionState.waiting &&
                    !storeSnapshot.hasData;

                final stores = _filterAndSortStores(
                  _parseStores(storeSnapshot.data?.snapshot.value),
                );

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _header()),
                    SliverToBoxAdapter(child: SizedBox(height: 16.h)),
                    SliverToBoxAdapter(child: _searchBox()),
                    SliverToBoxAdapter(child: SizedBox(height: 18.h)),
                    SliverToBoxAdapter(child: _quickFilters()),
                    SliverToBoxAdapter(child: SizedBox(height: 20.h)),
                    SliverToBoxAdapter(child: _categoriesList(categories)),
                    SliverToBoxAdapter(child: SizedBox(height: 24.h)),
                    SliverToBoxAdapter(
                      child: _resultsHeader(stores.length),
                    ),
                    if (loading)
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 120.h),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (_, __) => const _StoreSkeleton(),
                            childCount: 4,
                          ),
                        ),
                      )
                    else if (stores.isEmpty)
                      SliverToBoxAdapter(child: _emptyState())
                    else
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 120.h),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final store = stores[index];
                              return Padding(
                                padding: EdgeInsets.only(bottom: 14.h),
                                child: _ExploreStoreCard(
                                  store: store,
                                  onTap: () => _openStore(store),
                                ),
                              );
                            },
                            childCount: stores.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 0),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(.08),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              Icons.tune_rounded,
              color: AppColors.primary,
              size: 23.sp,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'استكشف Bringo',
                style: TextStyle(
                  color: AppColors.dark,
                  fontSize: 25.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'اكتشف أفضل المتاجر القريبة منك',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      child: Container(
        height: 56.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: AppColors.softPink),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(.05),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: TextField(
          controller: searchController,
          textAlign: TextAlign.right,
          onChanged: (value) => setState(() => searchText = value.trim()),
          decoration: InputDecoration(
            hintText: 'ابحث عن متجر...',
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
            border: InputBorder.none,
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 24.sp,
            ),
            suffixIcon: searchText.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();
                      setState(() => searchText = '');
                    },
                    icon: Icon(Icons.close_rounded, size: 20.sp),
                  ),
          ),
        ),
      ),
    );
  }

  Widget _quickFilters() {
    const filters = [
      _FilterItem(_ExploreFilter.all, 'الكل', Icons.apps_rounded),
      _FilterItem(_ExploreFilter.nearby, 'الأقرب', Icons.near_me_rounded),
      _FilterItem(_ExploreFilter.topRated, 'الأعلى تقييمًا', Icons.star_rounded),
      _FilterItem(_ExploreFilter.fastest, 'الأسرع', Icons.bolt_rounded),
      _FilterItem(_ExploreFilter.newest, 'جديد', Icons.auto_awesome_rounded),
      _FilterItem(_ExploreFilter.offers, 'العروض', Icons.local_offer_rounded),
      _FilterItem(_ExploreFilter.openNow, 'مفتوح الآن', Icons.storefront_rounded),
    ];

    return SizedBox(
      height: 42.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        reverse: true,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, index) {
          final item = filters[index];
          final selected = selectedFilter == item.filter;

          return InkWell(
            borderRadius: BorderRadius.circular(18.r),
            onTap: () => setState(() => selectedFilter = item.filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: EdgeInsets.symmetric(horizontal: 13.w),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.softPink,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    item.icon,
                    size: 16.sp,
                    color: selected ? Colors.white : AppColors.primary,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.dark,
                      fontSize: 11.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _categoriesList(List<Map<String, dynamic>> categories) {
    final allCategories = [
      {
        'id': 'all',
        'name': 'كل المتاجر',
        'icon': Icons.store_mall_directory_rounded,
      },
      ...categories,
    ];

    return SizedBox(
      height: 92.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 18.w),
        reverse: true,
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: allCategories.length,
        separatorBuilder: (_, __) => SizedBox(width: 12.w),
        itemBuilder: (_, index) {
          final item = allCategories[index];
          final id = item['id']?.toString() ?? '';
          final selected = selectedCategoryId == id;

          return InkWell(
            borderRadius: BorderRadius.circular(20.r),
            onTap: () => setState(() => selectedCategoryId = id),
            child: SizedBox(
              width: 74.w,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58.w,
                    height: 58.w,
                    decoration: BoxDecoration(
                      color: selected ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(19.r),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : AppColors.softPink,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(.05),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(
                      item['icon'] is IconData
                          ? item['icon'] as IconData
                          : Icons.category_rounded,
                      color: selected ? Colors.white : AppColors.primary,
                      size: 27.sp,
                    ),
                  ),
                  SizedBox(height: 7.h),
                  Text(
                    item['name']?.toString() ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.dark,
                      fontSize: 10.5.sp,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _resultsHeader(int count) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 18.w),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
            decoration: BoxDecoration(
              color: AppColors.softPink,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Text(
              '$count متجر',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const Spacer(),
          Text(
            _resultsTitle(),
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 19.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  String _resultsTitle() {
    switch (selectedFilter) {
      case _ExploreFilter.nearby:
        return 'المتاجر الأقرب إليك';
      case _ExploreFilter.topRated:
        return 'الأعلى تقييمًا';
      case _ExploreFilter.fastest:
        return 'أسرع المتاجر توصيلًا';
      case _ExploreFilter.newest:
        return 'جديد على Bringo';
      case _ExploreFilter.offers:
        return 'عروض اليوم';
      case _ExploreFilter.openNow:
        return 'المتاجر المفتوحة الآن';
      case _ExploreFilter.all:
        return 'كل المتاجر';
    }
  }

  Widget _emptyState() {
    return Padding(
      padding: EdgeInsets.fromLTRB(30.w, 65.h, 30.w, 120.h),
      child: Column(
        children: [
          Container(
            width: 96.w,
            height: 96.w,
            decoration: const BoxDecoration(
              color: AppColors.softPink,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.storefront_outlined,
              color: AppColors.primary,
              size: 44.sp,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            'لا توجد متاجر مطابقة',
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 19.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            'جرّب تغيير البحث أو اختيار قسم آخر',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
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

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
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

  double _degreesToRadians(double value) => value * math.pi / 180;

  bool _hasOffer(Map<String, dynamic> store) {
    return store['hasOffer'] == true ||
        store['isOffer'] == true ||
        _discountValue(store) > 0;
  }

  bool _isOpen(Map<String, dynamic> store) {
    if (store['isOpen'] is bool) return store['isOpen'] == true;
    final status = _firstText([store['openStatus'], store['status']]);
    return status.isEmpty ||
        status == 'open' ||
        status == 'active' ||
        status == 'مفتوح';
  }

  double _discountValue(Map<String, dynamic> store) {
    return double.tryParse(
          (store['discount'] ?? store['discountPercent'] ?? 0).toString(),
        ) ??
        0;
  }

  double _distance(Map<String, dynamic> store) {
    return double.tryParse(store['_distanceKm']?.toString() ?? '') ??
        double.infinity;
  }

  double _rating(Map<String, dynamic> store) {
    return double.tryParse(store['rating']?.toString() ?? '0') ?? 0;
  }

  int _deliveryMinutes(Map<String, dynamic> store) {
    final direct = _toInt(
      store['deliveryMinutes'] ?? store['estimatedDeliveryMinutes'],
    );
    if (direct > 0) return direct;

    final text = _firstText([store['deliveryTime']]);
    final match = RegExp(r'\d+').firstMatch(text);
    return int.tryParse(match?.group(0) ?? '') ?? 999;
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  int _toInt(dynamic value) {
    return int.tryParse(value?.toString() ?? '0') ?? 0;
  }
}

enum _ExploreFilter {
  all,
  nearby,
  topRated,
  fastest,
  newest,
  offers,
  openNow,
}

class _FilterItem {
  final _ExploreFilter filter;
  final String label;
  final IconData icon;

  const _FilterItem(this.filter, this.label, this.icon);
}

class _ExploreStoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const _ExploreStoreCard({
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = _firstText([
      store['name'],
      store['storeName'],
      store['title'],
      'متجر Bringo',
    ]);
    final image = _firstText([
      store['coverImage'],
      store['bannerImage'],
      store['image'],
      store['logo'],
    ]);
    final type = _typeLabel(
      _firstText([store['type'], store['storeType'], store['categoryName']]),
    );
    final rating =
        double.tryParse(store['rating']?.toString() ?? '0') ?? 0;
    final deliveryFee =
        double.tryParse(store['deliveryFee']?.toString() ?? '0') ?? 0;
    final distance =
        double.tryParse(store['_distanceKm']?.toString() ?? '');
    final deliveryTime = _firstText([
      store['deliveryTime'],
      store['estimatedDeliveryText'],
      '25 - 35 دقيقة',
    ]);
    final isOpen = _isOpen(store);
    final discount = double.tryParse(
          (store['discount'] ?? store['discountPercent'] ?? 0).toString(),
        ) ??
        0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(25.r),
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.055),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(8.w, 6.h, 4.w, 4.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        _StatusBadge(isOpen: isOpen),
                        const Spacer(),
                        Expanded(
                          flex: 3,
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              color: AppColors.dark,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      type,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 13.h),
                    Wrap(
                      alignment: WrapAlignment.end,
                      runSpacing: 7.h,
                      spacing: 7.w,
                      children: [
                        _InfoPill(
                          icon: Icons.star_rounded,
                          text: rating > 0 ? rating.toStringAsFixed(1) : 'جديد',
                          star: true,
                        ),
                        _InfoPill(
                          icon: Icons.schedule_rounded,
                          text: deliveryTime,
                        ),
                        if (distance != null)
                          _InfoPill(
                            icon: Icons.near_me_rounded,
                            text: '${distance.toStringAsFixed(1)} كم',
                          ),
                      ],
                    ),
                    SizedBox(height: 11.h),
                    Row(
                      children: [
                        if (discount > 0)
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.softPink,
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              'خصم ${discount.toStringAsFixed(0)}%',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        const Spacer(),
                        Icon(
                          Icons.delivery_dining_rounded,
                          color: AppColors.primary,
                          size: 16.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          deliveryFee <= 0
                              ? 'توصيل مجاني'
                              : '${deliveryFee.toStringAsFixed(0)} جنيه',
                          style: TextStyle(
                            color: AppColors.dark,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(width: 11.w),
            SizedBox(
              width: 126.w,
              height: 132.h,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20.r),
                child: _SmartImage(
                  image: image,
                  icon: Icons.storefront_rounded,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  static bool _isOpen(Map<String, dynamic> store) {
    if (store['isOpen'] is bool) return store['isOpen'] == true;
    final status = _firstText([store['openStatus'], store['status']]);
    return status.isEmpty ||
        status == 'open' ||
        status == 'active' ||
        status == 'مفتوح';
  }

  static String _typeLabel(String value) {
    switch (value.toLowerCase()) {
      case 'restaurant':
      case 'restaurants':
        return 'مطعم';
      case 'supermarket':
      case 'grocery':
      case 'market':
        return 'سوبر ماركت';
      case 'pharmacy':
        return 'صيدلية';
      case 'bakery':
        return 'مخبوزات';
      case 'fruits':
        return 'خضروات وفواكه';
      default:
        return value.trim().isEmpty ? 'متجر' : value;
    }
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;

  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    final color = isOpen ? const Color(0xFF16A36A) : Colors.red;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: color.withOpacity(.10),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6.w,
            height: 6.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 4.w),
          Text(
            isOpen ? 'مفتوح' : 'مغلق',
            style: TextStyle(
              color: color,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool star;

  const _InfoPill({
    required this.icon,
    required this.text,
    this.star = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FB),
        borderRadius: BorderRadius.circular(11.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13.sp,
            color: star ? const Color(0xFFFFB800) : AppColors.primary,
          ),
          SizedBox(width: 3.w),
          Text(
            text,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 9.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreSkeleton extends StatelessWidget {
  const _StoreSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 152.h,
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _bar(110.w),
                  SizedBox(height: 12.h),
                  _bar(75.w),
                  const Spacer(),
                  _bar(180.w),
                ],
              ),
            ),
          ),
          Container(
            width: 126.w,
            margin: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bar(double width) {
    return Container(
      width: width,
      height: 12.h,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.r),
      ),
    );
  }
}

class _SmartImage extends StatelessWidget {
  final String image;
  final IconData icon;

  const _SmartImage({
    required this.image,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cleanImage = image.trim();

    if (cleanImage.isEmpty) return _fallback();

    if (cleanImage.startsWith('data:image')) {
      try {
        final bytes = base64Decode(cleanImage.split(',').last);
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
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
        fit: BoxFit.cover,
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
        fit: BoxFit.cover,
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
      color: const Color(0xFFFFF7FB),
      child: Center(
        child: Icon(
          icon,
          color: AppColors.primary,
          size: 38.sp,
        ),
      ),
    );
  }
}
