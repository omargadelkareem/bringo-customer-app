import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/core/widgets/app_skeleton.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class SupermarketStoreDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  const SupermarketStoreDetailsScreen({
    super.key,
    required this.store,
  });

  @override
  State<SupermarketStoreDetailsScreen> createState() =>
      _SupermarketStoreDetailsScreenState();
}

class _SupermarketStoreDetailsScreenState
    extends State<SupermarketStoreDetailsScreen> {
  String selectedCategory = 'all';
  String get storeId =>
      widget.store['id']?.toString().trim().isNotEmpty == true
          ? widget.store['id'].toString()
          : widget.store['firebaseKey']?.toString() ?? '';

  String get storeName =>
      widget.store['name']?.toString() ?? 'سوبر ماركت';

  String get storeLogo =>
      widget.store['image']?.toString() ?? '';

  String get storeCover =>
      widget.store['coverImage']?.toString() ??
      widget.store['cover']?.toString() ??
      storeLogo;


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

  List<Map<String, dynamic>> _parseProducts(dynamic value) {
    if (value == null || value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(value);
    final products = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      if (value is! Map) return;

      final product = Map<String, dynamic>.from(value);
      product['firebaseKey'] = key.toString();
      product['id'] = product['id']?.toString().trim().isNotEmpty == true
          ? product['id'].toString()
          : key.toString();

      if (product['isAvailable'] == false) return;

      products.add(product);
    });

    products.sort((a, b) {
      final aSort = int.tryParse(a['sort']?.toString() ?? '0') ?? 0;
      final bSort = int.tryParse(b['sort']?.toString() ?? '0') ?? 0;
      return aSort.compareTo(bSort);
    });

    return products;
  }

  static const List<_StoreCategoryDefinition> _fixedCategories = [
    _StoreCategoryDefinition(
      id: 'grocery',
      title: 'البقالة',
      keywords: [
        'بقالة',
        'سكر',
        'ارز',
        'رز',
        'مكرونة',
        'زيت',
        'دقيق',
        'صلصة',
        'بقوليات',
        'فول',
        'عدس',
        'تونة',
        'معلبات',
        'توابل',
        'عسل',
        'مربى',
      ],
    ),
    _StoreCategoryDefinition(
      id: 'pampers',
      title: 'البامبرز',
      keywords: [
        'بامبرز',
        'حفاض',
        'حفاضات',
        'ديابر',
        'diaper',
        'pampers',
        'مناديل مبللة',
        'بيبي',
      ],
    ),
    _StoreCategoryDefinition(
      id: 'dairy',
      title: 'الألبان',
      keywords: [
        'البان',
        'لبن',
        'حليب',
        'جبن',
        'جبنة',
        'زبادي',
        'قشطة',
        'قشطه',
        'زبدة',
        'زبده',
        'سمنة',
        'سمنه',
      ],
    ),
    _StoreCategoryDefinition(
      id: 'drinks',
      title: 'المشروبات',
      keywords: [
        'مشروبات',
        'مشروب',
        'مياه',
        'ماء',
        'عصير',
        'بيبسي',
        'كوكا',
        'سفن',
        'شاي',
        'قهوة',
        'قهوه',
        'نسكافيه',
        'لبن رايب',
      ],
    ),
    _StoreCategoryDefinition(
      id: 'fast_food',
      title: 'الوجبات السريعة',
      keywords: [
        'وجبات سريعة',
        'سناكس',
        'شيبسي',
        'بسكويت',
        'شوكولاتة',
        'شوكولاته',
        'اندومي',
        'نودلز',
        'كيك',
        'كورن فليكس',
        'مقرمشات',
        'فشار',
      ],
    ),
  ];

  String _productCategoryText(Map<String, dynamic> product) {
    return _normalize(
      [
        product['categoryName'],
        product['menuCategoryName'],
        product['sectionName'],
        product['category'],
        product['name'],
        product['brand'],
      ].whereType<Object>().map((value) => value.toString()).join(' '),
    );
  }

  String _productGroup(Map<String, dynamic> product) {
    final text = _productCategoryText(product);

    for (final category in _fixedCategories) {
      final matches = category.keywords.any(
        (keyword) => text.contains(_normalize(keyword)),
      );

      if (matches) return category.id;
    }

    // أي منتج غير معروف يظل ظاهرًا داخل "الكل" فقط،
    // ولا ينشئ تبويبًا عشوائيًا مثل مطاعم أو أقسام خارج السوبر ماركت.
    return 'other';
  }

  List<_StoreCategory> _buildCategories(
    List<Map<String, dynamic>> products,
  ) {
    String firstImageFor(String categoryId) {
      for (final product in products) {
        if (_productGroup(product) != categoryId) continue;

        final image = product['image']?.toString().trim() ?? '';
        if (image.isNotEmpty) return image;
      }

      return storeLogo;
    }

    return [
      _StoreCategory(
        id: 'all',
        title: 'الكل',
        image: storeLogo,
      ),
      ..._fixedCategories.map(
        (category) => _StoreCategory(
          id: category.id,
          title: category.title,
          image: firstImageFor(category.id),
        ),
      ),
    ];
  }

  List<Map<String, dynamic>> _filterProducts(
    List<Map<String, dynamic>> products,
  ) {
    if (selectedCategory == 'all') {
      return products;
    }

    return products
        .where(
          (product) => _productGroup(product) == selectedCategory,
        )
        .toList();
  }

  void _openProduct(Map<String, dynamic> product) {
    final productWithStore = <String, dynamic>{
      ...product,
      'storeId': storeId,
      'storeName': storeName,
      'storeType':
          widget.store['type']?.toString() ?? 'supermarket',
    };

    context.push(
      AppRoutes.productDetails,
      extra: productWithStore,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFFFFBFD),
        body: StreamBuilder<DatabaseEvent>(
          stream: FirebaseDatabase.instance
              .ref('products')
              .orderByChild('storeId')
              .equalTo(storeId)
              .onValue,
          builder: (context, snapshot) {
            final loading =
                snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

            final allProducts = _parseProducts(
              snapshot.data?.snapshot.value,
            );

            final categories = _buildCategories(allProducts);

            if (!categories.any(
              (category) => category.id == selectedCategory,
            )) {
              selectedCategory = 'all';
            }

            final products = _filterProducts(allProducts);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _storeAppBar(),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: Offset(0, -22.h),
                    child: _storeInfoCard(),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    minHeight: 124.h,
                    maxHeight: 124.h,
                    child: Container(
                      color: const Color(0xFFFFFBFD),
                      child: _categoryTabs(
                        categories,
                        loading: loading,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _resultsHeader(
                    loading ? null : products.length,
                  ),
                ),
                if (loading)
                  _productsLoading()
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(
                      icon: Icons.cloud_off_rounded,
                      title: 'تعذر تحميل المنتجات',
                      subtitle:
                          'تحقق من اتصال الإنترنت وحاول مرة أخرى',
                    ),
                  )
                else if (products.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'لا توجد منتجات في هذا القسم',
                      subtitle: 'سيتم إضافة المنتجات قريبًا',
                    ),
                  )
                else
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      14.w,
                      14.h,
                      14.w,
                      130.h,
                    ),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final product = products[index];

                          return _StoreProductCard(
                            product: product,
                            onTap: () => _openProduct(product),
                          );
                        },
                        childCount: products.length,
                      ),
                      gridDelegate:
                          SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12.w,
                        mainAxisSpacing: 14.h,
                        childAspectRatio: .68,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  SliverAppBar _storeAppBar() {
    return SliverAppBar(
      expandedHeight: 245.h,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      leadingWidth: 64.w,
      leading: Padding(
        padding: EdgeInsets.only(
          right: 12.w,
          top: 8.h,
          bottom: 8.h,
        ),
        child: _circleButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            _ProductImage(
              image: storeCover,
              fallbackIcon:
                  Icons.local_grocery_store_rounded,
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x44000000),
                    Color(0x11000000),
                    Color(0xCC000000),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 18.w,
              left: 18.w,
              bottom: 28.h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 78.w,
                    height: 78.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(23.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.18),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(19.r),
                      child: _ProductImage(
                        image: storeLogo,
                        fallbackIcon:
                            Icons.local_grocery_store_rounded,
                      ),
                    ),
                  ),
                  SizedBox(width: 13.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          widget.store['tags']?.toString() ??
                              'كل احتياجات البيت في مكان واحد',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.9),
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
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

  Widget _circleButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: SizedBox(
          width: 44.w,
          height: 44.w,
          child: Icon(
            icon,
            color: AppColors.dark,
            size: 21.sp,
          ),
        ),
      ),
    );
  }

  Widget _storeInfoCard() {
    final deliveryTime =
        widget.store['deliveryTime']?.toString() ??
            '25 - 35 دقيقة';

    final rating =
        widget.store['rating']?.toString() ?? '4.8';

    final deliveryFee =
        widget.store['deliveryFee']?.toString() ?? '25';

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 16.h,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.07),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _infoItem(
              icon: Icons.star_rounded,
              iconColor: const Color(0xFFF59E0B),
              title: rating,
              subtitle: 'التقييم',
            ),
          ),
          _divider(),
          Expanded(
            child: _infoItem(
              icon: Icons.delivery_dining_rounded,
              iconColor: AppColors.primary,
              title: '$deliveryFee جنيه',
              subtitle: 'رسوم التوصيل',
            ),
          ),
          _divider(),
          Expanded(
            child: _infoItem(
              icon: Icons.schedule_rounded,
              iconColor: const Color(0xFF7C3AED),
              title: deliveryTime,
              subtitle: 'وقت التوصيل',
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      width: 1,
      height: 46.h,
      color: Colors.grey.shade200,
    );
  }

  Widget _infoItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          color: iconColor,
          size: 22.sp,
        ),
        SizedBox(height: 5.h),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.dark,
            fontSize: 11.5.sp,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          subtitle,
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 9.5.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _categoryTabs(
    List<_StoreCategory> categories, {
    required bool loading,
  }) {
    if (loading) {
      return ListView.separated(
        padding: EdgeInsets.symmetric(
          horizontal: 14.w,
          vertical: 10.h,
        ),
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        separatorBuilder: (_, __) => SizedBox(width: 11.w),
        itemBuilder: (_, __) {
          return AppSkeleton(
            child: Container(
              width: 76.w,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22.r),
              ),
            ),
          );
        },
      );
    }

    return ListView.separated(
      padding: EdgeInsets.symmetric(
        horizontal: 14.w,
        vertical: 10.h,
      ),
      scrollDirection: Axis.horizontal,
      reverse: true,
      physics: const BouncingScrollPhysics(),
      itemCount: categories.length,
      separatorBuilder: (_, __) => SizedBox(width: 11.w),
      itemBuilder: (_, index) {
        final category = categories[index];
        final selected = selectedCategory == category.id;

        return InkWell(
          onTap: () {
            setState(() {
              selectedCategory = category.id;
            });
          },
          borderRadius: BorderRadius.circular(22.r),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: 92.w,
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary
                  : Colors.white,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(
                color: selected
                    ? AppColors.primary
                    : const Color(0xFFF1E5EB),
              ),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color:
                            AppColors.primary.withOpacity(.18),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ]
                  : [],
            ),
            child: Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18.r),
                    child: _ProductImage(
                      image: category.image,
                      fallbackIcon:
                          Icons.shopping_bag_rounded,
                    ),
                  ),
                ),
                SizedBox(height: 5.h),
                Text(
                  category.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? Colors.white
                        : AppColors.dark,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _resultsHeader(int? count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.w,
        12.h,
        16.w,
        2.h,
      ),
      child: Row(
        children: [
          if (count != null)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10.w,
                vertical: 5.h,
              ),
              decoration: BoxDecoration(
                color: AppColors.softPink,
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Text(
                '$count منتج',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          const Spacer(),
          Text(
            selectedCategory == 'all'
                ? 'كل المنتجات'
                : 'منتجات القسم',
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

  SliverPadding _productsLoading() {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        14.w,
        14.h,
        14.w,
        130.h,
      ),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, __) => AppSkeleton(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(23.r),
              ),
            ),
          ),
          childCount: 6,
        ),
        gridDelegate:
            SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 14.h,
          childAspectRatio: .68,
        ),
      ),
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(30.w),
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
                size: 50.sp,
              ),
            ),
            SizedBox(height: 18.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 18.sp,
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _StoreProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? '';
    final brand = product['brand']?.toString() ?? '';
    final image = product['image']?.toString() ?? '';

    final price = double.tryParse(
          product['price']?.toString() ?? '0',
        ) ??
        0;

    final oldPrice = double.tryParse(
          product['oldPrice']?.toString() ?? '0',
        ) ??
        0;

    final hasDiscount =
        oldPrice > price && oldPrice > 0 && price > 0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(23.r),
      child: Container(
        padding: EdgeInsets.all(10.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23.r),
          border: Border.all(
            color: const Color(0xFFF3EAEE),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.045),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18.r),
                      child: _ProductImage(
                        image: image,
                        fallbackIcon:
                            Icons.shopping_bag_rounded,
                      ),
                    ),
                  ),
                  if (hasDiscount)
                    Positioned(
                      top: 8.h,
                      left: 8.w,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 5.h,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius:
                              BorderRadius.circular(13.r),
                        ),
                        child: Text(
                          'عرض',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: 8.h),
            if (brand.trim().isNotEmpty)
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
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
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 22.sp,
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${price.toStringAsFixed(0)} جنيه',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (hasDiscount)
                      Text(
                        '${oldPrice.toStringAsFixed(0)} جنيه',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 9.5.sp,
                          decoration:
                              TextDecoration.lineThrough,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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

class _ProductImage extends StatelessWidget {
  final String image;
  final IconData fallbackIcon;

  const _ProductImage({
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
        size: 34.sp,
      ),
    );
  }
}

class _StoreCategoryDefinition {
  final String id;
  final String title;
  final List<String> keywords;

  const _StoreCategoryDefinition({
    required this.id,
    required this.title,
    required this.keywords,
  });
}

class _StoreCategory {
  final String id;
  final String title;
  final String image;

  const _StoreCategory({
    required this.id,
    required this.title,
    required this.image,
  });
}

class _StickyHeaderDelegate
    extends SliverPersistentHeaderDelegate {
  final double minHeight;
  final double maxHeight;
  final Widget child;

  const _StickyHeaderDelegate({
    required this.minHeight,
    required this.maxHeight,
    required this.child,
  });

  @override
  double get minExtent => minHeight;

  @override
  double get maxExtent => maxHeight;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox.expand(child: child);
  }

  @override
  bool shouldRebuild(
    covariant _StickyHeaderDelegate oldDelegate,
  ) {
    return minHeight != oldDelegate.minHeight ||
        maxHeight != oldDelegate.maxHeight ||
        child != oldDelegate.child;
  }
}
