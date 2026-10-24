import 'package:flutter/foundation.dart';

class CartManager {
  static final ValueNotifier<List<Map<String, dynamic>>> cartNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  static List<Map<String, dynamic>> get items => cartNotifier.value;

  static int get count {
    return items.fold<int>(
      0,
      (sum, item) =>
          sum + (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1),
    );
  }

  static double get subtotal {
    return items.fold<double>(0, (sum, item) {
      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
      final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      return sum + (price * quantity);
    });
  }

  static String get storeId {
    if (items.isEmpty) return '';
    return items.first['storeId']?.toString().trim() ?? '';
  }

  static String get storeName {
    if (items.isEmpty) return '';
    return items.first['storeName']?.toString().trim() ?? '';
  }

  static String get storeType {
    if (items.isEmpty) return '';
    return items.first['storeType']?.toString().trim() ?? '';
  }

  static bool canAddProduct(Map<String, dynamic> product) {
    if (items.isEmpty) return true;

    final currentStoreId = storeId;
    final productStoreId = product['storeId']?.toString().trim() ?? '';

    if (currentStoreId.isEmpty || productStoreId.isEmpty) return false;

    return currentStoreId == productStoreId;
  }

  static bool addProduct(Map<String, dynamic> product, int quantity) {
    final productId = product['id']?.toString().trim() ?? '';
    final productStoreId = product['storeId']?.toString().trim() ?? '';

    if (productId.isEmpty) return false;

    if (productStoreId.isEmpty) {
      debugPrint('CartManager: المنتج لا يحتوي على storeId');
      return false;
    }

    if (!canAddProduct(product)) return false;

    final safeQuantity = quantity < 1 ? 1 : quantity;
    final list = List<Map<String, dynamic>>.from(items);

    final index = list.indexWhere(
      (item) => item['id']?.toString() == productId,
    );

    if (index != -1) {
      final oldQuantity =
          int.tryParse(list[index]['quantity']?.toString() ?? '1') ?? 1;

      list[index] = {
        ...list[index],
        'quantity': oldQuantity + safeQuantity,
      };
    } else {
      list.add({
        ...product,
        'storeId': productStoreId,
        'storeName': product['storeName']?.toString() ?? '',
        'storeType': product['storeType']?.toString() ?? '',
        'quantity': safeQuantity,
      });
    }

    cartNotifier.value = list;
    return true;
  }

  static void updateQuantity(String productId, int quantity) {
    final list = List<Map<String, dynamic>>.from(items);

    final index = list.indexWhere(
      (item) => item['id']?.toString() == productId,
    );

    if (index == -1) return;

    if (quantity <= 0) {
      removeProduct(productId);
      return;
    }

    list[index] = {
      ...list[index],
      'quantity': quantity,
    };

    cartNotifier.value = list;
  }

  static void removeProduct(String productId) {
    final list = List<Map<String, dynamic>>.from(items);

    list.removeWhere(
      (item) => item['id']?.toString() == productId,
    );

    cartNotifier.value = list;
  }

  static void clear() {
    cartNotifier.value = [];
  }
}
