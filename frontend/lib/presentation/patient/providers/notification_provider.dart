import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class NotificationItem {
  final String  title;
  final String  body;
  final String  type;   // 'appointment' | 'queue' | 'prescription' | 'general'
  final String? refId;  // doctor/appointment id for routing
  final DateTime receivedAt;
  final bool isRead;

  const NotificationItem({
    required this.title,
    required this.body,
    required this.type,
    this.refId,
    required this.receivedAt,
    this.isRead = false,
  });

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        title:      title,
        body:       body,
        type:       type,
        refId:      refId,
        receivedAt: receivedAt,
        isRead:     isRead ?? this.isRead,
      );

  IconData get icon {
    switch (type) {
      case 'appointment':  return Icons.calendar_today_rounded;
      case 'queue':        return Icons.queue_rounded;
      case 'prescription': return Icons.medication_rounded;
      default:             return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'appointment':  return const Color(0xFF1A73E8);
      case 'queue':        return const Color(0xFFF59E0B);
      case 'prescription': return const Color(0xFF7C3AED);
      default:             return const Color(0xFF10B981);
    }
  }

  String get timeAgo {
    final diff = DateTime.now().difference(receivedAt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24)   return '${diff.inHours} hours ago';
    if (diff.inDays == 1)    return 'Yesterday';
    return '${diff.inDays} days ago';
  }
}

// ─── StateNotifier ────────────────────────────────────────────────────────────
class NotificationNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationNotifier() : super([]);

  void add(NotificationItem item) {
    state = [item, ...state];
  }

  void markAllRead() {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
  }

  void markRead(int index) {
    final updated = [...state];
    updated[index] = updated[index].copyWith(isRead: true);
    state = updated;
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<NotificationItem>>(
  (ref) => NotificationNotifier(),
);
