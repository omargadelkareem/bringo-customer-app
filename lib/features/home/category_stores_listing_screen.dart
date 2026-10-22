import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/features/home/category_stores_screen.dart' as legacy;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CategoryStoresListingScreen extends StatefulWidget {
  final String storeType;
  final String title;

  const CategoryStoresListingScreen({
    super.key,
    required this.storeType,
    required this.title,
  });

  @override
  State<CategoryStoresListingScreen> createState() =>
      _CategoryStoresListingScreenState();
}

class _CategoryStoresListingScreenState
    extends State<CategoryStoresListingScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _filter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseStores(dynamic value) {
    if (value is! Map) return [];
    final result = <Map<String, dynamic>>[];
    final requestedType = widget.storeType.trim().toLowerCase();

    Map<dynamic, dynamic>.from(value).forEach((key, raw) {
      if (raw is! Map) return;
      final store = Map<String, dynamic>.from(raw);
      store['firebaseKey'] = key.toString();
      store['id'] = store['id']?.toString().trim().isNotEmpty == true
          ? store['id'].toString()
          : key.toString();

      final values = <String>{
        store['type']?.toString().trim().toLowerCase() ?? '',
        store['category']?.toString().trim().toLowerCase() ?? '',
        store['categoryId']?.toString().trim().toLowerCase() ?? '',
      };
      const restaurantAliases = {
        'restaurant',
        'restaurants',
        'food',
        'foods',
        'مطعم',
        'مطاعم',
      };
      final matches = requestedType == 'restaurant'
          ? values.any(restaurantAliases.contains)
          : values.contains(requestedType);
      if (!matches || store['isActive'] == false) return;
      result.add(store);
    });

    result.sort((a, b) {
      final aSort = int.tryParse(a['sort']?.toString() ?? '0') ?? 0;
      final bSort = int.tryParse(b['sort']?.toString() ?? '0') ?? 0;
      return aSort.compareTo(bSort);
    });
    return result;
  }

  List<Map<String, dynamic>> _filterStores(List<Map<String, dynamic>> stores) {
    var result = [...stores];
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((store) {
        final text = [store['name'], store['address'], store['tags']]
            .whereType<Object>()
            .join(' ')
            .toLowerCase();
        return text.contains(q);
      }).toList();
    }

    if (_filter == 'open') {
      result = result.where((store) => store['isOpen'] != false).toList();
    } else if (_filter == 'rating') {
      result.sort((a, b) {
        final ar = double.tryParse(a['rating']?.toString() ?? '0') ?? 0;
        final br = double.tryParse(b['rating']?.toString() ?? '0') ?? 0;
        return br.compareTo(ar);
      });
    } else if (_filter == 'fast') {
      result.sort((a, b) => _minutes(a).compareTo(_minutes(b)));
    }
    return result;
  }

  int _minutes(Map<String, dynamic> store) {
    final text = store['deliveryTime']?.toString() ?? '';
    final match = RegExp(r'\d+').firstMatch(text);
    return int.tryParse(match?.group(0) ?? '') ?? 999;
  }

  String get _searchHint {
    switch (widget.storeType) {
      case 'restaurant':
        return 'دور على مطعم أو أكلة...';
      case 'supermarket':
        return 'دور على سوبر ماركت...';
      case 'pharmacy':
        return 'دور على صيدلية...';
      default:
        return 'دور على متجر...';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F8F6),
        body: SafeArea(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('stores').onValue,
            builder: (context, snapshot) {
              final loading = snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData;
              final stores = loading
                  ? <Map<String, dynamic>>[]
                  : _filterStores(_parseStores(snapshot.data?.snapshot.value));

              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _topBar()),
                  SliverToBoxAdapter(child: _search()),
                  SliverToBoxAdapter(child: _filters()),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 12.h),
                      child: Row(
                        children: [
                          Text(
                            'كل ${widget.title}',
                            style: TextStyle(
                              color: AppColors.dark,
                              fontSize: 20.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          if (!loading)
                            Text(
                              '${stores.length}',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (loading)
                    SliverPadding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, __) => const _LoadingStoreCard(),
                          childCount: 4,
                        ),
                      ),
                    )
                  else if (stores.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _empty(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 110.h),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final store = stores[index];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 18.h),
                              child: _MarketplaceStoreCard(
                                store: store,
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => legacy.StoreProductsScreen(
                                        store: store,
                                      ),
                                    ),
                                  );
                                },
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
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(12.w, 9.h, 16.w, 12.h),
      child: Row(
        children: [
          InkWell(
            onTap: () => Navigator.pop(context),
            borderRadius: BorderRadius.circular(50),
            child: SizedBox(
              width: 42.w,
              height: 42.w,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 19.sp,
                color: AppColors.dark,
              ),
            ),
          ),
          Expanded(
            child: Text(
              widget.title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 19.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(width: 42.w),
        ],
      ),
    );
  }

  Widget _search() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
      child: Container(
        height: 50.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F5F2),
          borderRadius: BorderRadius.circular(14.r),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.dark,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: _searchHint,
            hintStyle: TextStyle(
              color: AppColors.textHint,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.dark,
              size: 22.sp,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: Icon(Icons.close_rounded, size: 19.sp),
                  ),
            contentPadding: EdgeInsets.symmetric(vertical: 14.h),
          ),
        ),
      ),
    );
  }

  Widget _filters() {
    const items = [
      ('all', 'الكل', Icons.grid_view_rounded),
      ('open', 'مفتوح الآن', Icons.storefront_rounded),
      ('rating', 'الأعلى تقييمًا', Icons.star_outline_rounded),
      ('fast', 'الأسرع توصيلًا', Icons.bolt_rounded),
    ];

    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(bottom: 15.h),
      child: SizedBox(
        height: 39.h,
        child: ListView.separated(
          reverse: true,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.symmetric(horizontal: 16.w),
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(width: 8.w),
          itemBuilder: (_, index) {
            final item = items[index];
            final selected = _filter == item.$1;
            return InkWell(
              onTap: () => setState(() => _filter = item.$1),
              borderRadius: BorderRadius.circular(30.r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                decoration: BoxDecoration(
                  color: selected ? AppColors.dark : Colors.white,
                  borderRadius: BorderRadius.circular(30.r),
                  border: Border.all(
                    color: selected ? AppColors.dark : const Color(0xFFE2E4DF),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item.$3,
                      size: 15.sp,
                      color: selected ? Colors.white : AppColors.dark,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      item.$2,
                      style: TextStyle(
                        color: selected ? Colors.white : AppColors.dark,
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
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.storefront_outlined, size: 54.sp, color: AppColors.textHint),
            SizedBox(height: 14.h),
            Text(
              _query.isEmpty ? 'مفيش متاجر متاحة حاليًا' : 'مفيش نتائج للبحث',
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 17.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarketplaceStoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const _MarketplaceStoreCard({required this.store, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString().trim().isNotEmpty == true
        ? store['name'].toString()
        : 'متجر';
    final cover = store['coverImage']?.toString().trim().isNotEmpty == true
        ? store['coverImage'].toString()
        : store['image']?.toString() ?? '';
    final logo = store['image']?.toString() ?? '';
    final tags = store['tags']?.toString() ?? '';
    final address = store['address']?.toString() ?? '';
    final rating = store['rating']?.toString().trim().isNotEmpty == true
        ? store['rating'].toString()
        : '4.5';
    final time = store['deliveryTime']?.toString().trim().isNotEmpty == true
        ? store['deliveryTime'].toString()
        : '25 - 35 دقيقة';
    final fee = store['deliveryFee']?.toString().trim() ?? '';
    final isOpen = store['isOpen'] != false;

    return Opacity(
      opacity: isOpen ? 1 : .72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18.r),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: const Color(0xFFE9EAE6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(17.r)),
                  child: SizedBox(
                    height: 145.h,
                    width: double.infinity,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _StoreImage(image: cover),
                        if (!isOpen)
                          Container(
                            color: Colors.black.withOpacity(.48),
                            alignment: Alignment.center,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 13.w,
                                vertical: 6.h,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20.r),
                              ),
                              child: Text(
                                'مغلق حاليًا',
                                style: TextStyle(
                                  color: AppColors.dark,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ),
                        Positioned(
                          top: 11.h,
                          left: 11.w,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9.w,
                              vertical: 5.h,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(.96),
                              borderRadius: BorderRadius.circular(9.r),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded,
                                    color: const Color(0xFFFFB800), size: 16.sp),
                                SizedBox(width: 3.w),
                                Text(
                                  rating,
                                  style: TextStyle(
                                    color: AppColors.dark,
                                    fontSize: 11.sp,
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
                Padding(
                  padding: EdgeInsets.fromLTRB(13.w, 12.h, 13.w, 13.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 52.w,
                        height: 52.w,
                        padding: EdgeInsets.all(2.w),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: const Color(0xFFE6E7E3)),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.r),
                          child: _StoreImage(image: logo),
                        ),
                      ),
                      SizedBox(width: 11.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: AppColors.dark,
                                fontSize: 15.5.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (tags.trim().isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              Text(
                                tags,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ] else if (address.trim().isNotEmpty) ...[
                              SizedBox(height: 3.h),
                              Text(
                                address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 10.5.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            SizedBox(height: 9.h),
                            Row(
                              children: [
                                _Meta(icon: Icons.schedule_rounded, text: time),
                                SizedBox(width: 12.w),
                                if (fee.isNotEmpty)
                                  _Meta(
                                    icon: Icons.delivery_dining_rounded,
                                    text: '$fee ج.م',
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(top: 16.h),
                        child: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: const Color(0xFFB7BBB4),
                          size: 14.sp,
                        ),
                      ),
                    ],
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

class _Meta extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Meta({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Flexible(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: AppColors.textSecondary),
          SizedBox(width: 4.w),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreImage extends StatelessWidget {
  final String image;
  const _StoreImage({required this.image});

  @override
  Widget build(BuildContext context) {
    final value = image.trim();
    if (value.isEmpty) return _placeholder();
    if (value.startsWith('http')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    try {
      final clean = value.startsWith('data:image') ? value.split(',').last : value;
      return Image.memory(
        base64Decode(clean),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } catch (_) {
      return _placeholder();
    }
  }

  Widget _placeholder() {
    return Container(
      color: const Color(0xFFF0F2EC),
      alignment: Alignment.center,
      child: Icon(
        Icons.storefront_rounded,
        color: AppColors.primary,
        size: 34.sp,
      ),
    );
  }
}

class _LoadingStoreCard extends StatelessWidget {
  const _LoadingStoreCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 225.h,
      margin: EdgeInsets.only(bottom: 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE9EAE6)),
      ),
      child: Column(
        children: [
          Container(
            height: 145.h,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0EC),
              borderRadius: BorderRadius.vertical(top: Radius.circular(17.r)),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(13.w),
            child: Row(
              children: [
                Container(
                  width: 52.w,
                  height: 52.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0EC),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                SizedBox(width: 11.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 12.h, width: 130.w, color: const Color(0xFFEEF0EC)),
                      SizedBox(height: 8.h),
                      Container(height: 9.h, width: 190.w, color: const Color(0xFFEEF0EC)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
