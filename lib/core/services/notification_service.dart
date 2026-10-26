import 'package:firebase_database/firebase_database.dart';

class NotificationService {
  final DatabaseReference _db = FirebaseDatabase.instance.ref();

  Query? _userQuery(String userId, {int limit = 30}) {
    final id = userId.trim();
    if (id.isEmpty) return null;
    return _db
        .child('notifications')
        .orderByChild('userId')
        .equalTo(id)
        .limitToLast(limit);
  }

  Stream<List<Map<String, dynamic>>> watchUserNotifications(
    String userId, {
    int limit = 30,
  }) {
    final query = _userQuery(userId, limit: limit);
    if (query == null) return Stream.value(const []);

    return query.onValue.map((event) {
      final value = event.snapshot.value;
      if (value is! Map) return <Map<String, dynamic>>[];

      final items = <Map<String, dynamic>>[];
      Map<dynamic, dynamic>.from(value).forEach((key, raw) {
        if (raw is! Map) return;
        final item = Map<String, dynamic>.from(raw);
        item['firebaseKey'] = key.toString();
        items.add(item);
      });
      items.sort((a, b) => _timestamp(b).compareTo(_timestamp(a)));
      return items;
    });
  }

  Stream<int> watchUnreadCount(String userId) {
    return watchUserNotifications(userId, limit: 50).map(
      (items) => items.where((item) => !_isRead(item)).length,
    );
  }

  Future<void> markAsRead(String notificationId) async {
    final id = notificationId.trim();
    if (id.isEmpty) return;
    await _db.child('notifications/$id').update({
      'isRead': true,
      'read': true,
      'readAt': ServerValue.timestamp,
    });
  }

  Future<void> markAllAsRead(String userId) async {
    final query = _userQuery(userId, limit: 50);
    if (query == null) return;
    final snapshot = await query.get();
    final value = snapshot.value;
    if (value is! Map) return;

    final updates = <String, Object?>{};
    Map<dynamic, dynamic>.from(value).forEach((key, raw) {
      if (raw is! Map) return;
      final item = Map<String, dynamic>.from(raw);
      if (_isRead(item)) return;
      updates['notifications/$key/isRead'] = true;
      updates['notifications/$key/read'] = true;
      updates['notifications/$key/readAt'] = ServerValue.timestamp;
    });
    if (updates.isNotEmpty) await _db.update(updates);
  }

  static bool _isRead(Map<String, dynamic> item) =>
      item['isRead'] == true || item['read'] == true;

  static int _timestamp(Map<String, dynamic> item) {
    for (final key in const ['createdAt', 'timestamp', 'sentAt']) {
      final raw = item[key];
      if (raw is int) return raw;
      final parsed = int.tryParse(raw?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    return 0;
  }
}
