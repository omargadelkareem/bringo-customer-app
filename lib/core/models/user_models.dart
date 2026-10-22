// lib/core/models/user_model.dart

class UserModel {
  final String id;
  final String name;
  final String phone;
  final String password;
  final String address;
  final double? lat;
  final double? lng;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.password,
    required this.address,
    this.lat,
    this.lng,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'password': password,
      'address': address,
      'lat': lat,
      'lng': lng,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    };
  }

  factory UserModel.fromJson(Map data) {
    return UserModel(
      id: data['id'] ?? '',
      name: data['name'] ?? '',
      phone: data['phone'] ?? '',
      password: data['password'] ?? '',
      address: data['address'] ?? '',
      lat: (data['lat'] as num?)?.toDouble(),
      lng: (data['lng'] as num?)?.toDouble(),
    );
  }
}
