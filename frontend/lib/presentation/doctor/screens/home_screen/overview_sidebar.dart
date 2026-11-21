part of '../home_screen.dart';

// Moved verbatim from _QueueHomePageState (F1 split); an extension so these
// builders keep using the state's fields. None of them calls setState.
extension _OverviewSidebarView on _QueueHomePageState {
  // ─────────────────────────────────────────────────────────────────────────
  // DESKTOP OVERVIEW SIDEBAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverviewSidebar({double width = _kHomeSideWidth}) {
    final vmState = ref.watch(appointmentViewModelProvider);
    final list = vmState.patientAppointmentsList.value ?? <AppointmentList>[];
    final currentClinicId = _clinicId;
    final filteredList = currentClinicId == null
        ? list
        : list.where((a) => a.clinicId == currentClinicId).toList();

    final allSessions = vmState.todayQueueResult?.value ?? [];
    final activeQueueIds = filteredList.map((a) => a.queueId).whereType<int>().toSet();
    final visibleSessions = allSessions
        .where((s) => _shouldShowSession(s, hasBooking: activeQueueIds.contains(s.queueId)))
        .toList()
      ..sort(_bySessionStartTime);

    final compact = width < _kHomeSideWidth;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: kCardBg,
        border: Border(right: BorderSide(color: kBorder)),
      ),
      child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 10 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('OVERVIEW',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2, color: kTextMuted)),
            const SizedBox(height: 12),
            if (visibleSessions.isEmpty)
              _buildSessionOverviewBlock(null, filteredList, compact: compact)
            else
              for (int i = 0; i < visibleSessions.length; i++) ...[
                _buildSessionOverviewBlock(visibleSessions[i], filteredList, compact: compact),
                if (i != visibleSessions.length - 1) const SizedBox(height: 16),
              ],
          ]),
      ),
    );
  }

  Widget _buildSessionOverviewBlock(
      dynamic session, List<AppointmentList> filteredList, {required bool compact}) {
    final queueId = session?.queueId as int?;
    final scoped = queueId == null
        ? filteredList
        : filteredList.where((a) => a.queueId == queueId).toList();

    final total = _todayTotalCount(scoped);
    final waiting = scoped.where((a) {
      final s = a.status?.toLowerCase().trim() ?? '';
      return (s == 'booked' || s == 'in_progress') && _isTodayAppt(a);
    }).length;
    final completed = scoped.where((a) =>
        (a.status?.toLowerCase().trim() ?? '') == 'completed' && _isTodayAppt(a)).length;
    final skipped = scoped.where((a) =>
        (a.status?.toLowerCase().trim() ?? '') == 'skipped' && _isTodayAppt(a)).length;

    final label = session?.startTime != null
        ? '${_fmtTime(session.startTime as String?)} – ${_fmtTime(session.endTime as String?)}'
        : 'Today';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSecondary)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: compact ? 6 : 10,
        mainAxisSpacing: compact ? 6 : 10,
        childAspectRatio: compact ? 0.95 : 1.3,
        children: [
          _homeMiniStat('Total', total, kPrimary, compact: compact),
          _homeMiniStat('Waiting', waiting, kBlueDark, compact: compact),
          _homeMiniStat('Completed', completed, kGreen, compact: compact),
          _homeMiniStat('Skipped', skipped, kAmberDark, compact: compact),
        ],
      ),
    ]);
  }

  Widget _homeMiniStat(String label, int value, Color color, {required bool compact}) => Container(
    padding: EdgeInsets.all(compact ? 8 : 12),
    decoration: BoxDecoration(
      color: kPageBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value', style: TextStyle(fontSize: compact ? 16 : 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 10 : 11, color: kTextSecondary, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SCROLL / LOADING / ERROR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRefreshableScrollView({required List<Widget> slivers}) {
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: _refreshData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  Widget _buildLoadingBody(String doctorName) =>
      _buildRefreshableScrollView(
        slivers: [
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: kPrimary)),
          ),
        ],
      );

  Widget _buildErrorBody(Object e, String doctorName) =>
      _buildRefreshableScrollView(
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: kRedLight, shape: BoxShape.circle,
                    border: Border.all(color: kRedBorder),
                  ),
                  child: const Icon(Icons.error_outline, color: kRed, size: 22),
                ),
                const SizedBox(height: 10),
                Text('$e', style: const TextStyle(color: kTextMuted, fontSize: 12)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _refreshData,
                  style: TextButton.styleFrom(foregroundColor: kPrimary),
                  child: const Text('Retry'),
                ),
              ]),
            ),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER  (dark teal — same solid color, no gradient)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(String doctorName) {
    final initials   = _initials(doctorName);
    final loginState = ref.watch(doctorLoginViewModelProvider);
    final clinicName = loginState.clinicName ?? '';
    // clinicsList is fetched via getDoctorClinics at login + restart → ground truth.
    // phoneCheckResult fallback covers the brief window before clinicsList loads.
    final fromClinics = loginState.clinicsList?.maybeWhen(
          data: (list) => list,
          orElse: () => <DoctorDetails>[],
        ) ??
        <DoctorDetails>[];
    final fromCheck = loginState.phoneCheckResult.maybeWhen(
      data: (list) => list,
      orElse: () => <DoctorDetails>[],
    );
    final allClinics = fromClinics.isNotEmpty ? fromClinics : fromCheck;
    final multiClinic = allClinics.length > 1;
    final isReceptionist = ref.read(tokenProvider).roleId == 3;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF9FE1CB), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: kPrimaryDark, letterSpacing: 0.4,
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            isReceptionist ? doctorName : doctorDisplayName(doctorName),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700,
                              color: kTextPrimary, letterSpacing: -0.3, height: 1.15,
                            ),
                          ),
                        ),
                        if (isReceptionist) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: kPurpleLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: kPurpleBorder),
                            ),
                            child: const Text(
                              'Receptionist',
                              style: TextStyle(
                                fontSize: 9.5, fontWeight: FontWeight.w700,
                                color: kPurpleDark, letterSpacing: 0.2,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (clinicName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: multiClinic
                            ? () => _showClinicPicker(context, allClinics)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: kPrimary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                clinicName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500,
                                  color: kPrimary, height: 1.2,
                                ),
                              ),
                            ),
                            if (multiClinic) ...[
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_drop_down,
                                  size: 15, color: kPrimary),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF9FE1CB)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(
                      color: kPrimary, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('d MMM').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: kPrimaryDark, letterSpacing: 0.2,
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStandaloneSlotSection(List<AppointmentList> patients) {
    // find schedule slot's configured time range via slotId
    final slotId = patients.first.slotId;
    String? timeRange;
    if (slotId != null) {
      final scheduleSlots = _todayScheduledSlots();
      final match = scheduleSlots.where((s) => s.slotId == slotId).firstOrNull;
      if (match != null) {
        final s = _fmtScheduleTime(match.startTime);
        final e = _fmtScheduleTime(match.endTime);
        if (s.isNotEmpty && e.isNotEmpty) { timeRange = '$s – $e'; }
        else if (s.isNotEmpty) { timeRange = s; }
      }
    }
    // fallback: first–last patient appointment times
    timeRange ??= () {
      final s = _fmtTime(patients.first.startTime);
      final e = _fmtTime(patients.last.startTime);
      if (s.isEmpty) return null;
      return (e.isNotEmpty && e != s) ? '$s – $e' : s;
    }();

    return Container(
      decoration: const BoxDecoration(
        color: kPageBg,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: kCardBorder)),
        boxShadow: [
          BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-7, -7), blurRadius: 16, spreadRadius: 1),
          BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(7, 7),  blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Icon(Icons.calendar_month_rounded, size: 15, color: kBlueDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Slot Appointments',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
                if (timeRange != null) ...[
                  const SizedBox(height: 2),
                  Text(timeRange,
                      style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
                ],
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(20)),
              child: Text('${patients.length}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kBlueDark)),
            ),
          ]),
        ),
        const Divider(height: 1, color: kCardBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: patients.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSlotPatientCard(p, QueueState.idle),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildSlotPatientCard(AppointmentList p, QueueState queueState) {
    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final name      = p.patientName ?? 'Patient';
    final status    = p.status?.toLowerCase().trim() ?? '';
    final isIP      = status == 'in_progress';
    final isSkipped = status == 'skipped';
    final isBooked  = status == 'booked';
    return Container(
      decoration: const BoxDecoration(
        color: kPageBg,
        borderRadius: BorderRadius.all(Radius.circular(13)),
        boxShadow: [
          BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 8, spreadRadius: 1),
          BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(4, 4),  blurRadius: 8, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        // slot time badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: kPageBg,
            borderRadius: BorderRadius.all(Radius.circular(9)),
            boxShadow: [
              BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(3, 3), blurRadius: 5),
              BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 5),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('TIME', style: TextStyle(fontSize: 7, color: kTextMuted,
                fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            Text(_fmtTime(p.startTime),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: kPrimaryDark, height: 1.1)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          if (isIP)
            _badgeDot('In Progress', kPrimaryLight, kPrimaryDark, kPrimary)
          else if (isSkipped)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kAmber, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Skipped earlier',
                  style: TextStyle(fontSize: 11, color: kAmberDark, fontWeight: FontWeight.w500)),
            ])
          else if (p.gender != null)
            Text(p.gender!, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        ])),
        const SizedBox(width: 10),
        // action buttons
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (isSkipped && !isReceptionist)
            GestureDetector(
              onTap: () => _startSession(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 32, 173, 138),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text('Recall',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            )
          else if ((isBooked || isIP) && !isReceptionist) ...[
            GestureDetector(
              onTap: () => _startSession(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimaryDark,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(isIP ? 'Continue' : 'Start',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _skipPatient(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kRedLight, borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: kRedBorder),
                ),
                child: const Text('Skip',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRedDark)),
              ),
            ),
          ] else if (isBooked && isReceptionist)
            GestureDetector(
              onTap: () => _skipPatient(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kRedLight, borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: kRedBorder),
                ),
                child: const Text('Skip',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRedDark)),
              ),
            )
          else
            const Text('Waiting',
                style: TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  // Gradient pill switch — ON (accepting bookings) = teal→blue gradient with
  // the knob on the right; OFF (booking stopped) = flat grey, knob on the left.
  Widget _bookingToggleSwitch({
    required bool value,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 34, height: 19,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: value
                  ? const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF3B82F6)])
                  : null,
              color: value ? null : const Color(0xFFD1D5DB),
            ),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 15, height: 15,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
            ),
          ),
        ),
      );

  Widget _neuIconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              color: kPageBg,
              borderRadius: BorderRadius.all(Radius.circular(9)),
              boxShadow: [
                BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
                BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(3, 3),  blurRadius: 6),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );

  Widget _buildNowServingCard(
    AppointmentList p,
    QueueState queueState,
    int totalWaiting,
    bool hasIP,
    int? nextBookedQNo,
  ) {
    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final name     = p.patientName ?? 'Patient';
    final status   = p.status?.toLowerCase().trim() ?? '';
    final isIP     = status == 'in_progress';
    final isBooked = status == 'booked';
    final queueActive = queueState == QueueState.running || queueState == QueueState.paused;

    bool accessible = false;
    if (isIP) {
      accessible = true;
    } else if (queueActive && isBooked) {
      accessible = !hasIP && p.queueNumber == nextBookedQNo;
    }
    final effectiveAccessible = queueActive && accessible;

    return Container(
      decoration: const BoxDecoration(
      //  color: kPrimaryDark,
          color: Color.fromARGB(255, 25, 136, 108),
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Color(0x2E000000), offset: Offset(3, 3), blurRadius: 7),
                BoxShadow(color: Color(0x0FFFFFFF), offset: Offset(-2, -2), blurRadius: 5),
          // BoxShadow(color: Color(0xFF0A4A35), offset: Offset(4, 4), blurRadius: 10),
          // BoxShadow(color: Color(0xFF2EC48A), offset: Offset(-3, -3), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('NOW SERVING',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 1.1, color: Colors.white60)),
          const Spacer(),
          Text(
            'Token ${(p.queueNumber ?? 0).toString().padLeft(2, '0')}  •  $totalWaiting waiting',
            style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: const BorderRadius.all(Radius.circular(13)),
              boxShadow: const [
                BoxShadow(color: Color(0x2E000000), offset: Offset(3, 3), blurRadius: 7),
                BoxShadow(color: Color(0x0FFFFFFF), offset: Offset(-2, -2), blurRadius: 5),
              ],
            ),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('TKN',
                  style: TextStyle(fontSize: 8, color: Colors.white54,
                      fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              Text(
                (p.queueNumber ?? 0).toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1.0),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Colors.white, height: 1.2),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              if (isIP)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x55FFFFFF)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('In Progress',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 0.2)),
                  ]),
                ),
              if (isIP && p.gender != null) const SizedBox(width: 6),
              if (p.gender != null)
                Text(p.gender!,
                    style: const TextStyle(fontSize: 12, color: Colors.white60,
                        fontWeight: FontWeight.w500)),
            ]),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          if (queueActive) ...[
            Expanded(child: GestureDetector(
              onTap: () => _skipPatient(p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(color: Colors.white24),
                  color: const Color(0x0FFFFFFF),
                ),
                alignment: Alignment.center,
                child: const Text('Skip',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
              ),
            )),
            if (!isReceptionist) const SizedBox(width: 10),
          ],
          if (!isReceptionist)
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: effectiveAccessible ? () => _startSession(p) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: effectiveAccessible ? Colors.white : const Color(0x26FFFFFF),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    boxShadow: effectiveAccessible
                        ? const [
                            BoxShadow(color: Color(0x23000000), offset: Offset(3, 3), blurRadius: 7),
                            BoxShadow(color: Color(0x80FFFFFF), offset: Offset(-2, -2), blurRadius: 5),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isIP ? 'Continue' : 'Start session',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: effectiveAccessible ? kPrimaryDark : Colors.white38,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _maybeBlink(bool blink, Widget child) =>
      blink ? _ArrivedBlinkBadge(child: child) : child;

  Widget _buildUpNextCard(AppointmentList p, QueueState queueState) {
    final name          = p.patientName ?? 'Patient';
    final status        = p.status?.toLowerCase().trim() ?? '';
    final isSkipped     = status == 'skipped';
    final isBooked      = status == 'booked';
    final isArrived     = isSkipped && p.isArrived == true;
    final queueActive   = queueState == QueueState.running || queueState == QueueState.paused;
    final isReceptionist = ref.read(tokenProvider).roleId == 3;

    return Container(
      decoration: const BoxDecoration(
        color: kPageBg,
        borderRadius: BorderRadius.all(Radius.circular(13)),
        boxShadow: [
          BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 8, spreadRadius: 1),
          BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(4, 4),  blurRadius: 8, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: kPageBg,
            borderRadius: BorderRadius.all(Radius.circular(9)),
            boxShadow: [
              BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(3, 3), blurRadius: 5),
              BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 5),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('TKN',
                style: TextStyle(fontSize: 7, color: kTextMuted,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            Text(
              (p.queueNumber ?? 0).toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: kPrimaryDark, height: 1.0),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          if (isArrived)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Arrived at clinic — recall now',
                  style: TextStyle(fontSize: 11, color: kRedDark, fontWeight: FontWeight.w700)),
            ])
          else if (isSkipped)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kAmber, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Skipped earlier',
                  style: TextStyle(fontSize: 11, color: kAmberDark, fontWeight: FontWeight.w500)),
            ])
          else if (p.gender != null)
            Text(p.gender!,
                style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
        ])),
        const SizedBox(width: 10),
        if (isSkipped && queueActive && !isReceptionist)
          _maybeBlink(
            isArrived,
            GestureDetector(
              onTap: () => _startSession(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 32, 173, 138),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text('Recall',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          )
        else if (isBooked && queueActive && isReceptionist)
          GestureDetector(
            onTap: () => _skipPatient(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: kRedLight,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kRedBorder),
              ),
              child: const Text('Skip',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRedDark)),
            ),
          )
        else
          const Text('Waiting',
              style: TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
