part of '../patient_home_screen.dart';

// ════════════════════════════════════════════════════════════════════
//  SECTION TITLE
// ════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(
            action!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kPrimary,
            ),
          ),
        ),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════
//  QUICK TILE
//  Simple flat icon + label tile — replaces the old animated "highlighted"
//  quick action card now that booking has its own hero banner above.
// ════════════════════════════════════════════════════════════════════
class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: _neoBox(radius: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  EMPTY NOTE
// ════════════════════════════════════════════════════════════════════
class _EmptyNote extends StatelessWidget {
  final String message;
  const _EmptyNote(this.message);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: kPrimaryLight.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kPrimary.withValues(alpha: 0.15)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.calendar_today_rounded, size: 13, color: kPrimary),
        const SizedBox(width: 6),
        Text(
          message,
          style: const TextStyle(fontSize: 12, color: kTextSecondary),
        ),
      ],
    ),
  );
}

// // ════════════════════════════════════════════════════════════════════
// //  TOP DOCTOR CARD
// // ════════════════════════════════════════════════════════════════════
// class _TopDoctorCard extends StatelessWidget {
//   final DoctorDetails doctor;
//   final double? cardRating;
//   final VoidCallback onTap;
//   const _TopDoctorCard({required this.doctor, required this.onTap, this.cardRating});

//   @override
//   Widget build(BuildContext context) {
//     final name = doctor.name?.trim();
//     final spec = doctor.specialization?.trim();
//     final clinic = doctor.clinicName?.trim();
//     final rating = (cardRating != null && cardRating! > 0) ? cardRating : null;

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: _neoBox(radius: 12),
//         child: Row(
//           children: [
//             _doctorAvatar(spec, size: 42),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Dr. ${name?.isNotEmpty == true ? name : 'Doctor'}',
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontSize: 13,
//                       fontWeight: FontWeight.w700,
//                       color: kTextPrimary,
//                     ),
//                   ),
//                   if (spec != null && spec.isNotEmpty) ...[
//                     const SizedBox(height: 2),
//                     Text(
//                       spec,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 11,
//                         color: kTextSecondary,
//                       ),
//                     ),
//                   ],
//                   if (clinic != null && clinic.isNotEmpty) ...[
//                     const SizedBox(height: 2),
//                     Text(
//                       clinic,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 10,
//                         color: kTextMuted,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//             if (rating != null)
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//                 decoration: BoxDecoration(
//                   color: kAmberLight,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: kWarning.withValues(alpha: 0.25)),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(Icons.star_rounded, size: 12, color: kWarning),
//                     const SizedBox(width: 4),
//                     Text(
//                       rating.toStringAsFixed(1),
//                       style: const TextStyle(
//                         fontSize: 10,
//                         fontWeight: FontWeight.w700,
//                         color: kWarning,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _TopDoctorSkeletonCard extends StatelessWidget {
//   const _TopDoctorSkeletonCard();

//   @override
//   Widget build(BuildContext context) => Container(
//         padding: const EdgeInsets.all(12),
//         decoration: _neoBox(radius: 12),
//         child: Row(
//           children: const [
//             _Shimmer(width: 42, height: 42),
//             SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _Shimmer(width: 140, height: 11),
//                   SizedBox(height: 5),
//                   _Shimmer(width: 100, height: 10),
//                   SizedBox(height: 5),
//                   _Shimmer(width: 120, height: 9),
//                 ],
//               ),
//             ),
//             SizedBox(width: 8),
//             _Shimmer(width: 32, height: 22),
//           ],
//         ),
//       );
// }

class _TopDoctorCard extends StatelessWidget {
  final DoctorDetails doctor;
  final double? cardRating;
  final VoidCallback onTap;
  const _TopDoctorCard({
    required this.doctor,
    required this.onTap,
    this.cardRating,
  });

  @override
  Widget build(BuildContext context) {
    final name = doctor.name?.trim();
    final spec = doctor.specialization?.trim();
    final rating = (cardRating != null && cardRating! > 0) ? cardRating : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        decoration: _neoBox(radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _doctorAvatar(spec, size: 56),
                if (rating != null)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kWarning,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              doctorDisplayName(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
              ),
            ),
            if (spec != null && spec.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                spec,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: kPrimaryDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopDoctorSkeletonCard extends StatelessWidget {
  const _TopDoctorSkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
    width: 132,
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
    decoration: _neoBox(radius: 16),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(child: _Shimmer(width: 56, height: 56)),
        SizedBox(height: 10),
        _Shimmer(width: 90, height: 11),
        SizedBox(height: 6),
        _Shimmer(width: 70, height: 9),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  QUEUE PROGRESS RING
//  Draws the NOW circle's outline as a progress arc: a faint full track
//  plus a solid sweep covering serving/total of the circle, starting at
//  12 o'clock and filling clockwise as the queue advances.
// ════════════════════════════════════════════════════════════════════
class _QueueRingPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _QueueRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_QueueRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

// ── "Your turn" pulse ──────────────────────────────────────────────
// Matches _ArrivedBlinkBadge on the doctor home screen so the same motion
// means the same thing on both sides: 850ms, reversing, scale + glow.
const _kTurnPulsePeriod = Duration(milliseconds: 850);

// ════════════════════════════════════════════════════════════════════
//  APPOINTMENT CARD
// ════════════════════════════════════════════════════════════════════
class _ApptCard extends StatefulWidget {
  final AppointmentList appointment;
  final bool isToday;
  final bool isNext;
  final bool doctorOffline;
  final String? queueEvent;

  /// Real current_serving from socket events — used for skipped patients where
  /// the SP echoes their own token instead of the actual serving number.
  final int? currentServingOverride;

  /// Called when the patient taps "I've Arrived at Clinic" after being
  /// skipped. Returns true on success so the card can show a confirmation.
  final Future<bool> Function()? onMarkArrived;

  /// Called when the patient confirms cancelling this appointment. The parent
  /// owns the confirm dialog and the refresh, matching the appointments screen.
  final VoidCallback? onCancel;
  const _ApptCard({
    super.key,
    required this.appointment,
    this.isToday = false,
    this.isNext = false,
    this.doctorOffline = false,
    this.queueEvent,
    this.currentServingOverride,
    this.onMarkArrived,
    this.onCancel,
  });
  @override
  State<_ApptCard> createState() => _ApptCardState();
}
