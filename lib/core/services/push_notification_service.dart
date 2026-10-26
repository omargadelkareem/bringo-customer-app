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

  // Keep this id in sync with AndroidManifest.xml and the Admin FCM payload.
  static const String channelId = 'bringo_notifications_v2';

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    channelId,
    'Bringo Notifications',
    description: 'Order updates, offers and Bringo notifications',
    importance: Importance.max,
    playSound: true,
    enableVibration: true,
    showBadge: true,
  );

  static StreamSubscription<String>? _tokenSubscription;
  static StreamSubscription<RemoteMessage>? _foregroundSubscription;

  static Future<void> initialize() async {
    try {
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      const initializationSettings = InitializationSettings(
        android: androidSettings,
      );

      await _localNotifications.initialize(initializationSettings);

      final androidNotifications = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      await androidNotifications?.createNotificationChannel(_channel);

      // Android 13+ needs runtime notification permission. firebase_messaging
      // handles the platform permission request here.
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(token);
      }

      await _tokenSubscription?.cancel();
      _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
        if (token.isNotEmpty) await _saveToken(token);
      });

      await _foregroundSubscription?.cancel();
      _foregroundSubscription = FirebaseMessaging.onMessage.listen(
        _showForegroundNotification,
      );
    } catch (error) {
      // Push notifications must never block app startup.
      // ignore: avoid_print
      print('PushNotificationService.initialize error: $error');
    }
  }

  static Future<void> _showForegroundNotification(
    RemoteMessage message,
  ) async {
    final notification = message.notification;
    final title = notification?.title?.trim().isNotEmpty == true
        ? notification!.title!.trim()
        : (message.data['title']?.toString().trim().isNotEmpty == true
            ? message.data['title'].toString().trim()
            : 'Bringo');
    final body = notification?.body?.trim().isNotEmpty == true
        ? notification!.body!.trim()
        : message.data['body']?.toString().trim() ?? '';

    if (body.isEmpty && title == 'Bringo') return;

    await _localNotifications.show(
      message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Bringo Notifications',
          channelDescription: 'Order updates, offers and Bringo notifications',
          importance: Importance.max,
          priority: Priority.max,
          playSound: true,
          enableVibration: true,
          channelShowBadge: true,
          visibility: NotificationVisibility.public,
          category: AndroidNotificationCategory.message,
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
    } catch (error) {
      // ignore: avoid_print
      print('PushNotificationService.syncForCurrentUser error: $error');
    }
  }
}
