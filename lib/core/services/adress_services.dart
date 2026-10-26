import 'package:geocoding/geocoding.dart';

class AddressService {
  /// Returns a customer-friendly description of the GPS point.
  /// Administrative centers are intentionally not used as the primary label,
  /// because a village can administratively belong to Akhmim while being much
  /// closer to Sohag city.
  static Future<String> getAreaName(
    double latitude,
    double longitude,
  ) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return 'موقعك الحالي';

      final place = places.first;
      final parts = <String>[
        place.street?.trim() ?? '',
        place.subLocality?.trim() ?? '',
        place.locality?.trim() ?? '',
      ].where((e) => e.isNotEmpty).toSet().toList();

      return parts.isNotEmpty ? parts.join(' - ') : 'موقعك الحالي';
    } catch (_) {
      return 'موقعك الحالي';
    }
  }
}
