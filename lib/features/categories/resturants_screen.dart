import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class RestaurantsScreen extends StatefulWidget {
  const RestaurantsScreen({super.key});

  @override
  State<RestaurantsScreen> createState() => _RestaurantsScreenState();
}

class _RestaurantsScreenState extends State<RestaurantsScreen> {
  final DatabaseReference restaurantsRef =
      FirebaseDatabase.instance.ref('stores');

  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseRestaurants(DatabaseEvent event) {
    if (event.snapshot.value == null) return [];

    final rawData = event.snapshot.value;

    if (rawData is! Map) return [];

    final data = Map<dynamic, dynamic>.from(rawData);
    final List<Map<String, dynamic>> restaurants = [];

    data.forEach((key, value) {
      if (value is! Map) return;

      final item = Map<String, dynamic>.from(value);

      item['firebaseKey'] = key.toString();
      item['id'] = item['id']?.toString() ?? key.toString();

      // عرض المطاعم فقط
      if (item['type']?.toString() != 'restaurant') return;

      // إخفاء المتاجر غير المفعلة
      if (item['isActive'] == false) return;

      restaurants.add(item);
    });

    restaurants.sort((a, b) {
      final aSort = int.tryParse(a['sort']?.toString() ?? '0') ?? 0;
      final bSort = int.tryParse(b['sort']?.toString() ?? '0') ?? 0;

      return aSort.compareTo(bSort);
    });

    return restaurants;
  }

  List<Map<String, dynamic>> _filterRestaurants(
    List<Map<String, dynamic>> restaurants,
  ) {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) return restaurants;

    return restaurants.where((restaurant) {
      final name = restaurant['name']?.toString().toLowerCase() ?? '';
      final address = restaurant['address']?.toString().toLowerCase() ?? '';
      final tags = restaurant['tags']?.toString().toLowerCase() ?? '';

      return name.contains(query) ||
          address.contains(query) ||
          tags.contains(query);
    }).toList();
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
              _header(context),
              SizedBox(height: 14.h),
              _searchBox(),
              SizedBox(height: 14.h),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: restaurantsRef.onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      );
                    }

                    final restaurants = _filterRestaurants(
                      _parseRestaurants(snapshot.data!),
                    );

                    if (restaurants.isEmpty) {
                      return _emptyState();
                    }

                    return ListView.separated(
                      padding: EdgeInsets.fromLTRB(18.w, 0, 18.w, 120.h),
                      physics: const BouncingScrollPhysics(),
                      itemCount: restaurants.length,
                      separatorBuilder: (_, __) => SizedBox(height: 16.h),
                      itemBuilder: (context, index) {
                        return _RestaurantCard(
                          restaurant: restaurants[index],
                          onTap: () {
                            context.push(
                              AppRoutes.restaurantDetails,
                              extra: restaurants[index],
                            );
                          },
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

  Widget _header(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 16.h, 18.w, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Container(
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
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.dark,
                size: 20.sp,
              ),
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'المطاعم',
                style: TextStyle(
                  color: AppColors.dark,
                  fontSize: 27.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'اختار مطعمك واطلب أكلك بسهولة',
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
    return Container(
      height: 54.h,
      margin: EdgeInsets.symmetric(horizontal: 18.w),
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.06),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 24.sp,
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: TextField(
              controller: searchController,
              textAlign: TextAlign.right,
              onChanged: (value) {
                setState(() => searchQuery = value);
              },
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'ابحث عن مطعم أو أكلة...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(26.w),
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
                Icons.restaurant_menu_rounded,
                color: AppColors.primary,
                size: 55.sp,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              'لا توجد مطاعم حالياً',
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 20.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              'سيتم إضافة المطاعم المتاحة قريباً',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onTap;

  const _RestaurantCard({
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = restaurant['name']?.toString() ?? 'مطعم';
    final image = restaurant['image']?.toString() ?? '';
    final coverImage = restaurant['coverImage']?.toString() ?? '';
    final address = restaurant['address']?.toString() ?? 'سوهاج';
    final deliveryTime =
        restaurant['deliveryTime']?.toString() ?? '25 - 35 دقيقة';
    final minOrder = restaurant['minOrder']?.toString() ?? '0';
    final rating = restaurant['rating']?.toString() ?? '4.5';
    final tags = restaurant['tags']?.toString() ?? 'وجبات سريعة';

    return GestureDetector(
      onTap: onTap,
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
                    height: 135.h,
                    width: double.infinity,
                    child: _SmartImage(
                      image: coverImage.isNotEmpty ? coverImage : image,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                Positioned(
                  right: 16.w,
                  bottom: -31.h,
                  child: Container(
                    width: 66.w,
                    height: 66.w,
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
                      child: _SmartImage(image: image),
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
              ],
            ),
            SizedBox(height: 38.h),
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.dark,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 6.h),
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
                  Row(
                    children: [
                      _MiniInfo(
                        icon: Icons.timer_rounded,
                        text: deliveryTime,
                      ),
                      SizedBox(width: 8.w),
                      _MiniInfo(
                        icon: Icons.shopping_bag_outlined,
                        text: minOrder == '0'
                            ? 'بدون حد أدنى'
                            : 'حد أدنى $minOrder ج',
                      ),
                      const Spacer(),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: AppColors.primary,
                        size: 17.sp,
                      ),
                      SizedBox(width: 4.w),
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MiniInfo({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: AppColors.softPink,
        borderRadius: BorderRadius.circular(14.r),
      ),
      child: Row(
        children: [
          Text(
            text,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 4.w),
          Icon(icon, color: AppColors.primary, size: 14.sp),
        ],
      ),
    );
  }
}

class _SmartImage extends StatelessWidget {
  final String image;
  final BoxFit fit;

  const _SmartImage({
    required this.image,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    if (image.trim().isEmpty) {
      return _placeholder();
    }

    if (image.startsWith('http')) {
      return Image.network(
        image,
        fit: fit,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _placeholder();
        },
      );
    }

    if (image.startsWith('data:image')) {
      try {
        final base64String = image.split(',').last;
        final bytes = base64Decode(base64String);

        return Image.memory(
          bytes,
          fit: fit,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _placeholder(),
        );
      } catch (_) {
        return _placeholder();
      }
    }

    try {
      final bytes = base64Decode(image);

      return Image.memory(
        bytes,
        fit: fit,
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
      width: double.infinity,
      height: double.infinity,
      color: AppColors.softPink,
      child: Center(
        child: Icon(
          Icons.restaurant_rounded,
          color: AppColors.primary,
          size: 32.sp,
        ),
      ),
    );
  }
}
