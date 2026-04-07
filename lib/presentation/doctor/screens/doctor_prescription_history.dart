import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/patient_prescription_list.dart';


// ── Colors (same as prescription screen) ─────────────────────────
const _kPrimary  = Color(0xFF1A73E8);
const _kBg       = Color(0xFFF4F6FB);
const _kCardBg   = Colors.white;
const _kTextDark = Color(0xFF1F2937);
const _kTextMid  = Color(0xFF6B7280);
const _kBorder   = Color(0xFFE5E7EB);
const _kGreen    = Color(0xFF34A853);
const _kRed      = Color(0xFFEA4335);

class DoctorPrescriptionDetailScreen extends ConsumerStatefulWidget {
  final int appointmentId;
  final int patientId;
  final String patientName;
  final String? patientAge;
  final String? patientGender;
  final int? queueNumber;

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
  bool _loading = true;
  String? _error;
@override
void initState() {
  super.initState();
  Future.microtask(() {
    if (!mounted) return;
    _fetchDetails();
  });
}

Future<void> _fetchDetails() async {
  setState(() { _loading = true; _error = null; });
  try {
    await ref
        .read(prescriptionViewModelProvider.notifier)
        .appointmentWisePrescription(widget.appointmentId);

    if (!mounted) return;

    final state = ref.read(prescriptionViewModelProvider);
    final details = state.appointmentWisePrescriptions;

    if (details != null && details.isNotEmpty) {
      setState(() {
        _rx = PatientPrescription.fromFlatList(
          details,
          fallbackPatientId: widget.patientId,
          fallbackPatientName: widget.patientName,
        );
        _loading = false;
      });
    } else {
      setState(() {
        _error = 'No prescription data found';
        _loading = false;
      });
    }
  } catch (e) {
    if (!mounted) return;
    setState(() {
      _error = e.toString();
      _loading = false;
    });
  }
}
  String _fmtDate(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  static const _typeColor = {
    1: Color(0xFF2B7FFF),
    2: Color(0xFF8B5CF6),
    3: Color(0xFFEF4444),
    4: Color(0xFF06B6D4),
    5: Color(0xFF10B981),
    6: Color(0xFFF59E0B),
  };
  static const _typeLabel = {
    1: 'Tablet', 2: 'Syrup', 3: 'Injection',
    4: 'Drops',  5: 'Lotion', 6: 'Spray',
  };
  static const _typeIcon = {
    1: Icons.medication_rounded,
    2: Icons.local_drink_rounded,
    3: Icons.vaccines_rounded,
    4: Icons.water_drop_rounded,
    5: Icons.soap_rounded,
    6: Icons.air_rounded,
  };
@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: _kBg,
    // ✅ Column ऐवजी थेट Scaffold body वापरा
    appBar: PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: _buildHeader(),
    ),
    body: _buildBody(),
  );
}

Widget _buildHeader() => SafeArea(
  child: Container(
    color: _kCardBg,
    padding: const EdgeInsets.fromLTRB(4, 6, 14, 10),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: _kTextDark, size: 18),
        onPressed: () => Navigator.pop(context),
      ),
      const SizedBox(width: 2),
      const Expanded(
        child: Text('Prescription Details',
            style: TextStyle(
              color: _kTextDark, fontSize: 17,
              fontWeight: FontWeight.w800, letterSpacing: -0.2)),
      ),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: _kGreen.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kGreen.withOpacity(0.3)),
        ),
        child: const Text('Completed',
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700,
              color: _kGreen)),
      ),
      const SizedBox(width: 4),
      const Icon(Icons.more_vert_rounded, color: _kTextMid, size: 20),
    ]),
  ),
);

  // ── Body ─────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: _kPrimary));
    }
    if (_error != null) {
      return Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: _kRed, size: 48),
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: _kTextMid)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchDetails,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ));
    }

    final rx = _rx!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      children: [

        // ── Doctor row ────────────────────────────────────────────
        _infoCard(children: [
          _infoRow('Doctor', rx.doctorName),
          if (rx.specialization.isNotEmpty)
            _infoRow('Specialization', rx.specialization),
          if (rx.clinicName.isNotEmpty && rx.clinicName != 'Clinic')
            _infoRow('Clinic', rx.clinicName),
          _infoRow('Date', _fmtDate(rx.prescriptionDate)),
        ]),

        const SizedBox(height: 10),

        // ── Symptoms & Diagnosis ──────────────────────────────────
        if (rx.symptoms?.isNotEmpty == true ||
            rx.diagnosis?.isNotEmpty == true ||
            rx.clinicalNotes?.isNotEmpty == true) ...[
          _secLabel('Symptoms & Diagnosis'),
          const SizedBox(height: 8),
          _infoCard(children: [
            if (rx.symptoms?.isNotEmpty == true)
              _infoRow('Symptoms', rx.symptoms!),
            if (rx.diagnosis?.isNotEmpty == true)
              _infoRow('Diagnosis', rx.diagnosis!),
            if (rx.clinicalNotes?.isNotEmpty == true)
              _infoRow('Clinical Notes', rx.clinicalNotes!),
          ]),
          const SizedBox(height: 10),
        ],

        // ── Medicines ─────────────────────────────────────────────
        _secLabel('Medicines (${rx.medicines.length})'),
        const SizedBox(height: 8),
        ...rx.medicines.map((m) {
          final tc = _typeColor[m.medicineTypeId] ?? _kTextMid;
          final tl = _typeLabel[m.medicineTypeId] ?? m.mediTypeName ?? 'Med';
          final ti = _typeIcon[m.medicineTypeId] ?? Icons.medication_rounded;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _medCard(m, tc, tl, ti),
          );
        }),

        // ── Follow-up ─────────────────────────────────────────────
        if (rx.followUpDate != null) ...[
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(14),
       
decoration: BoxDecoration(
  color: _kCardBg,
  borderRadius: BorderRadius.circular(12),
  border: const Border(
    left: BorderSide(color: _kGreen, width: 3),
  ),
),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _kPrimary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Follow-up date',
                    style: TextStyle(fontSize: 11,
                        color: _kPrimary, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(_fmtDate(rx.followUpDate!),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w800,
                        color: _kTextDark)),
              ]),
            ]),
          ),
          const SizedBox(height: 10),
        ],

        // ── Advice ────────────────────────────────────────────────
        if (rx.advice?.isNotEmpty == true) ...[
          _secLabel('Advice'),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _kCardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border(
                left: BorderSide(color: _kGreen, width: 3),
                top: BorderSide(color: _kGreen.withOpacity(0.3), width: 0.5),
                right: BorderSide(color: _kGreen.withOpacity(0.3), width: 0.5),
                bottom: BorderSide(color: _kGreen.withOpacity(0.3), width: 0.5),
              ),
            ),
            child: Text(rx.advice!,
                style: const TextStyle(
                    fontSize: 13, color: _kTextDark, height: 1.5)),
          ),
        ],
      ],
    );
  }

  // ── Medicine card ─────────────────────────────────────────────────
  Widget _medCard(PrescriptionMedicineItem m, Color tc,
      String tl, IconData ti) {
    final doseParts = m.doseDisplay.split('-');
    final morning   = doseParts.length > 0 ? doseParts[0].trim() : '-';
    final afternoon = doseParts.length > 1 ? doseParts[1].trim() : '-';
    final night     = doseParts.length > 2 ? doseParts[2].trim() : '-';

    return Container(
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tc.withOpacity(0.3), width: 0.8),
      ),
      child: Column(children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: tc.withOpacity(0.08),
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(11)),
          ),
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: tc.withOpacity(0.15),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(ti, color: tc, size: 14),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                m.medicineName ?? 'Medicine #${m.medicineId ?? '-'}',
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: _kTextDark),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: tc.withOpacity(0.4)),
              ),
              child: Text(tl,
                  style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: tc)),
            ),
          ]),
        ),

        // Body — Dosage / Duration / Timing
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            // M-A-N dosage row
            Row(children: [
              _doseSlot('Morning',   morning,   tc),
              _dash(),
              _doseSlot('Afternoon', afternoon, tc),
              _dash(),
              _doseSlot('Night',     night,     tc),
            ]),
            const SizedBox(height: 10),
            // Duration + Timing row
            Row(children: [
              _detailChip(Icons.timer_outlined,
                  m.duration ?? '-', const Color(0xFF6366F1)),
              const SizedBox(width: 8),
              _detailChip(Icons.restaurant_outlined,
                  m.timing ?? '-', const Color(0xFFF59E0B)),
              if (m.extraInfo != null) ...[
                const SizedBox(width: 8),
                _detailChip(Icons.info_outline_rounded,
                    m.extraInfo!, _kTextMid),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _doseSlot(String label, String value, Color tc) => Expanded(
    child: Column(children: [
      Text(label,
          style: const TextStyle(fontSize: 9, color: _kTextMid)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          color: tc.withOpacity(0.08),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(value,
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w800, color: tc)),
      ),
    ]),
  );

  Widget _dash() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text('–',
        style: TextStyle(fontSize: 16, color: _kTextMid)),
  );

  Widget _detailChip(IconData icon, String label, Color color) =>
      Flexible(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(7),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: color),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
        ),
      );

  // ── Info card ─────────────────────────────────────────────────────
  Widget _infoCard({required List<Widget> children}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _kCardBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _kBorder, width: 0.5),
    ),
    child: Column(children: children),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 12, color: _kTextMid)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: _kTextDark)),
        ),
      ],
    ),
  );

  Widget _secLabel(String t) => Row(children: [
    Container(
      width: 3, height: 14,
      decoration: BoxDecoration(
        color: _kPrimary, borderRadius: BorderRadius.circular(2)),
    ),
    const SizedBox(width: 7),
    Text(t,
        style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: _kTextDark)),
  ]);
}