import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';

/// Client-side order alerts. Works while the app's Dart process is alive;
/// this is NOT a replacement for server-sent push notifications.
class OrderStatusNotificationService {
  OrderStatusNotificationService._();

  static final _db = FirebaseDatabase.instance;
  static final _box = GetStorage();
  static final _notifications = FlutterLocalNotificationsPlugin();
  static StreamSubscription<DatabaseEvent>? _subscription;
  static String? _activeUserId;
  static final Map<String, String> _statuses = {};
  static bool _seeded = false;

  static const _messages = <String, List<String>>{
    'confirmed': ['تم قبول طلبك', 'المتجر أكد طلبك وبيستعد لتجهيزه'],
    'preparing': ['طلبك بيتجهز', 'المتجر بيجهز طلبك دلوقتي'],
    'ready': ['طلبك جاهز', 'طلبك جاهز لاستلام الطيار'],
    'assigned': ['اتحدد طيار لطلبك', 'الطيار في طريقه لاستلام طلبك'],
    'pickedUp': ['الطيار استلم طلبك', 'طلبك مع الطيار دلوقتي'],
    'onDelivery': ['طلبك في الطريق', 'الطيار في طريقه ليك'],
    'arrived': ['الطيار وصل', 'الطيار وصل لموقع التوصيل'],
    'completed': ['تم تسليم طلبك', 'شكرًا لطلبك من برينجو'],
    'cancelled': ['تم إلغاء الطلب', 'تم إلغاء طلبك، تواصل مع الدعم لو محتاج مساعدة'],
  };

  static String? _userId() {
    for (final key in const ['userId', 'uid', 'id']) {
      final value = _box.read(key)?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static String _status(dynamic raw) {
    final value = (raw ?? '').toString().toLowerCase()
        .replaceAll(RegExp(r'[_\\s-]'), '');
    const aliases = <String, String>{
      'accepted': 'confirmed', 'confirmed': 'confirmed',
      'preparing': 'preparing', 'ready': 'ready',
      'assigned': 'assigned', 'picked': 'pickedUp',
      'pickedup': 'pickedUp', 'way': 'onDelivery',
      'ondelivery': 'onDelivery', 'arrived': 'arrived',
      'done': 'completed', 'delivered': 'completed',
      'completed': 'completed', 'rejected': 'cancelled',
      'cancelled': 'cancelled', 'canceled': 'cancelled',
      'pending': 'pending', 'new': 'pending',
    };
    return aliases[value] ?? value;
  }

  static Future<void> start() async {
    final userId = _userId();
    if (userId == _activeUserId && _subscription != null) return;
    await _subscription?.cancel();
    _subscription = null;
    _activeUserId = userId;
    _seeded = false;
    _statuses.clear();
    if (userId == null) return;

    _subscription = _db.ref('orders')
        .orderByChild('userId').equalTo(userId).onValue.listen((event) async {
      if (_activeUserId != userId) return;
      final current = <String, String>{};
      final raw = event.snapshot.value;
      if (raw is Map) {
        for (final entry in raw.entries) {
          if (entry.value is! Map) continue;
          final order = Map<dynamic, dynamic>.from(entry.value as Map);
          current[entry.key.toString()] =
              _status(order['status'] ?? order['orderStatus']);
        }
      }

      // Initial Firebase snapshot is historical data, not a new change.
      if (!_seeded) {
        _statuses.addAll(current);
        _seeded = true;
        return;
      }

      for (final entry in current.entries) {
        final oldStatus = _statuses[entry.key];
        if (oldStatus == null || oldStatus == entry.value) continue;
        final message = _messages[entry.value];
        if (message == null) continue;
        // Update before awaiting the notification to avoid duplicates.
        _statuses[entry.key] = entry.value;
        final shortId = entry.key.length > 7
            ? entry.key.substring(entry.key.length - 7)
            : entry.key;
        try {
          await _notifications.show(
            (entry.key + entry.value).hashCode & 0x7fffffff,
            message[0],
            '${message[1]} - طلب #$shortId',
            const NotificationDetails(
              android: AndroidNotificationDetails(
                'bringo_notifications_v2',
                'Bringo Notifications',
                channelDescription: 'Order status updates',
                importance: Importance.max,
                priority: Priority.high,
                playSound: true,
              ),
            ),
            payload: entry.key,
          );
        } catch (error) {
          // ignore: avoid_print
          print('Order status notification error: $error');
        }
      }
      _statuses
        ..removeWhere((key, _) => !current.containsKey(key))
        ..addAll(current);
    }, onError: (Object error) {
      // ignore: avoid_print
      print('Order status listener error: $error');
    });
  }
}
