import 'package:flutter/material.dart' hide SnackBar, ScaffoldMessenger;
import 'package:liveprice/widgets/app_message.dart';
import 'package:liveprice/services/audit_service.dart';
import 'package:liveprice/services/danger_zone.dart';
import 'package:liveprice/services/staff_session.dart';
import 'package:liveprice/theme/app_colors.dart';

class WipeDataButton extends StatefulWidget {
  const WipeDataButton({super.key});

  @override
  State<WipeDataButton> createState() => _WipeDataButtonState();
}

class _WipeDataButtonState extends State<WipeDataButton> {
  bool _busy = false;

  Future<bool> _confirm() async {
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surface,
            title: const Text('حذف كل بيانات المنتجات؟'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'سيُحذف: المنتجات، الكتالوج العام، سجل تغيّر الأسعار، ربط الفروع، وكميات الفروع.\n'
                  'لن يُحذف: الموظفون، سعر الصرف، إعدادات الجرد، وسجل الحركات.\n'
                  'لا يمكن التراجع.',
                  style: TextStyle(color: AppColors.textDim),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: c,
                  onChanged: (_) => setS(() {}),
                  decoration: const InputDecoration(hintText: 'اكتب: حذف'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              TextButton(
                onPressed: c.text.trim() == 'حذف' ? () => Navigator.pop(ctx, true) : null,
                child: const Text('حذف نهائي', style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
    return ok == true;
  }

  Future<void> _run() async {
    if (StaffSession.instance.profile?.isOwner != true) return;
    if (!await _confirm()) return;
    setState(() => _busy = true);
    try {
      final n = await DangerZone.wipeCatalogData();
      await AuditService.log('wipe_catalog', details: {'ops': n});
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('تم الحذف ($n عملية). أوقف التطبيق وشغّله من جديد.')));
      }
    } catch (e) {
      if (mounted) {
        showAppMessage('فشل الحذف: $e');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton.icon(
        onPressed: _busy ? null : _run,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          side: const BorderSide(color: Colors.redAccent),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent),
              )
            : const Icon(Icons.delete_forever_rounded),
        label: const Text('حذف كل بيانات المنتجات (للتجربة)'),
      ),
    );
  }
}
