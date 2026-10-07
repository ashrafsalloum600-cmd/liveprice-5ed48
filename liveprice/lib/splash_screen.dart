import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:liveprice/theme/app_colors.dart';

class SplashScreen extends StatelessWidget {
  final Widget next;

  const SplashScreen({super.key, required this.next});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Lottie.asset(
          'assets/images/welcompic/welcompic1.json',
          width: 220,
          fit: BoxFit.contain,
          onLoaded: (composition) {
            Future.delayed(composition.duration, () {
              if (context.mounted) {
                Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
              }
            });
          },
        ),
      ),
    );
  }
}
