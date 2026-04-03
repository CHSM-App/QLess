import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/core/theme/patient_theme.dart';
import 'package:qless/presentation/patient/screens/patient_notification.dart';
import 'package:qless/presentation/shared/screens/continue_as.dart' as continue_as;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF1A73E8), const Color(0xFF0D5DBF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Profile',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_rounded,
                                color: Colors.white),
                            onPressed: () {},
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.white.withOpacity(0.3),
                        child: const Text(
                          'AM',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'Arjun Mehta',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+91 98765 43210 · arjun@email.com',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ProfileCard(isDark: isDark, children: [
                  _ProfileInfoRow(
                      'Blood Group', 'O+', Icons.bloodtype_rounded, isDark),
                  _ProfileInfoRow('Date of Birth', '12 Aug 1992',
                      Icons.cake_rounded, isDark),
                  _ProfileInfoRow(
                      'Gender', 'Male', Icons.person_rounded, isDark),
                  _ProfileInfoRow('Age', '32 years',
                      Icons.calendar_today_rounded, isDark),
                ]),
                const SizedBox(height: 16),
                _ProfileCard(isDark: isDark, children: [
                  _MenuTile(
                    icon: Icons.group_rounded,
                    label: 'Family Members',
                    color: const Color(0xFF7C3AED),
                    isDark: isDark,
                    onTap: () {
                      
                    },
                    // onTap: () => Navigator.push(
                    //     context,
                    //     MaterialPageRoute(
                    //         builder: (_) => const FamilyMembersScreen())),
                  ),
                  _MenuTile(
                    icon: Icons.notifications_rounded,
                    label: 'Notifications',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen())),
                  ),
                  _MenuTile(
                    icon: Icons.medical_information_rounded,
                    label: 'Medical Records',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                    onTap: () {},
                  ),
                  _MenuTile(
                    icon: Icons.privacy_tip_rounded,
                    label: 'Privacy & Security',
                    color: const Color(0xFF06B6D4),
                    isDark: isDark,
                    onTap: () {},
                  ),
                  _MenuTile(
                    icon: Icons.help_rounded,
                    label: 'Help & Support',
                    color: const Color(0xFF6366F1),
                    isDark: isDark,
                    onTap: () {},
                    showDivider: false,
                  ),
                ]),
                const SizedBox(height: 16),
                _ProfileCard(isDark: isDark, children: [
                  _MenuTile(
                    icon: Icons.logout_rounded,
                    label: 'Logout',
                    color: AppTheme.error,
                    isDark: isDark,
                    onTap: () async {
                      await ref.read(tokenProvider.notifier).clearTokens();
                      if (!context.mounted) return;
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                          builder: (_) => const continue_as.SplashScreen(),
                        ),
                        (route) => false,
                      );
                    },
                    showDivider: false,
                  ),
                ]),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'MedCare v1.0.0',
                    style: TextStyle(
                        fontSize: 12,
                        color:
                            isDark ? Colors.white24 : AppTheme.textHint),
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final List<Widget> children;
  final bool isDark;
  const _ProfileCard({required this.children, required this.isDark});
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final bool isDark;
  const _ProfileInfoRow(this.label, this.value, this.icon, this.isDark);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.primary, size: 18),
          ),
          const SizedBox(width: 14),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;
  final bool showDivider;
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.isDark,
    required this.onTap,
    this.showDivider = true,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          onTap: onTap,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          trailing: Icon(Icons.chevron_right_rounded,
              color: isDark ? Colors.white24 : AppTheme.textHint),
        ),
        if (showDivider)
          Divider(
            indent: 20,
            endIndent: 20,
            height: 1,
            color: isDark ? Colors.white12 : AppTheme.divider,
          ),
      ],
    );
  }
}
