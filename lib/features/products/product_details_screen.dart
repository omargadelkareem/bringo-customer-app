import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/services/home_service.dart';
import 'package:bringo/features/cart/cart_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> product;

  const ProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  final HomeService homeService = HomeService();

  int quantity = 1;

  String get name => widget.product['name']?.toString() ?? '';
  String get brand => widget.product['brand']?.toString() ?? '';
  String get image => widget.product['image']?.toString() ?? '';
  String get categoryId => widget.product['categoryId']?.toString() ?? '';
  String get unit => widget.product['unit']?.toString() ?? 'قطعة';

  double get price =>
      double.tryParse(widget.product['price']?.toString() ?? '0') ?? 0;

  double get oldPrice =>
      double.tryParse(widget.product['oldPrice']?.toString() ?? '0') ?? 0;

  double get total => price * quantity;

  bool get hasOldPrice => oldPrice > price && oldPrice > 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBFD),
      bottomNavigationBar: _bottomAddToCart(),
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _imageHeader()),
            SliverToBoxAdapter(child: _productInfo()),
            SliverToBoxAdapter(child: _deliveryBox()),
            SliverToBoxAdapter(child: _similarProducts()),
            SliverToBoxAdapter(child: SizedBox(height: 120.h)),
          ],
        ),
      ),
    );
  }

  Widget _cartTopButton() {
    final count = CartManager.items.length;

    return InkWell(
      borderRadius: BorderRadius.circular(22.r),
      onTap: () {
        context.push('/cart');
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44.w,
            height: 44.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.95),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.08),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Icon(
              Icons.shopping_cart_rounded,
              color: AppColors.primary,
              size: 22.sp,
            ),
          ),
          if (count > 0)
            Positioned(
              top: -5.h,
              right: -5.w,
              child: Container(
                padding: EdgeInsets.all(5.w),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _imageHeader() {
    return Stack(
      children: [
        Container(
          height: 355.h,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.softPink,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(38.r),
              bottomRight: Radius.circular(38.r),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(38.r),
              bottomRight: Radius.circular(38.r),
            ),
            child: _SmartImage(
              image: image,
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          top: 18.h,
          right: 18.w,
          child: _circleButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => context.pop(),
          ),
        ),
        Positioned(
          top: 18.h,
          left: 18.w,
          child: _cartTopButton(),
        ),
        Positioned(
          bottom: 18.h,
          right: 18.w,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(.95),
              borderRadius: BorderRadius.circular(24.r),
            ),
            child: Row(
              children: [
                Icon(Icons.flash_on_rounded,
                    color: AppColors.primary, size: 18.sp),
                SizedBox(width: 5.w),
                Text(
                  'توصيل سريع',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(22.r),
      onTap: onTap,
      child: Container(
        width: 44.w,
        height: 44.w,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(.95),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.08),
              blurRadius: 18,
              offset: const Offset(0, 7),
            ),
          ],
        ),
        child: Icon(icon, color: AppColors.dark, size: 20.sp),
      ),
    );
  }

  Widget _productInfo() {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 22.h, 18.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (brand.isNotEmpty)
            Text(
              brand,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          SizedBox(height: 6.h),
          Text(
            name,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 25.sp,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 14.h),
          Row(
            children: [
              _quantityBox(),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_formatPrice(price)} جنيه',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (hasOldPrice)
                    Text(
                      '${_formatPrice(oldPrice)} جنيه',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 13.sp,
                        decoration: TextDecoration.lineThrough,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24.r),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(.06),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Text(
              'منتج متوفر الآن من Bringo. يمكنك إضافته للسلة وتحديد الكمية المناسبة، وسيتم توصيل الطلب حتى باب البيت بسرعة.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 14.sp,
                height: 1.7,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _quantityBox() {
    return Container(
      height: 48.h,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(.08),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          _qtyButton(
            icon: Icons.remove,
            onTap: () {
              if (quantity > 1) {
                setState(() => quantity--);
              }
            },
          ),
          SizedBox(
            width: 42.w,
            child: Text(
              '$quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          _qtyButton(
            icon: Icons.add,
            onTap: () {
              setState(() => quantity++);
            },
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18.r),
      onTap: onTap,
      child: Container(
        width: 34.w,
        height: 34.w,
        decoration: const BoxDecoration(
          color: AppColors.softPink,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.primary, size: 19.sp),
      ),
    );
  }

  Widget _deliveryBox() {
    return Padding(
      padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 0),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: AppColors.softPink),
        ),
        child: Row(
          children: [
            Container(
              width: 48.w,
              height: 48.w,
              decoration: const BoxDecoration(
                color: AppColors.softPink,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.delivery_dining_rounded,
                  color: AppColors.primary, size: 26.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'يوصل خلال 20 - 35 دقيقة',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: AppColors.dark,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'الدفع عند الاستلام متاح حاليًا',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _similarProducts() {
    return Padding(
      padding: EdgeInsets.only(top: 24.h),
      child: StreamBuilder<List<Map<String, dynamic>>>(
        stream: homeService.getProducts(),
        builder: (context, snapshot) {
          final allProducts = snapshot.data ?? [];

          final similar = allProducts.where((p) {
            final sameCategory = p['categoryId']?.toString() == categoryId;
            final notSameProduct =
                p['id']?.toString() != widget.product['id']?.toString();
            final available = p['isAvailable'] != false;

            return sameCategory && notSameProduct && available;
          }).toList();

          if (similar.isEmpty) {
            return const SizedBox.shrink();
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 18.w),
                child: Text(
                  'منتجات مماثلة',
                  style: TextStyle(
                    fontSize: 20.sp,
                    color: AppColors.dark,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              SizedBox(
                height: 245.h,
                child: ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 18.w),
                  scrollDirection: Axis.horizontal,
                  reverse: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: similar.length,
                  separatorBuilder: (_, __) => SizedBox(width: 14.w),
                  itemBuilder: (_, index) {
                    final item = similar[index];

                    return _SimilarProductCard(
                      product: item,
                      onTap: () {
                        context.pushReplacement(
                          '/product-details',
                          extra: item,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _bottomAddToCart() {
    return Container(
      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 18.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              height: 56.h,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: AppColors.softPink,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Center(
                child: Text(
                  '${_formatPrice(total)} جنيه',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: SizedBox(
                height: 56.h,
                child: ElevatedButton(
                  onPressed: () {
                    CartManager.addProduct(widget.product, quantity);

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        backgroundColor: AppColors.primary,
                        content: Text(
                          'تم إضافة $quantity × $name إلى السلة',
                          textAlign: TextAlign.right,
                        ),
                      ),
                    );

                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                  ),
                  child: Text(
                    'إضافة للسلة',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double value) {
    if (value % 1 == 0) return value.toInt().toString();
    return value.toStringAsFixed(2);
  }
}

class _SimilarProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _SimilarProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? '';
    final brand = product['brand']?.toString() ?? '';
    final image = product['image']?.toString() ?? '';
    final price = product['price']?.toString() ?? '0';

    return InkWell(
      borderRadius: BorderRadius.circular(26.r),
      onTap: onTap,
      child: Container(
        width: 160.w,
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(26.r),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(.07),
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
                borderRadius: BorderRadius.circular(20.r),
                child: _SmartImage(
                  image: image,
                  fit: BoxFit.cover,
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
                fontSize: 12.sp,
                height: 1.25,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 7.h),
            Row(
              children: [
                CircleAvatar(
                  radius: 15.r,
                  backgroundColor: AppColors.primary,
                  child: Icon(Icons.add, color: Colors.white, size: 18.sp),
                ),
                const Spacer(),
                Text(
                  '$price جنيه',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                  ),
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
  final BoxFit fit;

  const _SmartImage({
    required this.image,
    required this.fit,
  });

  @override
  Widget build(BuildContext context) {
    if (image.isEmpty) {
      return _fallback();
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
        );
      } catch (_) {
        return _fallback();
      }
    }

    return Image.network(
      image,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _fallback(),
    );
  }

  Widget _fallback() {
    return Container(
      color: AppColors.softPink,
      child: Icon(
        Icons.image,
        color: AppColors.primary,
        size: 40.sp,
      ),
    );
  }
}
