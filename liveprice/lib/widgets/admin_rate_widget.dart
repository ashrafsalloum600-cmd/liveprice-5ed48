import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:liveprice/services/pricing.dart';

class AdminRateWidget extends StatefulWidget {
  const AdminRateWidget({super.key});

  @override
  State<AdminRateWidget> createState() => _AdminRateWidgetState();
}

class _AdminRateWidgetState extends State<AdminRateWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _saving = false;

  Future<void> _saveRate() async {
    final raw = _controller.text.trim().replaceAll(',', '');
    final value = double.tryParse(raw);
    if (value == null || value <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل سعر صرف صحيح أكبر من صفر')));
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final current = Pricing.instance.usdToSyp;
      await FirebaseFirestore.instance.doc('settings/pricing').set({
        'usdToSyp': value,
        'updatedAt': FieldValue.serverTimestamp(),
        if (current != null && current != value) 'previousUsdToSyp': current,
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ سعر الصرف')));
      }
      _controller.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الحفظ: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'سعر الصرف',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'سعر 1\$ بالليرة', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              onPressed: _saving ? null : _saveRate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('حفظ سعر الصرف'),
            ),
          ),
        ],
      ),
    );
  }
}
