import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:liveprice/models/app_notification.dart';

class NotificationCenter extends ChangeNotifier {
  NotificationCenter._();
  static final NotificationCenter instance = NotificationCenter._();

  final List<AppNotification> notifications = [];
  final Map<String, double> _lastKnownPrices = {};
  bool _started = false;
  bool hasUnread = false;

  void start() {
    if (_started) return;
    _started = true;

    FirebaseFirestore.instance.collection('products').snapshots().listen((snapshot) {
      for (final change in snapshot.docChanges) {
        final data = change.doc.data();
        if (data == null) continue;

        final id = change.doc.id;
        final name = data['name'] as String? ?? '';
        final newPrice = (data['price'] as num?)?.toDouble() ?? 0.0;
        final oldPrice = _lastKnownPrices[id];

        if (change.type == DocumentChangeType.modified && oldPrice != null && oldPrice != newPrice) {
          notifications.insert(
            0,
            AppNotification(
              id: '${id}_${DateTime.now().millisecondsSinceEpoch}',
              title: name,
              body: 'تغيّر السعر من $oldPrice إلى $newPrice',
              time: DateTime.now(),
            ),
          );
          hasUnread = true;
          notifyListeners();
        }

        _lastKnownPrices[id] = newPrice;
      }
    }, onError: (e) => debugPrint('[NotificationCenter] $e'));
  }

  void markAllRead() {
    if (!hasUnread) return;
    hasUnread = false;
    notifyListeners();
  }
}
