import 'package:flutter/material.dart';
import 'package:liveprice/user_profile_screen.dart';
import 'package:liveprice/theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return const Drawer(
      backgroundColor: AppColors.background,
      width: 320,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
      child: SafeArea(child: ProfileContent()),
    );
  }
}
