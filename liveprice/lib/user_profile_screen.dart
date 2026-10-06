import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:liveprice/services/auth_service.dart';
import 'package:liveprice/widgets/social_sign_in_buttons.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  static const Color primary = Color(0xFF1E88E5);
  static const Color bg = Color(0xFFF8F9FA);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: UserProfileScreen.bg,
        appBar: AppBar(
          backgroundColor: UserProfileScreen.bg,
          elevation: 0,
          centerTitle: true,
          title: const Text(
            'الملف الشخصي',
            style: TextStyle(fontFamily: 'Cairo', color: Colors.black, fontWeight: FontWeight.w700),
          ),
        ),
        body: const ProfileContent(),
      ),
    );
  }
}

class ProfileContent extends StatefulWidget {
  const ProfileContent({super.key});

  @override
  State<ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends State<ProfileContent> {
  final AuthService _authService = AuthService();
  bool _isSigningIn = false;

  Future<void> _signInWithGoogle() async {
    if (_isSigningIn) return;
    setState(() => _isSigningIn = true);
    try {
      await _authService.signInWithGoogle();
    } on AuthServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSigningIn = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _authService.signOut();
    } on AuthServiceException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: StreamBuilder<User?>(
        stream: _authService.authStateChanges,
        builder: (context, snapshot) {
          final User? user = snapshot.data;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _ProfileHeader(user: user),
              const SizedBox(height: 16),
              if (user == null) ...[
                SocialSignInButtons(isGoogleLoading: _isSigningIn, onGooglePressed: _signInWithGoogle),
                const SizedBox(height: 20),
              ] else
                const SizedBox(height: 20),
              const _SectionCard(
                title: 'الحساب الشخصي',
                items: [
                  _ProfileItem(icon: Icons.person_outline_rounded, label: 'المعلومات الشخصية'),
                  _ProfileItem(icon: Icons.shopping_bag_outlined, label: 'طلباتي'),
                  _ProfileItem(icon: Icons.favorite_border_rounded, label: 'المفضلة'),
                  _ProfileItem(icon: Icons.location_on_outlined, label: 'العناوين المسجلة'),
                ],
              ),
              const SizedBox(height: 16),
              const _SectionCard(
                title: 'التفضيلات والدعم',
                items: [
                  _ProfileItem(icon: Icons.notifications_none_rounded, label: 'التنبيهات'),
                  _ProfileItem(icon: Icons.language_rounded, label: 'اللغة والأنماط'),
                  _ProfileItem(icon: Icons.support_agent_rounded, label: 'الدعم والمساعدة'),
                  _ProfileItem(icon: Icons.privacy_tip_outlined, label: 'الخصوصية والشروط'),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                items: [
                  _ProfileItem(
                    icon: Icons.logout_rounded,
                    label: 'تسجيل الخروج',
                    color: Colors.redAccent,
                    onTap: user == null ? null : _signOut,
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  final User? user;

  const _ProfileHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(15), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 44,
                backgroundColor: Color(0xFFE3F2FD),
                backgroundImage: user?.photoURL == null ? null : NetworkImage(user!.photoURL!),
                child: user?.photoURL == null
                    ? const Icon(Icons.person_rounded, size: 48, color: UserProfileScreen.primary)
                    : null,
              ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: UserProfileScreen.primary, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            user?.displayName ?? 'اسم المستخدم',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.black),
          ),
          const SizedBox(height: 4),
          Text(
            user?.email ?? '+963 999 999 999 · user@email.com',
            style: const TextStyle(fontFamily: 'Cairo', fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String? title;
  final List<_ProfileItem> items;

  const _SectionCard({this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 8),
            child: Text(
              title!,
              style: const TextStyle(
                fontFamily: 'Cairo',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black45,
              ),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(12), blurRadius: 14, offset: const Offset(0, 4))],
          ),
          child: Column(
            children: [
              for (int i = 0; i < items.length; i++) ...[
                items[i],
                if (i != items.length - 1)
                  const Divider(height: 1, indent: 56, endIndent: 16, color: Color(0xFFEFEFEF)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;

  const _ProfileItem({required this.icon, required this.label, this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap ?? () {},
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color ?? UserProfileScreen.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'Cairo',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: color ?? Colors.black87,
                ),
              ),
            ),
            if (color == null) const Icon(Icons.chevron_left_rounded, size: 22, color: Colors.black26),
          ],
        ),
      ),
    );
  }
}
