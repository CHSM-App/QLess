part of '../home_screen.dart';

class _WalkInInlinePanelState extends ConsumerState<_WalkInInlinePanel> {
  final _nameCtr   = TextEditingController();
  final _mobileCtr = TextEditingController();

  Timer? _mobileDebounce;

  bool    _loading = true;
  String? _error;

  List<DoctorAvailabilityModel> _todaySessions = [];
  DoctorAvailabilityModel? _selected;

  bool    _booking  = false;
  String? _bookError;

  Patients?           _foundPatient;
  bool                _checkingMobile    = false;
  int?                _resolvedPatientId;
  int?                _familyMemberId;
  int?                _familyHeadPatientId;
  int?                _familyGenderId;
  List<FamilyMember>  _familyMembers     = [];
  bool                _loadingMembers    = false;
  bool                _addingNewMember   = false;
  final _newMemberCtr = TextEditingController();
  int  _newMemberGender = 1;
  ProviderSubscription<String?>? _clinicIdSub;
  ProviderSubscription<ConnectivityStatus>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _mobileCtr.addListener(_onMobileChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
    // Clinic switch madhe walk-in sessions/queue time stale rahu naye mhanun refresh
    _clinicIdSub = ref.listenManual<String?>(
      doctorLoginViewModelProvider.select((s) => s.clinicId),
      (prev, next) {
        if (next != prev) {
          _selected = null;
          _mobileCtr.clear();
          _nameCtr.clear();
          _clearPatientState();
          _loadSessions();
        }
      },
    );
    // Sessions load fail zali (net offline) tr, net back aalyavar retry karaycha —
    // ha widget clinic-switch shivay kadhich swatah refresh hot nahi, so pull-to-refresh
    // ne parent madhla schedule refresh hoto pan ha panel stale/"No sessions" var atkun rahto.
    _connectivitySub = ref.listenManual<ConnectivityStatus>(
      connectivityNotifierProvider.select((s) => s.status),
      (prev, next) {
        final backOnline = (next == ConnectivityStatus.online || next == ConnectivityStatus.backOnline) &&
            (prev == ConnectivityStatus.offline || prev == ConnectivityStatus.unknown);
        if (backOnline && _error != null) _loadSessions();
      },
    );
  }

  @override
  void dispose() {
    _mobileDebounce?.cancel();
    _mobileCtr.removeListener(_onMobileChanged);
    _nameCtr.dispose();
    _mobileCtr.dispose();
    _newMemberCtr.dispose();
    _clinicIdSub?.close();
    _connectivitySub?.close();
    super.dispose();
  }

  ApiService? get _api {
    final dio = ref.read(dioProvider).value;
    if (dio == null) return null;
    return ApiService(dio);
  }

  void _clearPatientState() {
    _foundPatient = null; _resolvedPatientId = null;
    _familyMemberId = null; _familyHeadPatientId = null; _familyGenderId = null;
    _familyMembers = []; _loadingMembers = false; _addingNewMember = false;
    _newMemberCtr.clear(); _newMemberGender = 1;
  }

  Future<void> _loadSessions() async {
    setState(() { _loading = true; _error = null; });
    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final doctorId = isReceptionist
        ? ref.read(receptionistLoginViewModelProvider).doctorId
        : ref.read(doctorLoginViewModelProvider).doctorId;
    final clinicId = ref.read(doctorLoginViewModelProvider).clinicId
        ?? (isReceptionist ? ref.read(receptionistLoginViewModelProvider).clinicId : null);
    final api = _api;
    if (doctorId == null || api == null) {
      setState(() { _loading = false; _error = 'Doctor not linked'; });
      return;
    }
    final dayName = const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][DateTime.now().weekday - 1];
    DoctorScheduleModel? schedule;
    try {
      schedule = await api.getDoctorSchedule(doctorId, clinicId: clinicId);
    } catch (_) {
      // Offline / network failure — fall back to the schedule already cached in
      // memory by the home screen's own load (doctorSettingsViewModelProvider),
      // so walk-in booking still works offline instead of hard-erroring here.
      schedule = ref.read(doctorSettingsViewModelProvider).doctorSchedule;
    }
    if (schedule == null) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load sessions'; });
      return;
    }
    final todaySlots = (schedule.schedule ?? [])
        .where((d) => d.day == dayName && (d.isEnabled ?? 0) == 1)
        .expand((d) => d.slots ?? [])
        .toList();
    final sessions = todaySlots
        .where((slot) {
          if (_hasSessionEndedToday(slot.endTime)) return false;
          final mode = slot.bookingMode ?? 0;
          return mode == 1 || mode == 3; // queue only — exclude slots-only (mode 2)
        })
        .map((slot) => DoctorAvailabilityModel(
              dayOfWeek:   dayName,
              isEnabled:   true,
              slotId:      slot.slotId,
              startTime:   slot.startTime,
              endTime:     slot.endTime,
              bookingMode: slot.bookingMode,
              slotDuration: slot.slotDuration,
            ))
        .toList();
    if (!mounted) return;
    setState(() {
      _todaySessions = sessions;
      _selected = sessions.length == 1 ? sessions.first : null;
      _loading = false;
    });
  }

  void _onMobileChanged() {
    _mobileDebounce?.cancel();
    final digits = _mobileCtr.text.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      _mobileDebounce = Timer(const Duration(milliseconds: 800), () => _lookupMobile(digits));
    } else if (_checkingMobile || _foundPatient != null || _resolvedPatientId != null ||
               _familyMemberId != null || _familyHeadPatientId != null || _bookError != null) {
      setState(() { _checkingMobile = false; _bookError = null; _clearPatientState(); });
    }
  }

  Future<void> _lookupMobile(String mobile) async {
    setState(() { _checkingMobile = true; });
    final isOnline = ref.read(connectivityNotifierProvider).isOnline;
    if (!isOnline) {
      await _lookupMobileOffline(mobile);
      return;
    }
    final api = _api;
    if (api == null) {
      // No connection at the network-client layer either — same as offline.
      await _lookupMobileOffline(mobile);
      return;
    }
    try {
      final results = await api.checkPhonePatient(mobile);
      if (!mounted) return;
      // Discard if user already changed/cleared the field
      final currentDigits = _mobileCtr.text.trim().replaceAll(RegExp(r'\D'), '');
      if (currentDigits != mobile) return;
      if (results.isNotEmpty) {
        final p = results.first;
        setState(() { _foundPatient = p; _checkingMobile = false; _loadingMembers = true; });
        try {
          final members = p.patientId != null
              ? await api.fetchFamilyMembers(p.patientId!) : <FamilyMember>[];
          if (mounted) setState(() { _familyMembers = members; _loadingMembers = false; });
        } catch (_) {
          if (mounted) setState(() { _loadingMembers = false; });
        }
      } else {
        setState(() { _clearPatientState(); _checkingMobile = false; });
      }
    } catch (_) {
      // Network failed mid-call (went offline just now) — fall back to the
      // local match instead of just clearing, so the doctor still gets
      // recognition for a patient this doctor has already seen before.
      if (mounted) await _lookupMobileOffline(mobile);
    }
  }

  /// Offline mobile lookup — a full cross-doctor patient search needs the
  /// server, so this can only recognise patients THIS doctor has already
  /// seen (present in the cached appointment history). A genuinely new
  /// patient can't be identified offline; the doctor enters them as new and
  /// the server reconciles/matches by mobile once the walk-in booking syncs.
  Future<void> _lookupMobileOffline(String mobile) async {
    try {
      final isReceptionist = ref.read(tokenProvider).roleId == 3;
      final doctorId = isReceptionist
          ? ref.read(receptionistLoginViewModelProvider).doctorId
          : ref.read(doctorLoginViewModelProvider).doctorId;
      if (doctorId == null || doctorId == 0) {
        if (mounted) setState(() { _clearPatientState(); _checkingMobile = false; });
        return;
      }
      final cached = await ref.read(offlineQueueStoreProvider).getCachedAppointments(doctorId);
      AppointmentList? match;
      for (final a in cached) {
        final m = (a.mobile ?? '').trim().replaceAll(RegExp(r'\D'), '');
        if (m.length >= 10 && m.endsWith(mobile) && a.patientId != null) { match = a; break; }
      }
      debugPrint('[WalkIn offline lookup] doctorId=$doctorId cachedCount=${cached.length} '
          'searching=$mobile matched=${match != null} '
          'sampleMobiles=${cached.take(5).map((a) => a.mobile).toList()}');
      if (!mounted) return;
      final currentDigits = _mobileCtr.text.trim().replaceAll(RegExp(r'\D'), '');
      if (currentDigits != mobile) return;
      if (match != null) {
        setState(() {
          _foundPatient = Patients(
            patientId: match!.patientId,
            name:      match.patientName,
            mobileNo:  match.mobile,
            gender:    match.gender,
            DOB:       DateTime.tryParse(match.dob ?? ''),
          );
          // Family members can't be resolved without the server — booking
          // still works for the found patient themself (patient_id is set).
          _familyMembers  = [];
          _loadingMembers = false;
          _checkingMobile = false;
        });
      } else {
        setState(() { _clearPatientState(); _checkingMobile = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _clearPatientState(); _checkingMobile = false; });
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    DateTime? dt = DateTime.tryParse(iso);
    int h, m;
    if (dt != null) { h = dt.hour; m = dt.minute; }
    else {
      final p = iso.split(':');
      h = int.tryParse(p[0]) ?? 0;
      m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
    }
    final sf = h < 12 ? 'AM' : 'PM';
    final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${dh.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')} $sf';
  }

  String _modeLabel(int? m) => switch (m) { 1 => 'Queue', 2 => 'Slots', 3 => 'Queue+Slots', _ => '' };

  Future<void> _book() async {
    final name   = _nameCtr.text.trim();
    final mobile = _mobileCtr.text.trim();
    if (name.isEmpty) { setState(() { _bookError = 'Patient name is required'; }); return; }
    if (mobile.length < 10) { setState(() { _bookError = 'Enter valid 10-digit mobile'; }); return; }
    if (_selected == null) { setState(() { _bookError = 'Please select a session'; }); return; }

    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final doctorId = isReceptionist
        ? ref.read(receptionistLoginViewModelProvider).doctorId
        : ref.read(doctorLoginViewModelProvider).doctorId;
    final clinicId = ref.read(doctorLoginViewModelProvider).clinicId
        ?? (isReceptionist ? ref.read(receptionistLoginViewModelProvider).clinicId : null);
    if (doctorId == null) return;

    setState(() { _booking = true; _bookError = null; });

    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    final isNewFamily      = _familyHeadPatientId != null;
    final isExistingFamily = _familyMemberId != null;
    final isFamilyBooking  = isNewFamily || isExistingFamily;

    final body = <String, dynamic>{
      'name':             name,
      'mobile_no':        mobile,
      'doctor_id':        doctorId,
      'appointment_date': dateStr,
      'slot_id':          _selected!.slotId,
      'user_type':        isFamilyBooking ? 2 : 1,
      if (clinicId != null) 'clinic_id': clinicId,
      if (isExistingFamily) 'patient_id': _familyMemberId,
      if (isNewFamily) 'family_id': _familyHeadPatientId,
      if (isNewFamily && _familyGenderId != null) 'gender_id': _familyGenderId,
      if (!isFamilyBooking && _resolvedPatientId != null) 'patient_id': _resolvedPatientId,
    }..removeWhere((_, v) => v == null);

    bool didBook = false;
    String? successMsg;
    int? startedId;
    try {
      final isOnline = ref.read(connectivityNotifierProvider).isOnline;
      final resp = await ref.read(receptionistLoginViewModelProvider.notifier)
          .walkInBook(body, isOnline: isOnline);
      if (!mounted) return;
      if (resp.success == true) {
        didBook = true;
        successMsg = resp.message ?? 'Walk-in patient booked';
        // Receptionists don't write prescriptions — they just keep booking.
        if (!isReceptionist) startedId = resp.startedAppointmentId;
        if (!isOnline) {
          // Online arrivals show up via the queue_update socket event; offline
          // ones only exist in the local cache, so pull them into view now —
          // otherwise the newly booked walk-in stays invisible until sync.
          await ref.read(appointmentViewModelProvider.notifier)
              .fetchPatientAppointments(doctorId, isOnline: false, clinicId: clinicId);
        }
      } else {
        setState(() { _bookError = resp.message ?? 'Booking failed'; });
      }
    } catch (e) {
      if (mounted) setState(() { _bookError = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _booking = false; });
    }
    // Call onBooked() AFTER finally so the setState above completes before
    // the parent collapses this widget (prevents deactivated-ancestor crash).
    if (didBook && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(successMsg!),
        backgroundColor: kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      _nameCtr.clear();
      _mobileCtr.clear();
      setState(() { _clearPatientState(); _selected = _todaySessions.length == 1 ? _todaySessions.first : null; });
      if (startedId != null && widget.onAutoStarted != null) {
        widget.onBooked(); // close the form/dialog first
        widget.onAutoStarted!(startedId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookedFor = _resolvedPatientId != null || _familyMemberId != null || _familyHeadPatientId != null
        ? _nameCtr.text : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: _loading
          ? const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary)))
          : _error != null
              ? _errBox(_error!)
              : _todaySessions.isEmpty
                  ? _errBox('No sessions scheduled for today')
                  : Builder(builder: (context) {
                      final liveSessions = _todaySessions
                          .where((s) => !_hasSessionEndedToday(s.endTime))
                          .toList();
                      // Auto-clear stale selection
                      if (_selected != null &&
                          !liveSessions.any((s) => s.slotId == _selected!.slotId)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _selected = null);
                        });
                      }
                      if (liveSessions.isEmpty) {
                        return _errBox('No sessions available at this time');
                      }
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.event_rounded, size: 14, color: kPrimary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Today  ·  ${const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][DateTime.now().weekday - 1]}, ${DateTime.now().day} ${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][DateTime.now().month - 1]}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      if (liveSessions.length > 1) ...[
                        const Text('SELECT SESSION',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: kTextMuted, letterSpacing: 0.7)),
                        const SizedBox(height: 8),
                      ],
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: liveSessions.map((s) {
                          final isSel = _selected?.slotId == s.slotId;
                          return GestureDetector(
                            onTap: () => setState(() => _selected = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? kPrimaryDark : kPrimaryLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isSel ? kPrimaryDark : const Color(0xFF9FE1CB)),
                              ),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text('${_fmtTime(s.startTime)} – ${_fmtTime(s.endTime)}',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                        color: isSel ? Colors.white : kTextPrimary)),
                                const SizedBox(height: 2),
                                Text(_modeLabel(s.bookingMode),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                        color: isSel ? Colors.white70 : kTextMuted)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      _inlineField(controller: _nameCtr, label: 'Patient Name',
                          icon: Icons.person_outline_rounded,
                          type: TextInputType.name, caps: TextCapitalization.words),
                      const SizedBox(height: 10),
                      _inlineField(controller: _mobileCtr, label: 'Mobile Number',
                          icon: Icons.phone_outlined, type: TextInputType.phone, maxLen: 10,
                          formatters: [FilteringTextInputFormatter.digitsOnly]),

                      if (_checkingMobile) ...[
                        const SizedBox(height: 8),
                        const Row(children: [
                          SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary)),
                          SizedBox(width: 8),
                          Text('Checking...', style: TextStyle(fontSize: 12, color: kTextMuted)),
                        ]),
                      ] else if (_foundPatient != null && _resolvedPatientId == null &&
                                 _familyMemberId == null && _familyHeadPatientId == null) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: kPrimaryLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF9FE1CB)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                              child: Row(children: [
                                const Icon(Icons.person_rounded, size: 14, color: kPrimaryDark),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text('${_foundPatient!.name}  ·  ${_foundPatient!.mobileNo ?? ''}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                          color: kPrimaryDark)),
                                ),
                              ]),
                            ),
                            const Divider(height: 1, color: kBorder),
                            InkWell(
                              onTap: () => setState(() {
                                _resolvedPatientId = _foundPatient!.patientId;
                                _nameCtr.text = _foundPatient!.name ?? _nameCtr.text;
                                _foundPatient = null; _familyMemberId = null;
                                _familyHeadPatientId = null; _familyGenderId = null;
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(children: [
                                  const Icon(Icons.how_to_reg_rounded, size: 14, color: kPrimaryDark),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Book for ${_foundPatient!.name}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                            color: kPrimaryDark)),
                                  ),
                                ]),
                              ),
                            ),
                            if (_loadingMembers) ...[
                              const Divider(height: 1, color: kBorder),
                              const Padding(
                                padding: EdgeInsets.all(10),
                                child: Center(child: SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))),
                              ),
                            ] else if (_familyMembers.isNotEmpty) ...[
                              const Divider(height: 1, color: kBorder),
                              ..._familyMembers.map((m) => Column(children: [
                                InkWell(
                                  onTap: () => setState(() {
                                    _familyMemberId = m.memberId!;
                                    _nameCtr.text = m.memberName ?? '';
                                    _foundPatient = null; _resolvedPatientId = null;
                                    _familyHeadPatientId = null; _familyGenderId = null;
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    child: Row(children: [
                                      CircleAvatar(radius: 12, backgroundColor: kPrimaryLight,
                                          child: Text(m.avatarLetter,
                                              style: const TextStyle(color: kPrimaryDark, fontSize: 11,
                                                  fontWeight: FontWeight.w700))),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(m.memberName ?? '',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                              color: kTextPrimary))),
                                      Text([m.genderName, m.relationName]
                                              .where((s) => s != null && s.isNotEmpty).join(' · '),
                                          style: const TextStyle(fontSize: 11, color: kTextMuted)),
                                    ]),
                                  ),
                                ),
                                const Divider(height: 1, color: kBorder),
                              ])),
                            ],
                            InkWell(
                              onTap: () => setState(() => _addingNewMember = !_addingNewMember),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(children: [
                                  const Icon(Icons.person_add_alt_1_rounded, size: 14, color: kTextSecondary),
                                  const SizedBox(width: 8),
                                  const Text('Add new family member',
                                      style: TextStyle(fontSize: 12, color: kTextSecondary)),
                                  const Spacer(),
                                  Icon(_addingNewMember ? Icons.expand_less : Icons.expand_more,
                                      size: 16, color: kTextMuted),
                                ]),
                              ),
                            ),
                            if (_addingNewMember) ...[
                              const Divider(height: 1, color: kBorder),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  TextField(
                                    controller: _newMemberCtr,
                                    textCapitalization: TextCapitalization.words,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                        color: kTextPrimary),
                                    decoration: InputDecoration(
                                      hintText: 'Family member name',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      filled: true, fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: kBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: kBorder)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    _GenderPill(label: 'Male',   value: 1,
                                        selected: _newMemberGender == 1,
                                        onTap: () => setState(() => _newMemberGender = 1)),
                                    const SizedBox(width: 6),
                                    _GenderPill(label: 'Female', value: 2,
                                        selected: _newMemberGender == 2,
                                        onTap: () => setState(() => _newMemberGender = 2)),
                                    const SizedBox(width: 6),
                                    _GenderPill(label: 'Other',  value: 3,
                                        selected: _newMemberGender == 3,
                                        onTap: () => setState(() => _newMemberGender = 3)),
                                  ]),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final name = _newMemberCtr.text.trim();
                                        if (name.isEmpty) return;
                                        setState(() {
                                          _familyHeadPatientId = _foundPatient!.patientId;
                                          _familyGenderId      = _newMemberGender;
                                          _nameCtr.text        = name;
                                          _foundPatient        = null;
                                          _resolvedPatientId   = null;
                                          _familyMemberId      = null;
                                          _addingNewMember     = false;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimaryDark, foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      child: const Text('Use this member',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ]),
                        ),
                      ] else if (bookedFor != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: kGreenLight, borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kGreenBorder),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle_rounded, size: 16, color: kGreen),
                            const SizedBox(width: 8),
                            Text('Booking for $bookedFor',
                                style: const TextStyle(fontSize: 12, color: kGreenDark,
                                    fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ],

                      if (_bookError != null) ...[
                        const SizedBox(height: 10),
                        _errBox(_bookError!),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity, height: 44,
                        child: ElevatedButton(
                          onPressed: _booking ? null : _book,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryDark, foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _booking
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Book Walk-in Patient',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      ]);
                    }),
    );
  }

  Widget _inlineField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    TextCapitalization caps = TextCapitalization.none,
    int? maxLen,
    List<TextInputFormatter>? formatters,
  }) =>
      TextField(
        controller: controller,
        keyboardType: type,
        textCapitalization: caps,
        maxLength: maxLen,
        inputFormatters: formatters,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextSecondary),
          prefixIcon: Icon(icon, size: 16, color: kTextSecondary),
          counterText: '',
          filled: true, fillColor: kPageBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        ),
      );

  Widget _errBox(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: kRedLight, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kRedBorder),
    ),
    child: Text(msg, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kRedDark)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GENDER PILL
// ─────────────────────────────────────────────────────────────────────────────

class _GenderPill extends StatelessWidget {
  final String label;
  final int    value;
  final bool   selected;
  final VoidCallback onTap;
  const _GenderPill({required this.label, required this.value,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? kPrimaryDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? kPrimaryDark : kBorder),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : kTextSecondary)),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME SESSION FULLSCREEN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _HomeSessionFullscreenPage extends ConsumerStatefulWidget {
  final int sessionIndex;
  // Never passed by the caller; kept as null so the UI branches stay as they were.
  String? get slotLabel => null;
  final QueueState queueState;
  final List<AppointmentList> sessionPts;
  final bool sessionHasIP;
  final bool isEmergency;
  int? get sessionNextQNo => null;
  final VoidCallback onQueueStart;
  final VoidCallback onQueuePause;
  final VoidCallback onQueueStop;
  final VoidCallback onQueueEmergency;
  final Function(AppointmentList) onStartSession;
  final Function(AppointmentList) onSkip;
  final Function(AppointmentList) onCancel;
  final Function(AppointmentList) onPrescription;

  const _HomeSessionFullscreenPage({
    required this.sessionIndex,
    required this.queueState,
    required this.sessionPts,
    required this.sessionHasIP,
    required this.isEmergency,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
    required this.onQueueEmergency,
    required this.onStartSession,
    required this.onSkip,
    required this.onCancel,
    required this.onPrescription,
  });

  @override
  ConsumerState<_HomeSessionFullscreenPage> createState() =>
      _HomeSessionFullscreenPageState();
}
