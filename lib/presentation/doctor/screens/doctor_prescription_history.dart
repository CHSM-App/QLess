import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/patient_prescription_list.dart';

// ════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS — exact match with PatientListScreen
// ════════════════════════════════════════════════════════════════════
const kPrimary        = Color(0xFF26C6B0);
const kPrimaryDark    = Color(0xFF2BB5A0);
const kPrimaryLight   = Color(0xFFD9F5F1);
const kPrimaryLighter = Color(0xFFF2FCFA);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);
const kBg      = Color(0xFFF7F8FA);

const kSuccess    = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kGreenDark  = Color(0xFF276749);

const kError    = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);

const kPurple      = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);

const kInfo      = Color(0xFF3B82F6);
const kInfoLight = Color(0xFFDBEAFE);
const kInfoDark  = Color(0xFF1E40AF);

const kAmberLight = Color(0xFFFEF3C7);
const kAmberDark  = Color(0xFF975A16);
const kWarning    = Color(0xFFF6AD55);

// ── Medicine type maps (teal-palette aligned) ─────────────────────
const _typeColor = {
  1: Color(0xFF26C6B0), // Tablet  → primary teal
  2: Color(0xFF9F7AEA), // Syrup   → purple
  3: Color(0xFFFC8181), // Inject  → red
  4: Color(0xFF3B82F6), // Drops   → blue
  5: Color(0xFF68D391), // Lotion  → green
  6: Color(0xFFF6AD55), // Spray   → amber
};
const _typeColorLight = {
  1: Color(0xFFD9F5F1),
  2: Color(0xFFEDE9FE),
  3: Color(0xFFFEE2E2),
  4: Color(0xFFDBEAFE),
  5: Color(0xFFDCFCE7),
  6: Color(0xFFFEF3C7),
};
const _typeColorDark = {
  1: Color(0xFF2BB5A0),
  2: Color(0xFF6B46C1),
  3: Color(0xFFC53030),
  4: Color(0xFF1E40AF),
  5: Color(0xFF276749),
  6: Color(0xFF975A16),
};
const _typeLabel = {
  1: 'Tablet', 2: 'Syrup', 3: 'Injection',
  4: 'Drops',  5: 'Lotion', 6: 'Spray',
};
const _typeIcon = {
  1: Icons.medication_rounded,
  2: Icons.local_drink_rounded,
  3: Icons.vaccines_rounded,
  4: Icons.water_drop_rounded,
  5: Icons.soap_rounded,
  6: Icons.air_rounded,
};

// ── Avatar palette (same as PatientListScreen) ─────────────────────
const _avatarPalette = [
  (bg: Color(0xFFE0F5F1), fg: Color(0xFF2BB5A0)),
  (bg: Color(0xFFEDE9FE), fg: Color(0xFF6B46C1)),
  (bg: Color(0xFFFEF3C7), fg: Color(0xFF975A16)),
  (bg: Color(0xFFDBEAFE), fg: Color(0xFF1E40AF)),
  (bg: Color(0xFFFEE2E2), fg: Color(0xFFC53030)),
  (bg: Color(0xFFDCFCE7), fg: Color(0xFF276749)),
];

// ════════════════════════════════════════════════════════════════════
//  BREAKPOINTS
// ════════════════════════════════════════════════════════════════════
const _kTabletBreak  = 650.0;
const _kDesktopBreak = 1050.0;

// ════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════
class DoctorPrescriptionDetailScreen extends ConsumerStatefulWidget {
  final int     appointmentId;
  final int     patientId;
  final String  patientName;
  final String? patientAge;
  final String? patientGender;
  final int?    queueNumber;

  const DoctorPrescriptionDetailScreen({
    super.key,
    required this.appointmentId,
    required this.patientId,
    required this.patientName,
    this.patientAge,
    this.patientGender,
    this.queueNumber,
  });

  @override
  ConsumerState<DoctorPrescriptionDetailScreen> createState() =>
      _DoctorPrescriptionDetailScreenState();
}

class _DoctorPrescriptionDetailScreenState
    extends ConsumerState<DoctorPrescriptionDetailScreen> {
  PatientPrescription? _rx;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() { if (mounted) _fetchDetails(); });
  }

  Future<void> _fetchDetails() async {
    setState(() { _loading = true; _error = null; });
    try {
      await ref
          .read(prescriptionViewModelProvider.notifier)
          .appointmentWisePrescription(widget.appointmentId);
      if (!mounted) return;
      final details = ref.read(prescriptionViewModelProvider).appointmentWisePrescriptions;
      if (details != null && details.isNotEmpty) {
        setState(() {
          _rx = PatientPrescription.fromFlatList(
            details,
            fallbackPatientId:   widget.patientId,
            fallbackPatientName: widget.patientName,
          );
          _loading = false;
        });
      } else {
        setState(() { _error = 'No prescription data found'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  String _fmtDate(DateTime d) {
    const mo = ['', 'Jan','Feb','Mar','Apr','May','Jun',
                     'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${mo[d.month]} ${d.year}';
  }

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    if (p.isEmpty) return '?';
    return p.length == 1 ? p[0][0].toUpperCase()
        : '${p[0][0]}${p[1][0]}'.toUpperCase();
  }

  double get _width => MediaQuery.of(context).size.width;
  bool get _isDesktop => _width >= _kDesktopBreak;
  bool get _isTablet  => _width >= _kTabletBreak;

  // ── Build ─────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    body: Column(children: [
      _buildHeader(),
      Expanded(child: _buildBody()),
    ]),
  );

  // ── Header — PatientListScreen style ─────────────────────────────
  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: kBorder, width: 1)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  color: kTextPrimary, size: 15),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kPrimary.withOpacity(0.2)),
            ),
            child: const Icon(Icons.description_outlined, color: kPrimary, size: 16),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Prescription Details',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              SizedBox(height: 1),
              Text('View consultation summary',
                  style: TextStyle(fontSize: 11, color: kTextSecondary)),
            ]),
          ),
          // Completed badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(8)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kSuccess, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Completed', style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: kGreenDark)),
            ]),
          ),
        ]),
      ),
    ),
  );

  // ── Body ──────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) return const Center(
      child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5),
    );

    if (_error != null) return _buildError();

    final rx = _rx!;
    return _isDesktop ? _buildDesktop(rx) : _buildMobile(rx);
  }

  Widget _buildError() => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 60, height: 60,
        decoration: const BoxDecoration(color: kRedLight, shape: BoxShape.circle),
        child: const Icon(Icons.wifi_off_rounded, color: kError, size: 26),
      ),
      const SizedBox(height: 12),
      const Text('Failed to load prescription',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
      const SizedBox(height: 4),
      Text(_error!, style: const TextStyle(fontSize: 12, color: kTextSecondary),
          textAlign: TextAlign.center),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: _fetchDetails,
        icon: const Icon(Icons.refresh_rounded, size: 15),
        label: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary, foregroundColor: Colors.white, elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );

  // ── Mobile / Tablet — single column ──────────────────────────────
  Widget _buildMobile(PatientPrescription rx) {
    final hp = _isTablet ? 20.0 : 14.0;
    return ListView(
      padding: EdgeInsets.fromLTRB(hp, 14, hp, 30),
      children: [
        _patientBanner(rx),
        _gap(10),
        _appointmentCard(rx),
        if (_hasClinical(rx)) ...[_gap(10), _clinicalCard(rx)],
        _gap(10),
        _sectionHeader('Medicines', badge: '${rx.medicines.length}'),
        _gap(8),
        ...rx.medicines.map((m) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _medCard(m),
        )),
        if (rx.followUpDate != null) ...[_gap(4), _followUpCard(rx.followUpDate!)],
        if (rx.advice?.isNotEmpty == true) ...[
          _gap(10),
          _sectionHeader('Advice'),
          _gap(8),
          _adviceCard(rx.advice!),
        ],
      ],
    );
  }

  // ── Desktop — 2-column ───────────────────────────────────────────
  Widget _buildDesktop(PatientPrescription rx) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Left column — patient info + appointment + clinical
      SizedBox(
        width: 320,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: kBorder)),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
            children: [
              _patientBanner(rx),
              _gap(10),
              _appointmentCard(rx),
              if (_hasClinical(rx)) ...[_gap(10), _clinicalCard(rx)],
              if (rx.followUpDate != null) ...[_gap(10), _followUpCard(rx.followUpDate!)],
              if (rx.advice?.isNotEmpty == true) ...[
                _gap(10),
                _sectionHeader('Advice'),
                _gap(8),
                _adviceCard(rx.advice!),
              ],
            ],
          ),
        ),
      ),
      // Right column — medicines
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 30),
          children: [
            _sectionHeader('Medicines', badge: '${rx.medicines.length}'),
            _gap(10),
            ...rx.medicines.map((m) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _medCard(m),
            )),
          ],
        ),
      ),
    ],
  );

  bool _hasClinical(PatientPrescription rx) =>
      (rx.symptoms?.isNotEmpty == true) ||
      (rx.diagnosis?.isNotEmpty == true) ||
      (rx.clinicalNotes?.isNotEmpty == true);

  // ── Patient banner ────────────────────────────────────────────────
  Widget _patientBanner(PatientPrescription rx) {
    final av = _avatarPalette[widget.patientId % _avatarPalette.length];
    final meta = [
      if (widget.patientAge != null)    widget.patientAge!,
      if (widget.patientGender != null) widget.patientGender!,
      if (widget.queueNumber != null)   'Queue #${widget.queueNumber}',
    ].join(' · ');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimaryLighter,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimaryLight),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: av.bg, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(_initials(rx.patientName), style: TextStyle(
              fontSize: 14, fontWeight: FontWeight.w800, color: av.fg)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(rx.patientName, style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
              overflow: TextOverflow.ellipsis),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(meta, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
          ],
        ])),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(7)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 5, height: 5,
                decoration: const BoxDecoration(color: kSuccess, shape: BoxShape.circle)),
            const SizedBox(width: 4),
            const Text('Done', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: kGreenDark)),
          ]),
        ),
      ]),
    );
  }

  // ── Appointment info card ─────────────────────────────────────────
  Widget _appointmentCard(PatientPrescription rx) => _card(
    child: Column(children: [
      _infoRow('Appointment', '#${widget.appointmentId}'),
      _divider(),
      _infoRow('Date', _fmtDate(rx.prescriptionDate)),
      _divider(),
      _infoRow('Doctor', rx.doctorName),
      if (rx.specialization.isNotEmpty && rx.specialization != '-') ...[
        _divider(),
        _infoRow('Specialization', rx.specialization),
      ],
      if (rx.clinicName.isNotEmpty && rx.clinicName != 'Clinic') ...[
        _divider(),
        _infoRow('Clinic', rx.clinicName),
      ],
    ]),
  );

  // ── Symptoms / Diagnosis card ─────────────────────────────────────
  Widget _clinicalCard(PatientPrescription rx) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionHeader('Symptoms & Diagnosis'),
      const SizedBox(height: 8),
      _card(child: Column(children: [
        if (rx.symptoms?.isNotEmpty == true) ...[
          _infoRow('Symptoms', rx.symptoms!),
          if (rx.diagnosis?.isNotEmpty == true || rx.clinicalNotes?.isNotEmpty == true) _divider(),
        ],
        if (rx.diagnosis?.isNotEmpty == true) ...[
          _infoRow('Diagnosis', rx.diagnosis!),
          if (rx.clinicalNotes?.isNotEmpty == true) _divider(),
        ],
        if (rx.clinicalNotes?.isNotEmpty == true)
          _infoRow('Clinical Notes', rx.clinicalNotes!),
      ])),
    ],
  );

  // ── Follow-up card ────────────────────────────────────────────────
  Widget _followUpCard(DateTime date) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(width: 4,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4DD9C8), Color(0xFF2BB5A0)],
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: kPrimaryLight, borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.event_rounded, color: kPrimary, size: 16),
              ),
              const SizedBox(width: 10),
              Column(crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center, children: [
                const Text('Follow-up Date', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: kTextSecondary)),
                const SizedBox(height: 2),
                Text(_fmtDate(date), style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
              ]),
            ]),
          ),
        ),
      ]),
    ),
  );

  // ── Advice card ───────────────────────────────────────────────────
  Widget _adviceCard(String advice) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder),
    ),
    clipBehavior: Clip.antiAlias,
    child: IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(width: 4,
          decoration: BoxDecoration(color: kSuccess),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(advice, style: const TextStyle(
                fontSize: 13, color: kTextPrimary, height: 1.5)),
          ),
        ),
      ]),
    ),
  );

  // ── Medicine card ─────────────────────────────────────────────────
  Widget _medCard(PrescriptionMedicineItem m) {
    final tid   = m.medicineTypeId ?? 1;
    final tc    = _typeColor[tid]      ?? kPrimary;
    final tcL   = _typeColorLight[tid] ?? kPrimaryLight;
    final tcD   = _typeColorDark[tid]  ?? kPrimaryDark;
    final tl    = _typeLabel[tid]      ?? m.mediTypeName ?? 'Med';
    final ti    = _typeIcon[tid]       ?? Icons.medication_rounded;

    final parts = m.doseDisplay.split('-');
    final morning   = parts.isNotEmpty   ? parts[0].trim() : '-';
    final afternoon = parts.length > 1   ? parts[1].trim() : '-';
    final night     = parts.length > 2   ? parts[2].trim() : '-';
    final duration  = m.duration?.toString() ?? '-';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.withOpacity(0.30), width: 1.2),
        boxShadow: [BoxShadow(color: tc.withOpacity(0.05),
            blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: tc.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(color: tcL, borderRadius: BorderRadius.circular(7)),
              child: Icon(ti, color: tc, size: 13),
            ),
            const SizedBox(width: 9),
            Expanded(child: Text(
              m.medicineName ?? 'Medicine #${m.medicineId ?? '-'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                  color: kTextPrimary),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            )),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: tcL, borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tc.withOpacity(0.35)),
              ),
              child: Text(tl, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, color: tcD)),
            ),
          ]),
        ),
        // Body
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            // Dose slots
            Row(children: [
              _doseSlot('Morning',   morning,   tc, tcL),
              _dashWidget(),
              _doseSlot('Afternoon', afternoon, tc, tcL),
              _dashWidget(),
              _doseSlot('Night',     night,     tc, tcL),
            ]),
            const SizedBox(height: 10),
            // Detail chips
            Row(children: [
              _detailChip(Icons.timer_outlined,      duration,      kPurple, kPurpleLight),
              const SizedBox(width: 7),
              _detailChip(Icons.restaurant_outlined, m.timing ?? '-', kWarning, kAmberLight),
              if (m.extraInfo?.isNotEmpty == true) ...[
                const SizedBox(width: 7),
                _detailChip(Icons.info_outline_rounded, m.extraInfo!, kTextSecondary, kBorder),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }

  // ── Shared small widgets ──────────────────────────────────────────
  Widget _doseSlot(String label, String value, Color tc, Color tcL) =>
      Expanded(child: Column(children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600,
            color: kTextMuted)),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          decoration: BoxDecoration(
              color: tcL, borderRadius: BorderRadius.circular(7)),
          child: Text(value, textAlign: TextAlign.center, style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w800, color: tc)),
        ),
      ]));

  Widget _dashWidget() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 5),
    child: Text('–', style: const TextStyle(fontSize: 15, color: kTextMuted)),
  );

  Widget _detailChip(IconData icon, String label, Color fg, Color bg) =>
      Flexible(child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(7)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 4),
          Flexible(child: Text(label, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg))),
        ]),
      ));

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder),
      boxShadow: const [BoxShadow(color: Color(0x07000000),
          blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: child,
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        const SizedBox(width: 12),
        Flexible(child: Text(value, textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                color: kTextPrimary))),
      ],
    ),
  );

  Widget _divider() => const Divider(height: 1, color: kBorder);

  // ── Section header — matches PatientListScreen _SectionHeader ─────
  Widget _sectionHeader(String title, {String? badge}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(children: [
        Container(width: 3, height: 14,
            decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 7),
        Text(title, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      ]),
      if (badge != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: kPrimaryLighter, borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimaryLight),
          ),
          child: Text(badge, style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: kPrimaryDark)),
        ),
    ],
  );

  Widget _gap(double h) => SizedBox(height: h);
}