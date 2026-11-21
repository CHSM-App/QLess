part of '../patient_home_screen.dart';

// ════════════════════════════════════════════════════════════════════
//  SPECIALTY CHIP SKELETON
// ════════════════════════════════════════════════════════════════════
class _SpecialtyChipSkeleton extends StatefulWidget {
  @override
  State<_SpecialtyChipSkeleton> createState() => _SpecialtyChipSkeletonState();
}

class _SpecialtyChipSkeletonState extends State<_SpecialtyChipSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: _neoBox(radius: 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: Alignment(_anim.value - 1, 0),
                end: Alignment(_anim.value + 1, 0),
                colors: const [
                  Color(0xFFEDF2F7),
                  Color(0xFFE2E8F0),
                  Color(0xFFCBD5E0),
                  Color(0xFFE2E8F0),
                  Color(0xFFEDF2F7),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _Shimmer(width: 40, height: 8),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  APPOINTMENT SKELETON CARD
// ════════════════════════════════════════════════════════════════════
class _ApptSkeletonCard extends StatefulWidget {
  const _ApptSkeletonCard();
  @override
  State<_ApptSkeletonCard> createState() => _ApptSkeletonCardState();
}

class _ApptSkeletonCardState extends State<_ApptSkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bar({double? width, required double height}) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value + 1, 0),
          colors: const [
            Color(0xFFEDF2F7),
            Color(0xFFE2E8F0),
            Color(0xFFCBD5E0),
            Color(0xFFE2E8F0),
            Color(0xFFEDF2F7),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      padding: const EdgeInsets.all(12),
      decoration: _neoBox(radius: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment(_anim.value - 1, 0),
                end: Alignment(_anim.value + 1, 0),
                colors: const [
                  Color(0xFFEDF2F7),
                  Color(0xFFCBD5E0),
                  Color(0xFFEDF2F7),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(width: 130, height: 13),
                _bar(width: 90, height: 10),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _bar(width: 70, height: 10),
                    const SizedBox(width: 8),
                    _bar(width: 55, height: 10),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  TODAY APPOINTMENT POPUP
// ════════════════════════════════════════════════════════════════════
class _TodayAppointmentPopup extends StatelessWidget {
  final AppointmentList appointment;
  const _TodayAppointmentPopup({required this.appointment});

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = _timeTodayFromRaw(raw);
    if (parsed != null) return DateFormat('h:mm a').format(parsed);
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final dt = DateTime(
      2000,
      1,
      1,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
    return DateFormat('h:mm a').format(dt);
  }

  String _bookingLabel(int? type) {
    if (type == 2) return 'Slot';
    if (type == 1) return 'Queue';
    return 'Appointment';
  }

  Color _bookingColor(int? type) => type == 2 ? kInfo : kPrimary;

  @override
  Widget build(BuildContext context) {
    final appt = appointment;
    final doctorName = doctorDisplayName(appt.doctorName);
    final spec = appt.specialization ?? '';
    final clinic = appt.clinicName ?? '';
    final isQueue =
        appt.bookingType == 1 ||
        (appt.startTime == null || appt.startTime!.isEmpty);
    final timeStr = isQueue
        ? _fmtTime(appt.estimatedArrivalTime)
        : _fmtTime(appt.startTime);
    final endStr = isQueue ? null : _fmtTime(appt.endTime);
    final myToken = appt.myQueueNumber ?? appt.queueNumber;
    final serving = appt.currentServing;
    final isMyTurn = appt.isMyTurn ?? false;
    final isSkipped = appt.queueState?.toLowerCase() == 'skipped';
    final typeLabel = _bookingLabel(appt.bookingType);
    final typeColor = _bookingColor(appt.bookingType);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      backgroundColor: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 48, 16),
                decoration: const BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today\'s Appointment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You have an appointment today',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _doctorAvatar('cardio', size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctorName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (spec.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  spec,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextSecondary,
                                  ),
                                ),
                              ],
                              if (clinic.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.local_hospital_outlined,
                                      size: 10,
                                      color: kTextMuted,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        clinic,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: kTextMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: typeColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: kBorder, height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.access_time_rounded,
                          label: isQueue ? 'Est. Arrival' : 'Time',
                          value:
                              (endStr != null &&
                                  endStr.isNotEmpty &&
                                  endStr != '—')
                              ? '$timeStr – $endStr'
                              : timeStr,
                          color: kPrimary,
                        ),
                        if (myToken != null) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Your Token',
                            value: myToken.toString().padLeft(2, '0'),
                            color: kPurple,
                          ),
                        ],
                        if (serving != null && serving > 0) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.people_alt_outlined,
                            label: 'Now Serving',
                            value: serving.toString().padLeft(2, '0'),
                            color: kInfo,
                          ),
                        ],
                      ],
                    ),
                    if (isMyTurn) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'It\'s Your Turn!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isSkipped) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: kError,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.block_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'You were skipped — please contact the clinic',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if ((appt.patientName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 12,
                            color: kTextMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'For: ${appt.patientName}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info chip used inside today popup ─────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

// class _SpecialtyPillCard extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final Color color;
//   final VoidCallback onTap;
//   const _SpecialtyPillCard({
//     required this.icon,
//     required this.label,
//     required this.color,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) => GestureDetector(
//         onTap: onTap,
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//           decoration: BoxDecoration(
//             color: color.withValues(alpha: 0.14),
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Row(
//             children: [
//               Container(
//                 width: 34,
//                 height: 34,
//                 decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//                 child: Icon(icon, color: Colors.white, size: 17),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(label,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(
//                         fontSize: 12.5,
//                         fontWeight: FontWeight.w700,
//                         color: color)),
//               ),
//             ],
//           ),
//         ),
//       );
// }

class _SpecialtyPillCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SpecialtyPillCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _neoBox(radius: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SpecialtyPillSkeleton extends StatefulWidget {
  @override
  State<_SpecialtyPillSkeleton> createState() => _SpecialtyPillSkeletonState();
}

class _SpecialtyPillSkeletonState extends State<_SpecialtyPillSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: _neoBox(radius: 16),
    child: Row(
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment(_anim.value - 1, 0),
                end: Alignment(_anim.value + 1, 0),
                colors: const [
                  Color(0xFFEDF2F7),
                  Color(0xFFE2E8F0),
                  Color(0xFFCBD5E0),
                  Color(0xFFE2E8F0),
                  Color(0xFFEDF2F7),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _Shimmer(width: 60, height: 10)),
      ],
    ),
  );
}
