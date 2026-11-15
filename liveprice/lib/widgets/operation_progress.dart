import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class OpProgress {
  OpProgress(String initialTitle)
      : title = ValueNotifier<String>(initialTitle),
        stage = ValueNotifier<String?>(null),
        percent = ValueNotifier<double?>(null);

  final ValueNotifier<String> title;
  final ValueNotifier<String?> stage;
  final ValueNotifier<double?> percent;

  void dispose() {
    title.dispose();
    stage.dispose();
    percent.dispose();
  }
}

Future<T> runWithProgress<T>(
  BuildContext context,
  String title,
  Future<T> Function(void Function(double? percent, String? stage) report)
      task,
) async {
  final progress = OpProgress(title);
  var taskCompleted = false;
  var dialogShown = false;

  void report(double? percent, String? stage) {
    progress.percent.value = percent?.clamp(0, 1).toDouble();
    progress.stage.value = stage;
  }

  final taskFuture = Future<T>.sync(() => task(report));
  final dialogFuture = Future<void>.delayed(
    const Duration(milliseconds: 300),
  ).then((_) {
    if (taskCompleted || !context.mounted) return Future<void>.value();
    dialogShown = true;
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ValueListenableBuilder<String>(
                    valueListenable: progress.title,
                    builder: (context, value, _) => Text(
                      value,
                      style: TextStyle(
                        color: AppColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ValueListenableBuilder<String?>(
                    valueListenable: progress.stage,
                    builder: (context, value, _) => Text(
                      value ?? '',
                      style: TextStyle(
                        color: AppColors.textDim,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ValueListenableBuilder<double?>(
                    valueListenable: progress.percent,
                    builder: (context, value, _) => Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 8,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: value,
                                color: AppColors.accent,
                                backgroundColor: AppColors.surfaceHigh,
                              ),
                            ),
                          ),
                        ),
                        if (value != null) ...[
                          const SizedBox(width: 12),
                          Text(
                            '${(value * 100).round()}%',
                            style: TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  });

  try {
    return await taskFuture;
  } finally {
    taskCompleted = true;
    if (dialogShown) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      await dialogFuture;
    }
    progress.dispose();
  }
}
