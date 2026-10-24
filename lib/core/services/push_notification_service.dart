import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get_storage/get_storage.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final GetStorage _box = GetStorage();
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'bringo_notifications',
    'Bringo Notifications',
    description: 'Order updates, offers and Bringo notifications',
    importance: Importance.high,
    playSound: true,
  );

  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;

  static Future<void> initialize() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(android: androidSettings);
      await _localNotifications.initialize(initializationSettings);
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);

      await _messaging.requestPermission(alert: true, badge: true, sound: true);

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _saveToken(token);

      await _tokenSubscription?.cancel();
      _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
        if (token.isNotEmpty) await _saveToken(token);
      });

      await _foregroundSubscription?.cancel();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    } catch (_) {
      // Push notifications must never block app startup.
    }
  }

  static Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    final title = notification?.title?.trim() ?? '';
    final body = notification?.body?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return;

    await _localNotifications.show(
      message.messageId?.hashCode ?? DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title.isEmpty ? 'Bringo' : title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'bringo_notifications',
          'Bringo Notifications',
          channelDescription: 'Order updates, offers and Bringo notifications',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
        ),
      ),
      payload: message.data['notificationId']?.toString(),
    );
  }

  static String? _currentUserId() {
    final authUid = FirebaseAuth.instance.currentUser?.uid.trim();
    if (authUid != null && authUid.isNotEmpty) return authUid;

    for (final key in const ['userId', 'uid', 'id']) {
      final value = _box.read(key)?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return null;
  }

  static Future<void> _saveToken(String token) async {
    final userId = _currentUserId();
    if (userId == null) return;

    final safeTokenKey = token.replaceAll(RegExp(r'[.#$\[\]/]'), '_');
    await _database.ref('users/$userId/fcmTokens/$safeTokenKey').set({
      'token': token,
      'platform': 'flutter',
      'updatedAt': ServerValue.timestamp,
    });
  }

  static Future<void> syncForCurrentUser() async {
    try {
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _saveToken(token);
    } catch (_) {}
  }
}
