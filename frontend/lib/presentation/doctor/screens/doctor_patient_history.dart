import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_prescription_history.dart';
import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';

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

const _kError          = Color(0xFFE53E3E);
const _kBg             = Color(0xFFF7F8FA);

// ─────────────────────────────────────────────────────────────────────────────
// DATE FILTER  —  matches patient_list.dart
// ─────────────────────────────────────────────────────────────────────────────
enum _DateFilter { all, today, thisWeek, thisMonth, last3Months, last6Months, thisYear, custom }

extension _DateFilterX on _DateFilter {
  String get label => switch (this) {
    _DateFilter.all         => 'All Time',
    _DateFilter.today       => 'Today',
    _DateFilter.thisWeek    => 'This Week',
    _DateFilter.thisMonth   => 'This Month',
    _DateFilter.last3Months => 'Last 3 Months',
    _DateFilter.last6Months => 'Last 6 Months',
    _DateFilter.thisYear    => 'This Year',
    _DateFilter.custom      => 'Custom Range',
  };
  IconData get icon => switch (this) {
    _DateFilter.all         => Icons.all_inclusive_rounded,
    _DateFilter.today       => Icons.today_rounded,
    _DateFilter.thisWeek    => Icons.view_week_rounded,
    _DateFilter.thisMonth   => Icons.calendar_month_rounded,
    _DateFilter.last3Months => Icons.date_range_rounded,
    _DateFilter.last6Months => Icons.date_range_rounded,
    _DateFilter.thisYear    => Icons.calendar_today_rounded,
    _DateFilter.custom      => Icons.tune_rounded,
  };
}

bool _passesDateFilter(AppointmentList a, _DateFilter df,
    DateTime? customFrom, DateTime? customTo) {
  final p = DateTime.tryParse(a.appointmentDate ?? '');
  if (p == null) return df == _DateFilter.all;
  final now = DateTime.now();
  return switch (df) {
    _DateFilter.all         => true,
    _DateFilter.today       => p.year == now.year && p.month == now.month && p.day == now.day,
    _DateFilter.thisWeek    => p.isAfter(
        DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1))
            .subtract(const Duration(seconds: 1))),
    _DateFilter.thisMonth   => p.year == now.year && p.month == now.month,
    _DateFilter.last3Months => p.isAfter(now.subtract(const Duration(days: 90))),
    _DateFilter.last6Months => p.isAfter(now.subtract(const Duration(days: 180))),
    _DateFilter.thisYear    => p.year == now.year,
    _DateFilter.custom      => () {
        if (customFrom != null && p.isBefore(customFrom)) return false;
        if (customTo != null &&
            p.isAfter(customTo.add(const Duration(days: 1)))) return false;
        return true;
      }(),
  };
}

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

  // Date filter state.
  _DateFilter _dateFilter = _DateFilter.all;
  DateTime?   _customFrom;
  DateTime?   _customTo;
  bool        _sortNewest = true;

  bool get _hasDateFilter =>
      _dateFilter != _DateFilter.all || !_sortNewest;

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
      if (!_passesDateFilter(a, _dateFilter, _customFrom, _customTo)) return false;
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
      return _sortNewest ? db.compareTo(da) : da.compareTo(db);
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
      body: Column(
        children: [
          // ── Fixed header: title + search + filter ────────────────────────
          _buildHeader(),
          // ── Scrollable list only ─────────────────────────────────────────
          Expanded(
            child: async.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: _kPrimary),
              ),
              error: (e, _) => Center(
                child: Text('$e',
                    style: const TextStyle(color: _kTextMuted, fontSize: 12)),
              ),
              data: (list) {
                final completed = _completedAll(list);
                final grouped = _groupByDate(completed);
                final dateKeys = grouped.keys.toList();

                return Column(
                  children: [
                    _buildCountBar(completed.length),
                    Expanded(
                      child: RefreshIndicator(
                        color: _kPrimary,
                        onRefresh: _refresh,
                        child: _scrollable([
                          if (completed.isEmpty)
                            const SliverFillRemaining(
                              hasScrollBody: false,
                              child: _EmptyHistory(),
                            )
                          else
                            SliverPadding(
                              padding:
                                  const EdgeInsets.fromLTRB(14, 4, 14, 24),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (_, i) {
                                    final key = dateKeys[i];
                                    final items = grouped[key]!;
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(
                                              2, 12, 2, 8),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 3,
                                                height: 14,
                                                decoration: BoxDecoration(
                                                  color: _kPrimary,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
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
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 7,
                                                        vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: _kPrimaryLight,
                                                  borderRadius:
                                                      BorderRadius.circular(20),
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
                                              padding: const EdgeInsets.only(
                                                  bottom: 8),
                                              child: _historyCard(p),
                                            )),
                                      ],
                                    );
                                  },
                                  childCount: dateKeys.length,
                                ),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _scrollable(List<Widget> slivers) => CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      );

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _kBorder, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 14, 12),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.arrow_back_rounded,
                        color: _kTextPrimary, size: 22),
                    splashRadius: 20,
                  ),
                  Expanded(
                    child: AppExpandableHeaderSearch(
                      onChanged: (v) => setState(() => _query = v.trim()),
                      leadingIcon: Icons.history_rounded,
                      title: 'Patient History',
                      subtitle: 'All completed visits',
                      hintText: 'Search by name or mobile...',
                      accentColor: _kPrimary,
                      leadingBackgroundColor: _kPrimaryLight,
                      titleColor: _kTextPrimary,
                      subtitleColor: _kTextSecondary,
                      fieldColor: _kBg,
                      borderColor: _kBorder,
                      iconColor: _kTextMuted,
                      textColor: _kTextPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _showDateFilterSheet,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _hasDateFilter ? _kPrimary : _kBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _hasDateFilter ? _kPrimary : _kBorder),
                      ),
                      child: Icon(Icons.tune_rounded,
                          color: _hasDateFilter ? Colors.white : _kPrimary,
                          size: 18),
                    ),
                  ),
                ],
              ),
            ),
            if (_hasDateFilter)
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
                child: _buildFilterChips(),
              ),
          ],
        ),
      ),
    );
  }

  String _fmtDateChip(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  void _showDateFilterSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _HistoryDateFilterSheet(
          current: _dateFilter,
          customFrom: _customFrom,
          customTo: _customTo,
          sortNewest: _sortNewest,
          onApply: (f, from, to, newest) => setState(() {
            _dateFilter = f;
            _customFrom = from;
            _customTo   = to;
            _sortNewest = newest;
          }),
        ),
      );

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      child: Wrap(
        spacing: 6, runSpacing: 6,
        children: [
          if (_dateFilter != _DateFilter.all)
            _filterChip(
              icon: _dateFilter.icon,
              label: _dateFilter == _DateFilter.custom && _customFrom != null
                  ? '${_fmtDateChip(_customFrom!)} – ${_customTo != null ? _fmtDateChip(_customTo!) : '…'}'
                  : _dateFilter.label,
              onRemove: () => setState(() => _dateFilter = _DateFilter.all),
            ),
          if (!_sortNewest)
            _filterChip(
              icon: Icons.arrow_upward_rounded,
              label: 'Oldest First',
              onRemove: () => setState(() => _sortNewest = true),
            ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required IconData icon,
    required String label,
    required VoidCallback onRemove,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _kPrimary.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _kPrimaryDark, size: 11),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: _kPrimaryDark, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, color: _kPrimaryDark, size: 12),
          ),
        ]),
      );

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
          // Container(
          //   width: 44,
          //   height: 44,
          //   decoration: BoxDecoration(
          //     color: avBg,
          //     borderRadius: BorderRadius.circular(12),
          //     border: Border.all(color: avBd),
          //   ),
          //   alignment: Alignment.center,
          //   child: Text(initials,
          //       style: TextStyle(
          //           fontSize: 13,
          //           fontWeight: FontWeight.w800,
          //           color: avFg)),
          // ),
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
                // Row(children: [
                //   _completedBadge(),
                //   if (p.specialization != null) ...[
                //     const SizedBox(width: 5),
                //     Container(
                //       padding: const EdgeInsets.symmetric(
                //           horizontal: 7, vertical: 2),
                //       decoration: BoxDecoration(
                //         color: _kPrimaryLighter,
                //         borderRadius: BorderRadius.circular(6),
                //       ),
                //       child: Text(p.specialization!,
                //           style: const TextStyle(
                //               fontSize: 9,
                //               fontWeight: FontWeight.w700,
                //               color: _kPrimaryDark)),
                //     ),
                //   ],
                // ]),
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

// ─────────────────────────────────────────────────────────────────────────────
// DATE FILTER SHEET  —  matches patient_list.dart
// ─────────────────────────────────────────────────────────────────────────────
class _HistoryDateFilterSheet extends StatefulWidget {
  final _DateFilter current;
  final DateTime? customFrom, customTo;
  final bool sortNewest;
  final void Function(_DateFilter, DateTime?, DateTime?, bool) onApply;

  const _HistoryDateFilterSheet({
    required this.current,
    required this.customFrom,
    required this.customTo,
    required this.sortNewest,
    required this.onApply,
  });

  @override
  State<_HistoryDateFilterSheet> createState() =>
      _HistoryDateFilterSheetState();
}

class _HistoryDateFilterSheetState extends State<_HistoryDateFilterSheet> {
  late _DateFilter _sel;
  late DateTime?   _from, _to;
  late bool        _newest;

  @override
  void initState() {
    super.initState();
    _sel    = widget.current;
    _from   = widget.customFrom;
    _to     = widget.customTo;
    _newest = widget.sortNewest;
  }

  String _fmt(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  Future<void> _pick(bool isFrom) async {
    final p = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: _kPrimary)),
          child: child!),
    );
    if (p != null) setState(() => isFrom ? _from = p : _to = p);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            const Text('Filter by Date',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _kTextPrimary)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _sel = _DateFilter.all; _from = null; _to = null; _newest = true;
              }),
              child: const Text('Reset',
                  style: TextStyle(
                      color: _kError, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7, runSpacing: 7,
            children: _DateFilter.values
                .where((f) => f != _DateFilter.custom)
                .map((f) {
              final sel = _sel == f;
              return GestureDetector(
                onTap: () => setState(() => _sel = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? _kPrimary : _kBg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? _kPrimary : _kBorder,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(f.icon,
                        color: sel ? Colors.white : _kTextMuted, size: 12),
                    const SizedBox(width: 5),
                    Text(f.label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : _kTextSecondary)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => setState(() => _sel = _DateFilter.custom),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _sel == _DateFilter.custom ? _kPrimaryLight : _kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _sel == _DateFilter.custom ? _kPrimary : _kBorder,
                    width: _sel == _DateFilter.custom ? 1.5 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.tune_rounded,
                        color: _sel == _DateFilter.custom ? _kPrimary : _kTextMuted,
                        size: 15),
                    const SizedBox(width: 7),
                    Text('Custom Date Range',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: _sel == _DateFilter.custom
                                ? _kPrimary : _kTextMuted)),
                  ]),
                  if (_sel == _DateFilter.custom) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _datePick('From', _from, () => _pick(true))),
                      const SizedBox(width: 8),
                      Expanded(child: _datePick('To', _to, () => _pick(false))),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Sort Order',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: _kTextPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _sortBtn('Newest First', Icons.arrow_downward_rounded,
                _newest, () => setState(() => _newest = true))),
            const SizedBox(width: 8),
            Expanded(child: _sortBtn('Oldest First', Icons.arrow_upward_rounded,
                !_newest, () => setState(() => _newest = false))),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity, height: 46,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_sel, _from, _to, _newest);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _kPrimary, foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Apply Filter',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePick(String label, DateTime? val, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _kBorder)),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: _kPrimary, size: 13),
            const SizedBox(width: 7),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: _kTextMuted)),
              Text(val != null ? _fmt(val) : 'Select',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: val != null ? _kTextPrimary : _kTextMuted)),
            ]),
          ]),
        ),
      );

  Widget _sortBtn(String label, IconData icon, bool sel, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? _kPrimary : _kBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? _kPrimary : _kBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: sel ? Colors.white : _kTextMuted, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : _kTextSecondary)),
            ],
          ),
        ),
      );
}
