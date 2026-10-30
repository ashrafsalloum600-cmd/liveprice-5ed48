import 'package:flutter/material.dart';

import 'theme_controller.dart';

/// تبديل الثيم بشكل عادي وفوري (بدون لقطة شاشة ولا دائرة).
/// بقي الاسم والمفتاح كما هما حتى لا نعدّل باقي الملفات.
class ThemeReveal extends StatefulWidget {
  const ThemeReveal({super.key, required this.child});

  static final GlobalKey<ThemeRevealState> revealKey = GlobalKey<ThemeRevealState>();
  final Widget child;

  @override
  State<ThemeReveal> createState() => ThemeRevealState();
}

class ThemeRevealState extends State<ThemeReveal> {
  Future<void> toggle([Offset? origin]) => ThemeController.instance.toggle();

  @override
  Widget build(BuildContext context) => widget.child;
}
