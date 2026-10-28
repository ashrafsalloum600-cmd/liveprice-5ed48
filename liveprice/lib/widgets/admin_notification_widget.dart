import 'package:flutter/material.dart' hide SnackBar, ScaffoldMessenger;
import 'package:liveprice/widgets/app_message.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liveprice/theme/app_colors.dart';

class AdminNotificationWidget extends StatefulWidget {
  const AdminNotificationWidget({super.key});

  @override
  State<AdminNotificationWidget> createState() => _AdminNotificationWidgetState();
}

class _AdminNotificationWidgetState extends State<AdminNotificationWidget> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    if (_titleController.text.trim().isEmpty || _bodyController.text.trim().isEmpty) return;

    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    setState(() => _sending = true);
    try {
      await FirebaseFirestore.instance.collection('notifications_queue').add({
        'target': 'topic',
        'topic': 'all_traders',
        'message': {
          'notification': {'title': title, 'body': body},
          'webpush': {
            'headers': {'TTL': '86400'},
            'notification': {
              'title': title,
              'body': body,
              'icon': '/icons/Icon-192.png',
              'badge': '/icons/Icon-192.png',
            },
          },
          'data': {'type': 'admin_notice', 'click_action': 'FLUTTER_NOTIFICATION_CLICK'},
        },
        'createdAt': FieldValue.serverTimestamp(),
      });
      _titleController.clear();
      _bodyController.clear();
      if (mounted) {
        showAppMessage('تم إضافة الإشعار لقائمة الإرسال');
      }
    } catch (e) {
      if (mounted) {
        showAppMessage('فشل: $e');
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إرسال إشعار',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'العنوان', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _bodyController,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'المحتوى', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _sending ? null : _send,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Send Push Notification'),
            ),
          ),
        ],
      ),
    );
  }
}
