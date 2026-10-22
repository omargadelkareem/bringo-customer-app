import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/features/cart/cart_manager.dart';
import 'package:bringo/features/cart/cart_screen.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class StoreProductsScreen extends StatefulWidget {
  final Map<String, dynamic> store;

  const StoreProductsScreen({super.key, required this.store});

  @override
  State<StoreProductsScreen> createState() => _StoreProductsScreenState();
}

class _StoreProductsScreenState extends State<StoreProductsScreen> {
  final TextEditingController searchController = TextEditingController();
  String selectedCategory = 'all';
  String searchQuery = '';

  String get storeId {
    final id = widget.store['id']?.toString().trim() ?? '';
    return id.isNotEmpty ? id : widget.store['firebaseKey']?.toString() ?? '';
  }

  String get storeName => widget.store['name']?.toString().trim().isNotEmpty == true
      ? widget.store['name'].toString()
      : 'المتجر';

  bool get isStoreOpen => widget.store['isOpen'] != false;

  Map<String, dynamic> _productWithStore(Map<String, dynamic> product) => {
        ...product,
        'storeId': storeId,
        'storeName': storeName,
        'storeType': widget.store['type']?.toString().trim() ?? '',
      };

  void _addToCart(Map<String, dynamic> product) {
    if (!isStoreOpen) {
      _message('المتجر مغلق حاليًا');
      return;
    }
    final prepared = _productWithStore(product);
    if (!CartManager.canAddProduct(prepared)) {
      _showDifferentStoreDialog(prepared);
      return;
    }
    if (!CartManager.addProduct(prepared, 1)) {
      _message('تعذر إضافة المنتج للسلة');
    }
  }

  Future<void> _showDifferentStoreDialog(Map<String, dynamic> product) async {
    final currentStore = CartManager.storeName.trim();
    final replace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
          title: const Text('منتجات من متجر آخر', textAlign: TextAlign.right),
          content: Text(
            currentStore.isEmpty
                ? 'السلة تحتوي على منتجات من متجر آخر. هل تريد إفراغ السلة وإضافة هذا المنتج؟'
                : 'السلة تحتوي على منتجات من $currentStore. هل تريد إفراغ السلة وبدء طلب جديد من $storeName؟',
            textAlign: TextAlign.right,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('إفراغ السلة'),
            ),
          ],
        ),
      ),
    );
    if (replace != true) return;
    CartManager.clear();
    CartManager.addProduct(product, 1);
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message, textAlign: TextAlign.right),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  void _openCart() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen()));
  }

  List<Map<String, dynamic>> _parseProducts(dynamic value) {
    if (value is! Map) return [];
    final products = <Map<String, dynamic>>[];
    Map<dynamic, dynamic>.from(value).forEach((key, raw) {
      if (raw is! Map) return;
      final product = Map<String, dynamic>.from(raw);
      product['id'] = product['id']?.toString().trim().isNotEmpty == true
          ? product['id'].toString()
          : key.toString();
      if (product['isAvailable'] == false) return;
      products.add(product);
    });
    return products;
  }

  String _categoryName(Map<String, dynamic> product) {
    final value = product['categoryName']?.toString().trim() ??
        product['menuCategoryName']?.toString().trim() ??
        product['sectionName']?.toString().trim() ?? '';
    return value.isEmpty ? 'منتجات متنوعة' : value;
  }

  String _categoryId(Map<String, dynamic> product) {
    final id = product['categoryId']?.toString().trim() ?? '';
    return id.isNotEmpty
        ? id
        : _categoryName(product).toLowerCase().replaceAll(RegExp(r'\s+'), '_');
  }

  List<_ProductCategory> _categories(List<Map<String, dynamic>> products) {
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
      _ProductCategory(id: 'all', name: 'الكل', image: widget.store['image']?.toString() ?? ''),
      ...result.values,
    ];
  }

  List<Map<String, dynamic>> _filterProducts(List<Map<String, dynamic>> products) {
    var result = [...products];
    if (selectedCategory != 'all') {
      result = result.where((p) => _categoryId(p) == selectedCategory).toList();
    }
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result.where((p) {
        final name = p['name']?.toString().toLowerCase() ?? '';
        final brand = p['brand']?.toString().toLowerCase() ?? '';
        return name.contains(q) || brand.contains(q);
      }).toList();
    }
    return result;
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              StreamBuilder<DatabaseEvent>(
                stream: FirebaseDatabase.instance
                    .ref('products')
                    .orderByChild('storeId')
                    .equalTo(storeId)
                    .onValue,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                    return Column(children: [
                      _appBar(),
                      const Expanded(
                        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                      ),
                    ]);
                  }
                  final allProducts = _parseProducts(snapshot.data?.snapshot.value);
                  final categories = _categories(allProducts);
                  final products = _filterProducts(allProducts);
                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      SliverToBoxAdapter(child: _appBar()),
                      SliverToBoxAdapter(child: _storeInformation()),
                      SliverToBoxAdapter(child: _searchBox()),
                      SliverToBoxAdapter(child: _categoriesList(categories)),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16.w, 17.h, 16.w, 11.h),
                          child: Row(children: [
                            Text(
                              selectedCategory == 'all'
                                  ? 'كل المنتجات'
                                  : categories.firstWhere(
                                      (c) => c.id == selectedCategory,
                                      orElse: () => const _ProductCategory(id: 'all', name: 'المنتجات', image: ''),
                                    ).name,
                              style: TextStyle(
                                color: AppColors.dark,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 7.w),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
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
                          ]),
                        ),
                      ),
                      if (products.isEmpty)
                        SliverToBoxAdapter(child: _emptyProducts())
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 145.h),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: _StoreProductCard(
                                  product: products[index],
                                  storeOpen: isStoreOpen,
                                  onTap: () => _addToCart(products[index]),
                                  onAdd: () => _addToCart(products[index]),
                                ),
                              ),
                              childCount: products.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: ValueListenableBuilder<List<Map<String, dynamic>>>(
                  valueListenable: CartManager.cartNotifier,
                  builder: (context, items, _) {
                    if (items.isEmpty) return const SizedBox.shrink();
                    return _CartBar(items: items, onTap: _openCart);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _appBar() {
    return Container(
      height: 58.h,
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.border)),
      ),
      child: Row(children: [
        _topButton(
          icon: Icons.arrow_back_ios_new_rounded,
          onTap: () => Navigator.pop(context),
        ),
        Expanded(
          child: Text(
            storeName,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.dark,
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        SizedBox(width: 40.w),
      ]),
    );
  }

  Widget _topButton({required IconData icon, required VoidCallback onTap}) {
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
        child: Icon(icon, color: AppColors.dark, size: 19.sp),
      ),
    );
  }

  Widget _storeInformation() {
    final logo = widget.store['image']?.toString() ?? '';
    final cover = widget.store['coverImage']?.toString() ?? '';
    final rating = widget.store['rating']?.toString() ?? '4.5';
    final deliveryTime = widget.store['deliveryTime']?.toString() ?? '25 - 35 دقيقة';
    final deliveryFee = widget.store['deliveryFee']?.toString() ?? '';
    final tags = widget.store['tags']?.toString() ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (cover.trim().isNotEmpty)
        SizedBox(
          height: 130.h,
          width: double.infinity,
          child: Stack(fit: StackFit.expand, children: [
            _SmartImage(image: cover),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withOpacity(.20)],
                  ),
                ),
              ),
            ),
          ]),
        ),
      Container(
        color: Colors.white,
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 15.h),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 72.w,
            height: 72.w,
            padding: EdgeInsets.all(3.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              border: Border.all(color: AppColors.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13.r),
              child: _SmartImage(image: logo),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
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
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: isStoreOpen ? const Color(0xFFE9F8EF) : const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    isStoreOpen ? 'مفتوح' : 'مغلق',
                    style: TextStyle(
                      color: isStoreOpen ? const Color(0xFF168547) : const Color(0xFFD73A3A),
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ]),
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
              Wrap(spacing: 12.w, runSpacing: 6.h, children: [
                _storeMeta(Icons.star_rounded, rating, const Color(0xFFFFB800)),
                _storeMeta(Icons.access_time_rounded, deliveryTime, null),
                if (deliveryFee.trim().isNotEmpty)
                  _storeMeta(Icons.delivery_dining_rounded, '$deliveryFee جنيه', null),
              ]),
            ]),
          ),
        ]),
      ),
      Container(height: 8.h, color: AppColors.background),
    ]);
  }

  Widget _storeMeta(IconData icon, String text, Color? iconColor) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 15.sp, color: iconColor ?? AppColors.textSecondary),
      SizedBox(width: 4.w),
      Text(
        text,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
    ]);
  }

  Widget _searchBox() {
    return Container(
      height: 46.h,
      margin: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F5),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: searchController,
        onChanged: (value) => setState(() => searchQuery = value),
        style: TextStyle(color: AppColors.dark, fontSize: 12.sp, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: 'ابحث داخل $storeName',
          hintStyle: TextStyle(color: AppColors.textHint, fontSize: 11.5.sp),
          suffixIcon: Icon(Icons.search_rounded, color: AppColors.primary, size: 20.sp),
          contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        ),
      ),
    );
  }

  Widget _categoriesList(List<_ProductCategory> categories) {
    if (categories.length <= 1) return const SizedBox.shrink();
    return Container(
      margin: EdgeInsets.only(top: 14.h),
      height: 91.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        reverse: true,
        physics: const BouncingScrollPhysics(),
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        itemCount: categories.length,
        separatorBuilder: (_, __) => SizedBox(width: 11.w),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = selectedCategory == category.id;
          return InkWell(
            onTap: () => setState(() => selectedCategory = category.id),
            borderRadius: BorderRadius.circular(14.r),
            child: SizedBox(
              width: 66.w,
              child: Column(children: [
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
                  child: ClipOval(child: _SmartImage(image: category.image)),
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
              ]),
            ),
          );
        },
      ),
    );
  }

  Widget _emptyProducts() {
    return Padding(
      padding: EdgeInsets.only(top: 70.h),
      child: Center(
        child: Column(children: [
          Container(
            width: 80.w,
            height: 80.w,
            decoration: const BoxDecoration(color: AppColors.primaryLight, shape: BoxShape.circle),
            child: Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 35.sp),
          ),
          SizedBox(height: 14.h),
          Text(
            searchQuery.isNotEmpty ? 'لا توجد نتائج للبحث' : 'لا توجد منتجات حاليًا',
            style: TextStyle(color: AppColors.dark, fontSize: 16.sp, fontWeight: FontWeight.w900),
          ),
          SizedBox(height: 5.h),
          Text(
            'جرب قسم آخر أو ابحث باسم المنتج',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 11.sp),
          ),
        ]),
      ),
    );
  }
}

class _CartBar extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final VoidCallback onTap;
  const _CartBar({required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = items.fold<int>(
      0,
      (sum, item) => sum + (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1),
    );
    final total = items.fold<double>(0, (sum, item) {
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      return sum + (price * quantity);
    });
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.08), blurRadius: 18, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Material(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(14.r),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14.r),
            child: SizedBox(
              height: 56.h,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.w),
                child: Row(children: [
                  Container(
                    width: 31.w,
                    height: 31.w,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(9.r)),
                    child: Text(
                      '$count',
                      style: TextStyle(color: AppColors.primary, fontSize: 12.sp, fontWeight: FontWeight.w900),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Text(
                    'عرض السلة',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w900),
                  ),
                  const Spacer(),
                  Text(
                    '${total.toStringAsFixed(0)} جنيه',
                    style: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(width: 7.w),
                  Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 13.sp),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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
    final description = product['description']?.toString() ?? product['brand']?.toString() ?? '';
    final price = double.tryParse(product['price']?.toString() ?? '0') ?? 0;
    final oldPrice = double.tryParse(product['oldPrice']?.toString() ?? '0') ?? 0;
    final hasDiscount = oldPrice > price && oldPrice > 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: storeOpen ? onTap : null,
        borderRadius: BorderRadius.circular(14.r),
        child: Container(
          constraints: BoxConstraints(minHeight: 116.h),
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14.r),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12.r),
              child: SizedBox(width: 94.w, height: 94.w, child: _SmartImage(image: image)),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
                Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(
                    '${price.toStringAsFixed(0)} جنيه',
                    style: TextStyle(color: AppColors.primary, fontSize: 13.5.sp, fontWeight: FontWeight.w900),
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
                        color: storeOpen ? AppColors.primary : AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        color: storeOpen ? Colors.white : AppColors.textHint,
                        size: 21.sp,
                      ),
                    ),
                  ),
                ]),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProductCategory {
  final String id;
  final String name;
  final String image;
  const _ProductCategory({required this.id, required this.name, required this.image});
}

class _SmartImage extends StatelessWidget {
  final String image;
  const _SmartImage({required this.image});

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

  Widget _placeholder() => Container(
        color: AppColors.softPink,
        alignment: Alignment.center,
        child: Icon(Icons.storefront_rounded, color: AppColors.primary, size: 34.sp),
      );
}
