import 'package:bringo/core/constant/app_colors.dart';
import 'package:bringo/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_storage/get_storage.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  final GetStorage _box = GetStorage();

  static const Color _ink = Color(0xFF182322);
  static const Color _muted = Color(0xFF7B8381);
  static const Color _line = Color(0xFFEEEEEC);

  String get _userId =>
      (_box.read('userId') ?? _box.read('uid') ?? _box.read('id'))
          ?.toString()
          .trim() ??
      '';

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          leading: IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: Icon(Icons.arrow_forward_ios_rounded, color: _ink, size: 19.sp),
          ),
          title: Text(
            'الإشعارات',
            style: TextStyle(
              color: _ink,
              fontSize: 18.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          actions: [
            if (_userId.isNotEmpty)
              TextButton(
                onPressed: () => _notificationService.markAllAsRead(_userId),
                child: Text(
                  'قراءة الكل',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(1.h),
            child: const Divider(height: 1, thickness: 1, color: _line),
          ),
        ),
        body: SafeArea(top: false, child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_userId.isEmpty) return _emptyState();

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _notificationService.watchUserNotifications(_userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return _messageState(
            Icons.wifi_off_rounded,
            'تعذر تحميل الإشعارات',
            'حاول مرة تانية بعد شوية',
          );
        }

        final notifications = snapshot.data ?? const <Map<String, dynamic>>[];
        if (notifications.isEmpty) return _emptyState();

        return ListView.separated(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: notifications.length,
          separatorBuilder: (_, __) => Padding(
            padding: EdgeInsets.only(right: 72.w),
            child: const Divider(height: 1, thickness: 1, color: _line),
          ),
          itemBuilder: (context, index) {
            final item = notifications[index];
            return _NotificationRow(
              item: item,
              onTap: () async {
                final id = item['firebaseKey']?.toString() ?? '';
                if (id.isNotEmpty) {
                  await _notificationService.markAsRead(id);
                }
              },
            );
          },
        );
      },
    );
  }

  Widget _emptyState() => _messageState(
        Icons.notifications_none_rounded,
        'لا توجد إشعارات',
        'أي تحديث يخص طلباتك هيظهر هنا',
      );

  Widget _messageState(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppColors.primary, size: 48.sp),
            SizedBox(height: 14.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _ink,
                fontSize: 17.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(height: 6.h),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _muted,
                fontSize: 12.sp,
                height: 1.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationRow extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _NotificationRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] ?? item['subject'] ?? 'تحديث من Bringo')
        .toString()
        .trim();
    final body = (item['body'] ?? item['message'] ?? item['text'] ?? '')
        .toString()
        .trim();
    final isRead = item['isRead'] == true || item['read'] == true;
    final type = (item['type'] ?? '').toString().toLowerCase();

    IconData icon = Icons.notifications_none_rounded;
    if (type.contains('order')) icon = Icons.receipt_long_outlined;
    if (type.contains('offer') || type.contains('promo')) {
      icon = Icons.local_offer_outlined;
    }

    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead ? Colors.white : const Color(0xFFF8FBFA),
        padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 40.w,
              height: 40.w,
              child: Center(
                child: Icon(icon, color: AppColors.primary, size: 23.sp),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title.isEmpty ? 'تحديث من Bringo' : title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _NotificationRowColors.ink,
                            fontSize: 13.5.sp,
                            fontWeight: isRead ? FontWeight.w700 : FontWeight.w900,
                          ),
                        ),
                      ),
                      if (!isRead) ...[
                        SizedBox(width: 8.w),
                        Container(
                          width: 7.w,
                          height: 7.w,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (body.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Text(
                      body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: _NotificationRowColors.muted,
                        fontSize: 11.5.sp,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  SizedBox(height: 5.h),
                  Text(
                    _relativeTime(item),
                    style: TextStyle(
                      color: _NotificationRowColors.muted,
                      fontSize: 9.5.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _relativeTime(Map<String, dynamic> item) {
    int timestamp = 0;
    for (final key in const ['createdAt', 'timestamp', 'sentAt']) {
      final raw = item[key];
      timestamp = raw is int ? raw : int.tryParse(raw?.toString() ?? '') ?? 0;
      if (timestamp > 0) break;
    }
    if (timestamp <= 0) return '';

    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} د';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} س';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return '${date.day}/${date.month}/${date.year}';
  }
}

class _NotificationRowColors {
  static const Color ink = Color(0xFF182322);
  static const Color muted = Color(0xFF7B8381);
}
