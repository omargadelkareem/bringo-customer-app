import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bringo — live order tracking. Uses the existing orders/{orderId} schema.
class OrderTrackingScreen extends StatelessWidget {
  final String orderId;
  const OrderTrackingScreen({super.key, required this.orderId});

  static const teal = Color(0xFF1F5A59);
  static const dark = Color(0xFF174746);
  static const lime = Color(0xFFDDFB8A);
  static const canvas = Color(0xFFF7FAF8);
  static const ink = Color(0xFF182322);
  static const muted = Color(0xFF77817F);
  static const line = Color(0xFFE2E9E7);

  TextStyle _style(double size, {Color color = ink, FontWeight weight = FontWeight.w600, double? height}) =>
      GoogleFonts.cairo(fontSize: size.sp, color: color, fontWeight: weight, height: height);

  String _first(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim() ?? '';
      if (text.isNotEmpty && text != 'null') return text;
    }
    return '';
  }

  String _status(Map<String, dynamic> order) {
    final raw = _first([order['status'], order['orderStatus']])
        .replaceAll('_', '').replaceAll('-', '').toLowerCase();
    const aliases = <String, String>{
      'pending': 'pending', 'pendingprovider': 'pending', 'new': 'pending',
      'confirmed': 'confirmed', 'accepted': 'confirmed',
      'preparing': 'preparing', 'ready': 'ready',
      'assigned': 'assigned', 'picked': 'pickedUp', 'pickedup': 'pickedUp',
      'way': 'onDelivery', 'ondelivery': 'onDelivery',
      'arrived': 'arrived', 'done': 'completed', 'delivered': 'completed',
      'completed': 'completed', 'rejected': 'cancelled',
      'cancelled': 'cancelled', 'canceled': 'cancelled',
    };
    return aliases[raw] ?? 'pending';
  }

  int _step(String s) {
    switch (s) {
      case 'confirmed': return 1;
      case 'preparing': return 2;
      case 'ready': case 'assigned': return 3;
      case 'pickedUp': return 4;
      case 'onDelivery': case 'arrived': return 5;
      case 'completed': return 6;
      default: return 0;
    }
  }

  String _label(String s) => const {
    'pending':'بانتظار القبول', 'confirmed':'تم القبول', 'preparing':'جاري التجهيز',
    'ready':'جاهز للاستلام', 'assigned':'تم تعيين طيار',
    'pickedUp':'استلمه الطيار', 'onDelivery':'في الطريق',
    'arrived':'الطيار وصل', 'completed':'تم التسليم', 'cancelled':'تم الإلغاء',
  }[s] ?? 'قيد المتابعة';

  String _title(String s) => const {
    'pending':'طلبك وصل للمتجر', 'confirmed':'تم قبول طلبك',
    'preparing':'طلبك بيتجهز الآن', 'ready':'طلبك جاهز للاستلام',
    'assigned':'الطيار في طريقه للمتجر', 'pickedUp':'الطيار استلم طلبك',
    'onDelivery':'طلبك في الطريق إليك', 'arrived':'الطيار وصل لعنوانك',
    'completed':'طلبك وصل بالسلامة!', 'cancelled':'تم إلغاء الطلب',
  }[s] ?? 'متابعة طلبك';

  String _subtitle(String s) => const {
    'pending':'الطلب في انتظار تأكيد المتجر',
    'confirmed':'المتجر بيستعد لتجهيز طلبك',
    'preparing':'بنجهز احتياجاتك بعناية',
    'ready':'طلبك جاهز وينتظر الاستلام',
    'assigned':'تم تعيين طيار لاستلام طلبك',
    'pickedUp':'الطيار استلم الطلب ويستعد للتحرك',
    'onDelivery':'تابع هاتفك، طلبك في الطريق',
    'arrived':'يرجى الاستعداد لاستلام طلبك',
    'completed':'شكرًا لاختيارك Bringo',
    'cancelled':'تقدر تتواصل مع الدعم للمساعدة',
  }[s] ?? 'تابع رحلة طلبك لحظة بلحظة';

  String _shortId() => orderId.length > 7 ? orderId.substring(orderId.length - 7) : orderId;
  double _money(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;

  Future<void> _call(String phone) async {
    if (phone.trim().isEmpty) return;
    await launchUrl(Uri(scheme: 'tel', path: phone.trim()), mode: LaunchMode.externalApplication);
  }

  Future<void> _whatsapp(String phone) async {
    if (phone.trim().isEmpty) return;
    var number = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (number.startsWith('0')) number = '20${number.substring(1)}';
    final text = Uri.encodeComponent('مرحبًا، أريد الاستفسار عن طلب Bringo رقم $orderId');
    await launchUrl(Uri.parse('https://wa.me/$number?text=$text'), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 70.h,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: Container(
            padding: EdgeInsets.all(9.w),
            decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, border: Border.all(color: line)),
            child: Icon(Icons.arrow_forward_rounded, color: dark, size: 21.sp),
          ),
        ),
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const _BringoMark(size: 34), SizedBox(width: 8.w),
          Text('Bringo', style: _style(21, color: dark, weight: FontWeight.w900)),
        ]),
        centerTitle: true,
        actions: [Padding(padding: EdgeInsets.only(left: 16.w), child: Center(child: Text('تتبع الطلب', style: _style(11, color: muted, weight: FontWeight.w800))))],
      ),
      body: StreamBuilder<DatabaseEvent>(
        stream: FirebaseDatabase.instance.ref('orders/$orderId').onValue,
        builder: (context, snapshot) {
          if (snapshot.hasError) return _message(Icons.wifi_off_rounded, 'تعذر تحديث الطلب', 'تأكد من اتصال الإنترنت وحاول مرة أخرى');
          if (snapshot.connectionState == ConnectionState.waiting) return const _LoadingTracking();
          final raw = snapshot.data?.snapshot.value;
          if (raw is! Map) return _message(Icons.receipt_long_outlined, 'الطلب غير موجود', 'تأكد من رقم الطلب');
          final order = Map<String, dynamic>.from(raw);
          final status = _status(order);
          final driver = order['driver'] is Map ? Map<String, dynamic>.from(order['driver'] as Map) : <String, dynamic>{};
          final name = _first([order['driverName'], order['riderName'], order['captainName'], driver['name'], driver['fullName']]);
          final phone = _first([order['driverPhone'], order['riderPhone'], order['captainPhone'], driver['phone']]);
          final photo = _first([order['driverImage'], order['driverPhoto'], order['riderImage'], order['captainImage'], driver['image'], driver['photo'], driver['avatar'], driver['photoUrl']]);
          final rating = _money(_first([order['driverRating'], order['riderRating'], driver['rating']]));
          final addressData = order['address'] is Map ? Map<String, dynamic>.from(order['address'] as Map) : <String, dynamic>{};
          final address = _first([order['customerAddress'], addressData['area'], order['detectedAddress'], 'لم يتم تحديد العنوان']);
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(17.w, 8.h, 17.w, 40.h),
            children: [
              _hero(status, _money(order['total'])),
              SizedBox(height: 20.h),
              _timeline(status),
              if (name.isNotEmpty) ...[
                SizedBox(height: 16.h),
                _driver(name, phone, photo, rating),
              ],
              SizedBox(height: 16.h),
              _address(address),
              SizedBox(height: 16.h),
              _summary(order),
              SizedBox(height: 18.h),
              Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                const _BringoMark(size: 21), SizedBox(width: 6.w),
                Text('من مدينتك إلى بابك', style: _style(10, color: muted)),
              ])),
            ],
          );
        },
      ),
    ),
  );

  Widget _hero(String status, double total) {
    final cancelled = status == 'cancelled';
    final progress = cancelled ? 0.0 : (_step(status) + 1) / 7;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: dark, borderRadius: BorderRadius.circular(27.r)),
      child: Stack(children: [
        Positioned(top: -70.h, left: -55.w, child: Container(width: 190.w, height: 190.w, decoration: BoxDecoration(shape: BoxShape.circle, color: lime.withOpacity(.08)))),
        Positioned(bottom: -95.h, right: -75.w, child: Container(width: 210.w, height: 210.w, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: lime.withOpacity(.14), width: 24.w)))),
        Padding(
          padding: EdgeInsets.all(21.w),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 6.h),
                decoration: BoxDecoration(color: cancelled ? const Color(0xFFFFE6E6) : lime, borderRadius: BorderRadius.circular(30.r)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 7.w, height: 7.w, decoration: BoxDecoration(shape: BoxShape.circle, color: cancelled ? Colors.red : dark)),
                  SizedBox(width: 6.w), Text(_label(status), style: _style(10, color: dark, weight: FontWeight.w900)),
                ]),
              ),
              const Spacer(),
              Text('طلب #${_shortId()}', style: _style(11, color: Colors.white70, weight: FontWeight.w700)),
            ]),
            SizedBox(height: 23.h),
            Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_title(status), style: _style(23, color: Colors.white, weight: FontWeight.w900, height: 1.3)),
                SizedBox(height: 7.h),
                Text(_subtitle(status), style: _style(11.5, color: const Color(0xFFD4E5E0), height: 1.55)),
              ])),
              SizedBox(width: 10.w),
              Container(width: 63.w, height: 63.w, decoration: BoxDecoration(color: Colors.white.withOpacity(.09), borderRadius: BorderRadius.circular(20.r)),
                child: Icon(cancelled ? Icons.close_rounded : status == 'completed' ? Icons.verified_rounded : Icons.delivery_dining_rounded, color: lime, size: 34.sp)),
            ]),
            SizedBox(height: 24.h),
            ClipRRect(borderRadius: BorderRadius.circular(20.r), child: LinearProgressIndicator(
              value: progress, minHeight: 7.h, backgroundColor: Colors.white.withOpacity(.16),
              valueColor: AlwaysStoppedAnimation<Color>(cancelled ? const Color(0xFFFFB5B5) : lime),
            )),
            SizedBox(height: 15.h),
            Row(children: [
              Icon(Icons.sync_rounded, color: lime, size: 17.sp), SizedBox(width: 5.w),
              Expanded(child: Text(cancelled ? 'توقف تتبع الطلب' : status == 'completed' ? 'اكتملت رحلة طلبك' : 'يتم تحديث حالة طلبك تلقائيًا', style: _style(10, color: const Color(0xFFE2EFEB)))),
              Text('${total.toStringAsFixed(0)} جنيه', style: _style(15, color: Colors.white, weight: FontWeight.w900)),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _panel({required Widget child}) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(18.w),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23.r), border: Border.all(color: line)),
    child: child,
  );

  Widget _timeline(String status) {
    const steps = <(String, String, IconData)>[
      ('تم إرسال الطلب', 'وصل طلبك إلى المتجر', Icons.receipt_long_outlined),
      ('تم قبول الطلب', 'المتجر أكد استلام طلبك', Icons.verified_outlined),
      ('جاري التجهيز', 'بيتم تجهيز احتياجاتك', Icons.inventory_2_outlined),
      ('جاهز للاستلام', 'الطلب جاهز للطيار', Icons.shopping_bag_outlined),
      ('استلمه الطيار', 'تم استلام الطلب من المتجر', Icons.delivery_dining_rounded),
      ('في الطريق إليك', 'الطيار متجه لعنوانك', Icons.route_rounded),
      ('تم التسليم', 'طلبك وصل بالسلامة', Icons.home_outlined),
    ];
    final cancelled = status == 'cancelled';
    final current = _step(status);
    return _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const _BringoMark(size: 28), SizedBox(width: 9.w),
        Text('رحلة طلبك', style: _style(17, weight: FontWeight.w900)),
        const Spacer(),
        Container(padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(color: const Color(0xFFEAF3F2), borderRadius: BorderRadius.circular(20.r)),
          child: Text(cancelled ? 'ملغي' : '${current + 1} من 7', style: _style(10, color: teal, weight: FontWeight.w900))),
      ]),
      SizedBox(height: 23.h),
      if (cancelled) ...[
        Container(padding: EdgeInsets.all(12.w), decoration: BoxDecoration(color: const Color(0xFFFFF1F0), borderRadius: BorderRadius.circular(14.r)),
          child: Row(children: [Icon(Icons.info_outline, color: Colors.red.shade700), SizedBox(width: 9.w), Expanded(child: Text('تم إلغاء الطلب. لا توجد مراحل توصيل إضافية.', style: _style(11)))])),
        SizedBox(height: 15.h),
      ],
      ...List.generate(steps.length, (index) {
        final step = steps[index];
        final done = !cancelled && index < current;
        final active = !cancelled && index == current;
        final upcoming = cancelled || index > current;
        return IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Column(children: [
            AnimatedContainer(duration: const Duration(milliseconds: 280),
              width: active ? 44.w : 38.w, height: active ? 44.w : 38.w,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: active ? teal : done ? const Color(0xFFEAF3F2) : const Color(0xFFF3F5F4),
                border: active ? Border.all(color: lime, width: 3) : null),
              child: Icon(done ? Icons.check_rounded : step.$3,
                color: active ? lime : done ? teal : const Color(0xFFB6C0BD), size: 20.sp)),
            if (index != steps.length - 1) Expanded(child: Container(width: 2.w, margin: EdgeInsets.symmetric(vertical: 5.h),
              color: !upcoming && !cancelled ? const Color(0xFFB4D1CA) : line)),
          ]),
          SizedBox(width: 13.w),
          Expanded(child: Padding(padding: EdgeInsets.only(top: 3.h, bottom: index == steps.length - 1 ? 0 : 26.h),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(step.$1, style: _style(12.5, color: upcoming ? const Color(0xFF9BA6A2) : ink, weight: active ? FontWeight.w900 : FontWeight.w700))),
                if (active) Container(padding: EdgeInsets.symmetric(horizontal: 9.w, vertical: 3.h),
                  decoration: BoxDecoration(color: lime, borderRadius: BorderRadius.circular(20.r)),
                  child: Text('الآن', style: _style(9, color: dark, weight: FontWeight.w900))),
              ]),
              SizedBox(height: 3.h),
              Text(step.$2, style: _style(10.5, color: muted, height: 1.5)),
            ]))),
        ]));
      }),
    ]));
  }

  Widget _driver(String name, String phone, String photo, double rating) => _panel(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('طيار Bringo', style: _style(16, weight: FontWeight.w900)),
      SizedBox(height: 15.h),
      Row(children: [
        CircleAvatar(radius: 29.r, backgroundColor: const Color(0xFFEAF3F2),
          backgroundImage: photo.startsWith('http') ? NetworkImage(photo) : null,
          child: !photo.startsWith('http') ? Icon(Icons.delivery_dining_rounded, color: teal, size: 29.sp) : null),
        SizedBox(width: 12.w),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: _style(14, weight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
          SizedBox(height: 3.h),
          Text(phone.isEmpty ? 'مندوب التوصيل' : phone, style: _style(10.5, color: muted)),
        ])),
        if (rating > 0) Row(children: [Icon(Icons.star_rounded, color: const Color(0xFFF5AA29), size: 18.sp),
          Text(rating.toStringAsFixed(1), style: _style(11, weight: FontWeight.w900))]),
      ]),
      if (phone.isNotEmpty) ...[
        SizedBox(height: 17.h),
        Row(children: [
          Expanded(child: _contact('اتصال', Icons.call_outlined, teal, () => _call(phone))),
          SizedBox(width: 10.w),
          Expanded(child: _contact('واتساب', Icons.chat_outlined, const Color(0xFF218A5D), () => _whatsapp(phone))),
        ]),
      ],
    ],
  ));

  Widget _contact(String label, IconData icon, Color color, VoidCallback action) => SizedBox(height: 45.h,
    child: OutlinedButton.icon(onPressed: action, icon: Icon(icon, size: 18.sp), label: Text(label, style: _style(12, color: color, weight: FontWeight.w900)),
      style: OutlinedButton.styleFrom(foregroundColor: color, side: BorderSide(color: color.withOpacity(.3)),
        backgroundColor: color.withOpacity(.045), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13.r)))));

  Widget _address(String address) => _panel(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(padding: EdgeInsets.all(10.w), decoration: BoxDecoration(color: const Color(0xFFEAF3F2), borderRadius: BorderRadius.circular(13.r)),
      child: Icon(Icons.location_on_outlined, color: teal, size: 23.sp)),
    SizedBox(width: 12.w),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('عنوان التوصيل', style: _style(14, weight: FontWeight.w900)), SizedBox(height: 5.h),
      Text(address, style: _style(11.5, color: muted, height: 1.6)),
    ])),
  ]));

  Widget _summary(Map<String, dynamic> order) => _panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('ملخص الحساب', style: _style(16, weight: FontWeight.w900)),
    SizedBox(height: 17.h),
    _sumRow('قيمة المنتجات', _money(order['subtotal'])), SizedBox(height: 10.h),
    _sumRow('رسوم التوصيل', _money(order['deliveryFee'])),
    Padding(padding: EdgeInsets.symmetric(vertical: 13.h), child: const Divider(color: line, height: 1)),
    _sumRow('الإجمالي', _money(order['total']), bold: true),
  ]));

  Widget _sumRow(String title, double amount, {bool bold = false}) => Row(children: [
    Text(title, style: _style(bold ? 13 : 11.5, weight: bold ? FontWeight.w900 : FontWeight.w600)),
    const Spacer(),
    Text('${amount.toStringAsFixed(0)} جنيه', style: _style(bold ? 17 : 12.5, color: bold ? teal : ink, weight: FontWeight.w900)),
  ]);

  Widget _message(IconData icon, String title, String subtitle) => Center(child: Padding(
    padding: EdgeInsets.all(24.w), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 65.sp, color: teal), SizedBox(height: 15.h),
      Text(title, style: _style(19, weight: FontWeight.w900)), SizedBox(height: 5.h),
      Text(subtitle, style: _style(12, color: muted), textAlign: TextAlign.center),
    ]),
  ));
}

class _BringoMark extends StatelessWidget {
  final double size;
  const _BringoMark({this.size = 34});
  @override
  Widget build(BuildContext context) {
    final s = size.w;
    return SizedBox(width: s, height: s, child: Stack(children: [
      Positioned(left: s * .23, top: s * .08, child: Container(width: s * .26, height: s * .72,
        decoration: BoxDecoration(color: OrderTrackingScreen.teal, borderRadius: BorderRadius.circular(s * .17)))),
      Positioned(right: s * .08, bottom: s * .08, child: Container(width: s * .65, height: s * .65,
        decoration: const BoxDecoration(color: OrderTrackingScreen.teal, shape: BoxShape.circle))),
      Positioned(left: s * .30, bottom: s * .19, child: Transform.rotate(angle: -.60, child: Container(
        width: s * .49, height: s * .29,
        decoration: BoxDecoration(color: OrderTrackingScreen.lime,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(s * .30), bottomRight: Radius.circular(s * .30),
            topRight: Radius.circular(s * .10), bottomLeft: Radius.circular(s * .10)),
          border: Border.all(color: Colors.white, width: s * .065)),
      ))),
    ]));
  }
}

class _LoadingTracking extends StatelessWidget {
  const _LoadingTracking();
  @override
  Widget build(BuildContext context) => ListView(padding: EdgeInsets.all(18.w), children: [
    Container(height: 230.h, decoration: BoxDecoration(color: const Color(0xFF174746), borderRadius: BorderRadius.circular(27.r))),
    SizedBox(height: 18.h),
    Container(height: 460.h, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(23.r))),
  ]);
}
