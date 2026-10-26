import 'package:firebase_database/firebase_database.dart';

class DeliveryZone { final String id; final String name; const DeliveryZone({required this.id,required this.name}); }
class DeliveryZoneQuote {
  final String storeZoneId,customerZoneId,storeZoneName,customerZoneName; final double deliveryFee;
  const DeliveryZoneQuote({required this.storeZoneId,required this.customerZoneId,required this.storeZoneName,required this.customerZoneName,required this.deliveryFee});
  double get bringoShare=>double.parse((deliveryFee/3).toStringAsFixed(2));
  double get driverShare=>double.parse((deliveryFee-bringoShare).toStringAsFixed(2));
  Map<String,dynamic> toOrderMap()=>{'pricingType':'zone','deliveryPricingType':'zone','storeZoneId':storeZoneId,'storeZoneName':storeZoneName,'customerZoneId':customerZoneId,'customerZoneName':customerZoneName,'deliveryFee':deliveryFee,'bringoDeliveryShare':bringoShare,'driverDeliveryShare':driverShare};
}
class DeliveryZoneService {
  DeliveryZoneService._();
  static const zones=<DeliveryZone>[DeliveryZone(id:'sohag_east',name:'شرق سوهاج'),DeliveryZone(id:'sohag_west',name:'غرب سوهاج'),DeliveryZone(id:'kawamel',name:'سوهاج الجديدة - الكوامل')];
  static const Map<String,double> _defaultPrices={'sohag_east:sohag_east':20,'sohag_west:sohag_west':20,'sohag_east:sohag_west':35,'sohag_west:sohag_east':35,'sohag_east:kawamel':60,'kawamel:sohag_east':60,'sohag_west:kawamel':60,'kawamel:sohag_west':60,'kawamel:kawamel':20};
  static DeliveryZone zone(String id)=>zones.firstWhere((z)=>z.id==id,orElse:()=>throw StateError('منطقة التوصيل غير صحيحة'));
  static Future<String> getStoreZoneId(String storeId)async{if(storeId.trim().isEmpty)throw StateError('تعذر تحديد المتجر');final s=await FirebaseDatabase.instance.ref('stores/$storeId/deliveryZoneId').get();final v=s.value?.toString().trim()??'';if(zones.any((z)=>z.id==v))return v;throw StateError('منطقة المتجر غير محددة');}

  // GPS is the source of truth. Administrative labels such as Markaz Akhmim are ignored.
  // Ops can tune these boundaries remotely under settings/deliveryZonePricing/geo.
  static Future<String> resolveCustomerZone(double lat,double lng)async{
    double nileLng=31.7000,kawamelNorthLat=26.5050,kawamelWestLng=31.6200,kawamelEastLng=31.7900;
    try{final s=await FirebaseDatabase.instance.ref('settings/deliveryZonePricing/geo').get();if(s.value is Map){final m=Map<Object?,Object?>.from(s.value as Map);nileLng=double.tryParse(m['nileLongitude']?.toString()??'')??nileLng;kawamelNorthLat=double.tryParse(m['kawamelNorthLatitude']?.toString()??'')??kawamelNorthLat;kawamelWestLng=double.tryParse(m['kawamelWestLongitude']?.toString()??'')??kawamelWestLng;kawamelEastLng=double.tryParse(m['kawamelEastLongitude']?.toString()??'')??kawamelEastLng;}}catch(_){}
    if(lat<=kawamelNorthLat&&lng>=kawamelWestLng&&lng<=kawamelEastLng)return 'kawamel';
    return lng>=nileLng?'sohag_east':'sohag_west';
  }
  static Future<double> _remotePrice(String from,String to)async{final fallback=_defaultPrices['$from:$to']??35;try{final s=await FirebaseDatabase.instance.ref('settings/deliveryZonePricing/prices/$from/$to').get();final v=double.tryParse(s.value?.toString()??'');if(v!=null&&v>0)return v;}catch(_){}return fallback;}
  static Future<DeliveryZoneQuote> quote({required String storeId,required String customerZoneId})async{final sid=await getStoreZoneId(storeId),sz=zone(sid),cz=zone(customerZoneId),fee=await _remotePrice(sid,customerZoneId);return DeliveryZoneQuote(storeZoneId:sz.id,customerZoneId:cz.id,storeZoneName:sz.name,customerZoneName:cz.name,deliveryFee:fee);}
  static Future<DeliveryZoneQuote> quoteForCoordinates({required String storeId,required double latitude,required double longitude})async=>quote(storeId:storeId,customerZoneId:await resolveCustomerZone(latitude,longitude));
}
