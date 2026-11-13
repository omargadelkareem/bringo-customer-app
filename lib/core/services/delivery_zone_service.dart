import 'dart:convert';
import 'dart:io';
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
  final String distanceCalculation;
  const DeliveryZoneQuote({
    required this.storeZoneId, required this.customerZoneId,
    required this.storeZoneName, required this.customerZoneName,
    required this.deliveryFee, required this.distanceKm,
    required this.pricePerKm, required this.minimumFee,
    required this.storeLatitude, required this.storeLongitude,
    required this.distanceCalculation,
  });
  double get bringoShare => double.parse((deliveryFee / 3).toStringAsFixed(2));
  double get driverShare => double.parse((deliveryFee - bringoShare).toStringAsFixed(2));
  Map<String, dynamic> toOrderMap() => {
    'pricingType': 'distance', 'deliveryPricingType': 'distance',
    'distanceCalculation': distanceCalculation,
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
  static const double defaultPricePerKm = 10;
  static const double defaultMinimumFee = 25;

  // Public, admin-managed pricing. Orders retain the quoted values at checkout.
  static Future<(double, double)> _pricing() async {
    try {
      final snapshot = await FirebaseDatabase.instance.ref('config/deliveryPricing').get();
      final config = _map(snapshot.value);
      final perKm = _number(config['pricePerKm']);
      final minimum = _number(config['minimumFee']);
      return (
        perKm != null && perKm.isFinite && perKm > 0 ? perKm : defaultPricePerKm,
        minimum != null && minimum.isFinite && minimum >= 0 ? minimum : defaultMinimumFee,
      );
    } catch (_) {
      // Keep checkout usable if the optional configuration is not yet deployed.
      return (defaultPricePerKm, defaultMinimumFee);
    }
  }
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

  // OSRM's public demo server is for development/testing only.
  // Production should use a dedicated routing service or hosted OSRM.
  static Future<double> _roadDistanceKm({
    required double storeLat,
    required double storeLng,
    required double customerLat,
    required double customerLng,
  }) async {
    final uri = Uri.https('router.project-osrm.org',
      '/route/v1/driving/$storeLng,$storeLat;$customerLng,$customerLat',
      {'overview': 'false', 'steps': 'false'});
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(uri).timeout(const Duration(seconds: 12));
      final response = await request.close().timeout(const Duration(seconds: 12));
      if (response.statusCode != HttpStatus.ok) {
        throw StateError('خدمة حساب الطريق غير متاحة حاليًا');
      }
      final body = await utf8.decoder.bind(response).join().timeout(const Duration(seconds: 12));
      final data = jsonDecode(body);
      if (data is! Map || data['code'] != 'Ok' || data['routes'] is! List ||
          (data['routes'] as List).isEmpty) {
        throw StateError('لم يتم العثور على طريق بين المتجر وموقع التوصيل');
      }
      final meters = (data['routes'][0]['distance'] as num?)?.toDouble();
      if (meters == null || !meters.isFinite || meters <= 0) {
        throw StateError('تعذر التحقق من مسافة الطريق');
      }
      return meters / 1000;
    } on SocketException {
      throw StateError('تعذر الاتصال بخدمة حساب الطريق. حاول مجددًا');
    } on HandshakeException {
      throw StateError('تعذر الاتصال الآمن بخدمة حساب الطريق');
    } on FormatException {
      throw StateError('استجابة خدمة حساب الطريق غير صالحة');
    } finally {
      client.close(force: true);
    }
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
    // Never silently fall back to straight-line pricing on routing failure.
    final distance = await _roadDistanceKm(
      storeLat: storeLat, storeLng: storeLng,
      customerLat: latitude, customerLng: longitude,
    );
    final (pricePerKm, minimumFee) = await _pricing();
    final fee = math.max(minimumFee, (distance * pricePerKm).ceilToDouble());
    return DeliveryZoneQuote(
      storeZoneId: '', customerZoneId: '',
      storeZoneName: '', customerZoneName: '',
      deliveryFee: fee, distanceKm: double.parse(distance.toStringAsFixed(2)),
      pricePerKm: pricePerKm, minimumFee: minimumFee,
      storeLatitude: storeLat, storeLongitude: storeLng,
      distanceCalculation: 'road_route_osrm',
    );
  }
}
