import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'supermarket_store_details_screen.dart';

class SupermarketScreen extends StatefulWidget {
  const SupermarketScreen({super.key});

  @override
  State<SupermarketScreen> createState() => _SupermarketScreenState();
}

class _SupermarketScreenState extends State<SupermarketScreen> {
  final DatabaseReference storesRef =
      FirebaseDatabase.instance.ref('stores');

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  bool _isSupermarket(Map<String, dynamic> store) {
    final type = _normalize(store['type']?.toString() ?? '');
    final name = _normalize(store['name']?.toString() ?? '');
    final tags = _normalize(store['tags']?.toString() ?? '');

    return type == 'supermarket' ||
        type == 'market' ||
        type == 'grocery' ||
        type == 'grocery store' ||
        name.contains('سوبر ماركت') ||
        name.contains('ماركت') ||
        tags.contains('سوبر ماركت');
  }

  String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  List<Map<String, dynamic>> _parseStores(dynamic value) {
    if (value == null || value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(value);
    final stores = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      if (value is! Map) return;

      final store = Map<String, dynamic>.from(value);

      store['firebaseKey'] = key.toString();
      store['id'] = store['id']?.toString().trim().isNotEmpty == true
          ? store['id'].toString()
          : key.toString();

      if (store['isActive'] == false) return;
      if (!_isSupermarket(store)) return;

      stores.add(store);
    });

    stores.sort((a, b) {
      final aSort = int.tryParse(a['sort']?.toString() ?? '0') ?? 0;
      final bSort = int.tryParse(b['sort']?.toString() ?? '0') ?? 0;
      return aSort.compareTo(bSort);
    });

    return stores;
  }

  List<Map<String, dynamic>> _filterStores(
    List<Map<String, dynamic>> stores,
  ) {
    final query = _normalize(searchQuery);

    if (query.isEmpty) return stores;

    return stores.where((store) {
      final name = _normalize(store['name']?.toString() ?? '');
      final address = _normalize(store['address']?.toString() ?? '');
      final tags = _normalize(store['tags']?.toString() ?? '');

      return name.contains(query) ||
          address.contains(query) ||
          tags.contains(query);
    }).toList();
  }

  void _openStore(Map<String, dynamic> store) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SupermarketStoreDetailsScreen(
          store: store,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBFD),
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              SizedBox(height: 14.h),
              _searchBox(),
              SizedBox(height: 16.h),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: storesRef.onValue,
                  builder: (context, snapshot) {
                    final loading =
                        snapshot.connectionState == ConnectionState.waiting &&
                            !snapshot.hasData;

                    if (loading) {
                      return _storesShimmer();
                    }

                    if (snapshot.hasError) {
                      return _messageState(
                        icon: Icons.cloud_off_rounded,
                        title: 'تعذر تحميل المتاجر',
                        subtitle: 'تحقق من الإنترنت وحاول مرة أخرى',
                      );
                    }

                    final stores = _filterStores(
                      _parseStores(snapshot.data?.snapshot.value),
                    );

                    if (stores.isEmpty) {
                      return _messageState(
                        icon: Icons.storefront_outlined,
                        title: searchQuery.trim().isNotEmpty
                            ? 'لا توجد نتائج مطابقة'
                            : 'لا توجد متاجر سوبر ماركت حاليًا',
                        subtitle: searchQuery.trim().isNotEmpty
                            ? 'جرّب البحث باسم متجر آخر'
                            : 'أضف Bringo Market من لوحة الإدارة ليظهر هنا',
                      );
                    }

                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        18.w,
                        0,
                        18.w,
                        120.h,
                      ),
                      physics: const BouncingScrollPhysics(),
                      itemCount: stores.length,
                      separatorBuilder: (_, __) => SizedBox(height: 16.h),
                      itemBuilder: (_, index) {
                        final store = stores[index];

                        return _SupermarketStoreCard(
                          store: store,
                          onTap: () => _openStore(store),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header() {
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 20.h),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [
            Color(0xFFE8007A),
            Color(0xFFFF4FA3),
          ],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30.r),
          bottomRight: Radius.circular(30.r),
        ),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: () => context.pop(),
            borderRadius: BorderRadius.circular(16.r),
            child: Container(
              width: 46.w,
              height: 46.w,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(.18),
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 20.sp,
              ),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'السوبر ماركت',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 27.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'اختر المتجر ثم ابدأ التسوق',
                style: TextStyle(
                  color: Colors.white.withOpacity(.92),
                  fontSize: 12.5.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(width: 12.w),
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18.r),
            ),
            child: Icon(
              Icons.local_grocery_store_rounded,
              color: AppColors.primary,
              size: 28.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchBox() {
    return Container(
      height: 56.h,
      margin: EdgeInsets.symmetric(horizontal: 18.w),
      padding: EdgeInsets.symmetric(horizontal: 14.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: TextField(
        controller: searchController,
        textAlign: TextAlign.right,
        onChanged: (value) {
          setState(() {
            searchQuery = value.trim();
          });
        },
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'ابحث عن سوبر ماركت...',
          suffixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 26.sp,
          ),
          prefixIcon: searchQuery.isEmpty
              ? null
              : IconButton(
                  onPressed: () {
                    searchController.clear();
                    setState(() => searchQuery = '');
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }

  Widget _storesShimmer() {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 120.h),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, __) => SizedBox(height: 16.h),
      itemBuilder: (_, __) {
        return Container(
          height: 250.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          ),
        );
      },
    );
  }

  Widget _messageState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 105.w,
              height: 105.w,
              decoration: const BoxDecoration(
                color: AppColors.softPink,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 52.sp,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 19.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 7.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13.sp,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SupermarketStoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const _SupermarketStoreCard({
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString() ?? 'سوبر ماركت';
    final logo = store['image']?.toString() ?? '';
    final cover = store['coverImage']?.toString() ??
        store['cover']?.toString() ??
        logo;
    final tags = store['tags']?.toString() ?? 'كل احتياجات البيت';
    final address = store['address']?.toString() ?? '';
    final deliveryTime =
        store['deliveryTime']?.toString() ?? '25 - 35 دقيقة';
    final rating = store['rating']?.toString() ?? '4.8';
    final deliveryFee = store['deliveryFee']?.toString() ?? '25';
    final isOpen = store['isOpen'] != false &&
        store['acceptsOrders'] != false;

    return InkWell(
      onTap: isOpen ? onTap : null,
      borderRadius: BorderRadius.circular(28.r),
      child: Opacity(
        opacity: isOpen ? 1 : .72,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28.r),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(.08),
                blurRadius: 22,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28.r),
                    ),
                    child: SizedBox(
                      height: 138.h,
                      width: double.infinity,
                      child: _StoreImage(
                        image: cover,
                        fallbackIcon:
                            Icons.local_grocery_store_rounded,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 16.w,
                    bottom: -31.h,
                    child: Container(
                      width: 68.w,
                      height: 68.w,
                      padding: EdgeInsets.all(5.w),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22.r),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(.12),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18.r),
                        child: _StoreImage(
                          image: logo,
                          fallbackIcon:
                              Icons.local_grocery_store_rounded,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 12.w,
                    top: 12.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(.95),
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Row(
                        children: [
                          Text(
                            rating,
                            style: TextStyle(
                              color: AppColors.dark,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 4.w),
                          Icon(
                            Icons.star_rounded,
                            color: Colors.amber,
                            size: 17.sp,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: 12.w,
                    top: 12.h,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 6.h,
                      ),
                      decoration: BoxDecoration(
                        color: isOpen
                            ? const Color(0xFF16A34A)
                            : const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(18.r),
                      ),
                      child: Text(
                        isOpen ? 'مفتوح' : 'مغلق',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10.5.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 39.h),
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 17.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.dark,
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      tags,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Wrap(
                      spacing: 8.w,
                      runSpacing: 8.h,
                      children: [
                        _StoreInfoChip(
                          icon: Icons.schedule_rounded,
                          text: deliveryTime,
                        ),
                        _StoreInfoChip(
                          icon: Icons.delivery_dining_rounded,
                          text: '$deliveryFee ج توصيل',
                        ),
                      ],
                    ),
                    if (address.trim().isNotEmpty) ...[
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 17.sp,
                          ),
                          SizedBox(width: 5.w),
                          Expanded(
                            child: Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10.w,
        vertical: 7.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.softPink,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 5.w),
          Icon(
            icon,
            color: AppColors.primary,
            size: 15.sp,
          ),
        ],
      ),
    );
  }
}

class _StoreImage extends StatelessWidget {
  final String image;
  final IconData fallbackIcon;

  const _StoreImage({
    required this.image,
    required this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    final cleanImage = image.trim();

    if (cleanImage.isEmpty) return _fallback();

    if (cleanImage.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(cleanImage.split(',').last),
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
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    try {
      return Image.memory(
        base64Decode(cleanImage),
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
      color: AppColors.softPink,
      alignment: Alignment.center,
      child: Icon(
        fallbackIcon,
        color: AppColors.primary,
        size: 36.sp,
      ),
    );
  }
}
