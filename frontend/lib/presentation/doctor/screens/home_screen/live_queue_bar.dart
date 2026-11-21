part of '../home_screen.dart';

// Moved verbatim from _QueueHomePageState (F1 split); an extension so these
// builders keep using the state's fields. None of them calls setState.
extension _LiveQueueBarView on _QueueHomePageState {
  Widget _buildOfflineNoTodayData() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCardBorder),
      ),
      child: const Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.wifi_off_rounded, color: kTextSecondary, size: 26),
        SizedBox(height: 10),
        Text("Today's sessions aren't downloaded yet",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        SizedBox(height: 4),
        Text('Connect to the internet once to load today\'s sessions. '
            'After that you can keep working offline.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.35)),
      ]),
    );
  }

  Widget _buildNoLiveSessions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: kPrimaryLight, shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF9FE1CB)),
          ),
          child: const Icon(Icons.event_busy_rounded, color: kPrimaryDark, size: 22),
        ),
        const SizedBox(height: 10),
        const Text('No Schedule for Today',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(height: 4),
        const Text('Set your weekly availability to start accepting patients.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.35)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => DoctorAvailabilityPage(clinicId: _clinicId))),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kPrimaryDark,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.calendar_today_rounded, color: Colors.white, size: 13),
              SizedBox(width: 6),
              Text('Set Schedule',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }

Widget _buildAwaitingBookingsState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: kPrimaryLight, shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF9FE1CB)),
          ),
          child: const Icon(Icons.hourglass_empty_rounded, color: kPrimaryDark, size: 22),
        ),
        const SizedBox(height: 10),
        const Text('No Appointments Yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(height: 4),
        const Text(
          'Your schedule is live for today, but no patients have booked yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.35),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BADGES, CHIPS, HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _queueStateBadge(QueueState state) {
    late String label;
    late Color bg, fg, dot;
    switch (state) {
      case QueueState.running:
        label = 'Live'; bg = kPrimaryLight; fg = kPrimaryDark; dot = kPrimary; break;
      case QueueState.paused:
        label = 'Paused';  bg = kAmberLight;   fg = kAmberDark;   dot = kAmber;   break;
      case QueueState.stopped:
        label = 'Closed';
        bg = const Color(0xFFF1F5F9); fg = const Color(0xFF64748B); dot = const Color(0xFF94A3B8);
        break;
      case QueueState.idle:
        label = 'Idle'; bg = kRedLight; fg = kRedDark; dot = kRed; break;
    }
    return _badgeDot(label, bg, fg, dot);
  }

  Widget _badgeDot(String label, Color bg, Color fg, Color dot) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: dot.withValues(alpha: 0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 0.2, color: fg)),
    ]),
  );
}
