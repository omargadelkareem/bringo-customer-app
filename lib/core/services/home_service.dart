import 'package:firebase_database/firebase_database.dart';

class HomeService {
  final DatabaseReference db = FirebaseDatabase.instance.ref();

  Stream<List<Map<String, dynamic>>> getBanners() {
    return FirebaseDatabase.instance.ref('banners').onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final data = Map<dynamic, dynamic>.from(event.snapshot.value as Map);

      final list = data.entries
          .map((e) {
            final item = Map<String, dynamic>.from(e.value);
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

      final data = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );

      return data.entries.map((e) {
        final item = Map<String, dynamic>.from(e.value);

        item['firebaseKey'] = e.key;

        return item;
      }).toList();
    });
  }

  Stream<List<Map<String, dynamic>>> getProducts() {
    return db.child('products').onValue.map((event) {
      if (event.snapshot.value == null) return [];

      final data = Map<String, dynamic>.from(
        event.snapshot.value as Map,
      );

      return data.entries.map((e) {
        final item = Map<String, dynamic>.from(e.value);

        item['firebaseKey'] = e.key;

        return item;
      }).toList();
    });
  }
}
