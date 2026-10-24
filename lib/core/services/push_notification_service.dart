import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:get_storage/get_storage.dart';

class PushNotificationService {
  PushNotificationService._();

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FirebaseDatabase _database = FirebaseDatabase.instance;
  static final GetStorage _box = GetStorage();

  static StreamSubscription<String>? _tokenSubscription;

  static Future<void> initialize() async {
    try {
      await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) {
        await _saveToken(token);
      }

      await _tokenSubscription?.cancel();
      _tokenSubscription = _messaging.onTokenRefresh.listen((token) async {
        if (token.isNotEmpty) await _saveToken(token);
      });
    } catch (_) {
      // Push notifications must never block app startup.
    }
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
