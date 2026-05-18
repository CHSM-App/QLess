// ─── NOTIFICATIONS SCREEN ────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/theme/patient_theme.dart';
import 'package:qless/presentation/patient/providers/notification_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final notifications = ref.watch(notificationProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (notifications.any((n) => !n.isRead))
            TextButton(
              onPressed: () =>
                  ref.read(notificationProvider.notifier).markAllRead(),
              child: const Text('Mark all read',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
        ],
      ),
      body: notifications.isEmpty
          ? const _EmptyState()
          : ListView.separated(
              padding: const EdgeInsets.all(24),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final n = notifications[i];
                return GestureDetector(
                  onTap: () =>
                      ref.read(notificationProvider.notifier).markRead(i),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: !n.isRead
                          ? (isDark
                              ? AppTheme.primary.withValues(alpha: 0.12)
                              : AppTheme.primary.withValues(alpha: 0.04))
                          : (isDark
                              ? const Color(0xFF1E293B)
                              : Colors.white),
                      borderRadius: BorderRadius.circular(20),
                      border: !n.isRead
                          ? Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.2),
                              width: 1.5)
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.15 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: n.color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(n.icon, color: n.color, size: 22),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      n.title,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800,
                                        color: isDark
                                            ? Colors.white
                                            : AppTheme.textPrimary,
                                      ),
                                    ),
                                  ),
                                  if (!n.isRead)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.white54
                                      : AppTheme.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                n.timeAgo,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white38
                                      : AppTheme.textHint,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 32, color: AppTheme.primary),
          ),
          const SizedBox(height: 14),
          const Text('No notifications yet',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary)),
          const SizedBox(height: 6),
          const Text('You\'ll see appointment and queue updates here',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}
