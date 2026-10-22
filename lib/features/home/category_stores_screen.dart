import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/features/cart/cart_manager.dart';
import 'package:bringo/features/cart/cart_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class CategoryStoresScreen extends StatefulWidget {
  final String storeType;
  final String title;

  const CategoryStoresScreen({
    super.key,
    required this.storeType,
    required this.title,
  });

  @override
  State<CategoryStoresScreen> createState() => _CategoryStoresScreenState();
}

class _CategoryStoresScreenState extends State<CategoryStoresScreen> {
  final TextEditingController searchController = TextEditingController();

  String searchQuery = '';

  String selectedFilter = 'all';

  final List<Map<String, dynamic>> filters = [
    {
      'id': 'all',
      'title': 'الكل',
    },
    {
      'id': 'open',
      'title': 'مفتوح الآن',
    },
    {
      'id': 'rating',
      'title': 'الأعلى تقييمًا',
    },
    {
      'id': 'fast',
      'title': 'الأسرع',
    },
  ];

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // STORES
  // =========================================================

  List<Map<String, dynamic>> _parseStores(dynamic value) {
    if (value == null || value is! Map) return [];

    final stores = <Map<String, dynamic>>[];

    Map<dynamic, dynamic>.from(value).forEach(
      (key, value) {
        if (value is! Map) return;

        final store = Map<String, dynamic>.from(value);

        store['firebaseKey'] = key.toString();

        store['id'] = store['id']?.toString().trim().isNotEmpty == true
            ? store['id'].toString()
            : key.toString();

        final type = store['type']?.toString().trim().toLowerCase() ?? '';

        if (type != widget.storeType.toLowerCase()) return;

        if (store['isActive'] == false) return;

        stores.add(store);
      },
    );

    stores.sort((a, b) {
      final aSort = int.tryParse(a['sort']?.toString() ?? '0') ?? 0;

      final bSort = int.tryParse(b['sort']?.toString() ?? '0') ?? 0;

      return aSort.compareTo(bSort);
    });

    return stores;
  }

  List<Map<String, dynamic>> _filteredStores(
    List<Map<String, dynamic>> stores,
  ) {
    var result = [...stores];

    // ===============================
    // Search
    // ===============================

    final query = searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      result = result.where((store) {
        final text = [
          store['name'],
          store['address'],
          store['tags'],
        ].whereType<Object>().join(' ').toLowerCase();

        return text.contains(query);
      }).toList();
    }

    // ===============================
    // Filters
    // ===============================

    switch (selectedFilter) {
      case 'open':
        result = result.where((store) => store['isOpen'] != false).toList();
        break;

      case 'rating':
        result.sort((a, b) {
          final aRating = double.tryParse(a['rating']?.toString() ?? '0') ?? 0;

          final bRating = double.tryParse(b['rating']?.toString() ?? '0') ?? 0;

          return bRating.compareTo(aRating);
        });
        break;

      case 'fast':
        result.sort((a, b) {
          final aTime = _extractDeliveryMinutes(
            a['deliveryTime']?.toString(),
          );

          final bTime = _extractDeliveryMinutes(
            b['deliveryTime']?.toString(),
          );

          return aTime.compareTo(bTime);
        });
        break;
    }

    return result;
  }

  int _extractDeliveryMinutes(String? value) {
    if (value == null || value.isEmpty) {
      return 999;
    }

    final matches = RegExp(r'\d+').allMatches(value).toList();

    if (matches.isEmpty) {
      return 999;
    }

    return int.tryParse(matches.first.group(0) ?? '') ?? 999;
  }

  // =========================================================
  // CATEGORY
  // =========================================================

  IconData get _categoryIcon {
    switch (widget.storeType) {
      case 'pharmacy':
        return Icons.local_pharmacy_rounded;

      case 'vegetables':
        return Icons.eco_rounded;

      case 'beauty':
        return Icons.spa_rounded;

      case 'meat':
        return Icons.set_meal_rounded;

      case 'bakery':
        return Icons.bakery_dining_rounded;

      case 'fish':
        return Icons.water_rounded;

      case 'restaurant':
        return Icons.restaurant_rounded;

      case 'supermarket':
        return Icons.shopping_cart_rounded;

      default:
        return Icons.storefront_rounded;
    }
  }

  String get _subtitle {
    switch (widget.storeType) {
      case 'pharmacy':
        return 'اختر الصيدلية المناسبة لك';

      case 'vegetables':
        return 'أفضل متاجر الخضار والفاكهة';

      case 'beauty':
        return 'متاجر العناية ومستحضرات التجميل';

      case 'meat':
        return 'أفضل متاجر اللحوم والدواجن';

      case 'bakery':
        return 'المخابز والحلويات بالقرب منك';

      case 'fish':
        return 'متاجر الأسماك والمأكولات البحرية';

      case 'restaurant':
        return 'اختار مطعمك واطلب أكلك';

      case 'supermarket':
        return 'كل احتياجات البيت من مكان واحد';

      default:
        return 'اختر المتجر وابدأ طلبك';
    }
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              _header(),

              const SizedBox(height: 10),

              // Search
              _searchBox(),

              SizedBox(height: 17.h),

              // Stores title
              _storesTitle(),

              SizedBox(height: 11.h),

              // Filters
              _filtersList(),

              SizedBox(height: 14.h),

              // Stores
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance.ref('stores').onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return _loadingStores();
                    }

                    final stores = _filteredStores(
                      _parseStores(
                        snapshot.data?.snapshot.value,
                      ),
                    );

                    if (stores.isEmpty) {
                      return _emptyState();
                    }

                    return RefreshIndicator(
                      color: AppColors.primary,
                      onRefresh: () async {
                        await Future.delayed(
                          const Duration(milliseconds: 500),
                        );
                      },
                      child: ListView.separated(
                        padding: EdgeInsets.fromLTRB(
                          16.w,
                          0,
                          16.w,
                          120.h,
                        ),
                        physics: const AlwaysScrollableScrollPhysics(
                          parent: BouncingScrollPhysics(),
                        ),
                        itemCount: stores.length,
                        separatorBuilder: (_, __) => SizedBox(height: 10.h),
                        itemBuilder: (_, index) {
                          final store = stores[index];

                          return _StoreCard(
                            store: store,
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => StoreProductsScreen(
                                    store: store,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
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

  // =========================================================
  // HEADER
  // =========================================================

  Widget _header() {
    return Container(
      height: 60.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withOpacity(.7),
          ),
        ),
      ),
      child: Row(
        children: [
          // Back
          _headerButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () {
              Navigator.pop(context);
            },
          ),

          SizedBox(width: 8.w),

          // Title
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.dark,
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  _subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 9.5.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: 8.w),

          // Cart
          _headerButton(
            icon: Icons.shopping_bag_outlined,
            onTap: () {
              // TODO:
              // افتح صفحة السلة هنا
            },
          ),
        ],
      ),
    );
  }

  Widget _headerButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          width: 40.w,
          height: 40.w,
          decoration: BoxDecoration(
            color: AppColors.lightGrey,
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: Icon(
            icon,
            color: AppColors.dark,
            size: 19.sp,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Widget _searchBox() {
    return Container(
      height: 48,
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F5),
        borderRadius: BorderRadius.circular(13.r),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: TextField(
        controller: searchController,
        textAlign: TextAlign.right,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        style: TextStyle(
          color: AppColors.dark,
          fontSize: 13.sp,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'ابحث عن متجر...',
          hintStyle: TextStyle(
            color: AppColors.textHint,
            fontSize: 12.5.sp,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  onPressed: () {
                    searchController.clear();

                    setState(() {
                      searchQuery = '';
                    });
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.textSecondary,
                    size: 19.sp,
                  ),
                )
              : null,
          suffixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 21.sp,
          ),
          contentPadding: EdgeInsets.symmetric(
            vertical: 13.h,
          ),
        ),
      ),
    );
  }

  // =========================================================
  // TITLE
  // =========================================================

  Widget _storesTitle() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Text(
            'اختر من المتاجر',
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 18.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          Container(
            width: 37.w,
            height: 37.w,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.border,
              ),
            ),
            child: Icon(
              Icons.tune_rounded,
              color: AppColors.primary,
              size: 19.sp,
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================
  // FILTERS
  // =========================================================

  Widget _filtersList() {
    return SizedBox(
      height: 36.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 7.w),
        itemBuilder: (_, index) {
          final filter = filters[index];

          final id = filter['id'].toString();

          final selected = selectedFilter == id;

          return InkWell(
            onTap: () {
              setState(() {
                selectedFilter = id;
              });
            },
            borderRadius: BorderRadius.circular(20.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                ),
              ),
              child: Text(
                filter['title'].toString(),
                style: TextStyle(
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontSize: 10.5.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // =========================================================
  // LOADING
  // =========================================================

  Widget _loadingStores() {
    return ListView.separated(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      itemCount: 5,
      separatorBuilder: (_, __) => SizedBox(height: 10.h),
      itemBuilder: (_, __) {
        return Container(
          height: 112.h,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppColors.border,
            ),
          ),
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              Container(
                width: 88.w,
                height: 88.w,
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _loadingLine(
                      width: 130.w,
                      height: 13.h,
                    ),
                    SizedBox(height: 10.h),
                    _loadingLine(
                      width: 180.w,
                      height: 9.h,
                    ),
                    SizedBox(height: 12.h),
                    _loadingLine(
                      width: 110.w,
                      height: 9.h,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _loadingLine({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppColors.lightGrey,
        borderRadius: BorderRadius.circular(20.r),
      ),
    );
  }

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92.w,
              height: 92.w,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _categoryIcon,
                color: AppColors.primary,
                size: 43,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              searchQuery.isNotEmpty ? 'لا توجد نتائج' : 'لا توجد متاجر حاليًا',
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 18.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 7.h),
            Text(
              searchQuery.isNotEmpty
                  ? 'جرب البحث باسم متجر آخر'
                  : 'سيتم إضافة المتاجر قريبًا',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// STORE CARD
// ===========================================================

class StoreProductsScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  const StoreProductsScreen({
    super.key,
    required this.store,
  });

  @override
  State<StoreProductsScreen> createState() => _StoreProductsScreenState();
}

class _StoreProductsScreenState extends State<StoreProductsScreen> {
  String selectedCategory = 'all';
  String searchQuery = '';

  final TextEditingController searchController = TextEditingController();

  Map<String, dynamic> _productWithStore(
    Map<String, dynamic> product,
  ) {
    return {
      ...product,
      'storeId': storeId,
      'storeName': storeName,
      'storeType': widget.store['type']?.toString().trim() ?? '',
    };
  }

  void _openProductDetails(
    Map<String, dynamic> product,
  ) {
    final preparedProduct = _productWithStore(product);

    context.push(
      AppRoutes.productDetails,
      extra: preparedProduct,
    );
  }

  void _addToCart(
    Map<String, dynamic> product,
  ) {
    if (!isStoreOpen) {
      _showMessage('المتجر مغلق حاليًا');
      return;
    }

    final preparedProduct = _productWithStore(product);

    if (!CartManager.canAddProduct(preparedProduct)) {
      _showDifferentStoreDialog(preparedProduct);
      return;
    }

    final added = CartManager.addProduct(
      preparedProduct,
      1,
    );

    if (added) {
      _showMessage('تمت إضافة المنتج للسلة');
    } else {
      _showMessage('تعذر إضافة المنتج للسلة');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.right,
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _showDifferentStoreDialog(
    Map<String, dynamic> product,
  ) async {
    final currentStore = CartManager.storeName.trim();

    final replace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            title: const Text(
              'منتجات من متجر آخر',
              textAlign: TextAlign.right,
            ),
            content: Text(
              currentStore.isEmpty
                  ? 'السلة تحتوي على منتجات من متجر آخر. هل تريد إفراغ السلة وإضافة هذا المنتج؟'
                  : 'السلة تحتوي على منتجات من $currentStore. هل تريد إفراغ السلة وبدء طلب جديد من $storeName؟',
              textAlign: TextAlign.right,
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                child: const Text('إفراغ السلة'),
              ),
            ],
          ),
        );
      },
    );

    if (replace != true) return;

    CartManager.clear();

    final added = CartManager.addProduct(
      product,
      1,
    );

    if (added) {
      _showMessage('تمت إضافة المنتج للسلة');
    }
  }

  void _openCart() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const CartScreen(),
      ),
    );
  }

  String get storeId {
    final id = widget.store['id']?.toString().trim() ?? '';

    if (id.isNotEmpty) return id;

    return widget.store['firebaseKey']?.toString() ?? '';
  }

  String get storeName =>
      widget.store['name']?.toString().trim().isNotEmpty == true
          ? widget.store['name'].toString()
          : 'المتجر';

  bool get isStoreOpen => widget.store['isOpen'] != false;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  // =========================================================
  // PRODUCTS
  // =========================================================

  List<Map<String, dynamic>> _parseProducts(dynamic value) {
    if (value == null || value is! Map) return [];

    final products = <Map<String, dynamic>>[];

    Map<dynamic, dynamic>.from(value).forEach((key, value) {
      if (value is! Map) return;

      final product = Map<String, dynamic>.from(value);

      product['id'] = product['id']?.toString().trim().isNotEmpty == true
          ? product['id'].toString()
          : key.toString();

      if (product['isAvailable'] == false) return;

      products.add(product);
    });

    return products;
  }

  // =========================================================
  // CATEGORY
  // =========================================================

  String _categoryId(Map<String, dynamic> product) {
    final id = product['categoryId']?.toString().trim() ?? '';

    if (id.isNotEmpty) return id;

    return _categoryName(product).toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  String _categoryName(Map<String, dynamic> product) {
    final value = product['categoryName']?.toString().trim() ??
        product['menuCategoryName']?.toString().trim() ??
        product['sectionName']?.toString().trim() ??
        '';

    return value.isEmpty ? 'منتجات متنوعة' : value;
  }

  List<_ProductCategory> _categories(
    List<Map<String, dynamic>> products,
  ) {
    final result = <String, _ProductCategory>{};

    for (final product in products) {
      final id = _categoryId(product);

      result.putIfAbsent(
        id,
        () => _ProductCategory(
          id: id,
          name: _categoryName(product),
          image: product['image']?.toString() ?? '',
        ),
      );
    }

    return [
      _ProductCategory(
        id: 'all',
        name: 'الكل',
        image: widget.store['image']?.toString() ?? '',
      ),
      ...result.values,
    ];
  }

  List<Map<String, dynamic>> _filterProducts(
    List<Map<String, dynamic>> products,
  ) {
    var result = [...products];

    if (selectedCategory != 'all') {
      result = result.where((product) {
        return _categoryId(product) == selectedCategory;
      }).toList();
    }

    final query = searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      result = result.where((product) {
        final name = product['name']?.toString().toLowerCase() ?? '';

        final brand = product['brand']?.toString().toLowerCase() ?? '';

        return name.contains(query) || brand.contains(query);
      }).toList();
    }

    return result;
  }

  // =========================================================
  // BUILD
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: StreamBuilder<DatabaseEvent>(
            stream: FirebaseDatabase.instance
                .ref('products')
                .orderByChild('storeId')
                .equalTo(storeId)
                .onValue,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return Column(
                  children: [
                    _appBar(),
                    const Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                );
              }

              final allProducts = _parseProducts(
                snapshot.data?.snapshot.value,
              );

              final categories = _categories(allProducts);

              final products = _filterProducts(allProducts);

              return CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  // ==============================
                  // APP BAR
                  // ==============================

                  SliverToBoxAdapter(
                    child: _appBar(),
                  ),

                  // ==============================
                  // STORE INFORMATION
                  // ==============================

                  SliverToBoxAdapter(
                    child: _storeInformation(),
                  ),

                  // ==============================
                  // SEARCH
                  // ==============================

                  SliverToBoxAdapter(
                    child: _searchBox(),
                  ),

                  // ==============================
                  // CATEGORIES
                  // ==============================

                  SliverToBoxAdapter(
                    child: _categoriesList(categories),
                  ),

                  // ==============================
                  // TITLE
                  // ==============================

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16.w,
                        17.h,
                        16.w,
                        11.h,
                      ),
                      child: Row(
                        children: [
                          Text(
                            selectedCategory == 'all'
                                ? 'كل المنتجات'
                                : categories
                                    .firstWhere(
                                      (category) =>
                                          category.id == selectedCategory,
                                      orElse: () => const _ProductCategory(
                                        id: 'all',
                                        name: 'المنتجات',
                                        image: '',
                                      ),
                                    )
                                    .name,
                            style: TextStyle(
                              color: AppColors.dark,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(width: 7.w),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 8.w,
                              vertical: 3.h,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primaryLight,
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                            child: Text(
                              '${products.length}',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 10.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ==============================
                  // PRODUCTS
                  // ==============================

                  if (products.isEmpty)
                    SliverToBoxAdapter(
                      child: _emptyProducts(),
                    )
                  else
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        16.w,
                        0,
                        16.w,
                        130.h,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            return Padding(
                              padding: EdgeInsets.only(
                                bottom: 10.h,
                              ),
                              child: _StoreProductCard(
                                product: products[index],
                                storeOpen: isStoreOpen,
                                onTap: () {
                                  _openProductDetails(
                                    products[index],
                                  );
                                },
                                onAdd: () {
                                  _addToCart(
                                    products[index],
                                  );
                                },
                              ),
                            );
                          },
                          childCount: products.length,
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

  // =========================================================
  // APP BAR
  // =========================================================

  Widget _appBar() {
    return Container(
      height: 58.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
          ),
        ),
      ),
      child: Row(
        children: [
          _topButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          Text(
            storeName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Spacer(),
          _topButton(
            icon: Icons.shopping_bag_outlined,
            onTap: () {
              // TODO: افتح السلة
            },
          ),
        ],
      ),
    );
  }

  Widget _topButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppColors.lightGrey,
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Icon(
          icon,
          color: AppColors.dark,
          size: 19.sp,
        ),
      ),
    );
  }

  // =========================================================
  // STORE INFORMATION
  // =========================================================

  Widget _storeInformation() {
    final logo = widget.store['image']?.toString() ?? '';

    final cover = widget.store['coverImage']?.toString() ?? '';

    final rating = widget.store['rating']?.toString() ?? '4.5';

    final deliveryTime =
        widget.store['deliveryTime']?.toString() ?? '25 - 35 دقيقة';

    final deliveryFee = widget.store['deliveryFee']?.toString() ?? '';

    final tags = widget.store['tags']?.toString() ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // =======================================
        // COVER
        // =======================================

        if (cover.trim().isNotEmpty)
          SizedBox(
            height: 130.h,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                _SmartImage(image: cover),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(.20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // =======================================
        // DETAILS
        // =======================================

        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(
            16.w,
            14.h,
            16.w,
            15.h,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo

              Container(
                width: 72.w,
                height: 72.w,
                padding: EdgeInsets.all(3.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(
                    color: AppColors.border,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13.r),
                  child: _SmartImage(
                    image: logo,
                  ),
                ),
              ),

              SizedBox(width: 12.w),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            storeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.dark,
                              fontSize: 17.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: isStoreOpen
                                ? const Color(0xFFE9F8EF)
                                : const Color(0xFFFFEEEE),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            isStoreOpen ? 'مفتوح' : 'مغلق',
                            style: TextStyle(
                              color: isStoreOpen
                                  ? const Color(0xFF168547)
                                  : const Color(0xFFD73A3A),
                              fontSize: 9.5.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (tags.trim().isNotEmpty) ...[
                      SizedBox(height: 4.h),
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
                    ],
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 12.w,
                      runSpacing: 6.h,
                      children: [
                        _storeMeta(
                          icon: Icons.star_rounded,
                          text: rating,
                          iconColor: const Color(0xFFFFB800),
                        ),
                        _storeMeta(
                          icon: Icons.access_time_rounded,
                          text: deliveryTime,
                        ),
                        if (deliveryFee.trim().isNotEmpty)
                          _storeMeta(
                            icon: Icons.delivery_dining_rounded,
                            text: '$deliveryFee جنيه',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Container(
          height: 8.h,
          color: AppColors.background,
        ),
      ],
    );
  }

  Widget _storeMeta({
    required IconData icon,
    required String text,
    Color? iconColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15.sp,
          color: iconColor ?? AppColors.textSecondary,
        ),
        SizedBox(width: 4.w),
        Text(
          text,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  // =========================================================
  // SEARCH
  // =========================================================

  Widget _searchBox() {
    return Container(
      height: 46.h,
      margin: EdgeInsets.fromLTRB(
        16.w,
        14.h,
        16.w,
        0,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) {
          setState(() {
            searchQuery = value;
          });
        },
        style: TextStyle(
          color: AppColors.dark,
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'ابحث داخل $storeName',
          hintStyle: TextStyle(
            color: AppColors.textHint,
            fontSize: 11.5.sp,
          ),
          suffixIcon: Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 20.sp,
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
      ),
    );
  }

  // =========================================================
  // CATEGORIES
  // =========================================================

  Widget _categoriesList(
    List<_ProductCategory> categories,
  ) {
    if (categories.length <= 1) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.only(top: 14.h),
      height: 91.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: categories.length,
        separatorBuilder: (context, index) {
          return SizedBox(width: 11.w);
        },
        itemBuilder: (context, index) {
          final category = categories[index];

          final selected = selectedCategory == category.id;

          return InkWell(
            onTap: () {
              setState(() {
                selectedCategory = category.id;
              });
            },
            borderRadius: BorderRadius.circular(14.r),
            child: SizedBox(
              width: 66.w,
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 58.w,
                    height: 58.w,
                    padding: EdgeInsets.all(3.w),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? AppColors.primary : AppColors.border,
                        width: selected ? 2 : 1,
                      ),
                    ),
                    child: ClipOval(
                      child: _SmartImage(
                        image: category.image,
                      ),
                    ),
                  ),
                  SizedBox(height: 5.h),
                  Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? AppColors.primary : AppColors.dark,
                      fontSize: 9.5.sp,
                      fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
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

  // =========================================================
  // EMPTY
  // =========================================================

  Widget _emptyProducts() {
    return Padding(
      padding: EdgeInsets.only(top: 70.h),
      child: Center(
        child: Column(
          children: [
            Container(
              width: 80.w,
              height: 80.w,
              decoration: const BoxDecoration(
                color: AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.shopping_bag_outlined,
                color: AppColors.primary,
                size: 35.sp,
              ),
            ),
            SizedBox(height: 14.h),
            Text(
              searchQuery.isNotEmpty
                  ? 'لا توجد نتائج للبحث'
                  : 'لا توجد منتجات حاليًا',
              style: TextStyle(
                color: AppColors.dark,
                fontSize: 16.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 5.h),
            Text(
              'جرب قسم آخر أو ابحث باسم المنتج',
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===========================================================
// PRODUCT CARD
// ===========================================================

class _StoreProductCard extends StatelessWidget {
  final Map<String, dynamic> product;
  final bool storeOpen;
  final VoidCallback onAdd;
  final VoidCallback onTap;

  const _StoreProductCard({
    required this.product,
    required this.storeOpen,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'منتج';

    final image = product['image']?.toString() ?? '';

    final description = product['description']?.toString() ??
        product['brand']?.toString() ??
        '';

    final price = double.tryParse(
          product['price']?.toString() ?? '0',
        ) ??
        0;

    final oldPrice = double.tryParse(
          product['oldPrice']?.toString() ?? '0',
        ) ??
        0;

    final hasDiscount = oldPrice > price && oldPrice > 0;

    return Container(
      constraints: BoxConstraints(
        minHeight: 116.h,
      ),
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // =====================================
          // IMAGE
          // =====================================

          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: SizedBox(
              width: 94.w,
              height: 94.w,
              child: _SmartImage(
                image: image,
              ),
            ),
          ),

          SizedBox(width: 12.w),

          // =====================================
          // INFORMATION
          // =====================================

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.dark,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  SizedBox(height: 5.h),
                  Text(
                    description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                SizedBox(height: 10.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${price.toStringAsFixed(0)} جنيه',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (hasDiscount) ...[
                      SizedBox(width: 7.w),
                      Text(
                        oldPrice.toStringAsFixed(0),
                        style: TextStyle(
                          color: AppColors.textHint,
                          fontSize: 10.sp,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                    const Spacer(),
                    InkWell(
                      onTap: storeOpen ? onAdd : null,
                      borderRadius: BorderRadius.circular(10.r),
                      child: Container(
                        width: 34.w,
                        height: 34.w,
                        decoration: BoxDecoration(
                          color: storeOpen
                              ? AppColors.primary
                              : AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: Icon(
                          Icons.add_rounded,
                          color: storeOpen ? Colors.white : AppColors.textHint,
                          size: 21.sp,
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
    );
  }
}

// ===========================================================
// PRODUCT CATEGORY MODEL
// ===========================================================

class _ProductCategory {
  final String id;
  final String name;
  final String image;

  const _ProductCategory({
    required this.id,
    required this.name,
    required this.image,
  });
}

class _StoreCard extends StatelessWidget {
  final Map<String, dynamic> store;
  final VoidCallback onTap;

  const _StoreCard({
    required this.store,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = store['name']?.toString().trim().isNotEmpty == true
        ? store['name'].toString()
        : 'متجر';

    final logo = store['image']?.toString() ?? '';

    final tags = store['tags']?.toString() ?? '';

    final time = store['deliveryTime']?.toString().trim().isNotEmpty == true
        ? store['deliveryTime'].toString()
        : '25 - 35 دقيقة';

    final rating = store['rating']?.toString().trim().isNotEmpty == true
        ? store['rating'].toString()
        : '4.5';

    final deliveryFee = store['deliveryFee']?.toString() ?? '';

    final isOpen = store['isOpen'] != false;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isOpen ? onTap : null,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          constraints: BoxConstraints(
            minHeight: 108.h,
          ),
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(
              color: AppColors.border,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(.025),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // =============================================
              // IMAGE
              // =============================================

              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12.r),
                    child: SizedBox(
                      width: 88.w,
                      height: 88.w,
                      child: _SmartImage(
                        image: logo,
                      ),
                    ),
                  ),
                  if (!isOpen)
                    Positioned.fill(
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(.58),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10.w,
                            vertical: 5.h,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(.35),
                            borderRadius: BorderRadius.circular(20.r),
                          ),
                          child: Text(
                            'مغلق',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),

              SizedBox(width: 12.w),

              // =============================================
              // INFORMATION
              // =============================================

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Store name

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.dark,
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        if (isOpen) ...[
                          SizedBox(width: 6.w),
                          Container(
                            width: 7.w,
                            height: 7.w,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),

                    // Tags

                    if (tags.trim().isNotEmpty) ...[
                      SizedBox(height: 4.h),
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
                    ],

                    SizedBox(height: 9.h),

                    // Rating + time

                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: const Color(0xFFFFB800),
                          size: 16.sp,
                        ),
                        SizedBox(width: 3.w),
                        Text(
                          rating,
                          style: TextStyle(
                            color: AppColors.dark,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          margin: EdgeInsets.symmetric(
                            horizontal: 9.w,
                          ),
                          width: 3.w,
                          height: 3.w,
                          decoration: const BoxDecoration(
                            color: AppColors.textHint,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Icon(
                          Icons.access_time_rounded,
                          color: AppColors.textSecondary,
                          size: 14.sp,
                        ),
                        SizedBox(width: 4.w),
                        Flexible(
                          child: Text(
                            time,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (deliveryFee.trim().isNotEmpty) ...[
                      SizedBox(height: 7.h),
                      Row(
                        children: [
                          Icon(
                            Icons.delivery_dining_rounded,
                            color: AppColors.primary,
                            size: 15.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'التوصيل $deliveryFee جنيه',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              SizedBox(width: 5.w),

              // =============================================
              // ARROW
              // =============================================

              Icon(
                Icons.arrow_forward_ios_rounded,
                color: AppColors.textHint,
                size: 14.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final Map<String, dynamic> product;

  const _ProductCard({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final name = product['name']?.toString() ?? 'منتج';
    final image = product['image']?.toString() ?? '';
    final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;

    return Container(
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.05),
            blurRadius: 17,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17.r),
              child: _SmartImage(image: image),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 12.5.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7.h),
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
      padding: EdgeInsets.symmetric(
        horizontal: 9.w,
        vertical: 6.h,
      ),
      decoration: BoxDecoration(
        color: AppColors.softPink,
        borderRadius: BorderRadius.circular(14.r),
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
          SizedBox(width: 4.w),
          Icon(
            icon,
            color: AppColors.primary,
            size: 14.sp,
          ),
        ],
      ),
    );
  }
}

class _SmartImage extends StatelessWidget {
  final String image;

  const _SmartImage({
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    final cleanImage = image.trim();

    if (cleanImage.isEmpty) return _placeholder();

    if (cleanImage.startsWith('http')) {
      return Image.network(
        cleanImage,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }

    if (cleanImage.startsWith('data:image')) {
      try {
        return Image.memory(
          base64Decode(cleanImage.split(',').last),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      } catch (_) {
        return _placeholder();
      }
    }

    try {
      return Image.memory(
        base64Decode(cleanImage),
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
      color: AppColors.softPink,
      alignment: Alignment.center,
      child: Icon(
        Icons.storefront_rounded,
        color: AppColors.primary,
        size: 34.sp,
      ),
    );
  }
}
