import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class RestaurantDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantDetailsScreen({
    super.key,
    required this.restaurant,
  });

  @override
  State<RestaurantDetailsScreen> createState() =>
      _RestaurantDetailsScreenState();
}

class _RestaurantDetailsScreenState extends State<RestaurantDetailsScreen> {
  final TextEditingController searchController = TextEditingController();

  String selectedCategory = 'الكل';
  String selectedFilter = 'all';
  String searchQuery = '';

  bool isFavorite = false;

  String get restaurantId =>
      widget.restaurant['id']?.toString() ??
      widget.restaurant['firebaseKey']?.toString() ??
      '';

  String get restaurantName => widget.restaurant['name']?.toString() ?? 'مطعم';

  String get restaurantLogo => widget.restaurant['image']?.toString() ?? '';

  String get restaurantCover =>
      widget.restaurant['coverImage']?.toString() ??
      widget.restaurant['cover']?.toString() ??
      restaurantLogo;

  String get restaurantTags =>
      widget.restaurant['tags']?.toString() ??
      widget.restaurant['categories']?.toString() ??
      'وجبات متنوعة';

  String get deliveryTime =>
      widget.restaurant['deliveryTime']?.toString() ?? '25 - 35 دقيقة';

  String get deliveryFee {
    final value = widget.restaurant['deliveryFee']?.toString().trim() ?? '';

    if (value.isEmpty || value == '0') {
      return '30 جنيه';
    }

    if (value.contains('جنيه')) return value;

    return '$value جنيه';
  }

  double get restaurantRating {
    return double.tryParse(
          widget.restaurant['rating']?.toString() ?? '4.8',
        ) ??
        4.8;
  }

  bool get isRestaurantOpen {
    return widget.restaurant['isOpen'] != false &&
        widget.restaurant['isActive'] != false;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _parseProducts(dynamic value) {
    if (value == null || value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(value);

    final result = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      if (value is! Map) return;

      final product = Map<String, dynamic>.from(value);
      product['firebaseKey'] = key.toString();

      if (product['isAvailable'] != false) {
        result.add(product);
      }
    });

    result.sort((a, b) {
      final aSort = int.tryParse(a['sort']?.toString() ?? '0') ?? 0;
      final bSort = int.tryParse(b['sort']?.toString() ?? '0') ?? 0;

      return aSort.compareTo(bSort);
    });

    return result;
  }

  String _productCategory(Map<String, dynamic> product) {
    final category = product['menuCategoryName']?.toString().trim() ??
        product['categoryName']?.toString().trim() ??
        product['restaurantCategory']?.toString().trim() ??
        product['sectionName']?.toString().trim() ??
        product['section']?.toString().trim() ??
        product['category']?.toString().trim() ??
        '';

    return category.isEmpty ? 'أخرى' : category;
  }

  List<String> _extractCategories(
    List<Map<String, dynamic>> products,
  ) {
    final categories = <String>{};

    for (final product in products) {
      categories.add(_productCategory(product));
    }

    final list = categories.toList();

    list.sort((a, b) => a.compareTo(b));

    return ['الكل', ...list];
  }

  List<Map<String, dynamic>> _filterProducts(
    List<Map<String, dynamic>> products,
  ) {
    var result = products.where((product) {
      final name = product['name']?.toString().toLowerCase().trim() ?? '';

      final description =
          product['description']?.toString().toLowerCase().trim() ?? '';

      final category = _productCategory(product);

      final query = searchQuery.toLowerCase().trim();

      final matchesSearch = query.isEmpty ||
          name.contains(query) ||
          description.contains(query) ||
          category.toLowerCase().contains(query);

      final matchesCategory =
          selectedCategory == 'الكل' || category == selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();

    switch (selectedFilter) {
      case 'bestSeller':
        result = result.where((product) {
          return product['isBestSeller'] == true ||
              product['bestSeller'] == true ||
              product['isFeatured'] == true;
        }).toList();
        break;

      case 'lowPrice':
        result.sort((a, b) {
          return _priceOf(a).compareTo(_priceOf(b));
        });
        break;

      case 'highPrice':
        result.sort((a, b) {
          return _priceOf(b).compareTo(_priceOf(a));
        });
        break;

      default:
        break;
    }

    return result;
  }

  double _priceOf(Map<String, dynamic> product) {
    return double.tryParse(
          product['price']?.toString() ?? '0',
        ) ??
        0;
  }

  void _openProduct(Map<String, dynamic> product) {
    context.push(
      AppRoutes.productDetails,
      extra: product,
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
              .equalTo(restaurantId)
              .onValue,
          builder: (context, snapshot) {
            final loading =
                snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData;

            final allProducts = _parseProducts(
              snapshot.data?.snapshot.value,
            );

            final categories = _extractCategories(allProducts);

            if (!categories.contains(selectedCategory)) {
              selectedCategory = 'الكل';
            }

            final filteredProducts = _filterProducts(allProducts);

            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _restaurantAppBar(),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: Offset(0, -24.h),
                    child: _restaurantInfoCard(),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: Offset(0, -12.h),
                    child: _searchBox(),
                  ),
                ),
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _StickyHeaderDelegate(
                    minHeight: 68.h,
                    maxHeight: 68.h,
                    child: Container(
                      color: const Color(0xFFFFFBFD),
                      alignment: Alignment.center,
                      child: _categoriesBar(categories),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: _filtersBar(),
                ),
                SliverToBoxAdapter(
                  child: _resultsHeader(
                    loading ? null : filteredProducts.length,
                  ),
                ),
                if (loading)
                  _loadingGrid()
                else if (snapshot.hasError)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _errorState(),
                  )
                else if (filteredProducts.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(),
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
                          final product = filteredProducts[index];

                          return _ProductCard(
                            product: product,
                            onTap: () => _openProduct(product),
                          );
                        },
                        childCount: filteredProducts.length,
                      ),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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

  SliverAppBar _restaurantAppBar() {
    return SliverAppBar(
      expandedHeight: 275.h,
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
        child: _circleAction(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => context.pop(),
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(
            left: 12.w,
            top: 8.h,
            bottom: 8.h,
          ),
          child: _circleAction(
            icon: isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            iconColor: isFavorite ? AppColors.primary : AppColors.dark,
            onTap: () {
              setState(() {
                isFavorite = !isFavorite;
              });
            },
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [
          StretchMode.zoomBackground,
        ],
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'restaurant-cover-$restaurantId',
              child: _SmartImage(
                image: restaurantCover,
                fit: BoxFit.cover,
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x55000000),
                    Color(0x11000000),
                    Color(0xCC000000),
                  ],
                  stops: [
                    0,
                    .48,
                    1,
                  ],
                ),
              ),
            ),
            Positioned(
              right: 18.w,
              left: 18.w,
              bottom: 30.h,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    width: 82.w,
                    height: 82.w,
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(.18),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20.r),
                      child: _SmartImage(
                        image: restaurantLogo,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 13.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                restaurantName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.w900,
                                  shadows: const [
                                    Shadow(
                                      color: Colors.black45,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: 7.w),
                            Container(
                              width: 21.w,
                              height: 21.w,
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14.sp,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          restaurantTags,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(.9),
                            fontSize: 12.5.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 9.h),
                        _openStatus(),
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

  Widget _circleAction({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = AppColors.dark,
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
            color: iconColor,
            size: 21.sp,
          ),
        ),
      ),
    );
  }

  Widget _openStatus() {
    final color =
        isRestaurantOpen ? const Color(0xFF22C55E) : const Color(0xFFEF4444);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10.w,
        vertical: 5.h,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.18),
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(
          color: color.withOpacity(.7),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7.w,
            height: 7.w,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            isRestaurantOpen ? 'مفتوح الآن' : 'مغلق الآن',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10.5.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _restaurantInfoCard() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.symmetric(
        horizontal: 12.w,
        vertical: 17.h,
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
              title: restaurantRating.toStringAsFixed(1),
              subtitle: 'التقييم',
            ),
          ),
          _verticalDivider(),
          Expanded(
            child: _infoItem(
              icon: Icons.delivery_dining_rounded,
              iconColor: AppColors.primary,
              title: deliveryFee,
              subtitle: 'رسوم التوصيل',
            ),
          ),
          _verticalDivider(),
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

  Widget _verticalDivider() {
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

  Widget _searchBox() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        height: 54.h,
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(19.r),
          border: Border.all(
            color: const Color(0xFFF1E5EB),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(.04),
              blurRadius: 15,
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
            hintText: 'ابحث داخل منيو $restaurantName...',
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
            prefixIcon: searchQuery.isEmpty
                ? null
                : IconButton(
                    onPressed: () {
                      searchController.clear();

                      setState(() {
                        searchQuery = '';
                      });
                    },
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.grey.shade500,
                      size: 20.sp,
                    ),
                  ),
            suffixIcon: Icon(
              Icons.search_rounded,
              color: AppColors.primary,
              size: 24.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _categoriesBar(List<String> categories) {
    return SizedBox(
      height: 52.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 9.w),
        itemBuilder: (_, index) {
          final category = categories[index];
          final selected = selectedCategory == category;

          return InkWell(
            onTap: () {
              setState(() {
                selectedCategory = category;
              });
            },
            borderRadius: BorderRadius.circular(18.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: EdgeInsets.symmetric(horizontal: 17.w),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(
                  color: selected ? AppColors.primary : Colors.grey.shade200,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(.2),
                          blurRadius: 15,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [],
              ),
              alignment: Alignment.center,
              child: Text(
                category,
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.dark,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _filtersBar() {
    final filters = [
      const _FilterItem(
        id: 'all',
        title: 'الكل',
        icon: Icons.grid_view_rounded,
      ),
      const _FilterItem(
        id: 'bestSeller',
        title: 'الأكثر طلبًا',
        icon: Icons.local_fire_department_rounded,
      ),
      const _FilterItem(
        id: 'lowPrice',
        title: 'الأقل سعرًا',
        icon: Icons.south_rounded,
      ),
      const _FilterItem(
        id: 'highPrice',
        title: 'الأعلى سعرًا',
        icon: Icons.north_rounded,
      ),
    ];

    return SizedBox(
      height: 48.h,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(horizontal: 14.w),
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (_, index) {
          final filter = filters[index];
          final selected = selectedFilter == filter.id;

          return FilterChip(
            selected: selected,
            showCheckmark: false,
            onSelected: (_) {
              setState(() {
                selectedFilter = filter.id;
              });
            },
            avatar: Icon(
              filter.icon,
              color: selected ? AppColors.primary : Colors.grey.shade600,
              size: 17.sp,
            ),
            label: Text(filter.title),
            labelStyle: TextStyle(
              color: selected ? AppColors.primary : AppColors.dark,
              fontSize: 11.sp,
              fontWeight: FontWeight.w800,
            ),
            selectedColor: AppColors.softPink,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected
                  ? AppColors.primary.withOpacity(.25)
                  : Colors.grey.shade200,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
          );
        },
      ),
    );
  }

  Widget _resultsHeader(int? count) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.w,
        15.h,
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
            selectedCategory == 'الكل' ? 'منيو المطعم' : selectedCategory,
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

  SliverPadding _loadingGrid() {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        14.w,
        14.h,
        14.w,
        130.h,
      ),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate(
          (_, __) => const _ProductSkeleton(),
          childCount: 6,
        ),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 14.h,
          childAspectRatio: .68,
        ),
      ),
    );
  }

  Widget _emptyState() {
    return Padding(
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
              searchQuery.isNotEmpty
                  ? Icons.search_off_rounded
                  : Icons.restaurant_menu_rounded,
              color: AppColors.primary,
              size: 50.sp,
            ),
          ),
          SizedBox(height: 18.h),
          Text(
            searchQuery.isNotEmpty
                ? 'لا توجد نتائج مطابقة'
                : 'لا توجد منتجات في هذا القسم',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7.h),
          Text(
            searchQuery.isNotEmpty
                ? 'جرّب البحث باسم منتج آخر'
                : 'سيتم إضافة المنتجات قريبًا',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (searchQuery.isNotEmpty ||
              selectedCategory != 'الكل' ||
              selectedFilter != 'all') ...[
            SizedBox(height: 18.h),
            TextButton.icon(
              onPressed: () {
                searchController.clear();

                setState(() {
                  searchQuery = '';
                  selectedCategory = 'الكل';
                  selectedFilter = 'all';
                });
              },
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة ضبط الفلاتر'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: EdgeInsets.all(30.w),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            color: Colors.grey.shade500,
            size: 58.sp,
          ),
          SizedBox(height: 14.h),
          Text(
            'تعذر تحميل المنيو',
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'تحقق من اتصال الإنترنت وحاول مرة أخرى',
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
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final VoidCallback onTap;

  const _ProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? '';
    final description = product['description']?.toString() ?? '';

    final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;

    final oldPrice = double.tryParse(
          product['oldPrice']?.toString() ?? '0',
        ) ??
        0;

    final image = product['image']?.toString() ?? '';

    final isBestSeller = product['isBestSeller'] == true ||
        product['bestSeller'] == true ||
        product['isFeatured'] == true;

    final hasDiscount = oldPrice > price && oldPrice > 0 && price > 0;

    final discount =
        hasDiscount ? (((oldPrice - price) / oldPrice) * 100).round() : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(23.r),
        child: Container(
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
                flex: 6,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(23.r),
                          topRight: Radius.circular(23.r),
                        ),
                        child: Hero(
                          tag:
                              'product-${product['firebaseKey'] ?? product['id'] ?? name}',
                          child: _SmartImage(
                            image: image,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    if (isBestSeller)
                      Positioned(
                        top: 9.h,
                        right: 9.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 9.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(13.r),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.local_fire_department_rounded,
                                color: Colors.white,
                                size: 13.sp,
                              ),
                              SizedBox(width: 3.w),
                              Text(
                                'الأكثر طلبًا',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8.5.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (hasDiscount)
                      Positioned(
                        top: 9.h,
                        left: 9.w,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(13.r),
                          ),
                          child: Text(
                            '-$discount%',
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
              Expanded(
                flex: 5,
                child: Padding(
                  padding: EdgeInsets.all(11.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: AppColors.dark,
                          fontSize: 13.sp,
                          height: 1.25,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (description.isNotEmpty) ...[
                        SizedBox(height: 5.h),
                        Text(
                          description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 9.5.sp,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            width: 37.w,
                            height: 37.w,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: Colors.white,
                              size: 23.sp,
                            ),
                          ),
                          const Spacer(),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (hasDiscount)
                                Text(
                                  '${oldPrice.toStringAsFixed(0)} جنيه',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 9.sp,
                                    decoration: TextDecoration.lineThrough,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              Text(
                                '${price.toStringAsFixed(0)} جنيه',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
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
    );
  }
}

class _ProductSkeleton extends StatefulWidget {
  const _ProductSkeleton();

  @override
  State<_ProductSkeleton> createState() => _ProductSkeletonState();
}

class _ProductSkeletonState extends State<_ProductSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;
  late final Animation<double> opacity;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    opacity = Tween<double>(
      begin: .45,
      end: .95,
    ).animate(controller);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: opacity,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(23.r),
        ),
        child: Column(
          children: [
            Expanded(
              flex: 6,
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF1E9ED),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(23.r),
                    topRight: Radius.circular(23.r),
                  ),
                ),
              ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: EdgeInsets.all(11.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _skeletonLine(
                      width: double.infinity,
                      height: 12.h,
                    ),
                    SizedBox(height: 8.h),
                    _skeletonLine(
                      width: 105.w,
                      height: 10.h,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Container(
                          width: 37.w,
                          height: 37.w,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF1E9ED),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const Spacer(),
                        _skeletonLine(
                          width: 65.w,
                          height: 14.h,
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
    );
  }

  Widget _skeletonLine({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1E9ED),
        borderRadius: BorderRadius.circular(12.r),
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
    final cleanImage = image.trim();

    if (cleanImage.isEmpty) {
      return _fallback();
    }

    if (cleanImage.startsWith('data:image')) {
      try {
        final bytes = base64Decode(
          cleanImage.split(',').last,
        );

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

          return _fallback(showIcon: false);
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

  Widget _fallback({
    bool showIcon = true,
  }) {
    return Container(
      color: AppColors.softPink,
      alignment: Alignment.center,
      child: showIcon
          ? Icon(
              Icons.restaurant_rounded,
              color: AppColors.primary,
              size: 36.sp,
            )
          : null,
    );
  }
}

class _FilterItem {
  final String id;
  final String title;
  final IconData icon;

  const _FilterItem({
    required this.id,
    required this.title,
    required this.icon,
  });
}

class _StickyHeaderDelegate extends SliverPersistentHeaderDelegate {
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
    return SizedBox.expand(
      child: child,
    );
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
