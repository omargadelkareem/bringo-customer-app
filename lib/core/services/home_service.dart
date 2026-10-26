import 'package:firebase_database/firebase_database.dart';

class HomeService {
  final DatabaseReference db = FirebaseDatabase.instance.ref();

  Stream<List<Map<String, dynamic>>> getBanners() {
    return db.child('banners').onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      final list = data.entries
          .where((e) => e.value is Map)
          .map((e) {
            final item = Map<String, dynamic>.from(e.value as Map);
            item['id'] = e.key.toString();
            return item;
          })
          .where((e) => e['isActive'] != false)
          .toList();

      list.sort((a, b) => (a['sort'] ?? 0).compareTo(b['sort'] ?? 0));
      return list;
    });
  }

  Stream<List<Map<String, dynamic>>> getCategories() {
    return db.child('categories').onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);
      return data.entries.where((e) => e.value is Map).map((e) {
        final item = Map<String, dynamic>.from(e.value as Map);
        item['firebaseKey'] = e.key.toString();
        return item;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getStoreProducts(
    String storeId, {
    int limit = 30,
  }) {
    final cleanStoreId = storeId.trim();
    if (cleanStoreId.isEmpty) return Stream.value(const []);

    return _productQuery(
      db.child('products')
          .orderByChild('storeId')
          .equalTo(cleanStoreId)
          .limitToFirst(limit),
    );
  }

  /// Scoped category feed. Never downloads the complete products tree.
  /// Add `.indexOn: ["categoryId"]` under `/products` in RTDB rules.
  Stream<List<Map<String, dynamic>>> getCategoryProducts(
    String categoryId, {
    int limit = 40,
  }) {
    final cleanCategoryId = categoryId.trim();
    if (cleanCategoryId.isEmpty) return Stream.value(const []);

    return _productQuery(
      db.child('products')
          .orderByChild('categoryId')
          .equalTo(cleanCategoryId)
          .limitToFirst(limit),
    );
  }

  Stream<List<Map<String, dynamic>>> _productQuery(Query query) {
    return query.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <Map<String, dynamic>>[];

      final products = <Map<String, dynamic>>[];
      Map<dynamic, dynamic>.from(value).forEach((key, raw) {
        if (raw is! Map) return;
        final item = Map<String, dynamic>.from(raw);
        item['firebaseKey'] = key.toString();
        item['id'] ??= key.toString();
        if (item['isAvailable'] == false) return;
        products.add(item);
      });
      return products;
    });
  }
}
