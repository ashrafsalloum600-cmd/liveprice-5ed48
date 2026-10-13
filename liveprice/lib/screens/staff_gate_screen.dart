import 'dart:async';

import 'package:flutter/material.dart';
import 'package:liveprice/models/staff_profile.dart';
import 'package:liveprice/screens/admin_price_upload_screen.dart';
import 'package:liveprice/services/audit_service.dart';
import 'package:liveprice/services/auth_service.dart';
import 'package:liveprice/services/staff_session.dart';
import 'package:liveprice/theme/app_colors.dart';

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
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
                const Text(
                  'دخول الموظفين',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
                const SizedBox(height: 24),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  children: [
                    for (final branch in const [('b1', 'المركز الرئيسي'), ('b2', 'طرطوس'), ('b3', 'جديدة البحر')])
                      ChoiceChip(
                        label: Text(branch.$2),
                        selected: _branchId == branch.$1,
                        onSelected: _signingIn ? null : (_) => setState(() => _branchId = branch.$1),
                        selectedColor: AppColors.accent,
                        labelStyle: TextStyle(color: _branchId == branch.$1 ? Colors.white : AppColors.text),
                      ),
                  ],
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
                            _signIn(() => _authService.signInWithEmail(_authService.branchEmail(_branchId!), password)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, foregroundColor: Colors.white),
                  child: _signingIn ? const CircularProgressIndicator() : const Text('دخول'),
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
                OutlinedButton.icon(
                  onPressed: _signingIn ? null : () => _signIn(_authService.signInWithGoogle),
                  icon: const Icon(Icons.g_mobiledata_rounded),
                  label: const Text('الدخول كمالك بحساب Google'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUnauthorized() => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('هذا الحساب غير مصرّح له بالإدارة', style: TextStyle(color: AppColors.text)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: StaffSession.instance.signOut, child: const Text('تسجيل الخروج')),
        ],
      ),
    ),
  );

  Widget _buildManager(StaffProfile profile) => Scaffold(
    backgroundColor: AppColors.bg,
    body: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('مرحباً ${profile.name} — ${profile.branchId}', style: const TextStyle(color: AppColors.text)),
          const SizedBox(height: 12),
          const Text('ميزة رفع الجرد قريباً', style: TextStyle(color: AppColors.text)),
          const SizedBox(height: 20),
          ElevatedButton(onPressed: StaffSession.instance.signOut, child: const Text('تسجيل الخروج')),
        ],
      ),
    ),
  );

  Widget _buildContent(StaffSession session) {
    if (session.loading || !session.initialized) {
      return const Scaffold(
        backgroundColor: AppColors.bg,
        body: Center(child: CircularProgressIndicator(color: AppColors.accent)),
      );
    }
    if (session.user == null) return _buildLoginForm();

    final profile = session.profile;
    if (profile == null || !profile.isValid) return _buildUnauthorized();
    if (profile.isOwner) return const AdminPriceUploadScreen();
    if (profile.isManager) return _buildManager(profile);
    return _buildUnauthorized();
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
