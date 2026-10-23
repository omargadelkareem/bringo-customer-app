import 'package:firebase_database/firebase_database.dart';

class DeliveryZone {
  final String id;
  final String name;

  const DeliveryZone({required this.id, required this.name});
}

class DeliveryZoneQuote {
  final String storeZoneId;
  final String customerZoneId;
  final String storeZoneName;
  final String customerZoneName;
  final double deliveryFee;

  const DeliveryZoneQuote({
    required this.storeZoneId,
    required this.customerZoneId,
    required this.storeZoneName,
    required this.customerZoneName,
    required this.deliveryFee,
  });

  double get bringoShare => double.parse((deliveryFee / 3).toStringAsFixed(2));
  double get driverShare => double.parse((deliveryFee - bringoShare).toStringAsFixed(2));

  Map<String, dynamic> toOrderMap() => {
        'pricingType': 'zone',
        'storeZoneId': storeZoneId,
        'storeZoneName': storeZoneName,
        'customerZoneId': customerZoneId,
        'customerZoneName': customerZoneName,
        'deliveryFee': deliveryFee,
        'bringoDeliveryShare': bringoShare,
        'driverDeliveryShare': driverShare,
      };
}

class DeliveryZoneService {
  DeliveryZoneService._();

  static const zones = <DeliveryZone>[
    DeliveryZone(id: 'sohag_east', name: 'شرق سوهاج'),
    DeliveryZone(id: 'sohag_west', name: 'غرب سوهاج'),
    DeliveryZone(id: 'kawamel', name: 'سوهاج الجديدة - الكوامل'),
  ];

  static const Map<String, double> _defaultPrices = {
    'sohag_east:sohag_east': 20,
    'sohag_west:sohag_west': 20,
    'sohag_east:sohag_west': 35,
    'sohag_west:sohag_east': 35,
    'sohag_east:kawamel': 60,
    'kawamel:sohag_east': 60,
    'sohag_west:kawamel': 60,
    'kawamel:sohag_west': 60,
    'kawamel:kawamel': 20,
  };

  static DeliveryZone zone(String id) => zones.firstWhere(
        (item) => item.id == id,
        orElse: () => zones.first,
      );

  static Future<String> getStoreZoneId(String storeId) async {
    if (storeId.trim().isEmpty) return 'sohag_east';
    try {
      final snap = await FirebaseDatabase.instance.ref('stores/$storeId/deliveryZoneId').get();
      final value = snap.value?.toString().trim() ?? '';
      if (zones.any((item) => item.id == value)) return value;
    } catch (_) {}
    return 'sohag_east';
  }

  static Future<double> _remotePrice(String from, String to) async {
    final fallback = _defaultPrices['$from:$to'] ?? 35;
    try {
      final snap = await FirebaseDatabase.instance
          .ref('settings/deliveryZonePricing/prices/$from/$to')
          .get();
      final value = double.tryParse(snap.value?.toString() ?? '');
      if (value != null && value > 0) return value;
    } catch (_) {}
    return fallback;
  }

  static Future<DeliveryZoneQuote> quote({
    required String storeId,
    required String customerZoneId,
  }) async {
    final storeZoneId = await getStoreZoneId(storeId);
    final storeZone = zone(storeZoneId);
    final customerZone = zone(customerZoneId);
    final fee = await _remotePrice(storeZone.id, customerZone.id);
    return DeliveryZoneQuote(
      storeZoneId: storeZone.id,
      customerZoneId: customerZone.id,
      storeZoneName: storeZone.name,
      customerZoneName: customerZone.name,
      deliveryFee: fee,
    );
  }
}
