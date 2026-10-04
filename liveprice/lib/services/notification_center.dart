import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:liveprice/models/app_notification.dart';

class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  static const String _seenKey = 'notif_last_seen';

  List<AppNotification> notifications = [];
  final List<AppNotification> _extra = [];
  List<AppNotification> _log = [];
  int _lastSeen = 0;
  bool _started = false;
  bool hasUnread = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    _lastSeen = DateTime.now().millisecondsSinceEpoch;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_seenKey);
      if (saved == null) {
        await prefs.setInt(_seenKey, _lastSeen);
      } else {
        _lastSeen = saved;
      }
    } catch (_) {}

    FirebaseFirestore.instance.collection('price_changes').orderBy('at', descending: true).limit(30).snapshots().listen(
      (snap) {
        _log = snap.docs.map((d) {
          final m = d.data();
          final cur = m['currency'] as String? ?? 'SYP';
          return AppNotification(
            id: d.id,
            title: m['name'] as String? ?? '',
            body: 'تغيّر السعر من ${_fmt(m['oldPrice'], cur)} إلى ${_fmt(m['newPrice'], cur)}',
            time: (m['at'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );
        }).toList();
        _refresh();
      },
      onError: (e) => debugPrint('[NotificationCenter] $e'),
    );
  }

  String _fmt(dynamic v, String cur) {
    final n = (v as num?)?.toDouble() ?? 0;
    if (cur == 'USD') return '\$${n.toStringAsFixed(2)}';
    final s = n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return '$s ل.س';
  }

  void _refresh() {
    notifications = [..._extra, ..._log]..sort((a, b) => b.time.compareTo(a.time));
    hasUnread = notifications.any((n) => n.time.millisecondsSinceEpoch > _lastSeen);
    notifyListeners();
  }

  void addFromRemote(String title, String body) {
    _extra.insert(
      0,
      AppNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        body: body,
        time: DateTime.now(),
      ),
    );
    _refresh();
  }

  Future<void> markAllRead() async {
    if (!hasUnread) return;
    final newest = notifications.first.time.millisecondsSinceEpoch;
    if (newest > _lastSeen) _lastSeen = newest;
    hasUnread = false;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_seenKey, _lastSeen);
    } catch (_) {}
  }
}
