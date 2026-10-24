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

  List<Map<String, dynamic>> _searchStores(
    List<Map<String, dynamic>> stores,
  ) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return stores;

    return stores.where((store) {
      final text = [
        store['name'],
        store['address'],
        store['tags'],
      ].whereType<Object>().join(' ').toLowerCase();
      return text.contains(q);
    }).toList();
  }

  String get _searchHint {
    switch (widget.storeType) {
      case 'restaurant':
        return 'ابحث عن مطعم أو أكلة';
      case 'supermarket':
        return 'ابحث عن سوبر ماركت';
      case 'pharmacy':
        return 'ابحث عن صيدلية';
      default:
        return 'ابحث في ${widget.title}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance.ref('stores').onValue,
            builder: (context, snapshot) {
              final loading =
                  snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData;
              final stores = loading
                  ? <Map<String, dynamic>>[]
                  : _searchStores(
                      _parseStores(snapshot.data?.snapshot.value),
                    );

              return CustomScrollView(
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                slivers: [
                  SliverToBoxAdapter(child: _topBar()),
                  SliverToBoxAdapter(child: _search()),
                  if (loading)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 100.h),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, __) => const _LoadingStoreCard(),
                          childCount: 5,
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
                      padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 110.h),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final store = stores[index];
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: _DeliveryStoreCard(
                                store: store,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        legacy.StoreProductsScreen(store: store),
                                  ),
                                ),
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
    return Padding(
      padding: EdgeInsets.fromLTRB(8.w, 8.h, 8.w, 6.h),
      child: SizedBox(
        height: 44.h,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 19.sp,
                  color: AppColors.dark,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 52.w),
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.dark,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _search() {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 12.h),
      child: Container(
        height: 46.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF4F4F2),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _query = value),
          textInputAction: TextInputAction.search,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: AppColors.dark,
          ),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: _searchHint,
            hintStyle: TextStyle(
              color: AppColors.textHint,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.textSecondary,
              size: 21.sp,
            ),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _query = '');
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18.sp,
                      color: AppColors.textSecondary,
                    ),
                  ),
            contentPadding: EdgeInsets.symmetric(vertical: 13.h),
          ),
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
            Icon(
              Icons.storefront_outlined,
              size: 48.sp,
              color: AppColors.textHint,
            ),
            SizedBox(height: 12.h),
            Text(
              _query.isEmpty
                  ? 'مفيش متاجر متاحة حاليًا'
                  : 'مفيش نتائج للبحث',
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 16.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeliveryStoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const _DeliveryStoreCard({
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString().trim().isNotEmpty == true
        ? store['name'].toString()
        : 'متجر';
    final image = store['coverImage']?.toString().trim().isNotEmpty == true
        ? store['coverImage'].toString()
        : store['image']?.toString() ?? '';
    final tags = store['tags']?.toString().trim() ?? '';
    final address = store['address']?.toString().trim() ?? '';
    final rating = store['rating']?.toString().trim() ?? '';
    final time = store['deliveryTime']?.toString().trim().isNotEmpty == true
        ? store['deliveryTime'].toString()
        : '25 - 35 دقيقة';
    final fee = store['deliveryFee']?.toString().trim() ?? '';
    final isOpen = store['isOpen'] != false;
    final subtitle = tags.isNotEmpty ? tags : address;

    return Opacity(
      opacity: isOpen ? 1 : .62,
      child: Material(
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12.r),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 5.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10.r),
                  child: SizedBox(
                    width: 104.w,
                    height: 92.h,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _StoreImage(image: image),
                        if (!isOpen)
                          Container(
                            color: Colors.black.withOpacity(.42),
                            alignment: Alignment.center,
                            child: Text(
                              'مغلق',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                        if (subtitle.isNotEmpty) ...[
                          SizedBox(height: 4.h),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        SizedBox(height: 9.h),
                        Wrap(
                          spacing: 7.w,
                          runSpacing: 4.h,
                          children: [
                            _InlineMeta(
                              icon: Icons.schedule_rounded,
                              text: time,
                            ),
                            if (fee.isNotEmpty)
                              _InlineMeta(
                                icon: Icons.delivery_dining_outlined,
                                text: '$fee ج.م',
                              ),
                            if (rating.isNotEmpty)
                              _InlineMeta(
                                icon: Icons.star_rounded,
                                text: rating,
                                star: true,
                              ),
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

class _InlineMeta extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool star;

  const _InlineMeta({
    required this.icon,
    required this.text,
    this.star = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 13.sp,
          color: star ? const Color(0xFFFFB000) : AppColors.textSecondary,
        ),
        SizedBox(width: 3.w),
        Text(
          text,
          maxLines: 1,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
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

    if (value.startsWith('assets/')) {
      return Image.asset(
        value,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    try {
      final clean = value.startsWith('data:image')
          ? value.split(',').last
          : value;
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
        size: 30.sp,
      ),
    );
  }
}

class _LoadingStoreCard extends StatelessWidget {
  const _LoadingStoreCard();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Container(
            width: 104.w,
            height: 92.h,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF0EC),
              borderRadius: BorderRadius.circular(10.r),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 13.h,
                  width: 130.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0EC),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 9.h),
                Container(
                  height: 10.h,
                  width: 180.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0EC),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(height: 12.h),
                Container(
                  height: 9.h,
                  width: 110.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF0EC),
                    borderRadius: BorderRadius.circular(4.r),
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
