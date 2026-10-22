import 'package:bringo/core/routing/app_routes.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:go_router/go_router.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen>
    with SingleTickerProviderStateMixin {
  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color background = Color(0xFFF7FAF8);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);
  static const Color border = Color(0xFFE4EAE8);

  late final TabController tabController;
  final GetStorage box = GetStorage();
  late final String currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = _firstText([
      box.read('userId'),
      box.read('uid'),
      box.read('id'),
    ]);
    tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  String _statusOf(Map<String, dynamic> order) {
    final raw = _firstText([
      order['status'],
      order['orderStatus'],
    ]).replaceAll('_', '').replaceAll('-', '').toLowerCase();

    const aliases = {
      'pending': 'pending',
      'new': 'pending',
      'confirmed': 'confirmed',
      'accepted': 'confirmed',
      'preparing': 'preparing',
      'ready': 'ready',
      'assigned': 'assigned',
      'picked': 'pickedUp',
      'pickedup': 'pickedUp',
      'way': 'onDelivery',
      'ondelivery': 'onDelivery',
      'arrived': 'arrived',
      'done': 'completed',
      'delivered': 'completed',
      'completed': 'completed',
      'rejected': 'cancelled',
      'cancelled': 'cancelled',
      'canceled': 'cancelled',
    };
    return aliases[raw] ?? 'pending';
  }

  bool _matchStatus(Map<String, dynamic> order, String tab) {
    final status = _statusOf(order);
    if (tab == 'active') {
      return const [
        'pending',
        'preparing',
        'confirmed',
        'ready',
        'assigned',
        'pickedUp',
        'onDelivery',
        'arrived',
      ].contains(status);
    }
    if (tab == 'completed') return status == 'completed';
    if (tab == 'cancelled') return status == 'cancelled';
    return false;
  }

  void _openTracking(Map<String, dynamic> order) {
    final orderId = _firstText([
      order['firebaseKey'],
      order['id'],
    ]);

    if (orderId.isEmpty) {
      _showMessage('رقم الطلب غير متوفر');
      return;
    }

    context.push(AppRoutes.orderTracking, extra: orderId);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: darkTeal,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
          ),
          content: Text(message, textAlign: TextAlign.right),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId.isEmpty) {
      return _notLoggedIn();
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: Column(
            children: [
              _header(),
              SizedBox(height: 18.h),
              _tabs(),
              SizedBox(height: 8.h),
              Expanded(
                child: StreamBuilder<DatabaseEvent>(
                  stream: FirebaseDatabase.instance
                      .ref('orders')
                      .orderByChild('userId')
                      .equalTo(currentUserId)
                      .onValue,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _OrdersShimmer();
                    }

                    if (snapshot.hasError) {
                      return _errorState();
                    }

                    final allOrders = _parseOrders(
                      snapshot.data?.snapshot.value,
                    );

                    return TabBarView(
                      controller: tabController,
                      children: [
                        _ordersList(allOrders, 'active'),
                        _ordersList(allOrders, 'completed'),
                        _ordersList(allOrders, 'cancelled'),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notLoggedIn() {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(28.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _BringoMark(size: 76),
                SizedBox(height: 22.h),
                Text(
                  'سجل دخولك لمتابعة طلباتك',
                  style: TextStyle(
                    color: textDark,
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7.h),
                Text(
                  'كل طلباتك وحالتها هتظهر هنا لحظة بلحظة',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textGrey,
                    fontSize: 12.5.sp,
                    height: 1.6,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _parseOrders(dynamic value) {
    if (value == null || value is! Map) return [];

    final data = Map<dynamic, dynamic>.from(value);
    final orders = <Map<String, dynamic>>[];

    data.forEach((key, value) {
      if (value is! Map) return;
      final item = Map<String, dynamic>.from(value);
      item['firebaseKey'] = key.toString();
      if (item['userId']?.toString() == currentUserId) {
        orders.add(item);
      }
    });

    orders.sort((a, b) {
      final aTime = int.tryParse(a['createdAt']?.toString() ?? '0') ?? 0;
      final bTime = int.tryParse(b['createdAt']?.toString() ?? '0') ?? 0;
      return bTime.compareTo(aTime);
    });

    return orders;
  }

  Widget _header() {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, 15.h, 20.w, 0),
      child: Row(
        children: [
          Container(
            width: 46.w,
            height: 46.w,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: border),
            ),
            child: Icon(
              Icons.receipt_long_rounded,
              color: teal,
              size: 22.sp,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'طلباتي',
                    style: TextStyle(
                      color: textDark,
                      fontSize: 25.sp,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(width: 9.w),
                  const _BringoMark(size: 31),
                ],
              ),
              SizedBox(height: 3.h),
              Text(
                'كل طلباتك في مكان واحد',
                style: TextStyle(
                  color: textGrey,
                  fontSize: 11.5.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tabs() {
    return Container(
      height: 52.h,
      margin: EdgeInsets.symmetric(horizontal: 18.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFEDF2F0),
        borderRadius: BorderRadius.circular(17.r),
      ),
      child: TabBar(
        controller: tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        splashBorderRadius: BorderRadius.circular(14.r),
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: darkTeal.withOpacity(.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        labelColor: darkTeal,
        unselectedLabelColor: textGrey,
        labelStyle: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w900,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w700,
        ),
        tabs: const [
          Tab(text: 'قيد التنفيذ'),
          Tab(text: 'مكتملة'),
          Tab(text: 'ملغية'),
        ],
      ),
    );
  }

  Widget _ordersList(List<Map<String, dynamic>> orders, String tab) {
    final filtered = orders.where((o) => _matchStatus(o, tab)).toList();

    if (filtered.isEmpty) return _emptyState(tab);

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 120.h),
      physics: const BouncingScrollPhysics(),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => SizedBox(height: 13.h),
      itemBuilder: (_, index) {
        return _OrderCard(
          order: filtered[index],
          onTrack: () => _openTracking(filtered[index]),
        );
      },
    );
  }

  Widget _emptyState(String tab) {
    String title = 'لا توجد طلبات حاليًا';
    String subtitle = 'طلباتك ستظهر هنا';
    IconData icon = Icons.receipt_long_outlined;

    if (tab == 'active') {
      title = 'مفيش طلبات شغالة دلوقتي';
      subtitle = 'لما تعمل طلب جديد هتقدر تتابعه من هنا';
      icon = Icons.delivery_dining_rounded;
    } else if (tab == 'completed') {
      title = 'لسه مفيش طلبات مكتملة';
      subtitle = 'الطلبات اللي وصلتك هتظهر هنا';
      icon = Icons.check_circle_outline_rounded;
    } else if (tab == 'cancelled') {
      title = 'مفيش طلبات ملغية';
      subtitle = 'أي طلب تم إلغاؤه هيظهر هنا';
      icon = Icons.cancel_outlined;
    }

    return Center(
      child: Padding(
        padding: EdgeInsets.all(30.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92.w,
              height: 92.w,
              decoration: const BoxDecoration(
                color: Color(0xFFEAF3F2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: teal, size: 43.sp),
            ),
            SizedBox(height: 18.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textDark,
                fontSize: 17.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textGrey,
                fontSize: 12.sp,
                height: 1.55,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorState() {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(28.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_rounded, color: textGrey, size: 52.sp),
            SizedBox(height: 14.h),
            Text(
              'تعذر تحميل الطلبات',
              style: TextStyle(
                color: textDark,
                fontSize: 17.sp,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              'تحقق من اتصال الإنترنت وحاول مرة أخرى',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textGrey,
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Map<String, dynamic> order;
  final VoidCallback onTrack;

  const _OrderCard({
    required this.order,
    required this.onTrack,
  });

  static const Color teal = Color(0xFF1F5A59);
  static const Color darkTeal = Color(0xFF174746);
  static const Color lime = Color(0xFFDDFB8A);
  static const Color textDark = Color(0xFF182322);
  static const Color textGrey = Color(0xFF77817F);
  static const Color border = Color(0xFFE4EAE8);

  String _firstText(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  String _statusOf() {
    final raw = _firstText([
      order['orderStatus'],
      order['status'],
    ]).replaceAll('_', '').replaceAll('-', '').toLowerCase();

    const aliases = {
      'pending': 'pending',
      'new': 'pending',
      'confirmed': 'confirmed',
      'accepted': 'confirmed',
      'preparing': 'preparing',
      'ready': 'ready',
      'assigned': 'assigned',
      'picked': 'pickedUp',
      'pickedup': 'pickedUp',
      'way': 'onDelivery',
      'ondelivery': 'onDelivery',
      'arrived': 'arrived',
      'done': 'completed',
      'delivered': 'completed',
      'completed': 'completed',
      'rejected': 'cancelled',
      'cancelled': 'cancelled',
      'canceled': 'cancelled',
    };

    return aliases[raw] ?? 'pending';
  }

  int _progressStep(String status) {
    switch (status) {
      case 'pending':
        return 1;
      case 'confirmed':
        return 2;
      case 'preparing':
        return 3;
      case 'ready':
      case 'assigned':
        return 4;
      case 'pickedUp':
        return 5;
      case 'onDelivery':
      case 'arrived':
        return 6;
      case 'completed':
        return 7;
      default:
        return 1;
    }
  }

  String _storeName() {
    final store = order['store'] is Map
        ? Map<String, dynamic>.from(order['store'] as Map)
        : <String, dynamic>{};

    return _firstText([
      order['storeName'],
      order['restaurantName'],
      order['pharmacyName'],
      order['merchantName'],
      order['vendorName'],
      order['shopName'],
      store['name'],
      store['storeName'],
    ]);
  }

  String _storeImage() {
    final store = order['store'] is Map
        ? Map<String, dynamic>.from(order['store'] as Map)
        : <String, dynamic>{};

    return _firstText([
      order['storeLogo'],
      order['storeImage'],
      order['restaurantImage'],
      order['merchantImage'],
      store['logo'],
      store['image'],
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusOf();
    final total = double.tryParse(order['total']?.toString() ?? '0') ?? 0;
    final orderId = _firstText([order['id'], order['firebaseKey']]);
    final createdAt = int.tryParse(order['createdAt']?.toString() ?? '0') ?? 0;
    final items = _parseItems(order['items']);
    final storeName = _storeName();
    final storeImage = _storeImage();
    final progressStep = _progressStep(status);
    final isCancelled = status == 'cancelled';
    final isCompleted = status == 'completed';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isCancelled ? null : onTrack,
        borderRadius: BorderRadius.circular(22.r),
        child: Container(
          padding: EdgeInsets.all(15.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                textDirection: TextDirection.rtl,
                children: [
                  _storeAvatar(storeImage),
                  SizedBox(width: 11.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          storeName.isEmpty ? 'متجر Bringo' : storeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: textDark,
                            fontSize: 14.5.sp,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 3.h),
                        Text(
                          'طلب #${_shortId(orderId)}  •  ${_formatDate(createdAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textDirection: TextDirection.rtl,
                          style: TextStyle(
                            color: textGrey,
                            fontSize: 10.5.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 9.w),
                  _statusBadge(status),
                ],
              ),

              if (!isCancelled) ...[
                SizedBox(height: 16.h),
                Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20.r),
                        child: LinearProgressIndicator(
                          value: progressStep / 7,
                          minHeight: 6.h,
                          backgroundColor: const Color(0xFFEDF1EF),
                          valueColor: const AlwaysStoppedAnimation<Color>(lime),
                        ),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Text(
                      '$progressStep/7',
                      style: TextStyle(
                        color: teal,
                        fontSize: 10.5.sp,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],

              SizedBox(height: 15.h),

              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 12.w,
                  vertical: 11.h,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F9F8),
                  borderRadius: BorderRadius.circular(15.r),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Container(
                      width: 35.w,
                      height: 35.w,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEAF3F2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.shopping_bag_outlined,
                        color: teal,
                        size: 18.sp,
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        _itemsPreview(items),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: textDark,
                          fontSize: 11.5.sp,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      '${items.length} ${items.length == 1 ? 'منتج' : 'منتجات'}',
                      style: TextStyle(
                        color: textGrey,
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: 15.h),

              Row(
                textDirection: TextDirection.rtl,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'الإجمالي',
                        style: TextStyle(
                          color: textGrey,
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${total.toStringAsFixed(0)} جنيه',
                        style: TextStyle(
                          color: darkTeal,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (!isCancelled)
                    SizedBox(
                      height: 43.h,
                      child: ElevatedButton(
                        onPressed: onTrack,
                        style: ElevatedButton.styleFrom(
                          elevation: 0,
                          backgroundColor: isCompleted
                              ? const Color(0xFFEAF3F2)
                              : teal,
                          foregroundColor: isCompleted ? teal : Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 15.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13.r),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isCompleted ? 'التفاصيل' : 'تتبع الطلب',
                              style: TextStyle(
                                fontSize: 11.5.sp,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Icon(
                              isCompleted
                                  ? Icons.receipt_long_rounded
                                  : Icons.arrow_back_rounded,
                              size: 17.sp,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _storeAvatar(String image) {
    return Container(
      width: 52.w,
      height: 52.w,
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
        border: Border.all(color: border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: image.isNotEmpty
            ? Image.network(
                image,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _storeFallback(),
              )
            : _storeFallback(),
      ),
    );
  }

  Widget _storeFallback() {
    return Container(
      color: const Color(0xFFEAF3F2),
      child: Icon(
        Icons.storefront_rounded,
        color: teal,
        size: 25.sp,
      ),
    );
  }

  Widget _statusBadge(String status) {
    String text;
    IconData icon;
    Color bg = const Color(0xFFEAF3F2);
    Color fg = teal;

    switch (status) {
      case 'pending':
        text = 'بانتظار التأكيد';
        icon = Icons.schedule_rounded;
        break;
      case 'confirmed':
        text = 'تم التأكيد';
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'preparing':
        text = 'جاري التجهيز';
        icon = Icons.inventory_2_outlined;
        break;
      case 'ready':
        text = 'جاهز';
        icon = Icons.shopping_bag_outlined;
        break;
      case 'assigned':
        text = 'تم تعيين طيار';
        icon = Icons.delivery_dining_rounded;
        break;
      case 'pickedUp':
        text = 'استلمه الطيار';
        icon = Icons.shopping_bag_rounded;
        break;
      case 'onDelivery':
        text = 'في الطريق';
        icon = Icons.delivery_dining_rounded;
        bg = lime.withOpacity(.48);
        fg = darkTeal;
        break;
      case 'arrived':
        text = 'الطيار وصل';
        icon = Icons.location_on_rounded;
        bg = lime.withOpacity(.48);
        fg = darkTeal;
        break;
      case 'completed':
        text = 'تم التسليم';
        icon = Icons.check_circle_rounded;
        bg = const Color(0xFFE9F8EF);
        fg = const Color(0xFF15803D);
        break;
      case 'cancelled':
        text = 'ملغي';
        icon = Icons.cancel_rounded;
        bg = const Color(0xFFFFECEE);
        fg = const Color(0xFFD9364F);
        break;
      default:
        text = 'قيد التنفيذ';
        icon = Icons.schedule_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: fg, size: 12.5.sp),
          SizedBox(width: 4.w),
          Text(
            text,
            style: TextStyle(
              color: fg,
              fontSize: 9.2.sp,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  static List<Map<String, dynamic>> _parseItems(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value
          .where((item) => item != null && item is Map)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    if (value is Map) {
      return value.values
          .where((item) => item != null && item is Map)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
    }
    return [];
  }

  String _itemsPreview(List<Map<String, dynamic>> items) {
    if (items.isEmpty) return 'تفاصيل المنتجات غير متوفرة';

    final names = items
        .take(3)
        .map((e) => e['name']?.toString().trim() ?? '')
        .where((e) => e.isNotEmpty)
        .toList();

    if (names.isEmpty) return 'تفاصيل الطلب';

    return names.join('، ');
  }

  String _shortId(String id) {
    if (id.isEmpty) return '-';
    return id.length > 7 ? id.substring(id.length - 7) : id;
  }

  String _formatDate(int millis) {
    if (millis == 0) return '';
    final date = DateTime.fromMillisecondsSinceEpoch(millis);
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour >= 12 ? 'م' : 'ص';
    return '${date.day}/${date.month} • '
        '$hour:${date.minute.toString().padLeft(2, '0')} $period';
  }
}

class _OrdersShimmer extends StatelessWidget {
  const _OrdersShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(18.w, 10.h, 18.w, 120.h),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (_, __) => SizedBox(height: 13.h),
      itemBuilder: (_, __) {
        return _Shimmer(
          child: Container(
            height: 205.h,
            padding: EdgeInsets.all(15.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: const Color(0xFFE4EAE8)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _bone(52.w, 52.w, radius: 15.r),
                    SizedBox(width: 11.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _bone(120.w, 13.h),
                          SizedBox(height: 8.h),
                          _bone(165.w, 9.h),
                        ],
                      ),
                    ),
                    _bone(72.w, 27.h, radius: 18.r),
                  ],
                ),
                SizedBox(height: 18.h),
                _bone(double.infinity, 7.h),
                SizedBox(height: 17.h),
                _bone(double.infinity, 54.h, radius: 15.r),
                SizedBox(height: 15.h),
                Row(
                  children: [
                    _bone(90.w, 36.h, radius: 12.r),
                    const Spacer(),
                    _bone(72.w, 14.h),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Widget _bone(double width, double height, {double radius = 8}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE8ECEB),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _Shimmer extends StatefulWidget {
  final Widget child;

  const _Shimmer({required this.child});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final x = controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(-1.5 + x, 0),
              end: Alignment(1.5 + x, 0),
              colors: const [
                Color(0xFFE6EBE9),
                Color(0xFFF8FAF9),
                Color(0xFFE6EBE9),
              ],
              stops: const [.25, .5, .75],
            ).createShader(bounds);
          },
          child: child,
        );
      },
    );
  }
}

class _BringoMark extends StatelessWidget {
  final double size;

  const _BringoMark({this.size = 34});

  @override
  Widget build(BuildContext context) {
    const teal = Color(0xFF1F5A59);
    const lime = Color(0xFFDDFB8A);
    final s = size.w;

    return SizedBox(
      width: s,
      height: s,
      child: Stack(
        children: [
          Positioned(
            left: s * .23,
            top: s * .08,
            child: Container(
              width: s * .26,
              height: s * .72,
              decoration: BoxDecoration(
                color: teal,
                borderRadius: BorderRadius.circular(s * .17),
              ),
            ),
          ),
          Positioned(
            right: s * .08,
            bottom: s * .08,
            child: Container(
              width: s * .65,
              height: s * .65,
              decoration: const BoxDecoration(
                color: teal,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            left: s * .30,
            bottom: s * .19,
            child: Transform.rotate(
              angle: -.60,
              child: Container(
                width: s * .49,
                height: s * .29,
                decoration: BoxDecoration(
                  color: lime,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(s * .30),
                    bottomRight: Radius.circular(s * .30),
                    topRight: Radius.circular(s * .10),
                    bottomLeft: Radius.circular(s * .10),
                  ),
                  border: Border.all(
                    color: Colors.white,
                    width: s * .065,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
