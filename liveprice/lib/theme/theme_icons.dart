import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:flutter/material.dart';

enum ThemeIconSet { cupertino, material, outlined }

/// غيّر الأيقونات من هنا فقط: عدّل قيمة preset.
class ThemeIcons {
  static const ThemeIconSet preset = ThemeIconSet.material;

  static IconData of(bool dark) => switch (preset) {
    ThemeIconSet.cupertino => dark ? CupertinoIcons.moon_fill : CupertinoIcons.sun_max_fill,
    ThemeIconSet.material => dark ? Icons.nightlight_round : Icons.wb_sunny_rounded,
    ThemeIconSet.outlined => dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
  };
}
