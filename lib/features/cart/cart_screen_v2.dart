import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/routing/app_routes.dart';
import 'package:bringo/core/services/adress_services.dart';
import 'package:bringo/core/services/delivery_zone_service.dart';
import 'package:bringo/core/services/location_service.dart';
import 'package:bringo/features/cart/cart_manager.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

class CartScreen extends StatefulWidget {
  final List<Map<String, dynamic>> cartItems;
  const CartScreen({super.key, this.cartItems = const []});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final notesController = TextEditingController();
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final areaController = TextEditingController();
  final streetController = TextEditingController();
  final buildingController = TextEditingController();
  final floorController = TextEditingController();
  final apartmentController = TextEditingController();
  final landmarkController = TextEditingController();

  String customerName = '';
  String customerPhone = '';
  String detectedAddress = 'جاري تحديد موقعك...';
  String customerZoneId = 'sohag_east';
  double? deliveryLat;
  double? deliveryLng;
  bool loadingLocation = true;
  bool loadingUser = true;
  bool placingOrder = false;
  bool loadingQuote = true;
  DeliveryZoneQuote? deliveryQuote;

  double get deliveryFee => deliveryQuote?.deliveryFee ?? 20;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadLocation();
    _refreshQuote();
  }

  String _first(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  Future<void> _loadUser() async {
    final box = GetStorage();
    customerName = _first([box.read('name'), box.read('fullName'), box.read('userName'), box.read('customerName')]);
    customerPhone = _first([box.read('phone'), box.read('userPhone'), box.read('customerPhone'), box.read('mobile')]);
    final savedZone = _first([box.read('deliveryZoneId')]);
    if (DeliveryZoneService.zones.any((z) => z.id == savedZone)) customerZoneId = savedZone;
    nameController.text = customerName;
    phoneController.text = customerPhone;
    areaController.text = _first([box.read('deliveryAreaDetails')]);
    streetController.text = _first([box.read('deliveryStreet')]);
    buildingController.text = _first([box.read('deliveryBuilding')]);
    floorController.text = _first([box.read('deliveryFloor')]);
    apartmentController.text = _first([box.read('deliveryApartment')]);
    landmarkController.text = _first([box.read('deliveryLandmark')]);
    if (mounted) setState(() => loadingUser = false);
    await _refreshQuote();
  }

  Future<void> _refreshQuote() async {
    if (CartManager.storeId.trim().isEmpty) return;
    if (mounted) setState(() => loadingQuote = true);
    try {
      final quote = await DeliveryZoneService.quote(storeId: CartManager.storeId, customerZoneId: customerZoneId);
      if (mounted) setState(() => deliveryQuote = quote);
    } finally {
      if (mounted) setState(() => loadingQuote = false);
    }
  }

  Future<void> _selectZone(String? zoneId) async {
    if (zoneId == null || zoneId == customerZoneId) return;
    setState(() => customerZoneId = zoneId);
    await GetStorage().write('deliveryZoneId', zoneId);
    await _refreshQuote();
  }

  Future<void> _loadLocation() async {
    if (mounted) setState(() => loadingLocation = true);
    try {
      final location = await LocationService().getCurrentLocation().timeout(const Duration(seconds: 18));
      if (location != null && location.latitude != null && location.longitude != null) {
        deliveryLat = location.latitude;
        deliveryLng = location.longitude;
        detectedAddress = await AddressService.getAreaName(location.latitude!, location.longitude!).timeout(const Duration(seconds: 12), onTimeout: () => 'موقعك الحالي');
        if (detectedAddress.trim().isEmpty) detectedAddress = 'موقعك الحالي';
      } else {
        detectedAddress = 'لم يتم تحديد الموقع - يمكنك كتابة العنوان يدويًا';
      }
    } catch (_) {
      detectedAddress = 'لم يتم تحديد الموقع - يمكنك كتابة العنوان يدويًا';
    }
    if (mounted) setState(() => loadingLocation = false);
  }

  double _subtotal(List<Map<String, dynamic>> items) => items.fold(0, (sum, item) {
        final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
        final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
        return sum + price * qty;
      });

  int _count(List<Map<String, dynamic>> items) => items.fold(0, (sum, item) => sum + (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1));

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(text, textAlign: TextAlign.right), backgroundColor: AppColors.primary));
  }

  void _returnToShopping() {
    if (mounted) context.go(AppRoutes.mainLayout);
  }

  Future<void> _placeOrder(List<Map<String, dynamic>> items) async {
    if (items.isEmpty || placingOrder) return;
    final name = nameController.text.trim().isNotEmpty ? nameController.text.trim() : customerName;
    final phone = phoneController.text.trim().isNotEmpty ? phoneController.text.trim() : customerPhone;
    if (phone.isEmpty) return _message('اكتب رقم الهاتف');
    if (areaController.text.trim().isEmpty) return _message('اكتب اسم القرية أو المنطقة');
    if (streetController.text.trim().isEmpty) return _message('اكتب اسم الشارع أو الطريق');
    if (CartManager.storeId.trim().isEmpty) return _message('تعذر تحديد المتجر');
    if (loadingQuote) return _message('جاري حساب رسوم التوصيل');

    setState(() => placingOrder = true);
    try {
      final quote = deliveryQuote ?? await DeliveryZoneService.quote(storeId: CartManager.storeId, customerZoneId: customerZoneId);
      final box = GetStorage();
      await box.write('name', name);
      await box.write('phone', phone);
      await box.write('deliveryZoneId', customerZoneId);
      await box.write('deliveryAreaDetails', areaController.text.trim());
      await box.write('deliveryStreet', streetController.text.trim());
      await box.write('deliveryBuilding', buildingController.text.trim());
      await box.write('deliveryFloor', floorController.text.trim());
      await box.write('deliveryApartment', apartmentController.text.trim());
      await box.write('deliveryLandmark', landmarkController.text.trim());

      final subtotal = _subtotal(items);
      final ref = FirebaseDatabase.instance.ref('orders').push();
      final fullAddress = [
        quote.customerZoneName,
        areaController.text.trim(),
        streetController.text.trim(),
        if (buildingController.text.trim().isNotEmpty) 'منزل/عمارة ${buildingController.text.trim()}',
        if (floorController.text.trim().isNotEmpty) 'الدور ${floorController.text.trim()}',
        if (apartmentController.text.trim().isNotEmpty) 'شقة ${apartmentController.text.trim()}',
        if (landmarkController.text.trim().isNotEmpty) 'علامة مميزة: ${landmarkController.text.trim()}',
      ].join(' - ');

      await ref.set({
        'id': ref.key,
        'storeId': CartManager.storeId,
        'storeName': CartManager.storeName,
        'storeType': CartManager.storeType,
        'customerName': name,
        'customerPhone': phone,
        'userId': _first([box.read('userId'), box.read('uid'), box.read('id')]),
        'customerAddress': fullAddress,
        'detectedAddress': detectedAddress,
        'address': {
          'governorate': 'سوهاج',
          'deliveryZoneId': quote.customerZoneId,
          'deliveryZoneName': quote.customerZoneName,
          'area': areaController.text.trim(),
          'street': streetController.text.trim(),
          'building': buildingController.text.trim(),
          'floor': floorController.text.trim(),
          'apartment': apartmentController.text.trim(),
          'landmark': landmarkController.text.trim(),
          'notes': notesController.text.trim(),
          'latitude': deliveryLat,
          'longitude': deliveryLng,
        },
        'items': items.map((item) {
          final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
          return {'id': item['id']?.toString() ?? '', 'productId': item['id']?.toString() ?? '', 'name': item['name']?.toString() ?? '', 'image': item['image']?.toString() ?? '', 'price': price, 'quantity': qty, 'total': price * qty, 'storeId': CartManager.storeId};
        }).toList(),
        'subtotal': subtotal,
        ...quote.toOrderMap(),
        'deliveryPricing': {
          'type': 'zone',
          'storeZoneId': quote.storeZoneId,
          'storeZoneName': quote.storeZoneName,
          'customerZoneId': quote.customerZoneId,
          'customerZoneName': quote.customerZoneName,
          'fee': quote.deliveryFee,
        },
        'total': subtotal + quote.deliveryFee,
        'paymentMethod': 'cash',
        'paymentStatus': 'unpaid',
        'status': 'pending_provider',
        'orderStatus': 'pending_provider',
        'driverId': '',
        'driverKey': '',
        'driverName': '',
        'driverPhone': '',
        'estimatedDeliveryMinutes': 25,
        'createdAt': ServerValue.timestamp,
        'updatedAt': ServerValue.timestamp,
      });

      if (!mounted) return;
      CartManager.clear();
      await showDialog<void>(context: context, barrierDismissible: false, builder: (dialogContext) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22.r)), title: const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 58), content: const Text('تم إرسال طلبك بنجاح', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), actionsAlignment: MainAxisAlignment.center, actions: [TextButton(onPressed: () => Navigator.of(dialogContext).pop(), child: const Text('تمام'))]));
    } catch (_) {
      _message('حصل خطأ أثناء إرسال الطلب');
    } finally {
      if (mounted) setState(() => placingOrder = false);
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: ValueListenableBuilder<List<Map<String, dynamic>>>(
          valueListenable: CartManager.cartNotifier,
          builder: (context, rawItems, _) {
            final items = rawItems.map((e) => Map<String, dynamic>.from(e)).toList();
            final subtotal = _subtotal(items);
            return Scaffold(
              backgroundColor: const Color(0xFFF7F8F8),
              appBar: AppBar(backgroundColor: Colors.white, surfaceTintColor: Colors.white, elevation: 0, leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: _returnToShopping), title: const Text('سلة المشتريات', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)), centerTitle: true, actions: items.isEmpty ? null : [TextButton(onPressed: CartManager.clear, child: const Text('إفراغ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w800))), SizedBox(width: 6.w)]),
              bottomNavigationBar: items.isEmpty ? null : _bottomBar(items, subtotal),
              body: items.isEmpty ? _empty() : ListView(padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 130.h), children: [_storeStrip(items), SizedBox(height: 18.h), Text('طلبك', style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: AppColors.dark)), SizedBox(height: 10.h), ...List.generate(items.length, (i) => _itemCard(items[i])), SizedBox(height: 8.h), _addMore(), SizedBox(height: 22.h), _summary(subtotal)]),
            );
          },
        ),
      );

  Widget _storeStrip(List<Map<String, dynamic>> items) => Container(padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)), child: Row(children: [Container(width: 42.w, height: 42.w, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(11.r)), child: const Icon(Icons.storefront_rounded, color: AppColors.primary)), SizedBox(width: 11.w), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(CartManager.storeName.trim().isEmpty ? 'طلب Bringo' : CartManager.storeName, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)), SizedBox(height: 3.h), Text('${_count(items)} قطعة في الطلب', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary, fontWeight: FontWeight.w600))]))]));

  Widget _itemCard(Map<String, dynamic> item) {
    final id = item['id']?.toString() ?? '';
    final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
    final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
    return Container(margin: EdgeInsets.only(bottom: 10.h), padding: EdgeInsets.all(10.w), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15.r), border: Border.all(color: AppColors.border)), child: Row(children: [ClipRRect(borderRadius: BorderRadius.circular(12.r), child: SizedBox(width: 76.w, height: 76.w, child: _SmartImage(image: item['image']?.toString() ?? ''))), SizedBox(width: 11.w), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(item['name']?.toString() ?? 'منتج', maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.sp, height: 1.3, fontWeight: FontWeight.w900, color: AppColors.dark)), SizedBox(height: 8.h), Row(children: [Text('${(price * qty).toStringAsFixed(0)} جنيه', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: AppColors.primary)), const Spacer(), _qty(Icons.remove_rounded, () => qty <= 1 ? CartManager.removeProduct(id) : CartManager.updateQuantity(id, qty - 1)), SizedBox(width: 9.w), Text('$qty', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)), SizedBox(width: 9.w), _qty(Icons.add_rounded, () => CartManager.updateQuantity(id, qty + 1))])]))]));
  }

  Widget _qty(IconData icon, VoidCallback onTap) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(9.r), child: Container(width: 30.w, height: 30.w, decoration: BoxDecoration(color: const Color(0xFFF1F5F4), borderRadius: BorderRadius.circular(9.r)), child: Icon(icon, size: 18.sp, color: AppColors.primary)));
  Widget _addMore() => InkWell(onTap: _returnToShopping, borderRadius: BorderRadius.circular(12.r), child: Container(padding: EdgeInsets.symmetric(vertical: 13.h), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12.r), border: Border.all(color: AppColors.primary.withOpacity(.28))), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.add_rounded, color: AppColors.primary), SizedBox(width: 5.w), Text('إضافة منتجات أخرى', style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w900, color: AppColors.primary))])));
  Widget _summary(double subtotal) => Container(padding: EdgeInsets.all(16.w), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: AppColors.border)), child: Column(children: [_row('إجمالي المنتجات', subtotal), SizedBox(height: 11.h), _row('رسوم التوصيل', deliveryFee), if (deliveryQuote != null) Padding(padding: EdgeInsets.only(top: 5.h), child: Align(alignment: Alignment.centerRight, child: Text('${deliveryQuote!.storeZoneName} ← ${deliveryQuote!.customerZoneName}', style: TextStyle(fontSize: 10.sp, color: AppColors.textSecondary)))), Padding(padding: EdgeInsets.symmetric(vertical: 13.h), child: const Divider(height: 1)), _row('الإجمالي', subtotal + deliveryFee, bold: true)]));
  Widget _row(String title, double value, {bool bold = false}) => Row(children: [Text(title, style: TextStyle(fontSize: bold ? 15.sp : 13.sp, fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: bold ? AppColors.dark : AppColors.textSecondary)), const Spacer(), Text('${value.toStringAsFixed(0)} جنيه', style: TextStyle(fontSize: bold ? 17.sp : 13.sp, fontWeight: FontWeight.w900, color: bold ? AppColors.primary : AppColors.dark))]);

  Widget _bottomBar(List<Map<String, dynamic>> items, double subtotal) => Container(padding: EdgeInsets.fromLTRB(16.w, 11.h, 16.w, 12.h), decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: AppColors.border))), child: SafeArea(top: false, child: SizedBox(height: 56.h, child: ElevatedButton(onPressed: placingOrder ? null : () => _checkoutSheet(items), style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))), child: Row(children: [Text('${(subtotal + deliveryFee).toStringAsFixed(0)} جنيه', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)), const Spacer(), Text('متابعة الطلب', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)), SizedBox(width: 6.w), const Icon(Icons.arrow_back_rounded)])))));

  Future<void> _checkoutSheet(List<Map<String, dynamic>> items) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(builder: (context, sheetSetState) => Directionality(
            textDirection: TextDirection.rtl,
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .92),
              decoration: BoxDecoration(color: const Color(0xFFF7F8F8), borderRadius: BorderRadius.vertical(top: Radius.circular(24.r))),
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h + MediaQuery.of(context).viewInsets.bottom),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Center(child: Container(width: 42.w, height: 4.h, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)))),
                  SizedBox(height: 18.h),
                  Text('إتمام الطلب', style: TextStyle(fontSize: 21.sp, fontWeight: FontWeight.w900)),
                  SizedBox(height: 4.h),
                  Text('اختار منطقة التوصيل ثم راجع عنوانك', style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)),
                  SizedBox(height: 18.h),
                  _deliveryCard(onZoneChanged: (value) async { await _selectZone(value); sheetSetState(() {}); }),
                  SizedBox(height: 12.h),
                  Container(padding: EdgeInsets.all(14.w), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.local_shipping_outlined, color: AppColors.primary), SizedBox(width: 10.w), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(loadingQuote ? 'جاري حساب التوصيل...' : 'رسوم التوصيل ${deliveryFee.toStringAsFixed(0)} جنيه', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)), if (deliveryQuote != null) Text('${deliveryQuote!.storeZoneName} ← ${deliveryQuote!.customerZoneName}', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary))]))])),
                  SizedBox(height: 12.h),
                  Container(padding: EdgeInsets.all(14.w), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)), child: Row(children: [const Icon(Icons.payments_outlined, color: AppColors.primary), SizedBox(width: 10.w), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('الدفع عند الاستلام', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900)), Text('كاش', style: TextStyle(fontSize: 11.sp, color: AppColors.textSecondary))])), const Icon(Icons.check_circle_rounded, color: AppColors.primary)])),
                  SizedBox(height: 18.h),
                  SizedBox(width: double.infinity, height: 54.h, child: ElevatedButton(onPressed: placingOrder || loadingQuote ? null : () async { Navigator.of(sheetContext).pop(); await _placeOrder(items); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r))), child: Text('تأكيد الطلب • ${(_subtotal(items) + deliveryFee).toStringAsFixed(0)} جنيه', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)))),
                ]),
              ),
            ),
          )),
    );
  }

  Widget _deliveryCard({required ValueChanged<String?> onZoneChanged}) => Container(
        padding: EdgeInsets.all(14.w),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14.r), border: Border.all(color: AppColors.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Text('عنوان التوصيل', style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w900)), const Spacer(), InkWell(onTap: loadingLocation ? null : _loadLocation, child: Text('تحديث الموقع', style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: AppColors.primary)))]),
          SizedBox(height: 12.h),
          DropdownButtonFormField<String>(value: customerZoneId, decoration: InputDecoration(labelText: 'منطقة التوصيل *', prefixIcon: const Icon(Icons.map_outlined, color: AppColors.primary), filled: true, fillColor: const Color(0xFFF5F7F7), border: OutlineInputBorder(borderRadius: BorderRadius.circular(11.r), borderSide: BorderSide.none)), items: DeliveryZoneService.zones.map((zone) => DropdownMenuItem(value: zone.id, child: Text(zone.name))).toList(), onChanged: onZoneChanged),
          SizedBox(height: 12.h),
          if (loadingLocation) const LinearProgressIndicator(color: AppColors.primary) else Row(children: [const Icon(Icons.location_on_outlined, color: AppColors.primary), SizedBox(width: 8.w), Expanded(child: Text(detectedAddress, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700)))]),
          SizedBox(height: 14.h),
          _field(nameController, 'اسم المستلم', Icons.person_outline),
          SizedBox(height: 9.h),
          _field(phoneController, 'رقم الهاتف', Icons.phone_outlined, type: TextInputType.phone),
          SizedBox(height: 9.h),
          _field(areaController, 'الحي / القرية / المنطقة بالتفصيل *', Icons.location_city_outlined),
          SizedBox(height: 9.h),
          _field(streetController, 'الشارع أو الطريق *', Icons.signpost_outlined),
          SizedBox(height: 9.h),
          Row(children: [Expanded(child: _field(buildingController, 'المنزل', Icons.home_work_outlined)), SizedBox(width: 8.w), Expanded(child: _field(floorController, 'الدور', Icons.stairs_outlined)), SizedBox(width: 8.w), Expanded(child: _field(apartmentController, 'الشقة', Icons.door_front_door_outlined))]),
          SizedBox(height: 9.h),
          _field(landmarkController, 'علامة مميزة', Icons.place_outlined),
          SizedBox(height: 9.h),
          _field(notesController, 'ملاحظات للطيار', Icons.notes_outlined, lines: 2),
        ]),
      );

  Widget _field(TextEditingController controller, String hint, IconData icon, {TextInputType type = TextInputType.text, int lines = 1}) => TextField(controller: controller, keyboardType: type, maxLines: lines, style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700), decoration: InputDecoration(hintText: hint, prefixIcon: Icon(icon, size: 19.sp, color: AppColors.textSecondary), filled: true, fillColor: const Color(0xFFF5F7F7), contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 12.h), border: OutlineInputBorder(borderRadius: BorderRadius.circular(11.r), borderSide: BorderSide.none)));
  Widget _empty() => Center(child: Padding(padding: EdgeInsets.all(28.w), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 88.w, height: 88.w, decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(24.r)), child: Icon(Icons.shopping_bag_outlined, color: AppColors.primary, size: 40.sp)), SizedBox(height: 18.h), Text('سلتك فاضية', style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w900)), SizedBox(height: 6.h), Text('اختار منتجاتك وهتظهر هنا جاهزة للطلب', textAlign: TextAlign.center, style: TextStyle(fontSize: 12.sp, color: AppColors.textSecondary)), SizedBox(height: 20.h), TextButton(onPressed: _returnToShopping, child: const Text('الرجوع للتسوق'))])));

  @override
  void dispose() {
    notesController.dispose(); nameController.dispose(); phoneController.dispose(); areaController.dispose(); streetController.dispose(); buildingController.dispose(); floorController.dispose(); apartmentController.dispose(); landmarkController.dispose();
    super.dispose();
  }
}

class _SmartImage extends StatelessWidget {
  final String image;
  const _SmartImage({required this.image});
  @override
  Widget build(BuildContext context) {
    final value = image.trim();
    if (value.isEmpty) return _fallback();
    if (value.startsWith('data:image')) {
      try { return Image.memory(base64Decode(value.split(',').last), fit: BoxFit.cover, width: double.infinity, height: double.infinity); } catch (_) { return _fallback(); }
    }
    if (!value.startsWith('http')) {
      try { return Image.memory(base64Decode(value), fit: BoxFit.cover, width: double.infinity, height: double.infinity); } catch (_) { return _fallback(); }
    }
    return Image.network(value, fit: BoxFit.cover, width: double.infinity, height: double.infinity, errorBuilder: (_, __, ___) => _fallback());
  }
  Widget _fallback() => Container(color: AppColors.primaryLight, alignment: Alignment.center, child: const Icon(Icons.fastfood_outlined, color: AppColors.primary));
}
