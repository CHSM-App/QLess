// ─── NOTIFICATIONS SCREEN ────────────────────────────────────────────────────
//
// Server-backed inbox: rows come from sp_notification LIST and are kept in
// sync via the foreground FCM listener (main.dart → loadFromServer). The
// screen handles its own tap routing into appointments / prescription.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/navigation/navigator_key.dart';
import 'package:qless/presentation/patient/providers/notification_provider.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';

// Clinic-wide queue announcements (Doctor Arrived / Queue Paused / Queue
// Paused (Emergency)) carry no per-patient destination — backend mirrors
// them with ref_id=doctor_id|queue_id, so any "open this appointment" deep
// link would silently no-op. Treat them as informational: tap = mark read,
// hide the forward-arrow so the card doesn't falsely advertise a deep link.
// Local palette — this screen no longer depends on the (now removed) AppTheme.
const Color _primary       = Color(0xFF1A73E8);
const Color _textPrimary   = Color(0xFF1A1F36);
const Color _textSecondary = Color(0xFF6B7280);
const Color _textHint      = Color(0xFFADB5BD);

bool _isInformationalQueueAnnouncement(NotificationItem n) {
  if (n.type != 'queue') return false;
  final t = n.title.trim().toLowerCase();
  return t == 'doctor arrived' ||
      t == 'queue paused' ||
      t == 'queue paused (emergency)';
}

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    // Fetch the persisted inbox on open so notifications received while the
    // app was backgrounded / closed are visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(notificationProvider.notifier).loadFromServer();
    });
  }

  // Route each notification to the screen it's about. Tap also marks it read.
  // Cancellation / reschedule notifications jump straight to the "Cancelled"
  // filter so the patient sees the affected appointment and can rebook it.
  //
  // Architecture note: we pop this screen first, then drive the patient
  // shell (PatientBottomNav) via `patientShellKey` instead of pushing
  // standalone routes. Pushing /appointment as a top-level route hides the
  // bottom bar and creates a screen instance outside the shell — switching
  // tabs IN the shell keeps the bottom bar visible and back-stack clean.
  void _handleTap(BuildContext context, NotificationItem n) {
    // Clinic-wide queue announcements have no actionable destination — the
    // tap is just an ack. Returning early leaves the user on the inbox.
    if (_isInformationalQueueAnnouncement(n)) return;

    final titleLower = n.title.toLowerCase();
    // Cancel and reschedule land on DIFFERENT tabs: cancellation goes to
    // the Cancelled tab (status='cancelled' shows there), but reschedule
    // keeps status='reschedule' which the Cancelled filter explicitly
    // excludes — so route reschedule to 'all' where it's visible.
    final isCancel     = titleLower.contains('cancel');
    final isReschedule = titleLower.contains('reschedule');

    // Drop the inbox screen so a back press from the destination lands on
    // the shell (home tab) rather than re-opening notifications.
    Navigator.pop(context);

    switch (n.type) {
      case 'prescription':
        // Inbox row stores prescription_id in ref_id. If present, open the
        // specific prescription detail; otherwise fall back to the list.
        final pid = int.tryParse(n.refId ?? '');
        if (kDebugMode) {
          debugPrint(
            '[NotifInbox] prescription tap → refId="${n.refId}" parsed=$pid '
            '(title="${n.title}")',
          );
        }
        if (pid != null && pid > 0) {
          navigatorKey.currentState
              ?.pushNamed('/prescription-detail', arguments: pid);
        } else {
          navigatorKey.currentState?.pushNamed('/prescription');
        }
        break;
      case 'rating':
        // 'Appointment Complete — review it' notification: jump straight to
        // the review dialog (Practo-style direct action) rather than the
        // detail sheet. ref_id carries appointment_id.
        final ratingApptId = int.tryParse(n.refId ?? '');
        if (ratingApptId != null && ratingApptId > 0) {
          requestAppointmentsRatingDialog(ratingApptId);
        }
        break;
      case 'appointment':
      case 'queue':
        // Inbox row's ref_id is the appointment_id for these types.
        final apptId = int.tryParse(n.refId ?? '');
        patientShellKey.currentState?.openAppointmentsDeepLink(
          filter: isCancel
              ? 'cancelled'
              : isReschedule
                  ? 'all'
                  : null,
          appointmentId: (apptId != null && apptId > 0) ? apptId : null,
        );
        break;
      default:
        // 'general' or unknown — stay on the inbox (already popped above —
        // user lands on shell home, acceptable).
        break;
    }
  }

  // Group into Today / Yesterday / Earlier buckets so the list feels paced
  // even when there are many rows.
  Map<String, List<MapEntry<int, NotificationItem>>> _grouped(
      List<NotificationItem> list) {
    final now       = DateTime.now();
    final today     = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final groups = <String, List<MapEntry<int, NotificationItem>>>{
      'Today':     [],
      'Yesterday': [],
      'Earlier':   [],
    };

    for (var i = 0; i < list.length; i++) {
      final n = list[i];
      final d = DateTime(n.receivedAt.year, n.receivedAt.month, n.receivedAt.day);
      if (d == today) {
        groups['Today']!.add(MapEntry(i, n));
      } else if (d == yesterday) {
        groups['Yesterday']!.add(MapEntry(i, n));
      } else {
        groups['Earlier']!.add(MapEntry(i, n));
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final notifications = ref.watch(notificationProvider);
    final unread        = notifications.where((n) => !n.isRead).length;
    final groups        = _grouped(notifications);

    final bgColor = isDark
        ? const Color(0xFF0F172A)
        : const Color(0xFFF8FAFC);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 16,
        title: Row(
          children: [
            Text(
              'Notifications',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: isDark ? Colors.white : _textPrimary,
              ),
            ),
            if (unread > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (unread > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: () =>
                    ref.read(notificationProvider.notifier).markAllRead(),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('Read all'),
                style: TextButton.styleFrom(
                  foregroundColor: _primary,
                  textStyle: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: _primary,
        onRefresh: () =>
            ref.read(notificationProvider.notifier).loadFromServer(),
        child: notifications.isEmpty
            ? const _EmptyState()
            : ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  for (final entry in groups.entries)
                    if (entry.value.isNotEmpty) ...[
                      _SectionLabel(label: entry.key, isDark: isDark),
                      for (final pair in entry.value)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _NotificationCard(
                            item: pair.value,
                            isDark: isDark,
                            onTap: () {
                              ref
                                  .read(notificationProvider.notifier)
                                  .markRead(pair.key);
                              _handleTap(context, pair.value);
                            },
                          ),
                        ),
                      const SizedBox(height: 10),
                    ],
                ],
              ),
      ),
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.isDark});
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w800,
          color: isDark ? Colors.white54 : _textSecondary,
        ),
      ),
    );
  }
}

// ─── Compact card ────────────────────────────────────────────────────────────
class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.item,
    required this.isDark,
    required this.onTap,
  });
  final NotificationItem item;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final unread = !item.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: item.color.withValues(alpha: 0.08),
        highlightColor: item.color.withValues(alpha: 0.04),
        child: Ink(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: unread
                  ? _primary.withValues(alpha: 0.25)
                  : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
              width: unread ? 1.2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : _textPrimary,
                              height: 1.25,
                            ),
                          ),
                        ),
                        if (unread) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 5),
                            decoration: const BoxDecoration(
                              color: _primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: isDark
                            ? Colors.white60
                            : _textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule_rounded,
                          size: 12,
                          color: isDark
                              ? Colors.white38
                              : _textHint,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          item.timeAgo,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white38
                                : _textHint,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        if (item.type != 'general' &&
                            !_isInformationalQueueAnnouncement(item))
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: isDark
                                ? Colors.white38
                                : _textHint,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 140),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              size: 42,
              color: _primary,
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Center(
          child: Text(
            'No notifications yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Updates about your appointments, queue, and prescriptions will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                color: _textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
