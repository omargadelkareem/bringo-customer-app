import 'package:bringo/core/models/user_models.dart';
import 'package:bringo/core/services/push_notification_service.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:get_storage/get_storage.dart';

class AuthDbService {
  final DatabaseReference _usersRef = FirebaseDatabase.instance.ref('users');
  final GetStorage _box = GetStorage();

  static const String userIdKey = 'userId';

  Future<UserModel> register({
    required String name,
    required String phone,
    required String password,
    required String address,
    double? lat,
    double? lng,
  }) async {
    final exists = await _usersRef.orderByChild('phone').equalTo(phone).get();

    if (exists.exists) {
      throw Exception('رقم الهاتف مسجل بالفعل');
    }

    final newUserRef = _usersRef.push();

    final user = UserModel(
      id: newUserRef.key!,
      name: name,
      phone: phone,
      password: password,
      address: address,
      lat: lat,
      lng: lng,
    );

    await newUserRef.set(user.toJson());
    await _saveSession(user);
    await PushNotificationService.syncForCurrentUser();

    return user;
  }

  Future<UserModel> login({
    required String phone,
    required String password,
  }) async {
    final snapshot = await _usersRef.orderByChild('phone').equalTo(phone).get();

    if (!snapshot.exists) {
      throw Exception('رقم الهاتف غير مسجل');
    }

    final usersMap = Map<String, dynamic>.from(snapshot.value as Map);
    final firstUser = Map<String, dynamic>.from(usersMap.values.first);

    final user = UserModel.fromJson(firstUser);

    if (user.password != password) {
      throw Exception('كلمة المرور غير صحيحة');
    }

    await _saveSession(user);
    await PushNotificationService.syncForCurrentUser();
    return user;
  }

  Future<void> _saveSession(UserModel user) async {
    await _box.write(userIdKey, user.id);
    await _box.write('userName', user.name);
    await _box.write('name', user.name);
    await _box.write('phone', user.phone);
    await _box.write('address', user.address);
  }

  Future<void> saveUserId(String userId) async {
    await _box.write(userIdKey, userId);
  }

  String? getSavedUserId() {
    return _box.read<String>(userIdKey);
  }

  bool get isLoggedIn => getSavedUserId() != null;

  Future<void> logout() async {
    await _box.remove(userIdKey);
  }
}
