import 'dart:convert';

import 'package:bringo/core/constant/app_colors.dart';

import 'package:bringo/core/services/adress_services.dart';

import 'package:bringo/core/services/location_service.dart';

import 'package:bringo/features/cart/cart_manager.dart';

import 'package:firebase_database/firebase_database.dart';

import 'package:flutter/material.dart';

import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'package:get_storage/get_storage.dart';

class CartScreen extends StatefulWidget {

  final List <Map<String, dynamic>> cartItems;

  const CartScreen({

    super.key,

    this.cartItems = const [],

  });

  @override

  State<CartScreen> createState() => _CartScreenState();

}

class _CartScreenState extends State<CartScreen> {

  final notesController = TextEditingController();

  final fallbackNameController = TextEditingController();

  final fallbackPhoneController = TextEditingController();

  final areaController = TextEditingController();

  final streetController = TextEditingController();

  final buildingController = TextEditingController();

  final floorController = TextEditingController();

  final apartmentController = TextEditingController();

  final landmarkController = TextEditingController();

  late List<Map<String, dynamic>> items;

  String customerName = '';

  String customerPhone = '';

  String deliveryArea = '';

  String deliveryAddressText = 'جاري تحديد موقعك...';

  double? deliveryLat;

  double? deliveryLng;

  final double deliveryFee = 30;

  bool isLoading = false;

  bool isLoadingLocation = true;

  bool isLoadingUser = true;

  @override

  void initState() {

    super.initState();

    _loadCartItems();

    _loadUserAndLocation();

  }

  void _loadCartItems() {

    items = CartManager.items

        .map((e) => Map<String, dynamic>.from(e))

        .where((item) => item.isNotEmpty)

        .toList();

  }

  Future<void> _loadUserAndLocation() async {

    await Future.wait([

      _loadUserData(),

      _loadLocationData(),

    ]);

    if (!mounted) return;

    setState(() {});

  }

  String _firstText(List<dynamic> values) {

    for (final value in values) {

      final text = value?.toString().trim() ?? '';

      if (text.isNotEmpty && text != 'null') return text;

    }

    return '';

  }

  Future<void> _loadUserData() async {

    final box = GetStorage();

    String name = _firstText([

      box.read('name'),

      box.read('fullName'),

      box.read('userName'),

      box.read('customerName'),

      box.read('displayName'),

    ]);

    String phone = _firstText([

      box.read('phone'),

 box.read('userPhone'),

 box.read('customerPhone'),

 box.read('mobile'),

 box.read('telephone'),

 ]);

 final userId = _firstText([

 box.read('userId'),

box.read('uid'),

 box.read('id'),

]);

 if (userId.isNotEmpty) {

 try {

 final userSnap =

 await FirebaseDatabase.instance.ref('users/$userId').get();

if (userSnap.exists && userSnap.value is Map) {

final user = Map<dynamic, dynamic>.from(userSnap.value as Map);

 name = name.isNotEmpty

 ? name

 : _firstText([

 user['name'],

 user['fullName'],

 user['userName'],

 user['customerName'],

 ]);

 phone = phone.isNotEmpty

 ? phone

 : _firstText([

 user['phone'],

 user['userPhone'],

 user['customerPhone'],

 user['mobile'],

 user['telephone'],

 ]);

 }

 } catch (_) {}

 try {

 final customerSnap =

 await FirebaseDatabase.instance.ref('customers/$userId').get();

 if (customerSnap.exists && customerSnap.value is Map) {

          final user = Map<dynamic, dynamic>.from(customerSnap.value as Map);

          name = name.isNotEmpty

              ? name

              : _firstText([

                  user['name'],

                  user['fullName'],

                  user['userName'],

                  user['customerName'],

                ]);

          phone = phone.isNotEmpty

              ? phone

              : _firstText([

                  user['phone'],

                  user['userPhone'],

                  user['customerPhone'],

                  user['mobile'],

                  user['telephone'],

                ]);

        }

      } catch (_) {}

    }

    customerName = name.isNotEmpty ? name : 'عميل Bringo';

    customerPhone = phone;

    fallbackNameController.text = customerName;

    fallbackPhoneController.text = customerPhone;

    areaController.text = _firstText([box.read('deliveryAreaDetails')]);

    streetController.text = _firstText([box.read('deliveryStreet')]);

    buildingController.text = _firstText([box.read('deliveryBuilding')]);

    floorController.text = _firstText([box.read('deliveryFloor')]);

    apartmentController.text = _firstText([box.read('deliveryApartment')]);

    landmarkController.text = _firstText([box.read('deliveryLandmark')]);

    if (mounted) {

      setState(() => isLoadingUser = false);

    }

  }

  Future<void> _loadLocationData() async {

    try {

      final location = await LocationService()

          .getCurrentLocation()

          .timeout(const Duration(seconds: 18));

      if (!mounted) return;

      if (location != null &&

          location.latitude != null &&

          location.longitude != null) {

        deliveryLat = location.latitude;

        deliveryLng = location.longitude;

        final detectedArea = await AddressService.getAreaName(

          location.latitude!,

          location.longitude!,

        ).timeout(

          const Duration(seconds: 12),

          onTimeout: () => 'موقعك الحالي',

        );

        deliveryArea = detectedArea.trim().isNotEmpty

            ? detectedArea.trim()

            : 'موقعك الحالي';

        deliveryAddressText = deliveryArea;

      } else {

        deliveryAddressText = 'تعذر تحديد الموقع - اضغط لإعادة المحاولة';

        deliveryArea = '';

      }

    } catch (_) {

      deliveryAddressText = 'تعذر تحديد الموقع - اضغط لإعادة المحاولة';

      deliveryArea = '';

    }

    if (mounted) {

      setState(() => isLoadingLocation = false);

    }

  }

  Future<void> _retryLocation() async {

    if (isLoadingLocation) return;

    setState(() {

      isLoadingLocation = true;

      deliveryAddressText = 'جاري تحديد موقعك...';

    });

    await _loadLocationData();

  }

  double get subtotal {

    return items.fold(0, (sum, item) {

      final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;

      final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

      return sum + (price * qty);

    });

  }

  double get total => subtotal + deliveryFee;

  void increaseQty(int index) {

    final productId = items[index]['id']?.toString() ?? '';

    final currentQty = int.tryParse(items[index]['quantity'].toString()) ?? 1;

    CartManager.updateQuantity(productId, currentQty + 1);

  }

  void decreaseQty(int index) {

    final productId = items[index]['id']?.toString() ?? '';

    final currentQty = int.tryParse(items[index]['quantity'].toString()) ?? 1;

    if (currentQty <= 1) return;

    CartManager.updateQuantity(productId, currentQty - 1);

  }

  void removeItem(int index) {

    final productId = items[index]['id']?.toString() ?? '';

    CartManager.removeProduct(productId);

  }

  void openCheckoutSheet() {

    if (items.isEmpty) {

      showMessage('السلة فارغة');

      return;

    }

    showModalBottomSheet(

      context: context,

      isScrollControlled: true,

      backgroundColor: Colors.transparent,

      builder: (_) {

        return Padding(

          padding: EdgeInsets.only(

            bottom: MediaQuery.of(context).viewInsets.bottom,

          ),

          child: Container(

            constraints: BoxConstraints(

              maxHeight: MediaQuery.of(context).size.height * .92,

            ),

            padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 18.h),

            decoration: BoxDecoration(

              color: const Color(0xFFF7F9F8),

              borderRadius: BorderRadius.only(

                topLeft: Radius.circular(32.r),

                topRight: Radius.circular(32.r),

              ),

            ),

            child: SingleChildScrollView(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.end,

                children: [

                  Center(

                    child: Container(

                      width: 52.w,

                      height: 5.h,

                      decoration: BoxDecoration(

                        color: Colors.grey.shade300,

                        borderRadius: BorderRadius.circular(50.r),

                      ),

                    ),

                  ),

                  SizedBox(height: 18.h),

                  Text(

                    'تأكيد الطلب',

                    style: TextStyle(

                      fontSize: 21.sp,

                      fontWeight: FontWeight.w900,

                      color: AppColors.dark,

                    ),

                  ),

                  SizedBox(height: 6.h),

                  Text(

                    'الدفع كاش عند الاستلام',

                    style: TextStyle(

                      fontSize: 12.sp,

                      color: Colors.grey.shade600,

                      fontWeight: FontWeight.w600,

                    ),

                  ),

                  SizedBox(height: 18.h),

                  _deliveryInfoBox(),

                  SizedBox(height: 18.h),

                  _paymentMethod(),

                  SizedBox(height: 18.h),

                  _summaryBox(),

                  SizedBox(height: 18.h),

                  SizedBox(

                    width: double.infinity,

                    height: 56.h,

                    child: ElevatedButton(

                      onPressed: isLoading ? null : placeOrder,

                      style: ElevatedButton.styleFrom(

                        backgroundColor: const Color(0xFF1F5A59),

                        elevation: 0,

                        shape: RoundedRectangleBorder(

                          borderRadius: BorderRadius.circular(20.r),

                        ),

                      ),

                      child: isLoading

                          ? const CircularProgressIndicator(color: Colors.white)

                          : Text(

                              'إرسال الطلب الآن',

                              style: TextStyle(

                                color: Colors.white,

                                fontSize: 16.sp,

                                fontWeight: FontWeight.w900,

                              ),

                            ),

                    ),

                  ),

                ],

              ),

            ),

          ),

        );

      },

    );

  }

  Future<void> placeOrder() async {

    if (items.isEmpty) {

      showMessage('السلة فارغة');

      return;

    }

    final finalName = fallbackNameController.text.trim().isNotEmpty

        ? fallbackNameController.text.trim()

        : customerName.trim();

    final finalPhone = fallbackPhoneController.text.trim().isNotEmpty

        ? fallbackPhoneController.text.trim()

        : customerPhone.trim();

    if (finalPhone.isEmpty) {

      showMessage('اكتب رقم الهاتف مرة واحدة لإرسال الطلب');

      return;

    }

    final detailedArea = areaController.text.trim();

    final street = streetController.text.trim();

    final building = buildingController.text.trim();

    final floor = floorController.text.trim();

    final apartment = apartmentController.text.trim();

    final landmark = landmarkController.text.trim();

    if (detailedArea.isEmpty) {

      showMessage('اكتب اسم القرية أو المنطقة بالتفصيل');

      return;

    }

    if (street.isEmpty) {

      showMessage('اكتب اسم الشارع أو الطريق');

      return;

    }

    if (isLoadingLocation) {

      showMessage('جاري تحديد موقعك، انتظر لحظة');

      return;

    }

    if (deliveryLat == null || deliveryLng == null) {

      showMessage('تعذر تحديد موقعك. اضغط على الموقع لإعادة المحاولة');

      return;

    }

    final fullAddress = [

      detailedArea,

      street,

      if (building.isNotEmpty) 'منزل/عمارة $building',

      if (floor.isNotEmpty) 'الدور $floor',

      if (apartment.isNotEmpty) 'شقة $apartment',

      if (landmark.isNotEmpty) 'علامة مميزة: $landmark',

    ].join(' - ');

    final storeId = CartManager.storeId.trim();

    final storeName = CartManager.storeName.trim();

    final storeType = CartManager.storeType.trim();

    if (storeId.isEmpty) {

      showMessage('تعذر تحديد المتجر المرتبط بالمنتجات');

      return;

    }

    try {

      setState(() => isLoading = true);

      final box = GetStorage();

      final userId = _firstText([

        box.read('userId'),

        box.read('uid'),

        box.read('id'),

      ]);

      await box.write('name', finalName);

      await box.write('phone', finalPhone);

      await box.write('deliveryAreaDetails', detailedArea);

      await box.write('deliveryStreet', street);

      await box.write('deliveryBuilding', building);

      await box.write('deliveryFloor', floor);

      await box.write('deliveryApartment', apartment);

      await box.write('deliveryLandmark', landmark);

      final orderRef = FirebaseDatabase.instance.ref('orders').push();

      final orderItems = items.map((item) {

        final quantity = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

        final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;

        return {

          'id': item['id']?.toString() ?? '',

          'productId': item['id']?.toString() ?? '',

          'name': item['name']?.toString() ?? '',

          'image': item['image']?.toString() ?? '',

          'price': price,

          'quantity': quantity,

          'total': price * quantity,

          'storeId': storeId,

        };

      }).toList();

      await orderRef.set({

        'id': orderRef.key,

        'storeId': storeId,

        'storeName': storeName,

        'storeType': storeType,

        'customerName': finalName,

        'customerPhone': finalPhone,

        'userId': userId,

        'customerAddress': fullAddress,

        'detectedAddress': deliveryAddressText,

        'address': {

          'governorate': 'سوهاج',

          'detectedArea': deliveryArea,

          'area': detailedArea,

          'street': street,

          'building': building,

          'floor': floor,

          'apartment': apartment,

          'landmark': landmark,

          'notes': notesController.text.trim(),

          'latitude': deliveryLat,

          'longitude': deliveryLng,

        },

        'items': orderItems,

        'subtotal': subtotal,

        'deliveryFee': deliveryFee,

        'total': total,

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

      Navigator.pop(context);

      CartManager.clear();

      setState(() {

        items.clear();

        customerName = finalName;

        customerPhone = finalPhone;

      });

      notesController.clear();

      await _successDialog();

    } catch (e, stackTrace) {

      debugPrint('Place order error: $e');

      debugPrintStack(stackTrace: stackTrace);

      showMessage('حصل خطأ أثناء إرسال الطلب');

    } finally {

      if (mounted) setState(() => isLoading = false);

    }

  }

  Future<void> _successDialog() async {

    await showDialog(

      context: context,

      barrierDismissible: false,

      builder: (_) {

        return Dialog(

          shape: RoundedRectangleBorder(

            borderRadius: BorderRadius.circular(28.r),

          ),

          child: Padding(

            padding: EdgeInsets.all(24.w),

            child: Column(

              mainAxisSize: MainAxisSize.min,

              children: [

                Container(

                  width: 82.w,

                  height: 82.w,

                  decoration: const BoxDecoration(

                    color: const Color(0xFFE8F2F0),

                    shape: BoxShape.circle,

                  ),

                  child: Icon(

                    Icons.check_circle_rounded,

                    color: const Color(0xFF1F5A59),

                    size: 54.sp,

                  ),

                ),

                SizedBox(height: 18.h),

                Text(

                  'تم إرسال طلبك بنجاح',

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    fontSize: 22.sp,

                    fontWeight: FontWeight.w900,

                    color: AppColors.dark,

                  ),

                ),

                SizedBox(height: 10.h),

                Text(

                  'طلبك وصل لفريق Bringo وسيتم توصيله خلال 20 - 25 دقيقة تقريبًا.',

                  textAlign: TextAlign.center,

                  style: TextStyle(

                    fontSize: 14.sp,

                    height: 1.6,

                    fontWeight: FontWeight.w600,

                    color: Colors.grey.shade700,

                  ),

                ),

                SizedBox(height: 22.h),

                SizedBox(

                  width: double.infinity,

                  height: 50.h,

                  child: ElevatedButton(

                    onPressed: () => Navigator.pop(context),

                    style: ElevatedButton.styleFrom(

                      backgroundColor: const Color(0xFF1F5A59),

                      elevation: 0,

                      shape: RoundedRectangleBorder(

                        borderRadius: BorderRadius.circular(18.r),

                      ),

                    ),

                    child: Text(

                      'تمام',

                      style: TextStyle(

                        color: Colors.white,

                        fontSize: 15.sp,

                        fontWeight: FontWeight.w900,

                      ),

                    ),

                  ),

                ),

              ],

            ),

          ),

        );

      },

    );

  }

  void showMessage(String message) {

    ScaffoldMessenger.of(context).showSnackBar(

      SnackBar(

        backgroundColor: const Color(0xFF1F5A59),

        content: Text(message, textAlign: TextAlign.right),

      ),

    );

  }

  @override

  void dispose() {

    notesController.dispose();

    fallbackNameController.dispose();

    fallbackPhoneController.dispose();

    areaController.dispose();

    streetController.dispose();

    buildingController.dispose();

    floorController.dispose();

    apartmentController.dispose();

    landmarkController.dispose();

    super.dispose();

  }

  @override

  Widget build(BuildContext context) {

    return ValueListenableBuilder<List<Map<String, dynamic>>>(

      valueListenable: CartManager.cartNotifier,

      builder: (context, cartItems, _) {

        items = cartItems.map((e) => Map<String, dynamic>.from(e)).toList();

        return Scaffold(

          backgroundColor: const Color(0xFFF7F9F8),

          appBar: AppBar(

            backgroundColor: Colors.white,

            elevation: 0,

            foregroundColor: AppColors.dark,

            centerTitle: true,

            title: const Text('سلة المشتريات'),

          ),

          bottomNavigationBar: items.isEmpty ? null : _checkoutBar(),

          body: SafeArea(

            child: items.isEmpty

                ? _emptyCart()

                : SingleChildScrollView(

                    padding: EdgeInsets.fromLTRB(18.w, 14.h, 18.w, 130.h),

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.end,

                      children: [

                        _cartHeader(),

                        SizedBox(height: 16.h),

                        _cartItems(),

                        SizedBox(height: 24.h),

                        _summaryBox(),

                      ],

                    ),

                  ),

          ),

        );

      },

    );

  }

  Widget _emptyCart() {

    return Center(

      child: Padding(

        padding: EdgeInsets.all(24.w),

        child: Column(

          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            Container(

              width: 110.w,

              height: 110.w,

              decoration: const BoxDecoration(

                color: const Color(0xFFE8F2F0),

                shape: BoxShape.circle,

              ),

              child: Icon(

                Icons.shopping_cart_outlined,

                color: const Color(0xFF1F5A59),

                size: 54.sp,

              ),

            ),

            SizedBox(height: 18.h),

            Text(

              'السلة فارغة',

              style: TextStyle(

                fontSize: 22.sp,

                fontWeight: FontWeight.w900,

                color: AppColors.dark,

              ),

            ),

            SizedBox(height: 8.h),

            Text(

              'ابدأ بإضافة منتجات من الصفحة الرئيسية',

              textAlign: TextAlign.center,

              style: TextStyle(

                fontSize: 14.sp,

                color: Colors.grey.shade600,

                fontWeight: FontWeight.w600,

              ),

            ),

          ],

        ),

      ),

    );

  }

  Widget _cartHeader() {

    return Container(

      width: double.infinity,

      padding: EdgeInsets.all(18.w),

      decoration: BoxDecoration(

        gradient: const LinearGradient(

          colors: [

            Color(0xFF1F5A59),

            Color(0xFF174746),

          ],

        ),

        borderRadius: BorderRadius.circular(28.r),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.end,

        children: [

          Text(

            CartManager.storeName.trim().isNotEmpty ? CartManager.storeName.trim() : 'طلبك من Bringo',

            style: TextStyle(

              fontSize: 20.sp,

              fontWeight: FontWeight.w900,

              color: Colors.white,

            ),

          ),

          SizedBox(height: 8.h),

          Text(

            '${items.length} منتج في سلتك • راجع الكميات قبل المتابعة',

            style: TextStyle(

              fontSize: 13.sp,

              fontWeight: FontWeight.w700,

              color: Colors.white.withOpacity(.9),

            ),

          ),

        ],

      ),

    );

  }

  Widget _cartItems() {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.end,

      children: [

        _title('المنتجات'),

        SizedBox(height: 12.h),

        ...List.generate(items.length, (index) {

          final item = items[index];

          final price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;

          final qty = int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;

          return Container(

            margin: EdgeInsets.only(bottom: 12.h),

            padding: EdgeInsets.all(12.w),

            decoration: BoxDecoration(

              color: Colors.white,

              borderRadius: BorderRadius.circular(24.r),

              boxShadow: [

                BoxShadow(

                  color: AppColors.primary.withOpacity(.06),

                  blurRadius: 18,

                  offset: const Offset(0, 8),

                ),

              ],

            ),

            child: Row(

              children: [

                IconButton(

                  onPressed: () => removeItem(index),

                  icon: const Icon(Icons.delete_outline_rounded),

                  color: Colors.red,

                ),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.end,

                    children: [

                      Text(

                        item['name']?.toString() ?? '',

                        textAlign: TextAlign.right,

                        maxLines: 2,

                        overflow: TextOverflow.ellipsis,

                        style: TextStyle(

                          fontSize: 14.sp,

                          fontWeight: FontWeight.w900,

                          color: AppColors.dark,

                        ),

                      ),

                      SizedBox(height: 4.h),

                      Text(

                        item['brand']?.toString() ?? '',

                        style: TextStyle(

                          fontSize: 11.sp,

                          color: Colors.grey,

                          fontWeight: FontWeight.w600,

                        ),

                      ),

                      SizedBox(height: 10.h),

                      Row(

                        children: [

                          _qtyButton(Icons.remove, () => decreaseQty(index)),

                          SizedBox(width: 10.w),

                          Text(

                            '$qty',

                            style: TextStyle(

                              fontSize: 15.sp,

                              fontWeight: FontWeight.w900,

                            ),

                          ),

                          SizedBox(width: 10.w),

                          _qtyButton(Icons.add, () => increaseQty(index)),

                          const Spacer(),

                          Text(

                            '${(price * qty).toStringAsFixed(0)} جنيه',

                            style: TextStyle(

                              fontSize: 15.sp,

                              color: const Color(0xFF1F5A59),

                              fontWeight: FontWeight.w900,

                            ),

                          ),

                        ],

                      ),

                    ],

                  ),

                ),

                SizedBox(width: 12.w),

                ClipRRect(

                  borderRadius: BorderRadius.circular(18.r),

                  child: SizedBox(

                    width: 82.w,

                    height: 82.w,

                    child: _SmartImage(

                      image: item['image']?.toString() ?? '',

                    ),

                  ),

                ),

              ],

            ),

          );

        }),

      ],

    );

  }

  Widget _deliveryInfoBox() {

    final showNameInput =

        customerName.trim().isEmpty || customerName.trim() == 'عميل Bringo';

    final showPhoneInput = customerPhone.trim().isEmpty;

    return Container(

      padding: EdgeInsets.all(16.w),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(26.r),

      ),

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.end,

        children: [

          Text(

            'بيانات التوصيل',

            style: TextStyle(

              fontSize: 18.sp,

              fontWeight: FontWeight.w900,

              color: AppColors.dark,

            ),

          ),

          SizedBox(height: 14.h),

          if (isLoadingUser)

            _infoRow(Icons.person, 'الحساب', 'جاري تحميل بيانات الحساب...')

          else ...[

            if (showNameInput)

              _input(fallbackNameController, 'اسم المستلم', Icons.person)

            else

              _infoRow(Icons.person, 'الاسم', customerName),

            SizedBox(height: 12.h),

            if (showPhoneInput)

              _input(

                fallbackPhoneController,

                'رقم الهاتف',

                Icons.phone,

                keyboardType: TextInputType.phone,

              )

            else

              _infoRow(Icons.phone, 'رقم الهاتف', customerPhone),

          ],

          SizedBox(height: 14.h),

          InkWell(

            borderRadius: BorderRadius.circular(18.r),

            onTap: isLoadingLocation ? null : _retryLocation,

            child: Container(

              width: double.infinity,

              padding: EdgeInsets.all(14.w),

              decoration: BoxDecoration(

                color: const Color(0xFFF1F6F5),

                borderRadius: BorderRadius.circular(18.r),

                border: Border.all(color: const Color(0xFFD8E7E4)),

              ),

              child: Row(

                children: [

                  if (isLoadingLocation)

                    SizedBox(

                      width: 20.w,

                      height: 20.w,

                      child: const CircularProgressIndicator(

                        strokeWidth: 2.4,

                        color: const Color(0xFF1F5A59),

                      ),

                    )

                  else

                    Icon(

                      deliveryLat != null

                          ? Icons.my_location_rounded

                          : Icons.refresh_rounded,

                      color: const Color(0xFF1F5A59),

                      size: 22.sp,

                    ),

                  SizedBox(width: 10.w),

                  Expanded(

                    child: Column(

                      crossAxisAlignment: CrossAxisAlignment.end,

                      children: [

                        Text(

                          'الموقع التلقائي',

                          style: TextStyle(

                            fontSize: 12.sp,

                            color: Colors.grey.shade600,

                            fontWeight: FontWeight.w700,

                          ),

                        ),

                        SizedBox(height: 4.h),

                        Text(

                          isLoadingLocation

                              ? 'جاري تحديد موقعك...'

                              : deliveryAddressText,

                          textAlign: TextAlign.right,

                          style: TextStyle(

                            fontSize: 13.sp,

                            color: AppColors.dark,

                            fontWeight: FontWeight.w900,

                          ),

                        ),

                      ],

                    ),

                  ),

                ],

              ),

            ),

          ),

          SizedBox(height: 14.h),

          Text(

            'اكتب عنوان التوصيل بالتفصيل',

            style: TextStyle(

              fontSize: 15.sp,

              color: AppColors.dark,

              fontWeight: FontWeight.w900,

            ),

          ),

          SizedBox(height: 10.h),

          _input(areaController, 'القرية أو المنطقة *',

              Icons.location_city_rounded),

          SizedBox(height: 10.h),

          _input(streetController, 'اسم الشارع أو الطريق *',

              Icons.signpost_rounded),

          SizedBox(height: 10.h),

          Row(

            children: [

              Expanded(

                child: _input(apartmentController, 'الشقة',

                    Icons.door_front_door_outlined),

              ),

              SizedBox(width: 10.w),

              Expanded(

                child: _input(floorController, 'الدور', Icons.stairs_rounded),

              ),

              SizedBox(width: 10.w),

              Expanded(

                child: _input(buildingController, 'المنزل/العمارة',

                    Icons.home_work_outlined),

              ),

            ],

          ),

          SizedBox(height: 10.h),

          _input(

            landmarkController,

            'علامة مميزة قريبة',

            Icons.place_outlined,

            maxLines: 2,

          ),

          SizedBox(height: 10.h),

          _input(

            notesController,

            'ملاحظات اختيارية للطيار',

            Icons.notes,

            maxLines: 3,

          ),

        ],

      ),

    );

  }

  Widget _infoRow(IconData icon, String title, String value) {

    return Row(

      children: [

        Icon(icon, color: const Color(0xFF1F5A59), size: 22.sp),

        SizedBox(width: 8.w),

        Expanded(

          child: Text(

            value,

            textAlign: TextAlign.left,

            style: TextStyle(

              fontSize: 14.sp,

              fontWeight: FontWeight.w800,

              color: AppColors.dark,

            ),

          ),

        ),

        SizedBox(width: 12.w),

        Text(

          title,

          style: TextStyle(

            fontSize: 13.sp,

            fontWeight: FontWeight.w700,

            color: Colors.grey.shade600,

          ),

        ),

      ],

    );

  }

  Widget _paymentMethod() {

    return Container(

      padding: EdgeInsets.all(16.w),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius: BorderRadius.circular(24.r),

        border: Border.all(color: const Color(0xFFD8E7E4)),

      ),

      child: Row(

        children: [

          Container(

            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 7.h),

            decoration: BoxDecoration(

              color: const Color(0xFFE8F2F0),

              borderRadius: BorderRadius.circular(20.r),

            ),

            child: Text(

              'متاح الآن',

              style: TextStyle(

                color: const Color(0xFF1F5A59),

                fontSize: 12.sp,

                fontWeight: FontWeight.w900,

              ),

            ),

          ),

          const Spacer(),

          Column(

            crossAxisAlignment: CrossAxisAlignment.end,

            children: [

              Text(

                'الدفع عند الاستلام',

                style: TextStyle(

                  fontSize: 15.sp,

                  fontWeight: FontWeight.w900,

                  color: AppColors.dark,

                ),

              ),

              SizedBox(height: 4.h),

              Text(

                'سيتم إضافة الدفع الإلكتروني قريبًا',

                style: TextStyle(

                  fontSize: 12.sp,

                  color: Colors.grey,

                  fontWeight: FontWeight.w600,

                ),

              ),

            ],

          ),

          SizedBox(width: 12.w),

          const Icon(Icons.payments_rounded, color: AppColors.primary),

        ],

      ),

    );

  }

  Widget _summaryBox() {

    return Column(

      crossAxisAlignment: CrossAxisAlignment.end,

      children: [

        _title('ملخص الطلب'),

        SizedBox(height: 12.h),

        Container(

          padding: EdgeInsets.all(16.w),

          decoration: BoxDecoration(

            color: Colors.white,

            borderRadius: BorderRadius.circular(24.r),

          ),

          child: Column(

            children: [

              _summaryRow('إجمالي المنتجات', subtotal),

              SizedBox(height: 10.h),

              _summaryRow('رسوم التوصيل', deliveryFee),

              Divider(height: 26.h),

              _summaryRow('الإجمالي النهائي', total, bold: true),

            ],

          ),

        ),

      ],

    );

  }

  Widget _checkoutBar() {

    return Container(

      padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, 18.h),

      decoration: BoxDecoration(

        color: Colors.white,

        boxShadow: [

          BoxShadow(

            color: Colors.black.withOpacity(.08),

            blurRadius: 24,

            offset: const Offset(0, -8),

          ),

        ],

      ),

      child: SafeArea(

        top: false,

        child: SizedBox(

          height: 56.h,

          width: double.infinity,

          child: ElevatedButton(

            onPressed: isLoading ? null : openCheckoutSheet,

            style: ElevatedButton.styleFrom(

              backgroundColor: const Color(0xFF1F5A59),

              elevation: 0,

              shape: RoundedRectangleBorder(

                borderRadius: BorderRadius.circular(20.r),

              ),

            ),

            child: Text(

              'متابعة إتمام الطلب',

              style: TextStyle(

                color: Colors.white,

                fontSize: 16.sp,

                fontWeight: FontWeight.w900,

              ),

            ),

          ),

        ),

      ),

    );

  }

  Widget _title(String text) {

    return Text(

      text,

      textAlign: TextAlign.right,

      style: TextStyle(

        fontSize: 19.sp,

        fontWeight: FontWeight.w900,

        color: AppColors.dark,

      ),

    );

  }

  Widget _input(

    TextEditingController controller,

    String hint,

    IconData icon, {

    TextInputType keyboardType = TextInputType.text,

    int maxLines = 1,

  }) {

    return TextField(

      controller: controller,

      keyboardType: keyboardType,

      maxLines: maxLines,

      textAlign: TextAlign.right,

      decoration: InputDecoration(

        hintText: hint,

        prefixIcon: Icon(icon, color: AppColors.primary),

        filled: true,

        fillColor: const Color(0xFFF1F6F5),

        border: OutlineInputBorder(

          borderRadius: BorderRadius.circular(18.r),

          borderSide: BorderSide.none,

        ),

      ),

    );

  }

  Widget _qtyButton(IconData icon, VoidCallback onTap) {

    return InkWell(

      borderRadius: BorderRadius.circular(18.r),

      onTap: onTap,

      child: Container(

        width: 32.w,

        height: 32.w,

        decoration: const BoxDecoration(

          color: const Color(0xFFE8F2F0),

          shape: BoxShape.circle,

        ),

        child: Icon(icon, color: const Color(0xFF1F5A59), size: 18.sp),

      ),

    );

  }

  Widget _summaryRow(String title, double value, {bool bold = false}) {

    return Row(

      children: [

        Text(

          '${value.toStringAsFixed(0)} جنيه',

          style: TextStyle(

            fontSize: bold ? 17.sp : 14.sp,

            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,

            color: bold ? const Color(0xFF1F5A59) : AppColors.dark,

          ),

        ),

        const Spacer(),

        Text(

          title,

          style: TextStyle(

            fontSize: bold ? 17.sp : 14.sp,

            fontWeight: bold ? FontWeight.w900 : FontWeight.w700,

            color: AppColors.dark,

          ),

        ),

      ],

    );

  }

}

class _SmartImage extends StatelessWidget {

  final String image;

  const _SmartImage({required this.image});

  @override

  Widget build(BuildContext context) {

    if (image.isEmpty) return _fallback();

    if (image.startsWith('data:image')) {

      try {

        final bytes = base64Decode(image.split(',').last);

        return Image.memory(

          bytes,

          fit: BoxFit.cover,

          width: double.infinity,

          height: double.infinity,

        );

      } catch (_) {

        return _fallback();

      }

    }

    return Image.network(

      image,

      fit: BoxFit.cover,

      width: double.infinity,

      height: double.infinity,

      errorBuilder: (_, __, ___) => _fallback(),

    );

  }

  Widget _fallback() {

    return Container(

      color: const Color(0xFFE8F2F0),

      child: const Center(

        child: Icon(

          Icons.image,

          color: const Color(0xFF1F5A59),

        ),

      ),

    );

  }

}