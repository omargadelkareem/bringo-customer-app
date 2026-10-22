export 'store_products_screen.dart' show StoreProductsScreen;

import 'package:bringo/features/home/category_stores_listing_screen.dart';

class CategoryStoresScreen extends CategoryStoresListingScreen {
  const CategoryStoresScreen({
    super.key,
    required super.storeType,
    required super.title,
  });
}
