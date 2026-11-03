import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:liveprice/services/audit_service.dart';
import 'package:liveprice/services/staff_session.dart';
import 'package:liveprice/theme/app_colors.dart';
import 'package:liveprice/widgets/app_message.dart';

const _branchNames = {'b1': 'المركز الرئيسي', 'b2': 'طرطوس', 'b3': 'جديدة البحر'};
const _roleNames = {'manager': 'مدير فرع', 'owner': 'مالك'};

/// إدارة الموظفين (للمالك): عرض، تفعيل/تعطيل، تعديل الاسم والدور والفرع، وإضافة بالمعرّف UID.
class StaffManagementScreen extends StatefulWidget {
  const StaffManagementScreen({super.key});

  @override
  State<StaffManagementScreen> createState() => _StaffManagementScreenState();
}

class _StaffManagementScreenState extends State<StaffManagementScreen> {
  late Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _load() async {
    final snap = await FirebaseFirestore.instance.collection('staff').get();
    return snap.docs;
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _save(String uid, Map<String, dynamic> data, {bool isNew = false}) async {
    try {
      await FirebaseFirestore.instance.collection('staff').doc(uid).set(data, SetOptions(merge: true));
      await AuditService.log(isNew ? 'staff_add' : 'staff_update', details: {'uid': uid, ...data});
      showAppMessage(isNew ? 'تمت إضافة الموظف' : 'تم الحفظ');
      _reload();
    } catch (e) {
      showAppMessage('فشل الحفظ: $e');
    }
  }

  Future<void> _edit({String? uid, Map<String, dynamic>? data}) async {
    final isNew = uid == null;
    final uidC = TextEditingController();
    final nameC = TextEditingController(text: data?['name'] as String? ?? '');
    var role = (data?['role'] as String?) ?? 'manager';
    var branch = (data?['branchId'] as String?) ?? 'b1';
    if (!_roleNames.containsKey(role)) role = 'manager';
    if (!_branchNames.containsKey(branch)) branch = 'b1';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: Text(isNew ? 'إضافة موظف' : 'تعديل موظف'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isNew) ...[
                    TextField(
                      controller: uidC,
                      decoration: const InputDecoration(labelText: 'المعرّف UID (من Firebase Auth)'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: nameC,
                    decoration: const InputDecoration(labelText: 'الاسم'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: role,
                    decoration: const InputDecoration(labelText: 'الدور'),
                    items: [for (final e in _roleNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => setS(() => role = v ?? role),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: branch,
                    decoration: const InputDecoration(labelText: 'الفرع'),
                    items: [for (final e in _branchNames.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
                    onChanged: (v) => setS(() => branch = v ?? branch),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
              TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حفظ')),
            ],
          ),
        ),
      ),
    );
    if (ok != true) return;
    final id = isNew ? uidC.text.trim() : uid;
    if (id.isEmpty) {
      showAppMessage('أدخل المعرّف UID');
      return;
    }
    await _save(id, {
      'name': nameC.text.trim(),
      'role': role,
      'branchId': branch,
      if (isNew) 'active': true,
    }, isNew: isNew);
  }

  @override
  Widget build(BuildContext context) {
    final me = StaffSession.instance.user?.uid;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('إدارة الموظفين'),
          actions: [IconButton(tooltip: 'تحديث', onPressed: _reload, icon: const Icon(Icons.refresh))],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('إضافة موظف'),
        ),
        body: FutureBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator(color: AppColors.accent));
            }
            if (snap.hasError) {
              return const Center(child: Text('تعذرت قراءة الموظفين (صلاحيات المالك مطلوبة)'));
            }
            final docs = snap.data ?? const [];
            if (docs.isEmpty) return const Center(child: Text('لا يوجد موظفون'));
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: docs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final d = docs[i];
                final m = d.data();
                final active = m['active'] == true;
                final isMe = d.id == me;
                final name = (m['name'] as String?)?.trim();
                return Container(
                  decoration: ShapeDecoration(
                    color: AppColors.surface,
                    shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  ),
                  child: ListTile(
                    onTap: () => _edit(uid: d.id, data: m),
                    title: Text(
                      (name == null || name.isEmpty) ? d.id : name,
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.text),
                    ),
                    subtitle: Text(
                      '${_roleNames[m['role']] ?? m['role'] ?? '—'} • '
                      '${_branchNames[m['branchId']] ?? m['branchId'] ?? '—'}'
                      '${isMe ? ' • أنت' : ''}',
                      style: TextStyle(color: AppColors.textFaint),
                    ),
                    trailing: Switch(value: active, onChanged: isMe ? null : (v) => _save(d.id, {'active': v})),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
