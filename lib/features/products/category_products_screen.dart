import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/core/services/home_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class CategoryProductsScreen extends StatelessWidget {
  final String categoryId;
  final String categoryName;

  const CategoryProductsScreen({
    super.key,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  Widget build(BuildContext context) {
    final homeService = HomeService();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      appBar: AppBar(
        title: Text(categoryName),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.dark,
        elevation: 0,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: homeService.getCategoryProducts(categoryId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }

          if (snapshot.hasError) {
            return const Center(child: Text('تعذر تحميل المنتجات'));
          }

          final products = snapshot.data ?? const <Map<String, dynamic>>[];
          if (products.isEmpty) {
            return const Center(child: Text('لا توجد منتجات في هذا القسم'));
          }

          return GridView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: products.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 14.w,
              mainAxisSpacing: 14.h,
              childAspectRatio: .68,
            ),
            itemBuilder: (_, index) => _ProductCard(product: products[index]),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? '';
    final brand = product['brand']?.toString() ?? '';
    final price = product['price']?.toString() ?? '0';
    final oldPrice = product['oldPrice']?.toString() ?? '';
    final image = product['image']?.toString() ?? '';
    final hasOldPrice = oldPrice.trim().isNotEmpty && oldPrice != '0';

    return InkWell(
      borderRadius: BorderRadius.circular(28.r),
      onTap: () => context.push(AppRoutes.productDetails, extra: product),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(.08),
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
                borderRadius: BorderRadius.circular(22.r),
                child: _SmartImage(image: image),
              ),
            ),
            SizedBox(height: 10.h),
            Text(brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey)),
            SizedBox(height: 4.h),
            Text(
              name,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w800,
                color: AppColors.dark,
              ),
            ),
            SizedBox(height: 8.h),
            Row(
              children: [
                CircleAvatar(
                  radius: 18.r,
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.add, color: Colors.white),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$price جنيه',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w900,
                        )),
                    if (hasOldPrice)
                      Text('$oldPrice جنيه',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 11.sp,
                            decoration: TextDecoration.lineThrough,
                          )),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SmartImage extends StatelessWidget {
  final String image;
  const _SmartImage({required this.image});

  @override
  Widget build(BuildContext context) {
    final value = image.trim();
    if (value.isEmpty) return _fallback();

    if (value.startsWith('data:image') || value.length > 250) {
      try {
        final raw = value.contains(',') ? value.split(',').last : value;
        return Image.memory(
          base64Decode(raw),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      } catch (_) {
        return _fallback();
      }
    }

    if (value.startsWith('http')) {
      return Image.network(
        value,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _fallback(),
      );
    }

    return Image.asset(
      value,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() => Container(
        color: AppColors.softPink,
        alignment: Alignment.center,
        child: const Icon(Icons.image, color: AppColors.primary),
      );
}
