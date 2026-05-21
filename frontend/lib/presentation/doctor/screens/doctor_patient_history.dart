import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_prescription_history.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS — match home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary        = Color(0xFF26C6B0);
const _kPrimaryDark    = Color(0xFF2BB5A0);
const _kPrimaryLight   = Color(0xFFD9F5F1);
const _kPrimaryLighter = Color(0xFFF2FCFA);

const _kTextPrimary    = Color(0xFF2D3748);
const _kTextSecondary  = Color(0xFF718096);
const _kTextMuted      = Color(0xFFA0AEC0);

const _kBorder         = Color(0xFFEDF2F7);

const _kPurple         = Color(0xFF9F7AEA);
const _kPurpleLight    = Color(0xFFFAF5FF);
const _kPurpleBorder   = Color(0xFFE9D5FF);

const _kAmber          = Color(0xFFF6AD55);
const _kAmberLight     = Color(0xFFFFFBEB);
const _kAmberBorder    = Color(0xFFFCEFC7);

const _kRed            = Color(0xFFFC8181);
const _kRedLight       = Color(0xFFFFF5F5);
const _kRedBorder      = Color(0xFFFED7D7);

// ─────────────────────────────────────────────────────────────────────────────
// DOCTOR PATIENT HISTORY  —  All completed appointments, newest first.
// ─────────────────────────────────────────────────────────────────────────────

class DoctorPatientHistoryScreen extends ConsumerStatefulWidget {
  const DoctorPatientHistoryScreen({super.key});

  @override
  ConsumerState<DoctorPatientHistoryScreen> createState() =>
      _DoctorPatientHistoryScreenState();
}

class _DoctorPatientHistoryScreenState
    extends ConsumerState<DoctorPatientHistoryScreen> {
  String _query = '';

  int get _doctorId =>
      ref.read(doctorLoginViewModelProvider).doctorId ?? 0;

  Future<void> _refresh() async {
    if (_doctorId == 0) return;
    await ref
        .read(appointmentViewModelProvider.notifier)
        .fetchPatientAppointments(_doctorId);
  }

  List<AppointmentList> _completedAll(List<AppointmentList> all) {
    final filtered = all.where((a) {
      if ((a.status?.toLowerCase() ?? '') != 'completed') return false;
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      final name = (a.patientName ?? a.bookingFor ?? '').toLowerCase();
      final mobile = (a.mobile ?? '').toLowerCase();
      return name.contains(q) || mobile.contains(q);
    }).toList();

    filtered.sort((a, b) {
      final da = DateTime.tryParse(a.appointmentDate ?? '');
      final db = DateTime.tryParse(b.appointmentDate ?? '');
      if (da == null && db == null) return 0;
      if (da == null) return 1;
      if (db == null) return -1;
      return db.compareTo(da);
    });

    return filtered;
  }

  Map<String, List<AppointmentList>> _groupByDate(
      List<AppointmentList> items) {
    final out = <String, List<AppointmentList>>{};
    for (final a in items) {
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      final key = d == null
          ? 'Unknown'
          : DateFormat('EEEE, d MMMM yyyy').format(d);
      out.putIfAbsent(key, () => []).add(a);
    }
    return out;
  }

  int? _calcAge(String? dob) {
    if (dob == null) return null;
    final d = DateTime.tryParse(dob);
    return d == null ? null : DateTime.now().year - d.year;
  }

  String _initials(String name) => name
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0] : '')
      .join()
      .toUpperCase();

  void _openDetail(AppointmentList a) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DoctorPrescriptionDetailScreen(
        appointmentId: a.appointmentId ?? 0,
        patientId: a.patientId ?? 0,
        patientName: a.patientName ?? a.bookingFor ?? 'Patient',
        patientAge: _calcAge(a.dob)?.toString(),
        patientGender: a.gender,
        queueNumber: a.queueNumber,
      ),
    ));
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vmState = ref.watch(appointmentViewModelProvider);
    final async = vmState.patientAppointmentsList;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: _kTextPrimary),
        title: const Text(
          'All Patient History',
          style: TextStyle(
              color: _kTextPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: _kBorder),
        ),
      ),
      body: RefreshIndicator(
        color: _kPrimary,
        onRefresh: _refresh,
        child: async.when(
          loading: () => _scrollable(const [
            SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _kPrimary)),
            ),
          ]),
          error: (e, _) => _scrollable([
            SliverFillRemaining(
              child: Center(
                child: Text('$e',
                    style: const TextStyle(color: _kTextMuted, fontSize: 12)),
              ),
            ),
          ]),
          data: (list) {
            final completed = _completedAll(list);
            final grouped = _groupByDate(completed);
            final dateKeys = grouped.keys.toList();

            return _scrollable([
              SliverToBoxAdapter(child: _buildSearchBar()),
              SliverToBoxAdapter(child: _buildCountBar(completed.length)),
              if (completed.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: _EmptyHistory(),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(14, 4, 14, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final key = dateKeys[i];
                        final items = grouped[key]!;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.fromLTRB(2, 12, 2, 8),
                              child: Row(
                                children: [
                                  Container(
                                    width: 3,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: _kPrimary,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    key,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: _kTextPrimary,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 7, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: _kPrimaryLight,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${items.length}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: _kPrimaryDark,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ...items.map((p) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _historyCard(p),
                                )),
                          ],
                        );
                      },
                      childCount: dateKeys.length,
                    ),
                  ),
                ),
            ]);
          },
        ),
      ),
    );
  }

  Widget _scrollable(List<Widget> slivers) => CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      );

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(children: [
          const Icon(Icons.search_rounded, size: 18, color: _kTextMuted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              onChanged: (v) => setState(() => _query = v.trim()),
              style: const TextStyle(fontSize: 13, color: _kTextPrimary),
              decoration: const InputDecoration(
                hintText: 'Search by name or mobile',
                hintStyle: TextStyle(color: _kTextMuted, fontSize: 12),
                border: InputBorder.none,
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(vertical: 12, horizontal: 0),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildCountBar(int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Row(children: [
        const Icon(Icons.history_rounded, size: 14, color: _kPrimary),
        const SizedBox(width: 6),
        Text(
          '$total completed visit${total == 1 ? '' : 's'}',
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _kPrimaryDark),
        ),
      ]),
    );
  }

  Widget _historyCard(AppointmentList p) {
    final name = p.patientName ?? p.bookingFor ?? 'Unknown';
    final initials = _initials(name);
    final age = _calcAge(p.dob);

    final palettes = [
      (_kPrimaryLighter, _kPrimaryLight, _kPrimary),
      (_kPurpleLight, _kPurpleBorder, _kPurple),
      (_kAmberLight, _kAmberBorder, _kAmber),
      (_kRedLight, _kRedBorder, _kRed),
    ];
    final (avBg, avBd, avFg) =
        palettes[(p.queueNumber ?? 0) % palettes.length];

    final time = _fmtTime(p.startTime);

    return GestureDetector(
      onTap: () => _openDetail(p),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: avBd.withOpacity(0.6)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: avBd),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: avFg)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(
                  [
                    if (p.gender != null) p.gender!,
                    if (age != null) '$age yrs',
                    if (time.isNotEmpty) time,
                  ].join(' · '),
                  style:
                      const TextStyle(fontSize: 10, color: _kTextSecondary),
                ),
                const SizedBox(height: 5),
                Row(children: [
                  _completedBadge(),
                  if (p.specialization != null) ...[
                    const SizedBox(width: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: _kPrimaryLighter,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(p.specialization!,
                          style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: _kPrimaryDark)),
                    ),
                  ],
                ]),
              ],
            ),
          ),
          // const SizedBox(width: 8),
          // Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          //   Text((p.queueNumber ?? 0).toString().padLeft(2, '0'),
          //       style: TextStyle(
          //           fontSize: 22,
          //           fontWeight: FontWeight.w800,
          //           color: avFg,
          //           height: 1)),
          //   const Text('Token',
          //       style: TextStyle(fontSize: 9, color: _kTextMuted)),
          // ]),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: _kTextMuted),
        ]),
      ),
    );
  }

  Widget _completedBadge() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: _kPrimaryLighter, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.check_circle_rounded, size: 10, color: _kPrimaryDark),
          SizedBox(width: 4),
          Text('Completed',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _kPrimaryDark)),
        ]),
      );

  String _fmtTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toUtc();
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _kPrimaryLighter,
              shape: BoxShape.circle,
              border: Border.all(color: _kPrimaryLight),
            ),
            child: const Icon(Icons.history_rounded,
                color: _kPrimary, size: 26),
          ),
          const SizedBox(height: 12),
          const Text('No patient history yet',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kTextPrimary)),
          const SizedBox(height: 4),
          const Text('Completed visits will appear here.',
              style: TextStyle(fontSize: 11, color: _kTextMuted)),
        ],
      ),
    );
  }
}
