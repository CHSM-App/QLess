
// ─── NOTIFICATIONS SCREEN ────────────────────────────────────────────────────

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:qless/core/theme/patient_theme.dart';


class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifications = [
      {
        'icon': Icons.calendar_today_rounded,
        'color': const Color(0xFF1A73E8),
        'title': 'Appointment Reminder',
        'desc': 'Your appointment with Dr. Anika Sharma is tomorrow at 10:00 AM.',
        'time': '2 hours ago',
        'unread': true,
      },
      {
        'icon': Icons.queue_rounded,
        'color': const Color(0xFFF59E0B),
        'title': 'Queue Update',
        'desc': 'You are now 2nd in queue. Dr. Rajesh Kumar will see you soon.',
        'time': '5 hours ago',
        'unread': true,
      },
      {
        'icon': Icons.timer_rounded,
        'color': const Color(0xFFEF4444),
        'title': 'Doctor Running Late',
        'desc': 'Dr. Priya Nair is running 20 minutes late. Updated wait time: 60 min.',
        'time': 'Yesterday',
        'unread': false,
      },
      {
        'icon': Icons.check_circle_rounded,
        'color': const Color(0xFF10B981),
        'title': 'Appointment Confirmed',
        'desc': 'Your appointment with Dr. Mohan Verma on 2 Apr at 4:00 PM is confirmed.',
        'time': '2 days ago',
        'unread': false,
      },
      {
        'icon': Icons.medication_rounded,
        'color': const Color(0xFF7C3AED),
        'title': 'Prescription Available',
        'desc': 'Your prescription from Dr. Rajesh Kumar is now available. Tap to view.',
        'time': '3 days ago',
        'unread': false,
      },
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Mark all read',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(24),
        itemCount: notifications.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) {
          final n = notifications[i];
          final unread = n['unread'] as bool;
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: unread
                  ? (isDark
                      ? AppTheme.primary.withOpacity(0.12)
                      : AppTheme.primary.withOpacity(0.04))
                  : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: unread
                  ? Border.all(
                      color: AppTheme.primary.withOpacity(0.2), width: 1.5)
                  : null,
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(isDark ? 0.15 : 0.04),
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
                    color: (n['color'] as Color).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(n['icon'] as IconData,
                      color: n['color'] as Color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            n['title'] as String,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.textPrimary,
                            ),
                          ),
                          if (unread)
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
                        n['desc'] as String,
                        style: TextStyle(
                          fontSize: 12,
                          color:
                              isDark ? Colors.white54 : AppTheme.textSecondary,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        n['time'] as String,
                        style: TextStyle(
                          fontSize: 11,
                          color:
                              isDark ? Colors.white38 : AppTheme.textHint,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}


