import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

const String _googleLogo = '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">
<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>
<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>
<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>
<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>
</svg>
''';

class SocialSignInButtons extends StatelessWidget {
  final VoidCallback? onGooglePressed;
  final VoidCallback? onFacebookPressed;
  final bool isGoogleLoading;

  const SocialSignInButtons({super.key, this.onGooglePressed, this.onFacebookPressed, this.isGoogleLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'تسجيل الدخول',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black),
          ),
          const SizedBox(height: 4),
          const Text(
            'سجّل دخولك للاحتفاظ بمفضلتك على كل أجهزتك',
            style: TextStyle(fontSize: 12.5, color: Colors.black45),
          ),
          const SizedBox(height: 16),
          _SocialButton(
            label: 'المتابعة باستخدام Google',
            background: Colors.white,
            foreground: const Color(0xFF1F1F1F),
            borderColor: const Color(0xFF747775),
            icon: isGoogleLoading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1F1F1F)),
                  )
                : SvgPicture.string(_googleLogo, width: 20, height: 20),
            onPressed: isGoogleLoading ? null : onGooglePressed,
          ),
          const SizedBox(height: 12),
          _SocialButton(
            label: 'المتابعة باستخدام Facebook',
            background: const Color(0xFF1877F2),
            foreground: Colors.white,
            icon: const Icon(Icons.facebook, size: 24, color: Colors.white),
            onPressed: onFacebookPressed,
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;
  final Color? borderColor;
  final Widget icon;
  final VoidCallback? onPressed;

  const _SocialButton({
    required this.label,
    required this.background,
    required this.foreground,
    required this.icon,
    required this.onPressed,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: borderColor == null ? BorderSide.none : BorderSide(color: borderColor!),
      ),
      child: InkWell(
        // فارغ مؤقتاً كي يظهر تأثير الضغط أثناء تجربة التصميم
        onTap: onPressed ?? () {},
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: foreground),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
