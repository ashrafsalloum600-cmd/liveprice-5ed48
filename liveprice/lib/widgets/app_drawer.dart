import 'package:flutter/material.dart';
import 'package:liveprice/user_profile_screen.dart';
import 'package:liveprice/theme/app_colors.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.bg,
      elevation: 0,
      width: 300,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(20))),
      child: SafeArea(child: ProfileContent()),
    );
  }
}
