import 'package:geocoding/geocoding.dart';

class AddressService {
  static Future<String> getAreaName(
    double latitude,
    double longitude,
  ) async {
    try {
      final places = await placemarkFromCoordinates(latitude, longitude);
      if (places.isEmpty) return 'موقعك الحالي';

      final place = places.first;
      final parts = <String>[
        place.subLocality?.trim() ?? '',
        place.locality?.trim() ?? '',
        place.subAdministrativeArea?.trim() ?? '',
      ].where((e) => e.isNotEmpty).toSet().toList();

      return parts.isNotEmpty ? parts.join(' - ') : 'موقعك الحالي';
    } catch (_) {
      return 'موقعك الحالي';
    }
  }
}
