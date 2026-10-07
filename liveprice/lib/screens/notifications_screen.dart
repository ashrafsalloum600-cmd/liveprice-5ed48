import 'package:flutter/material.dart';
import 'package:liveprice/services/notification_center.dart';
import 'package:liveprice/theme/app_colors.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: NotificationCenter.instance,
      builder: (context, _) {
        final items = NotificationCenter.instance.notifications;
        if (items.isEmpty) {
          return const Center(
            child: Text('لا توجد تنبيهات حالياً', style: TextStyle(color: AppColors.textDim)),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final n = items[i];
            return Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [BoxShadow(color: Colors.black.withAlpha(20), blurRadius: 16, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.surfaceHigh, borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.notifications_rounded, size: 20, color: AppColors.text),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          n.title,
                          style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.text),
                        ),
                        const SizedBox(height: 2),
                        Text(n.body, style: const TextStyle(fontSize: 13, color: AppColors.textDim)),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
