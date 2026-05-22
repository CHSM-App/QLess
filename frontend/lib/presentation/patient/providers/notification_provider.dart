import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/dio_provider.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';

// ─── Model ────────────────────────────────────────────────────────────────────
class NotificationItem {
  final int?    id;        // server notification_id (null = local-only FCM)
  final String  title;
  final String  body;
  final String  type;      // 'appointment' | 'queue' | 'prescription' | 'rating' | 'general'
  final String? refId;     // doctor / appointment / prescription id for routing
  final DateTime receivedAt;
  final bool isRead;

  const NotificationItem({
    this.id,
    required this.title,
    required this.body,
    required this.type,
    this.refId,
    required this.receivedAt,
    this.isRead = false,
  });

  // SP returns: notification_id, title, body, type, ref_id, is_read, created_at
  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final readRaw = json['is_read'];
    final created = json['created_at']?.toString();
    return NotificationItem(
      id: (json['notification_id'] as num?)?.toInt(),
      title: (json['title'] ?? '').toString(),
      body:  (json['body']  ?? '').toString(),
      type:  (json['type']  ?? 'general').toString(),
      refId: json['ref_id']?.toString(),
      receivedAt: created != null
          ? DateTime.tryParse(created)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      isRead: readRaw == true || readRaw == 1 || readRaw == '1',
    );
  }

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
        id:         id,
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
      case 'rating':       return Icons.star_rounded;
      default:             return Icons.notifications_rounded;
    }
  }

  Color get color {
    switch (type) {
      case 'appointment':  return const Color(0xFF1A73E8);
      case 'queue':        return const Color(0xFFF59E0B);
      case 'prescription': return const Color(0xFF7C3AED);
      case 'rating':       return const Color(0xFFEAB308);
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
  NotificationNotifier(this._ref) : super([]);

  final Ref _ref;

  int? _patientId() =>
      _ref.read(patientLoginViewModelProvider).patientId;

  // Optimistic local insert (used by foreground FCM before server refresh
  // round-trips, so the user sees the row instantly).
  void add(NotificationItem item) {
    state = [item, ...state];
  }

  /// Fetch the canonical list from the server. Safe to call any time; if
  /// the user is not logged in or the API errors, state is left untouched.
  Future<void> loadFromServer() async {
    final pid = _patientId();
    if (pid == null || pid == 0) return;
    try {
      final api = _ref.read(apiServiceProvider);
      final raw = await api.getNotifications(pid);
      state = raw
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      if (kDebugMode) debugPrint('loadFromServer failed: $e');
    }
  }

  Future<void> markRead(int index) async {
    if (index < 0 || index >= state.length) return;
    final n = state[index];
    if (n.isRead) return;

    // Optimistic UI
    final updated = [...state];
    updated[index] = n.copyWith(isRead: true);
    state = updated;

    final pid = _patientId();
    if (n.id == null || pid == null) return;
    try {
      final api = _ref.read(apiServiceProvider);
      await api.markNotificationRead({
        'notification_id': n.id,
        'patient_id':      pid,
      });
    } catch (e) {
      if (kDebugMode) debugPrint('markRead failed: $e');
    }
  }

  Future<void> markAllRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    final pid = _patientId();
    if (pid == null) return;
    try {
      final api = _ref.read(apiServiceProvider);
      await api.markAllNotificationsRead(pid);
    } catch (e) {
      if (kDebugMode) debugPrint('markAllRead failed: $e');
    }
  }

  int get unreadCount => state.where((n) => !n.isRead).length;
}

// ─── Provider ─────────────────────────────────────────────────────────────────
final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<NotificationItem>>(
  (ref) => NotificationNotifier(ref),
);
