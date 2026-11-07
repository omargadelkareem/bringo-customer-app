import 'dart:async';
import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/features/home/store_products_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Searches the stores already loaded by HomeScreen.
/// Typing never makes a Firebase request.
class StoreSearchScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stores;
  const StoreSearchScreen({super.key, required this.stores});

  @override
  State<StoreSearchScreen> createState() => _StoreSearchScreenState();
}

class _StoreSearchScreenState extends State<StoreSearchScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  String _query = '';
  late final List<_SearchStore> _indexedStores;

  @override
  void initState() {
    super.initState();
    _indexedStores = widget.stores.map((store) {
      final name = (store['name'] ?? '').toString();
      final tags = (store['tags'] ?? '').toString();
      final address = (store['address'] ?? '').toString();
      final type = (store['storeType'] ?? store['type'] ?? '').toString();
      return _SearchStore(
        store: store,
        name: name,
        normalizedName: _normalize(name),
        searchable: _normalize('$name $tags $address $type'),
      );
    }).toList(growable: false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  static String _normalize(String text) => text
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[ً-ٰٟـ]'), '')
      .replaceAll(RegExp('[أإآٱ]'), 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll('ؤ', 'و')
      .replaceAll('ئ', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ');

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _query = _normalize(value));
    });
  }

  List<_SearchStore> get _results {
    if (_query.isEmpty) return _indexedStores.take(30).toList();
    final words = _query.split(' ').where((word) => word.isNotEmpty).toList();
    final matching = _indexedStores.where(
      (store) => words.every(store.searchable.contains),
    ).toList();
    matching.sort((a, b) {
      int score(_SearchStore store) {
        if (store.normalizedName == _query) return 0;
        if (store.normalizedName.startsWith(_query)) return 1;
        if (store.normalizedName.contains(_query)) return 2;
        return 3;
      }
      return score(a).compareTo(score(b));
    });
    return matching.take(60).toList();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _openStore(Map<String, dynamic> store) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StoreProductsScreen(store: store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAF8),
        appBar: AppBar(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          elevation: 0,
          title: const Text('ابحث في برينجو',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Column(
          children: [
            Container(
              color: Colors.white,
              padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 18.h),
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                onChanged: _onChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'دور على مطعم أو متجر...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (context, value, _) => value.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () {
                              _debounce?.cancel();
                              _controller.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF4F7F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 14.h),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(18.w, 18.h, 18.w, 10.h),
              child: Row(children: [
                Text(_query.isEmpty ? 'اكتشف المتاجر' : 'نتائج البحث',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900)),
                const Spacer(),
                Text('${results.length} متجر',
                    style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
              ]),
            ),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off_rounded,
                            size: 62.sp, color: AppColors.primary),
                        SizedBox(height: 12.h),
                        Text('ملقيناش متاجر بالاسم ده',
                            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800)),
                        SizedBox(height: 5.h),
                        const Text('جرب اسم تاني أو كلمة أقصر'),
                      ]),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(16.w, 4.h, 16.w, 28.h),
                      itemCount: results.length,
                      separatorBuilder: (_, __) => SizedBox(height: 10.h),
                      itemBuilder: (context, index) {
                        final item = results[index];
                        final image = (item.store['coverImage'] ??
                                item.store['image'] ?? '').toString();
                        final subtitle = (item.store['address'] ??
                                item.store['tags'] ?? '').toString();
                        return Material(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16.r),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16.r),
                            onTap: () => _openStore(item.store),
                            child: Padding(
                              padding: EdgeInsets.all(10.w),
                              child: Row(children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: SizedBox(
                                    width: 68.w,
                                    height: 68.w,
                                    child: _image(image),
                                  ),
                                ),
                                SizedBox(width: 12.w),
                                Expanded(child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.name.isEmpty ? 'متجر' : item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w900)),
                                    SizedBox(height: 5.h),
                                    Text(subtitle,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 11.sp,
                                            color: Colors.grey.shade600)),
                                  ],
                                )),
                                Icon(Icons.chevron_left_rounded,
                                    color: AppColors.primary),
                              ]),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _image(String value) {
    if (value.startsWith('http')) {
      return CachedNetworkImage(
        imageUrl: value,
        fit: BoxFit.cover,
        memCacheWidth: 180,
        maxWidthDiskCache: 300,
        placeholder: (_, __) => _fallback(),
        errorWidget: (_, __, ___) => _fallback(),
      );
    }
    if (value.startsWith('assets/')) {
      return Image.asset(value, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _fallback());
    }
    if (value.isNotEmpty) {
      try {
        return Image.memory(
          base64Decode(value.startsWith('data:image')
              ? value.split(',').last : value),
          fit: BoxFit.cover,
          cacheWidth: 180,
          errorBuilder: (_, __, ___) => _fallback(),
        );
      } catch (_) {}
    }
    return _fallback();
  }

  Widget _fallback() => Container(
    color: const Color(0xFFEAF2EE),
    alignment: Alignment.center,
    child: Icon(Icons.storefront_rounded, color: AppColors.primary),
  );
}

class _SearchStore {
  final Map<String, dynamic> store;
  final String name;
  final String normalizedName;
  final String searchable;
  const _SearchStore({
    required this.store,
    required this.name,
    required this.normalizedName,
    required this.searchable,
  });
}
