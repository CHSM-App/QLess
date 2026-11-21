part of '../home_screen.dart';

class _HomeSessionFullscreenPageState
    extends ConsumerState<_HomeSessionFullscreenPage> {
  static const List<(Color, Color, Color)> _kAvatarPalettes = [
    (Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF085041)),
    (Color(0xFFEDE9FE), Color(0xFFDDD6FE), Color(0xFF4C1D95)),
    (Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFF78350F)),
    (Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFF7F1D1D)),
  ];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  int? _calcAge(String? dob) {
    if (dob == null) return null;
    final bd = DateTime.tryParse(dob);
    if (bd == null) return null;
    final now = DateTime.now();
    int age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.slotLabel ?? 'Session ${widget.sessionIndex + 1}';
    final pts = widget.sessionPts;
    final waiting = pts
        .where((p) => ['booked', 'in_progress', 'skipped']
            .contains(p.status?.toLowerCase()))
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final completed = pts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'completed')
        .toList();

    return Scaffold(
      backgroundColor: kPageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Compact header ─────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close_fullscreen_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                  color: kTextSecondary,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary),
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                _queueStateBadge(widget.queueState),
                const SizedBox(width: 12),
              ]),
            ),
            const Divider(height: 1, color: kBorder),
            // ── Scrollable body ────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildLiveQueueBar(),
                  if (waiting.isEmpty && completed.isEmpty)
                    _buildEmptyState()
                  else ...[
                    if (waiting.isNotEmpty) ...[
                      _sectionLabel('Waiting', waiting.length, kPrimary,
                          kPrimaryLight, kPrimaryDark),
                      const SizedBox(height: 8),
                      ...waiting.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildPatientCard(p),
                          )),
                    ],
                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _sectionLabel('Completed', completed.length, kGreen,
                          kGreenLight, kGreenDark),
                      const SizedBox(height: 8),
                      ...completed.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildCompletedCard(p),
                          )),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveQueueBar() {
    if (widget.queueState == QueueState.stopped) return const SizedBox.shrink();
    final isRunning = widget.queueState == QueueState.running;
    final isPaused = widget.queueState == QueueState.paused;
    final pts = widget.sessionPts;
    final ip = pts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'in_progress')
        .firstOrNull;
    final booked = pts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final current = ip ?? booked.firstOrNull;
    final next = ip != null
        ? booked.firstOrNull
        : (booked.length > 1 ? booked[1] : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryLighter,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kPrimaryLight),
        ),
        padding: const EdgeInsets.all(11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _pulseDot(),
            const SizedBox(width: 6),
            const Text('LIVE QUEUE',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: kPrimary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_alt_outlined,
                    size: 10, color: kPrimaryDark),
                const SizedBox(width: 3),
                Text('${pts.length}',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDark)),
              ]),
            ),
            const Spacer(),
            _liveIconBtn(
              icon: isRunning
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: isRunning ? kAmberDark : kPrimaryDark,
              bg: isRunning ? kAmberLight : kPrimaryLight,
              border: isRunning ? kAmberBorder : const Color(0xFF9FE1CB),
              tooltip: isRunning ? 'Pause' : isPaused ? 'Resume' : 'Start',
              onTap: isRunning ? widget.onQueuePause : widget.onQueueStart,
            ),
            if (!widget.isEmergency) ...[
              const SizedBox(width: 5),
              _liveIconBtn(
                icon: Icons.close_rounded,
                color: kRedDark,
                bg: kRedLight,
                border: kRedBorder,
                tooltip: 'Close queue',
                onTap: widget.onQueueStop,
              ),
            ],
            const SizedBox(width: 5),
            _liveIconBtn(
              icon: Icons.warning_amber_rounded,
              color: kPurpleDark,
              bg: kPurpleLight,
              border: kPurpleBorder,
              tooltip: 'Emergency pause',
              onTap: widget.onQueueEmergency,
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _tokBox(
                label: 'CURRENT',
                value: current != null
                    ? (current.queueNumber ?? 0).toString().padLeft(2, '0')
                    : '--',
                isActive: true),
            const SizedBox(width: 5),
            _tokBox(
                label: 'UP NEXT',
                value: next != null
                    ? (next.queueNumber ?? 0).toString().padLeft(2, '0')
                    : '--'),
            const SizedBox(width: 5),
            _tokBox(
                label: 'REMAINING',
                value: pts.length.toString().padLeft(2, '0'),
                isGreen: true),
          ]),
        ]),
      ),
    );
  }

  Widget _buildPatientCard(AppointmentList p) {
    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final qs = widget.queueState;
    final hasIP = widget.sessionHasIP;
    final nextBookedQNo = widget.sessionNextQNo;
    final name = p.patientName ?? 'Patient';
    final initials = _initials(name);
    final age = _calcAge(p.dob);
    final status = p.status?.toLowerCase().trim() ?? '';
    final isIP = status == 'in_progress';
    final isSkipped = status == 'skipped';
    final isBooked = status == 'booked';
    final queueActive = qs == QueueState.running || qs == QueueState.paused;

    bool accessible = false;
    if (isIP) {
      accessible = true;
    } else if (isSkipped) {
      accessible = true;
    } else if (queueActive && isBooked) {
      accessible = !hasIP && p.queueNumber == nextBookedQNo;
    }
    final effectiveAccessible = isSkipped ? accessible : queueActive && accessible;
    final VoidCallback? effectiveSkip =
        isBooked && queueActive && (isReceptionist || accessible)
            ? () => widget.onSkip(p)
            : null;

    final (avBg, avBd, avFg) =
        _kAvatarPalettes[(p.queueNumber ?? 0) % _kAvatarPalettes.length];
    final Color borderColor =
        isIP ? kPrimary : isSkipped ? kAmber : kCardBorder;

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor, width: (isIP || isSkipped) ? 1.5 : 1.0),
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: avBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: avBd)),
            alignment: Alignment.center,
            child: Text(initials,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: avFg)),
          ),
          const SizedBox(width: 9),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                        height: 1.15),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(
                    [
                      if (p.gender != null) p.gender!,
                      if (age != null) '$age yrs'
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500)),
                if (isIP || isSkipped) ...[
                  const SizedBox(height: 3),
                  _statusChip(status),
                ],
              ])),
          if (p.queueNumber != null) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
              decoration: BoxDecoration(
                  color: avBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: avBd)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('TOKEN',
                        style: TextStyle(
                            fontSize: 8,
                            color: kTextMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 1),
                    Text(
                        (p.queueNumber ?? 0).toString().padLeft(2, '0'),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: avFg,
                            height: 1)),
                  ]),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Row(children: [
          if (effectiveSkip != null) ...[
            Expanded(
                child: GestureDetector(
              onTap: effectiveSkip,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: kRedLight,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: kRedBorder)),
                alignment: Alignment.center,
                child: const Text('Skip',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kRedDark)),
              ),
            )),
            if (!isReceptionist) const SizedBox(width: 7),
          ],
          if (!isReceptionist)
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: effectiveAccessible
                    ? () => widget.onStartSession(p)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: effectiveAccessible
                        ? kPrimaryDark
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isIP
                        ? 'Continue'
                        : isSkipped
                            ? 'Recall'
                            : 'Start Session',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: effectiveAccessible ? Colors.white : kTextMuted,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _buildCompletedCard(AppointmentList p) {
    final name = p.patientName ?? 'Patient';
    final initials = _initials(name);
    final age = _calcAge(p.dob);
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: kGreenLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGreenBorder)),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kGreenDark)),
          ),
          const SizedBox(width: 9),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                        height: 1.15),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(
                    [
                      if (p.gender != null) p.gender!,
                      if (age != null) '$age yrs'
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500)),
              ])),
        ]),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => widget.onPrescription(p),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: kPurpleLight,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kPurpleBorder)),
            alignment: Alignment.center,
            child: const Text('View Prescription',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kPurpleDark)),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptyState() => Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: kPrimaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF9FE1CB))),
            child:
                const Icon(Icons.inbox_rounded, color: kPrimaryDark, size: 22),
          ),
          const SizedBox(height: 10),
          const Text('No patients today',
              style: TextStyle(
                  color: kTextMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _sectionLabel(String label, int count, Color accent, Color accentLight,
          Color accentDark) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: accentLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withValues(alpha: 0.25))),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentDark)),
          ),
        ]),
      );

  Widget _queueStateBadge(QueueState state) {
    late String label;
    late Color bg, fg, dot;
    switch (state) {
      case QueueState.running:
        label = 'Running';
        bg = kPrimaryLight;
        fg = kPrimaryDark;
        dot = kPrimary;
        break;
      case QueueState.paused:
        label = 'Paused';
        bg = kAmberLight;
        fg = kAmberDark;
        dot = kAmber;
        break;
      case QueueState.stopped:
        label = 'Closed';
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        dot = const Color(0xFF94A3B8);
        break;
      case QueueState.idle:
        label = 'Idle';
        bg = kRedLight;
        fg = kRedDark;
        dot = kRed;
        break;
    }
    return _badgeDot(label, bg, fg, dot);
  }

  Widget _statusChip(String status) {
    Color bg, fg, dot;
    switch (status.toLowerCase()) {
      case 'in_progress':
        bg = kPrimaryLight;
        fg = kPrimaryDark;
        dot = kPrimary;
        break;
      case 'skipped':
        bg = kAmberLight;
        fg = kAmberDark;
        dot = kAmber;
        break;
      case 'completed':
        bg = kGreenLight;
        fg = kGreenDark;
        dot = kGreen;
        break;
      default:
        bg = kRedLight;
        fg = kRedDark;
        dot = kRed;
    }
    return _badgeDot(
      status == 'in_progress'
          ? 'In Progress'
          : status[0].toUpperCase() + status.substring(1),
      bg,
      fg,
      dot,
    );
  }

  Widget _badgeDot(String label, Color bg, Color fg, Color dot) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dot.withValues(alpha: 0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: fg)),
        ]),
      );

  Widget _liveIconBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border)),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );

  Widget _tokBox(
          {required String label,
          required String value,
          bool isActive = false,
          bool isGreen = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive
                ? kPrimaryDark
                : isGreen
                    ? kGreenLight
                    : kPrimaryLighter,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? null
                : Border.all(
                    color: isGreen ? kGreenBorder : kPrimaryLight),
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                    color: isActive
                        ? Colors.white.withValues(alpha: 0.75)
                        : isGreen
                            ? kGreenDark
                            : kTextSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: isActive
                        ? Colors.white
                        : isGreen
                            ? kGreenDark
                            : kTextPrimary)),
          ]),
        ),
      );

  Widget _pulseDot() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1.0),
        duration: const Duration(milliseconds: 900),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        onEnd: () => setState(() {}),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
        ),
      );
}
