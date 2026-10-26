export 'store_products_screen.dart' show StoreProductsScreen;

import 'package:bringo/features/home/category_stores_listing_screen.dart';

class CategoryStoresScreen extends CategoryStoresListingScreen {
  CategoryStoresScreen({
    super.key,
    required String storeType,
    required String title,
  }) : super(
          storeType: _resolveStoreType(storeType, title),
          title: title,
        );

  static String _normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه')
      .replaceAll('ى', 'ي')
      .replaceAll(RegExp(r'\s+'), ' ');

  static String _resolveStoreType(String rawType, String rawTitle) {
    final id = rawType.trim().toLowerCase();
    final name = _normalize(rawTitle);

    if (id == 'restaurants' ||
        id == 'restaurant' ||
        id == 'food' ||
        id == 'foods' ||
        name.contains('مطعم') ||
        name.contains('مطاعم')) {
      return 'restaurant';
    }

    if (id == 'supermarket' ||
        id == 'supermarkets' ||
        id == 'grocery_store' ||
        id == 'grocery' ||
        id == 'market' ||
        name.contains('سوبر ماركت') ||
        name.contains('سوبرماركت') ||
        name.contains('بقال')) {
      return 'supermarket';
    }

    const byId = <String, String>{
      'pharmacy': 'pharmacy',
      'pharmacies': 'pharmacy',
      'vegetables': 'vegetables',
      'fruits': 'vegetables',
      'vegetables_fruits': 'vegetables',
      'beauty': 'beauty',
      'cosmetics': 'beauty',
      'meat': 'meat',
      'butcher': 'meat',
      'bakery': 'bakery',
      'bakeries': 'bakery',
      'fish': 'fish',
      'seafood': 'fish',
    };

    final mapped = byId[id];
    if (mapped != null) return mapped;
    if (name.contains('صيدلي')) return 'pharmacy';
    if (name.contains('خضار') ||
        name.contains('خضروات') ||
        name.contains('فاكه') ||
        name.contains('فواكه')) {
      return 'vegetables';
    }
    if (name.contains('تجميل') || name.contains('عنايه شخصيه')) return 'beauty';
    if (name.contains('لحوم') || name.contains('دواجن')) return 'meat';
    if (name.contains('مخبز') ||
        name.contains('مخابز') ||
        name.contains('حلويات')) {
      return 'bakery';
    }
    if (name.contains('اسماك') || name.contains('ماكولات بحريه')) return 'fish';

    return id;
  }
}
