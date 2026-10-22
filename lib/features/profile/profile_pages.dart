import 'package:bringo/core/constant/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';

const _bg = Color(0xFFF7F9F8);
const _ink = Color(0xFF172323);
const _muted = Color(0xFF758180);
const _line = Color(0xFFE8ECEB);
const _lime = Color(0xFFDDFB8A);

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});
  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final box = GetStorage();
  late final TextEditingController nameController;
  late final TextEditingController phoneController;

  @override
  void initState() {
    super.initState();
    nameController = TextEditingController(text: box.read('userName')?.toString() ?? '');
    phoneController = TextEditingController(text: box.read('phone')?.toString() ?? '');
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> saveData() async {
    final name = nameController.text.trim();
    final phone = phoneController.text.trim();
    if (name.length < 2 || phone.length < 10) {
      _toast(context, 'راجع الاسم ورقم الهاتف');
      return;
    }
    await box.write('userName', name);
    await box.write('phone', phone);
    if (!mounted) return;
    _toast(context, 'تم حفظ بياناتك');
  }

  @override
  Widget build(BuildContext context) {
    return _Page(
      title: 'بياناتي الشخصية',
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _Intro(icon: Icons.person_outline_rounded, title: 'بيانات الحساب', text: 'استخدم بيانات صحيحة حتى نقدر نتواصل معك بخصوص الطلبات والتوصيل.'),
        SizedBox(height: 24.h),
        _Field(controller: nameController, label: 'الاسم', icon: Icons.person_outline_rounded),
        SizedBox(height: 12.h),
        _Field(controller: phoneController, label: 'رقم الهاتف', icon: Icons.phone_outlined, keyboardType: TextInputType.phone),
        SizedBox(height: 24.h),
        _PrimaryButton(title: 'حفظ التغييرات', onTap: saveData),
      ]),
    );
  }
}

class AddressesScreen extends StatefulWidget {
  const AddressesScreen({super.key});
  @override
  State<AddressesScreen> createState() => _AddressesScreenState();
}

class _AddressesScreenState extends State<AddressesScreen> {
  final box = GetStorage();
  final areaController = TextEditingController();
  final streetController = TextEditingController();
  final buildingController = TextEditingController();
  List<Map<String, dynamic>> addresses = [];

  @override
  void initState() { super.initState(); _load(); }
  void _load() {
    final data = box.read('addresses');
    if (data is List) addresses = data.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> _add() async {
    if (areaController.text.trim().isEmpty || streetController.text.trim().isEmpty) {
      _toast(context, 'اكتب المنطقة والشارع'); return;
    }
    addresses.add({'area': areaController.text.trim(), 'street': streetController.text.trim(), 'building': buildingController.text.trim(), 'createdAt': DateTime.now().millisecondsSinceEpoch});
    await box.write('addresses', addresses);
    areaController.clear(); streetController.clear(); buildingController.clear();
    setState(() {});
  }

  Future<void> _delete(int index) async {
    addresses.removeAt(index); await box.write('addresses', addresses); setState(() {});
  }

  @override
  void dispose() { areaController.dispose(); streetController.dispose(); buildingController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _Page(title: 'عناويني', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _Intro(icon: Icons.location_on_outlined, title: 'عناوين التوصيل', text: 'احفظ الأماكن التي تطلب إليها باستمرار لتنجز طلبك أسرع.'),
      SizedBox(height: 22.h),
      _Field(controller: areaController, label: 'المنطقة / القرية', icon: Icons.location_city_outlined),
      SizedBox(height: 10.h),
      _Field(controller: streetController, label: 'الشارع', icon: Icons.route_outlined),
      SizedBox(height: 10.h),
      _Field(controller: buildingController, label: 'العمارة / الدور / علامة مميزة', icon: Icons.home_work_outlined),
      SizedBox(height: 16.h),
      _PrimaryButton(title: 'حفظ العنوان', onTap: _add),
      SizedBox(height: 28.h),
      Text('العناوين المحفوظة', textAlign: TextAlign.right, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: _ink)),
      SizedBox(height: 12.h),
      if (addresses.isEmpty) _EmptyAddress() else ...List.generate(addresses.length, (i) => _AddressTile(item: addresses[i], onDelete: () => _delete(i))),
    ]));
  }
}

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});
  static const phone = '01115057318';

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) _toast(context, 'تعذر فتح الخدمة على جهازك');
  }

  @override
  Widget build(BuildContext context) {
    return _Page(title: 'الدعم والمساعدة', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: EdgeInsets.all(22.w),
        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24.r)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Container(width: 46.w, height: 46.w, decoration: const BoxDecoration(color: _lime, shape: BoxShape.circle), child: Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 25.sp)),
          SizedBox(height: 18.h),
          Text('كيف نقدر نساعدك؟', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.w900)),
          SizedBox(height: 7.h),
          Text('فريق Bringo موجود لمساعدتك في الطلب، التوصيل، أو أي مشكلة أثناء استخدام التطبيق.', textAlign: TextAlign.right, style: TextStyle(color: Colors.white.withOpacity(.82), height: 1.7, fontSize: 12.5.sp)),
        ]),
      ),
      SizedBox(height: 26.h),
      _SectionTitle('تواصل معنا'),
      _ActionRow(icon: Icons.chat_bubble_outline_rounded, title: 'واتساب', subtitle: 'الأسرع لمتابعة مشكلة في طلب', onTap: () => _open(context, Uri.parse('https://wa.me/201115057318?text=${Uri.encodeComponent('مرحبًا Bringo، أحتاج مساعدة بخصوص: ')}'))),
      _ActionRow(icon: Icons.phone_outlined, title: 'اتصل بالدعم', subtitle: phone, onTap: () => _open(context, Uri.parse('tel:$phone'))),
      SizedBox(height: 24.h),
      _SectionTitle('مساعدة سريعة'),
      const _Faq(title: 'عندي مشكلة في طلب حالي', body: 'تواصل معنا عبر واتساب واذكر رقم الطلب واسم المتجر ووصف المشكلة. يساعدنا ذلك على مراجعة الطلب والتواصل مع الأطراف المعنية بشكل أسرع.'),
      const _Faq(title: 'الطلب متأخر', body: 'قد يتغير وقت الوصول حسب تجهيز المتجر والطريق. إذا تجاوز الطلب الوقت المتوقع بشكل واضح، تواصل مع الدعم وأرسل رقم الطلب.'),
      const _Faq(title: 'وصل منتج ناقص أو غير صحيح', body: 'احتفظ بالطلب كما وصل إليك قدر الإمكان، وصوّر المنتج أو الفاتورة إن توفرت، ثم أرسل رقم الطلب والتفاصيل للدعم حتى نراجع الحالة مع المتجر.'),
      const _Faq(title: 'أريد إلغاء الطلب', body: 'إمكانية الإلغاء تعتمد على حالة الطلب. كلما تواصلت معنا قبل بدء تجهيز أو توصيل الطلب كان التعامل مع طلب الإلغاء أسهل.'),
      SizedBox(height: 18.h),
      _Notice(icon: Icons.schedule_rounded, text: 'الدعم: يوميًا من 9 صباحًا حتى 12 مساءً'),
    ]));
  }
}

class AboutBringoScreen extends StatelessWidget {
  const AboutBringoScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _Page(title: 'عن Bringo', child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Center(child: Container(width: 76.w, height: 76.w, decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(24.r)), child: Icon(Icons.shopping_bag_rounded, color: _lime, size: 38.sp))),
      SizedBox(height: 18.h),
      Text('Bringo', textAlign: TextAlign.center, style: TextStyle(fontSize: 30.sp, fontWeight: FontWeight.w900, color: _ink)),
      SizedBox(height: 6.h),
      Text('كل اللي محتاجه من مدينتك... أقرب ليك', textAlign: TextAlign.center, style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: AppColors.primary)),
      SizedBox(height: 30.h),
      const _ArticleTitle('فكرة Bringo'),
      const _ArticleText('Bringo منصة محلية للطلب والتوصيل صُممت لتجعل الوصول إلى احتياجاتك اليومية أبسط. بدل ما تتنقل بين أكثر من مكان، تقدر تستكشف المتاجر والخدمات المتاحة، تختار ما تحتاجه، وتتابع طلبك من مكان واحد.'),
      const _ArticleTitle('مش مجرد متجر'),
      const _ArticleText('Bringo لا يعتمد على متجر واحد أو نوع واحد من المنتجات. الفكرة هي ربط العميل بالمتاجر والمطاعم والسوبر ماركت والصيدليات والمخابز ومحلات اللحوم والخضروات وغيرها من الأنشطة المحلية، مع تجربة طلب موحدة وسهلة.'),
      const _ArticleTitle('ليه Bringo؟'),
      const _ArticleText('نؤمن أن التجارة المحلية تستحق تجربة رقمية قوية مثل التطبيقات العالمية، لكن بطابع يفهم المدينة وأهلها. هدفنا أن نسهّل على العميل الطلب، ونمنح المتجر قناة بيع إضافية، ونبني شبكة توصيل منظمة وواضحة.'),
      const _ArticleTitle('رؤيتنا'),
      const _ArticleText('أن يصبح Bringo جزءًا طبيعيًا من الحياة اليومية في المدن التي نعمل بها: عندما تحتاج شيئًا من حولك، يكون الوصول إليه سريعًا وواضحًا ومن خلال تجربة تثق بها.'),
      SizedBox(height: 12.h),
      _Notice(icon: Icons.verified_outlined, text: 'Bringo • الإصدار 1.0.0'),
    ]));
  }
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _LegalPage(
      title: 'سياسة الخصوصية',
      updated: 'آخر تحديث: 23 سبتمبر 2026',
      intro: 'توضح هذه السياسة كيف يتعامل Bringo مع المعلومات اللازمة لتقديم خدمة الطلب والتوصيل وتشغيل التطبيق. استخدامك للتطبيق يعني اطلاعك على هذه السياسة.',
      sections: const [
        ('1. المعلومات التي نجمعها', 'قد نعالج البيانات التي تقدمها أثناء استخدام التطبيق، مثل الاسم ورقم الهاتف وعناوين التوصيل وملاحظات الطلب، بالإضافة إلى بيانات الطلبات والمنتجات والمتاجر المرتبطة بها.'),
        ('2. الموقع الجغرافي', 'عند منح التطبيق إذن الموقع، قد نستخدم إحداثيات موقعك للمساعدة في تحديد عنوان التوصيل وتحسين دقة الخدمة. يمكنك التحكم في إذن الموقع من إعدادات جهازك، لكن بعض خصائص التوصيل قد تحتاج إلى موقع أو عنوان صالح.'),
        ('3. لماذا نستخدم البيانات؟', 'نستخدم البيانات لإنشاء الطلب وتنفيذه، عرض حالة الطلب، التواصل عند الحاجة، تحسين تجربة الاستخدام، تقديم الدعم، منع إساءة الاستخدام، ومعالجة المشكلات التشغيلية المرتبطة بالخدمة.'),
        ('4. مشاركة البيانات لتنفيذ الطلب', 'قد تتم مشاركة المعلومات الضرورية لتنفيذ الطلب مع المتجر أو مقدم الخدمة والطيار، مثل اسم العميل ورقم التواصل وعنوان التوصيل وتفاصيل الطلب. نهدف إلى مشاركة ما يلزم لتنفيذ الخدمة فقط.'),
        ('5. التخزين والحماية', 'نتخذ إجراءات تقنية وتنظيمية معقولة لحماية البيانات من الوصول أو الاستخدام غير المصرح به. ومع ذلك، لا توجد وسيلة تخزين أو نقل إلكتروني يمكن ضمان أمانها بصورة مطلقة.'),
        ('6. الاحتفاظ بالبيانات', 'قد نحتفظ ببيانات الطلب والمعلومات المرتبطة بها للمدة اللازمة لتشغيل الخدمة، الدعم، تسوية المشكلات، والالتزامات النظامية أو المحاسبية التي قد تنطبق. وقد تختلف المدة حسب نوع البيانات والغرض منها.'),
        ('7. صلاحيات الجهاز', 'قد يطلب التطبيق صلاحيات مثل الموقع أو الإشعارات عندما تكون مطلوبة لميزة معينة. يمكنك رفض أو إلغاء بعض الصلاحيات من إعدادات الجهاز، مع احتمال تأثر الميزة المرتبطة بها.'),
        ('8. حقوقك واختياراتك', 'يمكنك تحديث بعض بياناتك من داخل التطبيق، كما يمكنك التواصل مع الدعم للاستفسار عن بيانات حسابك أو طلب تصحيحها أو مناقشة حذفها عندما يكون ذلك ممكنًا وفق متطلبات تشغيل الخدمة والالتزامات المطبقة.'),
        ('9. خصوصية الأطفال', 'Bringo ليس مصممًا لجمع بيانات الأطفال عمدًا دون إشراف مناسب. إذا اعتقد ولي أمر أن طفلًا قدم بيانات شخصية بصورة غير مناسبة، يمكنه التواصل معنا لمراجعة الحالة.'),
        ('10. تحديث السياسة', 'قد نقوم بتحديث هذه السياسة عند تطوير الخدمة أو تغير طريقة تشغيلها. سيظهر تاريخ آخر تحديث داخل هذه الصفحة، ويُنصح بمراجعتها دوريًا.'),
        ('11. التواصل معنا', 'لأي سؤال متعلق بالخصوصية أو البيانات، تواصل مع دعم Bringo على الرقم 01115057318 أو من خلال واتساب الدعم داخل التطبيق.'),
      ],
    );
  }
}

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return _LegalPage(
      title: 'الشروط والأحكام',
      updated: 'آخر تحديث: 23 سبتمبر 2026',
      intro: 'تنظم هذه الشروط استخدام تطبيق Bringo وخدمات الطلب والتوصيل المتاحة من خلاله. يرجى قراءتها قبل استخدام الخدمة.',
      sections: const [
        ('1. طبيعة الخدمة', 'Bringo منصة تسهّل اكتشاف المتاجر والأنشطة المحلية وطلب المنتجات والخدمات المتاحة منها وترتيب التوصيل. قد تختلف المنتجات والأسعار والتوافر وأوقات التجهيز بحسب المتجر والمنطقة.'),
        ('2. بيانات المستخدم', 'يلتزم المستخدم بإدخال بيانات تواصل وعنوان صحيحة وكافية لتنفيذ الطلب. قد يؤدي نقص أو خطأ البيانات إلى تأخير الطلب أو تعذر تسليمه.'),
        ('3. الأسعار والرسوم', 'يعرض التطبيق السعر والرسوم المتاحة قبل تأكيد الطلب. قد تشمل التكلفة قيمة المنتجات ورسوم التوصيل وأي رسوم أو خصومات موضحة للمستخدم قبل التأكيد.'),
        ('4. توافر المنتجات', 'توافر المنتجات يعتمد على المتجر وقد يتغير. إذا تعذر توفير منتج بعد إرسال الطلب، قد يتم التواصل مع المستخدم بشأن البدائل أو تعديل الطلب بحسب الحالة.'),
        ('5. الإلغاء', 'إمكانية إلغاء الطلب تعتمد على مرحلته. بعد بدء التجهيز أو خروج الطلب للتوصيل قد لا يكون الإلغاء ممكنًا أو قد تترتب عليه تكلفة فعلية مرتبطة بالطلب، حسب الحالة وما تم توضيحه للمستخدم.'),
        ('6. التوصيل', 'أوقات التوصيل المعروضة تقديرية وقد تتأثر بوقت تجهيز المتجر، المسافة، حركة الطريق، الطقس، ضغط الطلبات أو ظروف تشغيلية أخرى.'),
        ('7. مشكلات الطلب', 'عند وجود منتج ناقص أو غير صحيح أو مشكلة في حالة الطلب، يجب التواصل مع الدعم وتقديم رقم الطلب والتفاصيل المتاحة حتى يمكن مراجعة الحالة مع المتجر أو الطيار.'),
        ('8. الاستخدام المقبول', 'يجب عدم استخدام التطبيق بطريقة احتيالية أو مسيئة أو لإرسال طلبات وهمية أو إلحاق الضرر بالمتاجر أو الطيارين أو المستخدمين أو أنظمة Bringo.'),
        ('9. تغييرات الخدمة', 'قد نضيف أو نعدل أو نوقف بعض الخصائص أو مناطق الخدمة أو المتاجر المتاحة بهدف تطوير التشغيل أو لأسباب فنية وتشغيلية.'),
        ('10. التواصل', 'للاستفسارات أو الشكاوى المتعلقة بالخدمة، يمكن التواصل مع دعم Bringo على 01115057318 أو عبر واتساب من صفحة الدعم.'),
      ],
    );
  }
}

class _LegalPage extends StatelessWidget {
  final String title, updated, intro;
  final List<(String, String)> sections;
  const _LegalPage({required this.title, required this.updated, required this.intro, required this.sections});
  @override
  Widget build(BuildContext context) => _Page(title: title, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Container(padding: EdgeInsets.all(18.w), decoration: BoxDecoration(color: const Color(0xFFEAF3F2), borderRadius: BorderRadius.circular(20.r)), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Icon(Icons.shield_outlined, color: AppColors.primary, size: 28.sp), SizedBox(height: 12.h),
      Text(updated, textAlign: TextAlign.right, style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: AppColors.primary)), SizedBox(height: 8.h),
      Text(intro, textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, height: 1.8, color: _ink)),
    ])),
    SizedBox(height: 24.h),
    ...sections.map((s) => Padding(padding: EdgeInsets.only(bottom: 22.h), child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      Text(s.$1, textAlign: TextAlign.right, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: _ink)), SizedBox(height: 8.h),
      Text(s.$2, textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, height: 1.9, color: const Color(0xFF53605F), fontWeight: FontWeight.w500)),
    ]))),
  ]));
}

class _Page extends StatelessWidget {
  final String title; final Widget child;
  const _Page({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Scaffold(backgroundColor: _bg, appBar: AppBar(backgroundColor: _bg, surfaceTintColor: _bg, elevation: 0, centerTitle: true, foregroundColor: _ink, title: Text(title, style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w900))), body: SingleChildScrollView(physics: const BouncingScrollPhysics(), padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 36.h), child: child));
}

class _Intro extends StatelessWidget {
  final IconData icon; final String title, text;
  const _Intro({required this.icon, required this.title, required this.text});
  @override
  Widget build(BuildContext context) => Row(textDirection: TextDirection.rtl, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(width: 48.w, height: 48.w, decoration: BoxDecoration(color: const Color(0xFFEAF3F2), borderRadius: BorderRadius.circular(16.r)), child: Icon(icon, color: AppColors.primary)), SizedBox(width: 13.w),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(title, style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w900, color: _ink)), SizedBox(height: 5.h), Text(text, textAlign: TextAlign.right, style: TextStyle(fontSize: 12.sp, height: 1.6, color: _muted))]))
  ]);
}

class _Field extends StatelessWidget {
  final TextEditingController controller; final String label; final IconData icon; final TextInputType? keyboardType;
  const _Field({required this.controller, required this.label, required this.icon, this.keyboardType});
  @override
  Widget build(BuildContext context) => TextField(controller: controller, keyboardType: keyboardType, textAlign: TextAlign.right, decoration: InputDecoration(hintText: label, prefixIcon: Icon(icon, color: AppColors.primary, size: 21.sp), filled: true, fillColor: Colors.white, contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 17.h), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r), borderSide: const BorderSide(color: _line)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15.r), borderSide: BorderSide(color: AppColors.primary, width: 1.4))));
}

class _PrimaryButton extends StatelessWidget {
  final String title; final VoidCallback onTap;
  const _PrimaryButton({required this.title, required this.onTap});
  @override
  Widget build(BuildContext context) => SizedBox(height: 52.h, child: ElevatedButton(onPressed: onTap, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r))), child: Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900))));
}

class _ActionRow extends StatelessWidget {
  final IconData icon; final String title, subtitle; final VoidCallback onTap;
  const _ActionRow({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(color: Colors.transparent, child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16.r), child: Padding(padding: EdgeInsets.symmetric(vertical: 14.h), child: Row(textDirection: TextDirection.rtl, children: [
    Container(width: 43.w, height: 43.w, decoration: BoxDecoration(color: const Color(0xFFEAF3F2), borderRadius: BorderRadius.circular(14.r)), child: Icon(icon, color: AppColors.primary, size: 21.sp)), SizedBox(width: 13.w),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(title, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: _ink)), SizedBox(height: 3.h), Text(subtitle, textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5.sp, color: _muted))])),
    SizedBox(width: 8.w), Icon(Icons.arrow_back_ios_new_rounded, size: 13.sp, color: const Color(0xFFABB4B3))
  ]))));
}

class _Faq extends StatelessWidget {
  final String title, body; const _Faq({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Theme(data: Theme.of(context).copyWith(dividerColor: Colors.transparent), child: ExpansionTile(tilePadding: EdgeInsets.zero, childrenPadding: EdgeInsets.only(bottom: 15.h), iconColor: AppColors.primary, collapsedIconColor: _muted, title: Text(title, textAlign: TextAlign.right, style: TextStyle(fontSize: 13.5.sp, fontWeight: FontWeight.w800, color: _ink)), children: [Align(alignment: Alignment.centerRight, child: Text(body, textAlign: TextAlign.right, style: TextStyle(fontSize: 12.sp, height: 1.7, color: _muted))) ]));
}

class _SectionTitle extends StatelessWidget {
  final String text; const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: 8.h), child: Text(text, textAlign: TextAlign.right, style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w900, color: _ink)));
}

class _Notice extends StatelessWidget {
  final IconData icon; final String text; const _Notice({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Container(padding: EdgeInsets.all(14.w), decoration: BoxDecoration(color: const Color(0xFFEAF3F2), borderRadius: BorderRadius.circular(15.r)), child: Row(textDirection: TextDirection.rtl, children: [Icon(icon, color: AppColors.primary, size: 20.sp), SizedBox(width: 10.w), Expanded(child: Text(text, textAlign: TextAlign.right, style: TextStyle(color: AppColors.primary, fontSize: 11.5.sp, fontWeight: FontWeight.w800)))]));
}

class _ArticleTitle extends StatelessWidget { final String text; const _ArticleTitle(this.text); @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(top: 10.h, bottom: 7.h), child: Text(text, textAlign: TextAlign.right, style: TextStyle(fontSize: 17.sp, fontWeight: FontWeight.w900, color: _ink))); }
class _ArticleText extends StatelessWidget { final String text; const _ArticleText(this.text); @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.only(bottom: 18.h), child: Text(text, textAlign: TextAlign.right, style: TextStyle(fontSize: 13.sp, height: 1.9, color: const Color(0xFF53605F)))); }

class _AddressTile extends StatelessWidget {
  final Map<String, dynamic> item; final VoidCallback onDelete;
  const _AddressTile({required this.item, required this.onDelete});
  @override
  Widget build(BuildContext context) => Container(margin: EdgeInsets.only(bottom: 10.h), padding: EdgeInsets.all(15.w), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: _line)), child: Row(textDirection: TextDirection.rtl, children: [
    Container(width: 42.w, height: 42.w, decoration: BoxDecoration(color: const Color(0xFFEAF3F2), borderRadius: BorderRadius.circular(13.r)), child: Icon(Icons.home_outlined, color: AppColors.primary, size: 21.sp)), SizedBox(width: 12.w),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(item['area']?.toString() ?? '', style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900, color: _ink)), SizedBox(height: 4.h), Text('${item['street'] ?? ''}${(item['building'] ?? '').toString().isNotEmpty ? ' • ${item['building']}' : ''}', textAlign: TextAlign.right, style: TextStyle(fontSize: 11.5.sp, color: _muted))])),
    IconButton(onPressed: onDelete, icon: Icon(Icons.delete_outline_rounded, color: Colors.red.shade400, size: 21.sp))
  ]));
}

class _EmptyAddress extends StatelessWidget { @override Widget build(BuildContext context) => Container(padding: EdgeInsets.symmetric(vertical: 30.h), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16.r), border: Border.all(color: _line)), child: Column(children: [Icon(Icons.location_off_outlined, color: _muted, size: 30.sp), SizedBox(height: 8.h), Text('لا توجد عناوين محفوظة', style: TextStyle(color: _muted, fontSize: 12.sp, fontWeight: FontWeight.w700))])); }

void _toast(BuildContext context, String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
