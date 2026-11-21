part of '../patient_home_screen.dart';

class _ApptCardState extends State<_ApptCard> with TickerProviderStateMixin {
  /// Drives the NOW ring's sweep so it glides to the new fraction when the
  /// queue advances instead of snapping.
  late AnimationController _ringCtrl;
  late Animation<double> _ringSweep;

  /// Drives the whole-card "your turn" pulse: a continuous scale + glow
  /// breathe, the same motion the doctor screen uses on a recall badge.
  late AnimationController _turnCtrl;

  /// True once the doctor has recalled this patient (they were called, missed
  /// it, and are being called again), which swaps the glow from teal to amber.
  bool _isRecallAlert = false;

  bool _arrivedSending = false;
  bool _arrivedSent = false;

  /// serving/total as a 0–1 fraction, guarding against a null or zero total.
  double get _queueProgress {
    final appt = widget.appointment;
    final total = appt.totalQueue ?? 0;
    if (total <= 0) return 0;
    final serving = widget.currentServingOverride ?? appt.currentServing ?? 0;
    return (serving / total).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    // Fill the ring from empty to the current fraction on first paint.
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ringSweep = Tween<double>(
      begin: 0,
      end: _queueProgress,
    ).animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic));
    _ringCtrl.forward();

    // Continuous breathe, mirroring _ArrivedBlinkBadge on the doctor home
    // screen (850ms, repeat(reverse: true), scale + glow). The doctor sees
    // that pulse on the patient they need to recall; the patient sees the same
    // pulse on the card they need to act on, so one motion means "you're up"
    // on both sides of the app. It keeps breathing until the turn is over.
    _turnCtrl = AnimationController(vsync: this, duration: _kTurnPulsePeriod);

    // Mounting straight into a live turn means the patient is seeing this card
    // for the first time in that state — opening the app on a call, or
    // returning to this tab — so it buzzes. Repeat buzzing on every socket
    // refresh is prevented by the ValueKey at the call site, which keeps this
    // State alive across refetches instead of remounting it.
    if (widget.appointment.isMyTurn == true) _startTurnPulse();
  }

  /// Buzz pattern marking the moment the turn arrives. Deliberately much
  /// louder than the single taps used for ordinary button feedback: this is
  /// the one alert the patient cannot afford to miss, and it has to carry
  /// through a pocket or a bag. Four heavy pulses for a first call, six for a
  /// recall — the extra length is what makes "again" recognisable without
  /// looking at the screen.
  void _turnBuzz({required bool isRecall}) {
    // ~110ms apart reads as one continuous burst rather than separate taps.
    const gap = Duration(milliseconds: 110);
    final pulses = isRecall ? 6 : 4;

    for (var i = 0; i < pulses; i++) {
      Future.delayed(gap * i, () {
        if (!mounted) return;
        // Alternate heavy/medium so the burst has texture instead of being a
        // flat rumble the hand stops noticing partway through.
        if (i.isEven) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
      });
    }
  }

  /// Fires one heavy pulse per breathe cycle so the phone keeps buzzing for
  /// as long as the turn stays active, instead of going silent after the
  /// initial burst. Hooked to _turnCtrl's forward-start so it repeats in
  /// lockstep with the visible pulse rather than running its own timer.
  void _onTurnCycle(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Starts (or re-marks) the continuous pulse and buzzes once. Called when
  /// the turn arrives and again on each doctor recall; the recall only flips
  /// the glow colour, leaving the controller running so the breathe never
  /// visibly restarts.
  void _startTurnPulse({bool isRecall = false}) {
    _turnBuzz(isRecall: isRecall);
    if (_isRecallAlert != isRecall) {
      setState(() => _isRecallAlert = isRecall);
    }
    if (!_turnCtrl.isAnimating) {
      _turnCtrl.addStatusListener(_onTurnCycle);
      _turnCtrl.repeat(reverse: true);
    }
  }

  /// True only for a genuine doctor recall: the serving number actually moved
  /// AND now points at this patient's own token.
  ///
  /// Without the "points at my token" half, this returned true every time the
  /// queue advanced for anyone else — and since the socket refetches the whole
  /// appointment list on every event, that buzzed the phone over and over
  /// while the patient simply sat on their turn.
  bool _isRecallOf(
    _ApptCard old,
    AppointmentList prev,
    AppointmentList curr,
  ) {
    final myToken = curr.myQueueNumber ?? curr.queueNumber;
    if (myToken == null) return false;

    // Socket override wins when present — it lands before the refetch does.
    final prevServing = old.currentServingOverride ?? prev.currentServing;
    final currServing = widget.currentServingOverride ?? curr.currentServing;

    return currServing != prevServing && currServing == myToken;
  }

  /// Turn is over (doctor completed or moved on) — settle back to a still card.
  void _stopTurnPulse() {
    if (!_turnCtrl.isAnimating) return;
    _turnCtrl.removeStatusListener(_onTurnCycle);
    _turnCtrl.stop();
    _turnCtrl.value = 0;
    if (_isRecallAlert) setState(() => _isRecallAlert = false);
  }

  Future<void> _handleMarkArrived() async {
    if (widget.onMarkArrived == null || _arrivedSending || _arrivedSent) return;
    setState(() => _arrivedSending = true);
    final ok = await widget.onMarkArrived!();
    if (!mounted) return;
    setState(() {
      _arrivedSending = false;
      if (ok) _arrivedSent = true;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not notify the clinic. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(_ApptCard old) {
    super.didUpdateWidget(old);
    final prev = old.appointment;
    final curr = widget.appointment;
    if (curr.currentServing != prev.currentServing ||
        curr.totalQueue != prev.totalQueue ||
        curr.isMyTurn != prev.isMyTurn) {
      // Sweep the ring from wherever it is now to the new fraction.
      _ringSweep = Tween<double>(
        begin: _ringSweep.value,
        end: _queueProgress,
      ).animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic));
      _ringCtrl.forward(from: 0);
    }
    // Turn just arrived → start the pulse.
    if (curr.isMyTurn == true && prev.isMyTurn != true) {
      _startTurnPulse();
    }
    // Doctor recall: the turn was already true and the doctor called this
    // patient again. isMyTurn never flips, so the check above can't catch it.
    //
    // The serving number must have changed AND landed back on this patient's
    // own token — that combination only happens on a real recall. Reacting to
    // any serving change would buzz every time the queue moved for someone
    // else, because the socket refetches the whole list on every event.
    else if (curr.isMyTurn == true &&
        prev.isMyTurn == true &&
        _isRecallOf(old, prev, curr)) {
      _startTurnPulse(isRecall: true);
    }
    // Turn is over → stop pulsing.
    else if (curr.isMyTurn != true && prev.isMyTurn == true) {
      _stopTurnPulse();
    }
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _turnCtrl.dispose();
    super.dispose();
  }

  // Text uses the neutral ink rather than a tint of the background, so the
  // message stays legible and the colour is carried by the fill, icon and
  // border instead of a same-hue-on-same-hue pairing.
  Widget _buildQueueBanner(String event, {Widget? trailing}) {
    final (
      Color bg,
      Color fg,
      Color iconColor,
      Color border,
      IconData icon,
      String text,
    ) = switch (event) {
      'queue_started' => (
        kGreenLight,
        kBannerInk,
        kSuccessDark,
        kSuccess.withValues(alpha: 0.35),
        Icons.play_circle_fill_rounded,
        'Queue is live',
      ),
      'queue_paused' => (
        kAmberLight,
        kBannerInk,
        kWarningDark,
        kWarning.withValues(alpha: 0.35),
        Icons.pause_circle_outline_rounded,
        'Queue paused temporarily',
      ),
      'queue_paused_emergency' => (
        kRedLight,
        kBannerInk,
        kErrorDark,
        kError.withValues(alpha: 0.35),
        Icons.warning_amber_rounded,
        'Emergency break • queue on hold',
      ),
      'queue_stopped' => (
        const Color(0xFFF7F8FA),
        kTextSecondary,
        kTextMuted,
        kBorder,
        Icons.stop_circle_outlined,
        'Queue stopped for today',
      ),
      _ => (
        kPrimaryLight,
        kBannerInk,
        kPrimary,
        kPrimary.withValues(alpha: 0.2),
        Icons.info_outline_rounded,
        event,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    return dt == null ? raw : DateFormat('d MMM yyyy').format(dt);
  }

  String _fmtClockTime(String? raw) {
    final parsed = _timeTodayFromRaw(raw);
    if (parsed != null) return DateFormat('h:mm a').format(parsed);
    final value = raw?.trim();
    return value == null || value.isEmpty ? '--' : value;
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;
    final name = appt.doctorName ?? 'Doctor';
    final spec = appt.specialization ?? '';
    final dateStr = _fmtDate(appt.appointmentDate);
    final isSlot = appt.bookingType == 2;
    final timeStr = isSlot
        ? () {
            final start = _fmtClockTime(appt.startTime);
            final end = _fmtClockTime(appt.endTime);
            return (end.isNotEmpty && end != '--') ? '$start – $end' : start;
          }()
        : 'Est. ${_fmtClockTime(appt.estimatedArrivalTime)}';

    final myToken = appt.myQueueNumber ?? appt.queueNumber;
    final totalQ = appt.totalQueue;
    final isSkipped = appt.queueState?.toLowerCase() == 'skipped';
    final isMyTurn = appt.isMyTurn ?? false;
    // Socket override is always fresher than the SP value.
    // Sanitize: when no socket data is available yet, the SP echoes the
    // patient's own queue_number as current_serving (SP bug). Discard it so
    // we show nothing rather than a misleading value.
    final rawServing = widget.currentServingOverride ?? appt.currentServing;
    final serving =
        (widget.currentServingOverride == null &&
            rawServing != null &&
            rawServing == myToken &&
            !isMyTurn)
        ? null
        : rawServing;
    // Show queue row (QUEUE NO. chip + badges) for today when token exists OR skipped.
    // The Skipped badge lives inside this row so it must show even when SP returns
    // null for my_queue_number (which happens for skipped patients).
    final showQueueSection = widget.isToday && (myToken != null || isSkipped);
    // NOW circle: hide when serving is unknown (null) to avoid showing stale/wrong data.
    final showQueue = widget.isToday && myToken != null && serving != null;

    // Derive effective queue event (socket live OR API cold-start)
    String? queueEvent = widget.queueEvent;
    if (queueEvent == null && widget.isToday && appt.bookingType == 1) {
      if (appt.queueStarted == true) queueEvent = 'queue_started';
    }
    final showBanner = widget.isToday && queueEvent != null;

    // Cancellable states mirror _canCancel in the appointments screen so both
    // surfaces offer the action on exactly the same appointments.
    final apptStatus = appt.status?.toLowerCase();
    final canCancel =
        widget.onCancel != null &&
        appt.appointmentId != null &&
        (apptStatus == 'upcoming' ||
            apptStatus == 'booked' ||
            apptStatus == 'confirmed');

    // Status badge — rides along in the queue banner when one is showing,
    // otherwise it gets its own row above the doctor block. Only the
    // actionable states get one; a plain "Today" chip said nothing the date
    // row below didn't already say, so there is no badge in that case.
    final Widget? statusBadge = isMyTurn
        // Static badge. The pulse lives on the card as a whole (see the
        // wrapper at the end of build), so animating this chip too would
        // compound into two motions at once.
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isRecallAlert ? kWarning : kPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 12,
                ),
                SizedBox(width: 4),
                Text(
                  'Your Turn!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        : isSkipped
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: kError,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_rounded, color: Colors.white, size: 11),
                SizedBox(width: 4),
                Text(
                  'Skipped',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        : null;

    Color borderColor;
    double borderWidth;
    if (isMyTurn) {
      borderColor = kPrimary;
      borderWidth = 2;
    } else if (isSkipped) {
      borderColor = kError;
      borderWidth = 2;
    } else if (queueEvent == 'queue_paused_emergency') {
      borderColor = kError;
      borderWidth = 2;
    } else if (queueEvent == 'queue_paused') {
      borderColor = kWarning;
      borderWidth = 1.8;
    } else if (queueEvent == 'queue_started' || widget.isNext) {
      borderColor = kPrimary;
      borderWidth = 1.8;
    } else {
      borderColor = kBorder;
      borderWidth = 1;
    }

    // Built directly rather than inside an AnimatedBuilder: nothing in the
    // card body ticks every frame any more, so a per-frame rebuild would be
    // pure waste. The two things that do animate (the NOW ring sweep and the
    // "your turn" pulse) own their own builders further down.
    final card = Container(
      decoration: _neoBox(
        radius: 14,
        border: borderWidth > 1
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Queue status banner (live socket event) ──────────
          if (showBanner)
            _buildQueueBanner(
              queueEvent,
              trailing: showQueueSection ? statusBadge : null,
            ),

          // ── Doctor offline warning ───────────────────────────
          if (widget.doctorOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kWarning.withValues(alpha: 0.12),
                // Only round top corners when no queue banner sits above this strip.
                borderRadius: showBanner
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(
                  bottom: BorderSide(color: kWarning.withValues(alpha: 0.3)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 13, color: kWarning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${doctorDisplayName(appt.doctorName)} has a network connection issue. Please come at your estimated time.',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kWarning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ── TOP ROW: status badge, only when no banner carries it ──
          if (showQueueSection && !showBanner && statusBadge != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Row(children: [const Spacer(), statusBadge]),
            ),
            // Hairline between the badge row and the doctor block.
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Divider(color: kDivider, height: 1, thickness: 1),
            ),
          ],

          // ── MAIN ROW: Avatar + Info + NOW badge ─────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Queue token takes the avatar's slot when this
                  // appointment has one; otherwise fall back to the
                  // specialty icon (slot bookings, future dates).
                  if (showQueueSection && myToken != null)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: kPrimary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'QUEUE',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: kPrimaryDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            myToken.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: kPurple,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _doctorAvatar(spec, size: 48),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorDisplayName(name),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (spec.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            spec,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                        if ((appt.clinicName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: kPrimary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  appt.clinicName ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if ((appt.patientName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 12,
                                color: kPrimary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  appt.patientName ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextSecondary,
                                    fontWeight: FontWeight.w500,
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

                  // NOW badge (queue live indicator)
                  if (showQueue) ...[
                    const SizedBox(width: 10),
                    const VerticalDivider(
                      color: kDivider,
                      width: 1,
                      thickness: 1,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Plain progress ring — the circle and its text never
                        // scale, pulse or blink. Only the arc moves, and only
                        // when the queue actually advances (see _ringSweep),
                        // so the numbers stay readable at all times.
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _ringSweep,
                              builder: (context, child) => CustomPaint(
                                size: const Size(53, 53),
                                painter: _QueueRingPainter(
                                  progress: _ringSweep.value,
                                  color: kPrimary,
                                  trackColor: kPrimary.withValues(alpha: 0.18),
                                  strokeWidth: 3,
                                ),
                                child: child,
                              ),
                              child: SizedBox(
                                width: 53,
                                height: 53,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'NOW',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: kTextSecondary,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    Text(
                                      '$serving/${totalQ ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary,
                                        height: 1.15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (queueEvent == 'queue_started') ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: kPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'live',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: kTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── BOTTOM ROW: date • time, with cancel on the right ──
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Divider(color: kDivider, height: 1, thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: canCancel
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: kPrimary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            dateStr,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const VerticalDivider(
                          color: kDivider,
                          width: 1,
                          thickness: 1,
                        ),
                        const SizedBox(width: 9),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: kPrimary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            timeStr,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Icon-only cancel. The label is dropped to keep the row
                  // on one line, so the button carries a tooltip and a
                  // semantics label for anyone who can't read the icon.
                  if (canCancel) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Cancel appointment',
                      child: GestureDetector(
                        onTap: widget.onCancel,
                        child: Semantics(
                          button: true,
                          label: 'Cancel appointment',
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: kRedLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: kError.withValues(alpha: 0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: kError,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── "I've Arrived at Clinic" — only for skipped patients ────
          if (isSkipped && widget.onMarkArrived != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: (appt.isArrived == true || _arrivedSent)
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: kPrimary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kPrimary.withValues(alpha: 0.25)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: kPrimary,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Doctor notified — you are marked as arrived',
                            style: TextStyle(
                              color: kPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: _arrivedSending ? null : _handleMarkArrived,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: kError,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _arrivedSending
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "I've Arrived at Clinic",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
            ),
        ],
      ),
    );

    if (!isMyTurn) return card;

    // "Your turn" → the card breathes on the same 850ms reversing loop the
    // doctor screen uses for its Recall button. No coloured glow: the teal
    // halo bled out around the card and read as a stray green shadow, so the
    // motion alone carries the alert. State is still visible when the card is
    // at rest via the 2px accent border and the "Your Turn!" badge.
    // The scale is 1.02 rather than the badge's 1.10 because this is a
    // full-width card — a 10% swell would shove the rows below it around.
    return AnimatedBuilder(
      animation: _turnCtrl,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + 0.02 * _turnCtrl.value,
        child: child,
      ),
      child: card,
    );
  }
}
