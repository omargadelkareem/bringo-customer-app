import 'dart:math' as math;
import 'package:firebase_database/firebase_database.dart';

class DeliveryZone {
  final String id, name;
  const DeliveryZone({required this.id, required this.name});
}

class DeliveryZoneQuote {
  final String storeZoneId, customerZoneId, storeZoneName, customerZoneName;
  final double deliveryFee, distanceKm, pricePerKm, minimumFee;
  final double storeLatitude, storeLongitude;
  const DeliveryZoneQuote({
    required this.storeZoneId, required this.customerZoneId,
    required this.storeZoneName, required this.customerZoneName,
    required this.deliveryFee, required this.distanceKm,
    required this.pricePerKm, required this.minimumFee,
    required this.storeLatitude, required this.storeLongitude,
  });
  double get bringoShare => double.parse((deliveryFee / 3).toStringAsFixed(2));
  double get driverShare => double.parse((deliveryFee - bringoShare).toStringAsFixed(2));
  Map<String, dynamic> toOrderMap() => {
    'pricingType': 'distance', 'deliveryPricingType': 'distance',
    'distanceCalculation': 'straight_line_estimate',
    'deliveryDistanceKm': distanceKm, 'deliveryPricePerKm': pricePerKm,
    'deliveryMinimumFee': minimumFee, 'storeLatitude': storeLatitude,
    'storeLongitude': storeLongitude,
    'storeZoneId': storeZoneId, 'storeZoneName': storeZoneName,
    'customerZoneId': customerZoneId, 'customerZoneName': customerZoneName,
    'deliveryFee': deliveryFee, 'bringoDeliveryShare': bringoShare,
    'driverDeliveryShare': driverShare,
  };
}

class DeliveryZoneService {
  DeliveryZoneService._();
  static const double pricePerKm = 11;
  static const double minimumFee = 25;
  static const zones = <DeliveryZone>[
    DeliveryZone(id: 'sohag_east', name: 'شرق سوهاج'),
    DeliveryZone(id: 'sohag_west', name: 'غرب سوهاج'),
    DeliveryZone(id: 'kawamel', name: 'سوهاج الجديدة - الكوامل'),
  ];

  static double? _number(dynamic value) =>
      value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '');

  static double? _coordinate(Map<dynamic, dynamic> store, List<String> keys) {
    for (final key in keys) {
      final value = _number(store[key]);
      if (value != null) return value;
    }
    return null;
  }

  static Map<dynamic, dynamic> _map(dynamic value) =>
      value is Map ? Map<dynamic, dynamic>.from(value) : {};

  static Future<(double, double)> _storeCoordinates(String storeId) async {
    if (storeId.trim().isEmpty) throw StateError('تعذر تحديد المتجر');
    final snapshot = await FirebaseDatabase.instance.ref('stores/$storeId').get();
    final store = _map(snapshot.value);
    final location = _map(store['location']);
    final coordinates = _map(store['coordinates']);
    final lat = _coordinate(store, ['latitude', 'lat', 'storeLatitude']) ??
        _coordinate(location, ['latitude', 'lat']) ??
        _coordinate(coordinates, ['latitude', 'lat']);
    final lng = _coordinate(store, ['longitude', 'lng', 'lon', 'storeLongitude']) ??
        _coordinate(location, ['longitude', 'lng', 'lon']) ??
        _coordinate(coordinates, ['longitude', 'lng', 'lon']);
    if (lat == null || lng == null || lat.abs() > 90 || lng.abs() > 180 ||
        (lat == 0 && lng == 0)) {
      throw StateError('إحداثيات المتجر غير متوفرة. حدد موقع المتجر من لوحة الإدارة لحساب التوصيل.');
    }
    return (lat, lng);
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const radius = 6371.0;
    double rad(double degrees) => degrees * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLon = rad(lon2 - lon1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) *
        math.pow(math.sin(dLon / 2), 2);
    return radius * 2 * math.asin(math.sqrt(a.clamp(0.0, 1.0)));
  }

  static Future<DeliveryZoneQuote> quoteForCoordinates({
    required String storeId,
    required double latitude,
    required double longitude,
  }) async {
    if (latitude.abs() > 90 || longitude.abs() > 180 ||
        (latitude == 0 && longitude == 0)) {
      throw StateError('موقع العميل غير صحيح');
    }
    final (storeLat, storeLng) = await _storeCoordinates(storeId);
    // This is a straight-line estimate, NOT road-routing distance.
    final distance = _haversineKm(storeLat, storeLng, latitude, longitude);
    final fee = math.max(minimumFee, (distance * pricePerKm).ceilToDouble());
    return DeliveryZoneQuote(
      storeZoneId: '', customerZoneId: '',
      storeZoneName: '', customerZoneName: '',
      deliveryFee: fee, distanceKm: double.parse(distance.toStringAsFixed(2)),
      pricePerKm: pricePerKm, minimumFee: minimumFee,
      storeLatitude: storeLat, storeLongitude: storeLng,
    );
  }
}
