import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide SnackBar, ScaffoldMessenger;
import 'package:liveprice/widgets/app_message.dart';
import 'package:liveprice/models/staff_profile.dart';
import 'package:liveprice/screens/admin_price_upload_screen.dart';
import 'package:liveprice/screens/inventory_upload_screen.dart';
import 'package:liveprice/screens/inventory_details_screen.dart';
import 'package:liveprice/services/audit_service.dart';
import 'package:liveprice/services/auth_service.dart';
import 'package:liveprice/services/staff_session.dart';
import 'package:liveprice/theme/app_colors.dart';
import 'package:liveprice/theme/spring.dart';

class StaffGateScreen extends StatefulWidget {
  const StaffGateScreen({super.key});

  @override
  State<StaffGateScreen> createState() => _StaffGateScreenState();
}

class _StaffGateScreenState extends State<StaffGateScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _passwordController = TextEditingController();
  String? _branchId;
  bool _obscurePassword = true;
  bool _signingIn = false;
  bool _justSignedIn = false;

  @override
  void initState() {
    super.initState();
    StaffSession.instance.addListener(_onSessionChanged);
    StaffSession.instance.start();
  }

  @override
  void dispose() {
    StaffSession.instance.removeListener(_onSessionChanged);
    _passwordController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    unawaited(_logLoginIfReady());
  }

  Future<void> _logLoginIfReady() async {
    final profile = StaffSession.instance.profile;
    if (_justSignedIn && profile != null && profile.isValid) {
      _justSignedIn = false;
      await AuditService.log('login');
    }
  }

  Future<void> _signIn(Future<void> Function() signIn) async {
    setState(() => _signingIn = true);
    try {
      await signIn();
      _justSignedIn = true;
      await _logLoginIfReady();
    } catch (error) {
      if (mounted) {
        showAppMessage(error.toString());
      }
    } finally {
      if (mounted) setState(() => _signingIn = false);
    }
  }

  Widget _buildLoginForm() {
    final password = _passwordController.text;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'دخول الموظفين',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
                const SizedBox(height: 24),
                _BranchPicker(
                  selected: _branchId,
                  enabled: !_signingIn,
                  onSelect: (id) => setState(() => _branchId = id),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'كلمة السر',
                    filled: true,
                    fillColor: AppColors.surface,
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _signingIn || _branchId == null || password.isEmpty
                      ? null
                      : () =>
                            _signIn(() => _authService.signInWithEmail(AuthService.branchEmail(_branchId!), password)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    elevation: 0,
                    shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(32)),
                  ),
                  child: _signingIn
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('دخول', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('أو')),
                      Expanded(child: Divider()),
                    ],
                  ),
                ),
                _GoogleButton(onTap: _signingIn ? null : () => _signIn(_authService.signInWithGoogle)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthorized(StaffProfile? profile, String uid, String? email) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('هذا الحساب غير مصرّح له بالإدارة', style: TextStyle(color: AppColors.text)),
          SelectableText(
            'السبب: ${profile == null ? 'لا يوجد مستند staff بهذا المعرّف' : profile.invalidReason}',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textDim),
          ),
          SelectableText('المعرّف: $uid', style: TextStyle(fontSize: 12, color: AppColors.textDim)),
          SelectableText('البريد: ${email ?? ''}', style: TextStyle(fontSize: 12, color: AppColors.textDim)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: StaffSession.instance.signOut, child: const Text('تسجيل الخروج')),
        ],
      ),
    ),
  );

  Widget _buildProfileReadError(String errorCode) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'تعذر قراءة بيانات الموظف من Firestore',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text),
            ),
            const SizedBox(height: 8),
            Text('رمز الخطأ: $errorCode', style: TextStyle(color: AppColors.text)),
            const SizedBox(height: 12),
            Text(
              'تحقق من قواعد Firestore للسماح بقراءة staff/{UID} للمستخدم المسجل.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.text),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: StaffSession.instance.signOut, child: const Text('تسجيل الخروج')),
          ],
        ),
      ),
    ),
  );

  Widget _buildManager(StaffProfile profile) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('مرحباً ${profile.name} — ${profile.branchId}', style: TextStyle(color: AppColors.text)),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              final branchNames = const {'b1': 'المركز الرئيسي', 'b2': 'طرطوس', 'b3': 'جديدة البحر'};
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => InventoryUploadScreen(
                    branchId: profile.branchId,
                    branchName: branchNames[profile.branchId] ?? profile.branchId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.upload_file),
            label: const Text('رفع ملف الجرد'),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () =>
                Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const InventoryDetailsScreen())),
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('تفاصيل مخزون الفروع'),
          ),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: StaffSession.instance.signOut, child: const Text('تسجيل الخروج')),
        ],
      ),
    ),
  );

  Widget _buildContent(StaffSession session) {
    if (session.loading || !session.initialized) {
      return Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (session.user == null) return _buildLoginForm();
    if (session.profileReadError != null) return _buildProfileReadError(session.profileReadError!);

    final profile = session.profile;
    if (profile == null || !profile.isValid) {
      return _buildUnauthorized(profile, session.user!.uid, session.user!.email);
    }
    if (profile.isOwner) return const AdminPriceUploadScreen();
    if (profile.isManager) return _buildManager(profile);
    return _buildUnauthorized(profile, session.user!.uid, session.user!.email);
  }

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: AnimatedBuilder(
      animation: StaffSession.instance,
      builder: (context, _) => _buildContent(StaffSession.instance),
    ),
  );
}

// ثلاثة أزرار متساوية بسطر واحد ثابت الحجم (لا تلتف ولا تتمدد عند الاختيار)
class _BranchPicker extends StatelessWidget {
  const _BranchPicker({required this.selected, required this.enabled, required this.onSelect});

  static const _branches = [('b1', 'المركز الرئيسي'), ('b2', 'طرطوس'), ('b3', 'جديدة البحر')];

  final String? selected;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _branches.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsetsDirectional.only(end: i < _branches.length - 1 ? 8 : 0),
              child: Pressable(
                onTap: enabled ? () => onSelect(_branches[i].$1) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  height: 48,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: ShapeDecoration(
                    color: selected == _branches[i].$1 ? AppColors.accent : AppColors.surface,
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                      side: BorderSide(
                        color: selected == _branches[i].$1 ? AppColors.accent : AppColors.border,
                        width: 0.8,
                      ),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _branches[i].$2,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected == _branches[i].$1 ? Colors.white : AppColors.text,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _GoogleButton extends StatelessWidget {
  const _GoogleButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          height: 52,
          decoration: ShapeDecoration(
            color: AppColors.surface,
            shape: ContinuousRectangleBorder(
              borderRadius: BorderRadius.circular(32),
              side: BorderSide(color: AppColors.border, width: 0.8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GoogleG(),
              SizedBox(width: 10),
              Text(
                'الدخول كمالك بحساب Google',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// حرف G بألوان Google يدور دورة وحدة بنابض عند ظهور الصفحة ثم يثبت
class _GoogleG extends StatelessWidget {
  const _GoogleG();

  static const _colors = [
    Color(0xFF4285F4),
    Color(0xFF34A853),
    Color(0xFFFBBC05),
    Color(0xFFEA4335),
    Color(0xFF4285F4),
  ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: const AppSpring(),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.rotate(angle: (1 - t) * -2 * math.pi, child: child),
      ),
      child: ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (rect) =>
            const SweepGradient(colors: _colors, transform: GradientRotation(-math.pi / 4)).createShader(rect),
        child: const Text(
          'G',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, height: 1),
        ),
      ),
    );
  }
}
