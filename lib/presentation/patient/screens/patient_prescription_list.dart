import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/prescription_viewmodel.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/print_prescription_screen.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';

// ── Shared colour palette ─────────────────────────────────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

const kError      = Color(0xFFFC8181);
const kRedLight   = Color(0xFFFEE2E2);
const kSuccess    = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kWarning    = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);
const kPurple     = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);
const kInfo       = Color(0xFF3B82F6);
const kInfoLight  = Color(0xFFDBEAFE);
const kIndigo     = Color(0xFF7F9CF5);
const kIndigoLight = Color(0xFFE0E7FF);

// ── Helpers ───────────────────────────────────────────────────────────────────
const _kAvatarColors = [kPrimary, kSuccess, kWarning, kPurple, kInfo, kError];
Color _avatarColor(int i) => _kAvatarColors[i % _kAvatarColors.length];

String _initials(String name) {
  final p = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
  if (p.isEmpty) return '?';
  if (p.length == 1) return p[0][0].toUpperCase();
  return '${p[0][0]}${p[1][0]}'.toUpperCase();
}

// ── Date filter enum ──────────────────────────────────────────────────────────
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

// ════════════════════════════════════════════════════════════════════
//  PRESCRIPTION LIST SCREEN
// ════════════════════════════════════════════════════════════════════
class PatientPrescriptionListScreen extends ConsumerStatefulWidget {
  const PatientPrescriptionListScreen({super.key});
  @override
  ConsumerState<PatientPrescriptionListScreen> createState() =>
      _PatientPrescriptionListScreenState();
}

class _PatientPrescriptionListScreenState
    extends ConsumerState<PatientPrescriptionListScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _search    = '';
  bool _hasFetched  = false;
  bool _hasFetchedFamily = false;

  _DateFilter _dateFilter    = _DateFilter.all;
  DateTime?   _customFrom;
  DateTime?   _customTo;
  bool        _sortNewest    = true;
  static const int _filterAll  = -1;
  static const int _filterSelf = -2;
  int _memberFilter = _filterAll;

  ProviderSubscription<PatientLoginState>? _patientSub;
  ProviderSubscription<TokenState>?        _tokenSub;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(tokenProvider.notifier).loadTokens();
      ref.read(patientLoginViewModelProvider.notifier).loadFromStoragePatient();
    });
    _patientSub = ref.listenManual<PatientLoginState>(
        patientLoginViewModelProvider, (_, __) => _tryFetch());
    _tokenSub = ref.listenManual<TokenState>(
        tokenProvider, (_, __) => _tryFetch());
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFetch());
  }

  void _tryFetch() {
    final pid    = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    final ts     = ref.read(tokenProvider);
    final ready  = !ts.isLoading && (ts.accessToken ?? '').isNotEmpty;
    if (ready && pid == 0) {
      ref.read(patientLoginViewModelProvider.notifier).loadFromStoragePatient();
      return;
    }
    if (pid > 0 && ready && !_hasFetched) {
      _hasFetched = true;
      ref.read(prescriptionViewModelProvider.notifier).patientPrescriptionList(pid);
    }
    if (ready && pid > 0 && !_hasFetchedFamily) {
      _hasFetchedFamily = true;
      ref.read(familyViewModelProvider.notifier).fetchAllFamilyMembers(pid);
    }
  }

  @override
  void dispose() {
    _patientSub?.close();
    _tokenSub?.close();
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool _passesDate(PatientPrescription p) {
    final now = DateTime.now();
    final d   = p.prescriptionDate;
    return switch (_dateFilter) {
      _DateFilter.all         => true,
      _DateFilter.today       => d.year == now.year && d.month == now.month && d.day == now.day,
      _DateFilter.thisWeek    => d.isAfter(DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1))
            .subtract(const Duration(seconds: 1))),
      _DateFilter.thisMonth   => d.year == now.year && d.month == now.month,
      _DateFilter.last3Months => d.isAfter(now.subtract(const Duration(days: 90))),
      _DateFilter.last6Months => d.isAfter(now.subtract(const Duration(days: 180))),
      _DateFilter.thisYear    => d.year == now.year,
      _DateFilter.custom      => () {
          if (_customFrom != null && d.isBefore(_customFrom!)) return false;
          if (_customTo   != null && d.isAfter(_customTo!.add(const Duration(days: 1)))) return false;
          return true;
        }(),
    };
  }

  bool _passesMember(PatientPrescription p, int pid, String pName,
      List<FamilyMember> members) {
    if (_memberFilter == _filterAll) return true;
    if (_memberFilter == _filterSelf) {
      if (pid > 0 && p.patientId == pid) return true;
      return pName.trim().toLowerCase() == p.patientName.toLowerCase();
    }
    if (_memberFilter > 0 && p.patientId == _memberFilter) return true;
    final m = members.cast<FamilyMember?>()
        .firstWhere((m) => m?.memberId == _memberFilter, orElse: () => null);
    final mn = m?.memberName?.trim().toLowerCase();
    return mn != null && mn.isNotEmpty && p.patientName.toLowerCase() == mn;
  }

  List<PatientPrescription> _filtered(List<PatientPrescription> src, String status,
      int pid, String pName, List<FamilyMember> members) {
    var list = src.where((p) {
      if (status != 'all' && p.status != status) return false;
      if (!_passesMember(p, pid, pName, members)) return false;
      if (!_passesDate(p)) return false;
      if (_search.trim().isNotEmpty) {
        final q = _search.toLowerCase();
        if (!(p.diagnosis ?? '').toLowerCase().contains(q) &&
            !p.prescriptionId.toString().contains(q) &&
            !p.doctorName.toLowerCase().contains(q)) return false;
      }
      return true;
    }).toList();
    list.sort((a, b) => _sortNewest
        ? b.prescriptionDate.compareTo(a.prescriptionDate)
        : a.prescriptionDate.compareTo(b.prescriptionDate));
    return list;
  }

  String _fmtDate(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  bool get _hasFilter => _dateFilter != _DateFilter.all || !_sortNewest;

  void _openDetail(PatientPrescription p) => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, anim, __) => PatientPrescriptionViewScreen(
            prescriptionId: p.prescriptionId,
            fallback: p,
            patientId: ref.read(patientLoginViewModelProvider).patientId ?? 0,
          ),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
                .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );

  void _showFilterSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _DateFilterSheet(
          current: _dateFilter, customFrom: _customFrom,
          customTo: _customTo, sortNewest: _sortNewest,
          onApply: (f, from, to, newest) => setState(() {
            _dateFilter = f; _customFrom = from; _customTo = to; _sortNewest = newest;
          }),
        ),
      );

  // ════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final patState  = ref.watch(patientLoginViewModelProvider);
    final pid       = patState.patientId ?? 0;
    final pName     = patState.name ?? 'Patient';
    final famState  = ref.watch(familyViewModelProvider);
    final members   = famState.allfamilyMembers.maybeWhen(
        data: (m) => m, orElse: () => const <FamilyMember>[]);
    final tokenSt   = ref.watch(tokenProvider);
    final tokenOk   = !tokenSt.isLoading && (tokenSt.accessToken ?? '').isNotEmpty;
    final waitAuth  = !tokenOk || pid == 0;

    final state   = ref.watch(prescriptionViewModelProvider);
    final apiList = state.prescriptionsListPatient ?? const <PrescriptionModel>[];
    final mapped  = apiList.map((m) => PatientPrescription.fromModel(m,
        fallbackPatientId: pid, fallbackPatientName: pName)).toList();

    final all    = _filtered(mapped, 'all',       pid, pName, members);
    final active = _filtered(mapped, 'active',    pid, pName, members);
    final past   = _filtered(mapped, 'completed', pid, pName, members)
                 + _filtered(mapped, 'expired',   pid, pName, members);

    return Scaffold(
      backgroundColor: Colors.white,
      // ── AppBar — back arrow + icon badge + title ──────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
           margin: const EdgeInsets.all(10), 
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kPrimary.withOpacity(0.2)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: kPrimary, size: 15),
          ),
        ),
        leadingWidth: 54,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kPrimary.withOpacity(0.2)),
              ),
              child: const Icon(Icons.receipt_long_rounded,
                  color: kPrimary, size: 15),
            ),
            const SizedBox(width: 8),
            const Text('Prescriptions',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    letterSpacing: -0.2)),
          ],
        ),
        actions: [
          // Member filter dropdown
          _MemberDropdown(
            selected: _memberFilter,
            patientName: pName,
            members: members,
            onChanged: (v) => setState(() => _memberFilter = v),
          ),
          const SizedBox(width: 14),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: kBorder, height: 1),
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search + filter row
              _buildSearchRow(),
              // Active filter chips
              if (_hasFilter) _buildFilterChips(),
              // Tab bar
              _buildTabBar(all.length, active.length, past.length),
              // Content
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildList(all,    waitAuth: waitAuth, state: state, pid: pid),
                    _buildList(active, waitAuth: waitAuth, state: state, pid: pid),
                    _buildList(past,   waitAuth: waitAuth, state: state, pid: pid),
                  ],
                ),
              ),
            ],
          ),
          if (state.isLoading)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                  child: CircularProgressIndicator(
                      color: kPrimary, strokeWidth: 2.5)),
            ),
        ],
      ),
    );
  }

  // ── Search + filter row ─────────────────────────────────────────────
  Widget _buildSearchRow() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Row(children: [
          Expanded(
            child: AppExpandableHeaderSearch(
              controller: _searchCtrl,
              leadingIcon: Icons.receipt_long_rounded,
              title: 'Search Prescriptions',
              subtitle: 'Diagnosis, Rx, doctor',
              hintText: 'Search diagnosis, Rx, doctor...',
              height: 40,
              accentColor: kPrimary,
              leadingBackgroundColor: kPrimaryLight,
              titleColor: kTextPrimary,
              subtitleColor: kTextMuted,
              fieldColor: const Color(0xFFF7F8FA),
              borderColor: kBorder,
              iconColor: kTextMuted,
              textColor: kTextPrimary,
              onChanged: (v) => setState(() => _search = v),
            ),
          ),
          const SizedBox(width: 8),
          // Filter button
          GestureDetector(
            onTap: _showFilterSheet,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _hasFilter ? kPrimary : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _hasFilter ? kPrimary : kBorder),
              ),
              child: Icon(Icons.tune_rounded,
                  color: _hasFilter ? Colors.white : kPrimary, size: 18),
            ),
          ),
          const SizedBox(width: 8),
          // Sort button
          GestureDetector(
            onTap: () => setState(() => _sortNewest = !_sortNewest),
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: Icon(
                _sortNewest
                    ? Icons.arrow_downward_rounded
                    : Icons.arrow_upward_rounded,
                color: kPrimary, size: 17,
              ),
            ),
          ),
        ]),
      );

  // ── Active filter chips ─────────────────────────────────────────────
  Widget _buildFilterChips() => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
        child: Wrap(
          spacing: 6, runSpacing: 6,
          children: [
            if (_dateFilter != _DateFilter.all)
              _chip(
                icon: _dateFilter.icon,
                label: _dateFilter == _DateFilter.custom && _customFrom != null
                    ? '${_fmtDate(_customFrom!)} – ${_customTo != null ? _fmtDate(_customTo!) : '…'}'
                    : _dateFilter.label,
                onRemove: () =>
                    setState(() => _dateFilter = _DateFilter.all),
              ),
            if (!_sortNewest)
              _chip(
                icon: Icons.arrow_upward_rounded,
                label: 'Oldest First',
                onRemove: () => setState(() => _sortNewest = true),
              ),
          ],
        ),
      );

  Widget _chip({required IconData icon, required String label,
      required VoidCallback onRemove}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: kPrimaryLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kPrimary.withOpacity(0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: kPrimary, size: 11),
          const SizedBox(width: 5),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: kPrimary, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, color: kPrimary, size: 12),
          ),
        ]),
      );

  // ── Tab bar ─────────────────────────────────────────────────────────
  Widget _buildTabBar(int all, int active, int past) => Container(
        color: Colors.white,
        child: Column(children: [
          TabBar(
            controller: _tabCtrl,
            labelColor: kPrimary,
            unselectedLabelColor: kTextMuted,
            indicatorColor: kPrimary,
            indicatorWeight: 2,
            labelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
            unselectedLabelStyle:
                const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            tabs: [
              Tab(text: 'All ($all)'),
              Tab(text: 'Active ($active)'),
              Tab(text: 'Past ($past)'),
            ],
          ),
          const Divider(height: 1, color: kBorder),
        ]),
      );

  // ── List body ───────────────────────────────────────────────────────
  Widget _buildList(List<PatientPrescription> items,
    {required bool waitAuth, required PrescriptionState state,
     required int pid}) {
  if (waitAuth || (state.isLoading && items.isEmpty)) {
    return const _PrescriptionSkeletonList();
  }
  if (state.error != null && items.isEmpty) return _errorState(state.error!, pid);
  if (items.isEmpty) return _emptyState(pid);

  return RefreshIndicator(
    color: kPrimary,
    strokeWidth: 2,
    onRefresh: () => ref
        .read(prescriptionViewModelProvider.notifier)
        .patientPrescriptionList(pid),
    child: ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _PrescriptionCard(
        prescription: items[i],
        fmtDate: _fmtDate,
        onTap: () => _openDetail(items[i]),
      ),
    ),
  );
}
Widget _emptyState(int pid) => RefreshIndicator(
      color: kPrimary,
      strokeWidth: 2,
      onRefresh: () => ref
          .read(prescriptionViewModelProvider.notifier)
          .patientPrescriptionList(pid),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(
                      color: kPrimaryLight, shape: BoxShape.circle),
                  child: const Icon(Icons.receipt_long_outlined,
                      size: 24, color: kPrimary),
                ),
                const SizedBox(height: 12),
                const Text('No prescriptions found',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 4),
                const Text('Pull down to refresh or try a different filter',
                    style: TextStyle(fontSize: 12, color: kTextMuted)),
                if (_hasFilter) ...[
                  const SizedBox(height: 14),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _dateFilter = _DateFilter.all; _sortNewest = true;
                    }),
                    icon: const Icon(Icons.clear_all_rounded, size: 15),
                    label: const Text('Clear Filters',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    style: TextButton.styleFrom(foregroundColor: kPrimary),
                  ),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  Widget _errorState(String msg, int pid) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56, height: 56,
              decoration: const BoxDecoration(
                  color: kRedLight, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 24, color: kError),
            ),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: kTextSecondary)),
            const SizedBox(height: 16),
            SizedBox(
              height: 38,
              child: ElevatedButton.icon(
                onPressed: () => ref
                    .read(prescriptionViewModelProvider.notifier)
                    .patientPrescriptionList(pid),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text('Retry',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  PRESCRIPTION CARD
// ════════════════════════════════════════════════════════════════════
class _PrescriptionCard extends StatelessWidget {
  final PatientPrescription prescription;
  final String Function(DateTime) fmtDate;
  final VoidCallback onTap;
  const _PrescriptionCard({
    required this.prescription, required this.fmtDate, required this.onTap,
  });

  Color get _sfg => switch (prescription.status) {
    'active'    => kSuccess,
    'completed' => kPrimary,
    _           => kTextMuted,
  };
  Color get _sbg => switch (prescription.status) {
    'active'    => kGreenLight,
    'completed' => kPrimaryLight,
    _           => const Color(0xFFF7F8FA),
  };
  String get _slbl => switch (prescription.status) {
    'active'    => 'Active',
    'completed' => 'Completed',
    _           => 'Expired',
  };
  IconData get _sic => switch (prescription.status) {
    'active'    => Icons.check_circle_rounded,
    'completed' => Icons.task_alt_rounded,
    _           => Icons.cancel_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: prescription.status == 'active'
                  ? kSuccess.withOpacity(0.3)
                  : kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Column(children: [
          // ── Top strip ──────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: prescription.status == 'active'
                  ? kGreenLight.withOpacity(0.35)
                  : const Color(0xFFF7F8FA),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.receipt_rounded, color: kPrimary, size: 9),
                  const SizedBox(width: 3),
                  Text('Rx #${prescription.prescriptionId}',
                      style: const TextStyle(
                          color: kPrimary, fontSize: 10,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.calendar_today_rounded,
                  color: kTextMuted, size: 9),
              const SizedBox(width: 2),
              Text(fmtDate(prescription.prescriptionDate),
                  style: const TextStyle(fontSize: 10, color: kTextMuted)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: _sbg, borderRadius: BorderRadius.circular(5)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_sic, color: _sfg, size: 9),
                  const SizedBox(width: 2),
                  Text(_slbl,
                      style: TextStyle(
                          color: _sfg, fontSize: 9,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),

          // ── Body ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Doctor avatar
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                        colors: [kPrimaryDark, kPrimary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: const Icon(Icons.person_rounded,
                      color: Colors.white, size: 16),
                ),
                const SizedBox(width: 8),
                // Doctor info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prescription.doctorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(prescription.specialization,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: kTextMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Patient badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 18, height: 18,
                        decoration: const BoxDecoration(
                            color: kPrimary, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: Text(
                          prescription.patientName
                              .split(' ')
                              .where((w) => w.isNotEmpty)
                              .take(1)
                              .map((w) => w[0].toUpperCase())
                              .join(),
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 4),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 80),
                        child: Text(prescription.patientName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: kTextPrimary)),
                      ),
                    ]),
                    if (prescription.patientAge != null &&
                        prescription.patientAge! > 0) ...[
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                            color: kPrimaryLight,
                            borderRadius: BorderRadius.circular(4)),
                        child: Text('${prescription.patientAge} yrs',
                            style: const TextStyle(
                                fontSize: 9, color: kPrimary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          // ── Bottom strip ───────────────────────────────────
          Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder))),
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(children: [
              Expanded(
                child: Wrap(spacing: 5, runSpacing: 3, children: [
                  _miniChip(Icons.medication_rounded,
                      '${prescription.medicines.length} Med',
                      kPurple, kPurpleLight),
                  if (prescription.followUpDate != null)
                    _miniChip(Icons.event_rounded,
                        fmtDate(prescription.followUpDate!),
                        kWarning, kAmberLight),
                ]),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: kPrimary,
                    borderRadius: BorderRadius.circular(7)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.visibility_rounded,
                      color: Colors.white, size: 11),
                  SizedBox(width: 3),
                  Text('View',
                      style: TextStyle(
                          color: Colors.white, fontSize: 11,
                          fontWeight: FontWeight.w700)),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _miniChip(IconData ic, String lbl, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(5)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(ic, color: fg, size: 9),
          const SizedBox(width: 3),
          Text(lbl,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w600, color: fg)),
        ]),
      );
}
// ════════════════════════════════════════════════════════════════════
//  MEMBER DROPDOWN
// ════════════════════════════════════════════════════════════════════
class _MemberDropdown extends StatelessWidget {
  final int selected;
  final String patientName;
  final List<FamilyMember> members;
  final ValueChanged<int> onChanged;

  static const int _filterAll  = -1;
  static const int _filterSelf = -2;

  const _MemberDropdown({
    required this.selected, required this.patientName,
    required this.members,  required this.onChanged,
  });

  String get _label {
    if (selected == _filterAll)  return 'All';
    if (selected == _filterSelf) return patientName.split(' ').first.isNotEmpty
        ? patientName.split(' ').first : 'Self';
    final m = members.cast<FamilyMember?>()
        .firstWhere((m) => m?.memberId == selected, orElse: () => null);
    return m?.memberName?.split(' ').first ?? 'Member';
  }

  Widget _avatar() {
    if (selected == _filterAll) {
      return Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
            color: kPrimaryLight, shape: BoxShape.circle,
            border: Border.all(color: kPrimary.withOpacity(0.3))),
        child: const Icon(Icons.people_rounded, color: kPrimary, size: 12),
      );
    }
    String name; Color color;
    if (selected == _filterSelf) {
      name = patientName; color = kPrimary;
    } else {
      final m   = members.cast<FamilyMember?>()
          .firstWhere((m) => m?.memberId == selected, orElse: () => null);
      name  = m?.memberName ?? 'M';
      final idx = members.indexWhere((m) => m.memberId == selected);
      color = _avatarColor(idx + 1);
    }
    return Container(
      width: 22, height: 22,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(_initials(name),
          style: const TextStyle(
              color: Colors.white, fontSize: 8, fontWeight: FontWeight.w700)),
    );
  }

  void _show(BuildContext ctx) async {
    final box     = ctx.findRenderObject() as RenderBox;
    final overlay = Navigator.of(ctx).overlay!.context.findRenderObject() as RenderBox;
    final pos = RelativeRect.fromRect(
      Rect.fromPoints(
        box.localToGlobal(box.size.bottomLeft(Offset.zero), ancestor: overlay),
        box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );
    final items = <PopupMenuEntry<int>>[
      _MemberItem(
        value: _filterAll, selected: selected == _filterAll,
        avatar: Container(width: 28, height: 28,
            decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
            child: const Icon(Icons.people_rounded, color: kPrimary, size: 14)),
        name: 'All members', sub: null,
      ),
      const PopupMenuDivider(height: 1),
      const _SecHeader('SELF'),
      _MemberItem(
        value: _filterSelf, selected: selected == _filterSelf,
        avatar: _AvatarCircle(name: patientName, color: kPrimary, size: 28),
        name: patientName.isNotEmpty ? patientName : 'Self', sub: 'Self',
      ),
      if (members.isNotEmpty) ...[
        const PopupMenuDivider(height: 1),
        const _SecHeader('FAMILY'),
        ...members.where((m) => (m.memberId ?? 0) > 0)
            .toList().asMap().entries.map((e) => _MemberItem(
              value: e.value.memberId!,
              selected: selected == e.value.memberId,
              avatar: _AvatarCircle(
                  name: e.value.memberName ?? 'M',
                  color: _avatarColor(e.key + 1), size: 28),
              name: e.value.memberName ?? 'Member',
              sub: e.value.relationName,
            )),
      ],
    ];
    final result = await showMenu<int>(
      context: ctx, position: pos, items: items,
      color: Colors.white,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: kBorder)),
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => _show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _avatar(),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 72),
              child: Text(_label,
                  overflow: TextOverflow.ellipsis, maxLines: 1,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
            const SizedBox(width: 3),
            const Icon(Icons.keyboard_arrow_down_rounded,
                color: kTextPrimary, size: 17),
          ]),
        ),
      );
}

class _SecHeader extends PopupMenuEntry<int> {
  final String label;
  const _SecHeader(this.label);
  @override double get height => 28;
  @override bool represents(int? v) => false;
  @override State<_SecHeader> createState() => _SecHeaderState();
}
class _SecHeaderState extends State<_SecHeader> {
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 3),
        child: Text(widget.label,
            style: const TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700,
                color: kTextMuted, letterSpacing: 0.6)),
      );
}

class _MemberItem extends PopupMenuEntry<int> {
  final int value; final bool selected;
  final Widget avatar; final String name; final String? sub;
  const _MemberItem({required this.value, required this.selected,
      required this.avatar, required this.name, required this.sub});
  @override double get height => 52;
  @override bool represents(int? v) => v == value;
  @override State<_MemberItem> createState() => _MemberItemState();
}
class _MemberItemState extends State<_MemberItem> {
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => Navigator.of(context).pop(widget.value),
        child: Container(
          color: widget.selected ? kPrimaryLight : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            widget.avatar,
            const SizedBox(width: 10),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(widget.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600,
                        color: widget.selected ? kPrimary : kTextPrimary)),
                if (widget.sub != null)
                  Text(widget.sub!,
                      style: const TextStyle(fontSize: 11, color: kTextMuted)),
              ],
            )),
            if (widget.selected)
              const Icon(Icons.check_rounded, color: kPrimary, size: 15),
          ]),
        ),
      );
}

class _AvatarCircle extends StatelessWidget {
  final String name; final Color color; final double size;
  const _AvatarCircle({required this.name, required this.color, required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size, height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(_initials(name),
            style: TextStyle(
                color: Colors.white, fontSize: size * 0.33,
                fontWeight: FontWeight.w700)),
      );
}

// ════════════════════════════════════════════════════════════════════
//  DATE FILTER SHEET
// ════════════════════════════════════════════════════════════════════
class _DateFilterSheet extends StatefulWidget {
  final _DateFilter current;
  final DateTime? customFrom, customTo;
  final bool sortNewest;
  final void Function(_DateFilter, DateTime?, DateTime?, bool) onApply;
  const _DateFilterSheet({required this.current, required this.customFrom,
      required this.customTo, required this.sortNewest, required this.onApply});
  @override State<_DateFilterSheet> createState() => _DateFilterSheetState();
}

class _DateFilterSheetState extends State<_DateFilterSheet> {
  late _DateFilter _sel;
  late DateTime? _from, _to;
  late bool _newest;

  @override void initState() {
    super.initState();
    _sel = widget.current; _from = widget.customFrom;
    _to  = widget.customTo; _newest = widget.sortNewest;
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
              colorScheme: const ColorScheme.light(primary: kPrimary)),
          child: child!),
    );
    if (p != null) setState(() => isFrom ? _from = p : _to = p);
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          Row(children: [
            const Text('Filter by Date',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _sel = _DateFilter.all; _from = null; _to = null; _newest = true;
              }),
              child: const Text('Reset',
                  style: TextStyle(color: kError, fontWeight: FontWeight.w600, fontSize: 13)),
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
                        color: sel ? kPrimary : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? kPrimary : kBorder,
                            width: sel ? 1.5 : 1),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(f.icon, color: sel ? Colors.white : kTextMuted, size: 12),
                        const SizedBox(width: 5),
                        Text(f.label,
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : kTextSecondary)),
                      ]),
                    ),
                  );
                }).toList(),
          ),
          const SizedBox(height: 10),
          // Custom range
          GestureDetector(
            onTap: () => setState(() => _sel = _DateFilter.custom),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _sel == _DateFilter.custom
                    ? kPrimaryLight : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _sel == _DateFilter.custom ? kPrimary : kBorder,
                    width: _sel == _DateFilter.custom ? 1.5 : 1),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(Icons.tune_rounded,
                      color: _sel == _DateFilter.custom ? kPrimary : kTextMuted,
                      size: 15),
                  const SizedBox(width: 7),
                  Text('Custom Date Range',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600,
                          color: _sel == _DateFilter.custom ? kPrimary : kTextMuted)),
                ]),
                if (_sel == _DateFilter.custom) ...[
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(child: _datePick('From', _from, () => _pick(true))),
                    const SizedBox(width: 8),
                    Expanded(child: _datePick('To', _to, () => _pick(false))),
                  ]),
                ],
              ]),
            ),
          ),
          const SizedBox(height: 14),
          const Text('Sort Order',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
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
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Apply Filter',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ]),
      );

  Widget _datePick(String label, DateTime? val, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: kPrimary, size: 13),
            const SizedBox(width: 7),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted)),
              Text(val != null ? _fmt(val) : 'Select',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: val != null ? kTextPrimary : kTextMuted)),
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
            color: sel ? kPrimary : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? kPrimary : kBorder),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, color: sel ? Colors.white : kTextMuted, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : kTextSecondary)),
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  PRESCRIPTION VIEW SCREEN
// ════════════════════════════════════════════════════════════════════
class PatientPrescriptionViewScreen extends ConsumerStatefulWidget {
  final int prescriptionId;
  final PatientPrescription fallback;
  final int patientId;
  const PatientPrescriptionViewScreen({
    super.key, required this.prescriptionId,
    required this.fallback, required this.patientId,
  });
  @override
  ConsumerState<PatientPrescriptionViewScreen> createState() =>
      _PatientPrescriptionViewScreenState();
}

class _PatientPrescriptionViewScreenState
    extends ConsumerState<PatientPrescriptionViewScreen> {
  late PatientPrescription _rx;

  @override void initState() {
    super.initState();
    _rx = widget.fallback;
    Future.microtask(() => ref
        .read(prescriptionViewModelProvider.notifier)
        .patientPrescriptionDetails(widget.prescriptionId));
  }

  String _fmtDate(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  String _fmtDateTime(DateTime d) {
    const months = ['','January','February','March','April','May','June',
        'July','August','September','October','November','December'];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.day} ${months[d.month]} ${d.year}  ·  $h:$min ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  static const _typeColor = {
    1: kInfo, 2: kPurple, 3: kError,
    4: kPrimary, 5: kSuccess, 6: kWarning,
     7: Color(0xFF4DD9C8),   // powders — teal
  8: Color(0xFF1E40AF),  
  };
  static const _typeLabel = {
    1: 'Tablet', 2: 'Syrup', 3: 'Injection',
    4: 'Drops',  5: 'Lotion', 6: 'Spray',
     7: 'Powder', 8: 'Inhaler',
  };
  static const _typeIcon = {
    1: Icons.medication_rounded,  2: Icons.local_drink_rounded,
    3: Icons.vaccines_rounded,    4: Icons.water_drop_rounded,
    5: Icons.soap_rounded,        6: Icons.air_rounded,
      7: Icons.grain_rounded,       8: Icons.air_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prescriptionViewModelProvider);
    final details = state.prescriptionDetailsPatient;
    if (details != null && details.isNotEmpty) {
      _rx = PatientPrescription.fromFlatList(details,
          fallbackPatientId:   ref.read(patientLoginViewModelProvider).patientId ?? 0,
          fallbackPatientName: ref.read(patientLoginViewModelProvider).name ?? 'Patient');
    }

    return Scaffold(
      backgroundColor: Colors.white,
      // ── AppBar — consistent with all screens ──────────────────────
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
         margin: const EdgeInsets.all(10), 
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kPrimary.withOpacity(0.2)),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: kPrimary, size: 15),
          ),
        ),
        leadingWidth: 54,
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: kPrimary.withOpacity(0.2)),
            ),
            child: const Icon(Icons.description_rounded,
                color: kPrimary, size: 15),
          ),
          const SizedBox(width: 8),
          const Text('Prescription Details',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                  letterSpacing: -0.2)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: kBorder, height: 1),
        ),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 100),
            children: [
              _buildClinicCard(),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Column(children: [
                  _buildPatientRow(),
                  if (_rx.diagnosis?.isNotEmpty == true) ...[
                    const SizedBox(height: 10), _buildDiagnosisCard()],
                  if (_rx.symptoms?.isNotEmpty == true) ...[
                    const SizedBox(height: 10), _buildSymptomsCard()],
                  const SizedBox(height: 10), _buildMedicinesCard(),
                  const SizedBox(height: 10), _buildNotesRow(),
                  if (_rx.followUpDate != null) ...[
                    const SizedBox(height: 10), _buildFollowUpCard()],
                  const SizedBox(height: 10), _buildFooter(),
                  const SizedBox(height: 10),
                ]),
              ),
            ],
          ),
          if (state.isLoading)
            Container(
              color: Colors.black.withOpacity(0.15),
              child: const Center(
                  child: CircularProgressIndicator(
                      color: kPrimary, strokeWidth: 2.5)),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ── Clinic card ─────────────────────────────────────────────────────
  Widget _buildClinicCard() => Container(
        margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05),
                blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // Teal gradient header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                  colors: [kPrimaryDark, kPrimary],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.local_hospital_rounded,
                    color: Colors.white, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_rx.clinicName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 14,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${_rx.clinicAddress}  ·  Ph: ${_rx.clinicContact}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.82), fontSize: 11)),
                ],
              )),
            ]),
          ),
          // Doctor sub-strip
          Container(
            width: double.infinity,
            color: kPrimaryDark,
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_rx.doctorName,
                      style: const TextStyle(
                          color: Colors.white, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('${_rx.qualification}  ·  ${_rx.specialization}',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.78), fontSize: 11)),
                  if (_rx.regNo?.isNotEmpty == true)
                    Text('Reg. ${_rx.regNo}',
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.65), fontSize: 10)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withOpacity(0.35)),
                ),
                child: Text('Rx #${_rx.prescriptionId}',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 12,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),
        ]),
      );

  // ── Patient row ─────────────────────────────────────────────────────
  Widget _buildPatientRow() => _Card(
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text(
              _rx.patientName.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join(),
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_rx.patientName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 4),
              Wrap(spacing: 5, children: [
                if (_rx.patientAge != null && _rx.patientAge! > 0)
                  _Chip('${_rx.patientAge} yrs'),
                if (_rx.patientGender?.isNotEmpty == true)
                  _Chip(_rx.patientGender!),
                if (_rx.tokenNumber != null)
                  _Chip('Token #${_rx.tokenNumber}'),
              ]),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Date',
                style: TextStyle(fontSize: 10, color: kTextMuted)),
            const SizedBox(height: 2),
            Text(_fmtDate(_rx.prescriptionDate),
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
          ]),
        ]),
      );

  // ── Symptoms card ───────────────────────────────────────────────────
  Widget _buildSymptomsCard() => _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionLbl('SYMPTOMS', kWarning),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kAmberLight.withOpacity(0.5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAmberLight),
            ),
            child: Text(_rx.symptoms!,
                style: const TextStyle(fontSize: 13, color: kTextPrimary, height: 1.45)),
          ),
        ]),
      );

  // ── Diagnosis card ──────────────────────────────────────────────────
  Widget _buildDiagnosisCard() => _Card(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _SectionLbl('DIAGNOSIS', kPrimary),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: kPrimaryLight, borderRadius: BorderRadius.circular(10)),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.all(5),
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                    color: kPrimary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6)),
                child: const Icon(Icons.biotech_rounded, color: kPrimary, size: 13),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(_rx.diagnosis!,
                  style: const TextStyle(
                      fontSize: 13, color: kTextPrimary,
                      fontWeight: FontWeight.w500, height: 1.45))),
            ]),
          ),
        ]),
      );

  // ── Medicines card ──────────────────────────────────────────────────
  Widget _buildMedicinesCard() => _Card(
        padding: EdgeInsets.zero,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: _SectionLbl('MEDICINES', kPrimary),
          ),
          LayoutBuilder(builder: (ctx, c) {
            final w  = c.maxWidth - 24;
            final c1 = w * 0.28, c2 = w * 0.30, c3 = w * 0.24, c4 = w * 0.18;
            return Column(children: [
              Container(
                color: const Color(0xFFF7F8FA),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: Row(children: [
                  SizedBox(width: c1, child: const _ColHead('MEDICINE')),
                  SizedBox(width: c2, child: const _ColHead2('FREQ/DOSE')),
                  SizedBox(width: c3, child: const _ColHead2('TIMING')),
                  SizedBox(width: c4, child: const _ColHead2('DURATION')),
                ]),
              ),
              const Divider(height: 1, color: kBorder),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _rx.medicines.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: kBorder, indent: 12),
                itemBuilder: (_, i) {
                  final m   = _rx.medicines[i];
                  final col = _typeColor[m.medicineTypeId] ?? kTextMuted;
                  final lbl = _typeLabel[m.medicineTypeId] ?? m.mediTypeName ?? 'Med';
                  final ic  = _typeIcon[m.medicineTypeId] ?? Icons.medication_rounded;
                  return _MedRow(med: m, color: col, typeLabel: lbl, typeIcon: ic,
                      c1: c1, c2: c2, c3: c3, c4: c4);
                },
              ),
            ]);
          }),
        ]),
      );

  // ── Notes row ───────────────────────────────────────────────────────
  Widget _buildNotesRow() {
    final hasClinical = _rx.clinicalNotes?.isNotEmpty == true;
    final hasAdvice   = _rx.advice?.isNotEmpty == true;
    if (!hasClinical && !hasAdvice) return const SizedBox.shrink();
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (hasClinical) Expanded(child: _noteBox(
        color: kInfoLight.withOpacity(0.3), borderColor: kInfoLight,
        iconColor: kInfo, icon: Icons.notes_rounded,
        title: 'INSTRUCTIONS', text: _rx.clinicalNotes!)),
      if (hasClinical && hasAdvice) const SizedBox(width: 10),
      if (hasAdvice) Expanded(child: _noteBox(
        color: kGreenLight.withOpacity(0.4), borderColor: kGreenLight,
        iconColor: kSuccess, icon: Icons.medical_information_rounded,
        title: "ADVICE", text: _rx.advice!)),
    ]);
  }

  Widget _noteBox({required Color color, required Color borderColor,
      required Color iconColor, required IconData icon,
      required String title, required String text}) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, color: iconColor, size: 12),
            const SizedBox(width: 5),
            Text(title,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: iconColor, letterSpacing: 0.4)),
          ]),
          const SizedBox(height: 7),
          Text(text,
              style: const TextStyle(fontSize: 12, color: kTextPrimary, height: 1.5)),
        ]),
      );

  // ── Follow-up card ──────────────────────────────────────────────────
  Widget _buildFollowUpCard() => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kGreenLight.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kGreenLight),
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: kSuccess.withOpacity(0.15),
                borderRadius: BorderRadius.circular(11)),
            child: const Icon(Icons.event_available_rounded,
                color: kSuccess, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('NEXT FOLLOW-UP',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    color: kSuccess, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(_fmtDateTime(_rx.followUpDate!),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
            if (_rx.followUpRoom?.isNotEmpty == true ||
                _rx.followUpInstruction?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(
                [
                  if (_rx.followUpRoom?.isNotEmpty == true) _rx.followUpRoom!,
                  if (_rx.followUpInstruction?.isNotEmpty == true)
                    _rx.followUpInstruction!,
                ].join('  ·  '),
                style: const TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
          ])),
        ]),
      );

  // ── Footer ──────────────────────────────────────────────────────────
  Widget _buildFooter() => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Valid for 30 days from issue date.',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
          SizedBox(height: 2),
          Text('Dispensed by licensed pharmacist only.',
              style: TextStyle(fontSize: 11, color: kTextMuted)),
        ])),
        SizedBox(
          width: 140,
          child: Column(children: [
            const Divider(color: kTextPrimary, thickness: 0.8),
            const SizedBox(height: 3),
            Text(_rx.doctorName,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
            Text('${_rx.qualification}  ·  ${_rx.specialization}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 10, color: kTextMuted)),
          ]),
        ),
      ]);

  // ── Bottom bar ──────────────────────────────────────────────────────
  Widget _buildBottomBar() => Container(
        padding: EdgeInsets.fromLTRB(
            14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorder, width: 1)),
        ),
        child: Row(children: [
          Expanded(child: _botBtn(Icons.download_rounded, 'Download', () =>
              _pushPdf())),
          const SizedBox(width: 10),
          Expanded(child: _botBtn(Icons.share_rounded, 'Share', () =>
              _pushPdf())),
        ]),
      );

  void _pushPdf() => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) =>
              PatientPrescriptionPdfScreen(prescription: _rx),
          transitionsBuilder: (_, anim, __, child) => SlideTransition(
            position: Tween<Offset>(
                    begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
            child: child,
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      );

  Widget _botBtn(IconData ic, String lbl, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: kPrimary, borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(ic, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(lbl,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700,
                    fontSize: 13)),
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SHARED CARD CONTAINER
// ════════════════════════════════════════════════════════════════════
class _Card extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const _Card({required this.child,
      this.padding = const EdgeInsets.all(14)});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );
}

// ── Chip ──────────────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: kPrimaryLight, borderRadius: BorderRadius.circular(6)),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500, color: kPrimary)),
      );
}

// ── Section label ─────────────────────────────────────────────────────────────
class _SectionLbl extends StatelessWidget {
  final String text; final Color color;
  const _SectionLbl(this.text, this.color);
  @override
  Widget build(BuildContext context) => Row(children: [
        Container(width: 3, height: 13,
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 7),
        Text(text, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: color, letterSpacing: 0.6)),
      ]);
}

// ════════════════════════════════════════════════════════════════════
//  MEDICINE ROW
// ════════════════════════════════════════════════════════════════════
class _MedRow extends StatelessWidget {
  final PrescriptionMedicineItem med;
  final Color color; final String typeLabel; final IconData typeIcon;
  final double c1, c2, c3, c4;
  const _MedRow({required this.med, required this.color,
      required this.typeLabel, required this.typeIcon,
      required this.c1, required this.c2, required this.c3, required this.c4});

  List<String> _splitSlots(String? raw) {
    final parts = (raw ?? '').split('-').map((p) => p.trim()).toList();
    while (parts.length < 3) parts.add('-');
    return parts.take(3).map((p) => p.isEmpty ? '-' : p).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dose = _splitSlots(med.doseDisplay);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: c1,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              med.medicineName?.isNotEmpty == true
                  ? med.medicineName! : 'Med #${med.medicineId ?? '-'}',
              maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary),
            ),
            if (med.extraInfo?.isNotEmpty == true) ...[
              const SizedBox(height: 2),
              Text(med.extraInfo!,
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 10, color: color)),
            ],
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(4)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(typeIcon, color: color, size: 9),
                const SizedBox(width: 3),
                Flexible(child: Text(typeLabel,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w700, color: color))),
              ]),
            ),
          ]),
        ),
        SizedBox(width: c2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    Expanded(child: _SlotHead('M')),
                    Expanded(child: _SlotHead('A')),
                    Expanded(child: _SlotHead('N')),
                  ]),
              const SizedBox(height: 3),
              const Divider(height: 1, thickness: 0.8, color: kBorder),
              const SizedBox(height: 3),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Expanded(child: _SlotVal(dose[0])),
                Expanded(child: _SlotVal(dose[1])),
                Expanded(child: _SlotVal(dose[2])),
              ]),
            ]),
          ),
        ),
        SizedBox(width: c3,
          child: Text(med.timing ?? '-',
              textAlign: TextAlign.center, maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600, color: kTextPrimary)),
        ),
        SizedBox(width: c4,
          child: Text(med.duration ?? '-',
              textAlign: TextAlign.center, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700, color: kTextPrimary)),
        ),
      ]),
    );
  }
}

class _SlotHead extends StatelessWidget {
  final String text; const _SlotHead(this.text);
  @override Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextMuted));
}
class _SlotVal extends StatelessWidget {
  final String text; const _SlotVal(this.text);
  @override Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown, alignment: Alignment.center,
        child: Text(text, textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)));
}
class _ColHead extends StatelessWidget {
  final String text; const _ColHead(this.text);
  @override Widget build(BuildContext context) => Text(text,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
          color: kTextMuted, letterSpacing: 0.3),
      maxLines: 1, overflow: TextOverflow.ellipsis);
}
class _ColHead2 extends StatelessWidget {
  final String text; const _ColHead2(this.text);
  @override Widget build(BuildContext context) => Text(text,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
          color: kTextMuted, letterSpacing: 0.3),
      maxLines: 1, overflow: TextOverflow.ellipsis);
}

// ════════════════════════════════════════════════════════════════════
//  ADAPTER MODELS (unchanged logic)
// ════════════════════════════════════════════════════════════════════
DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}
DateTime _parseDateOrNow(String? raw) => _tryParseDate(raw) ?? DateTime.now();
String _statusFromFollowUp(DateTime? fu) {
  if (fu == null) return 'completed';
  return fu.isAfter(DateTime.now()) ? 'active' : 'completed';
}

class PatientPrescription {
  final int prescriptionId, patientId;
  final String patientName, doctorName, qualification, specialization,
      clinicName, clinicAddress, clinicContact, status;
  final int? patientAge, tokenNumber;
  final String? patientGender, regNo, followUpRoom, followUpInstruction,
      symptoms, diagnosis, clinicalNotes, advice;
  final DateTime prescriptionDate;
  final DateTime? followUpDate;
  final List<PrescriptionMedicineItem> medicines;

  const PatientPrescription({
    required this.prescriptionId, required this.patientId,
    required this.patientName, required this.doctorName,
    required this.qualification, required this.specialization,
    required this.clinicName, required this.clinicAddress,
    required this.clinicContact, required this.prescriptionDate,
    required this.medicines, required this.status,
    this.patientAge, this.tokenNumber, this.patientGender,
    this.regNo, this.followUpRoom, this.followUpInstruction,
    this.symptoms, this.diagnosis, this.clinicalNotes,
    this.followUpDate, this.advice,
  });

  factory PatientPrescription.fromModel(PrescriptionModel model,
      {required int fallbackPatientId, required String fallbackPatientName}) {
    final fu = _tryParseDate(model.followUpDate);
    final flatMeds = (model.medicines == null || model.medicines!.isEmpty)
        ? [if (model.medicineId != null || model.medicineName != null)
            PrescriptionMedicineItem.fromFlatModel(model)]
        : <PrescriptionMedicineItem>[];
    return PatientPrescription(
      prescriptionId: model.prescriptionId ?? 0,
      patientId: model.patientId ?? fallbackPatientId,
      patientName: model.patientName ?? fallbackPatientName,
      doctorName: model.doctorName ??
          (model.doctorId != null ? 'Doctor #${model.doctorId}' : 'Doctor'),
      qualification: model.qualification ?? '-',
      specialization: model.specialization ?? '-',
      clinicName: model.clinicName ?? 'Clinic',
      clinicAddress: model.clinicAddress ?? '-',
      clinicContact: model.clinicContact ?? '-',
      prescriptionDate: _parseDateOrNow(model.prescriptionDate),
      symptoms: model.symptoms, diagnosis: model.diagnosis,
      clinicalNotes: model.clinicalNotes, followUpDate: fu, advice: model.advice,
      medicines: (model.medicines ?? <PrescriptionMedicineModel>[])
              .map(PrescriptionMedicineItem.fromModel).toList() + flatMeds,
      status: _statusFromFollowUp(fu),
    );
  }

  factory PatientPrescription.fromFlatList(List<PrescriptionModel> items,
      {required int fallbackPatientId, required String fallbackPatientName}) {
    final first = items.first;
    final fu = _tryParseDate(first.followUpDate);
    final meds = items.map(PrescriptionMedicineItem.fromFlatModel)
        .where((m) => m.medicineId != null || m.medicineName != null).toList();
    return PatientPrescription(
      prescriptionId: first.prescriptionId ?? 0,
      patientId: first.patientId ?? fallbackPatientId,
      patientName: first.patientName ?? fallbackPatientName,
      doctorName: first.doctorName ??
          (first.doctorId != null ? 'Doctor #${first.doctorId}' : 'Doctor'),
      qualification: first.qualification ?? '-',
      specialization: first.specialization ?? '-',
      clinicName: first.clinicName ?? 'Clinic',
      clinicAddress: first.clinicAddress ?? '-',
      clinicContact: first.clinicContact ?? '-',
      prescriptionDate: _parseDateOrNow(first.prescriptionDate),
      symptoms: first.symptoms, diagnosis: first.diagnosis,
      clinicalNotes: first.clinicalNotes, followUpDate: fu, advice: first.advice,
      medicines: meds, status: _statusFromFollowUp(fu),
    );
  }
}

class PrescriptionMedicineItem {
  final int? medicineId;
  final int medicineTypeId;
  final String? mediTypeName, medicineName, frequency, duration, timing,
      tabletDosage, syrupDosageMl, injDosage, injRoute, dropsCount,
      dropsApplication, lotionApplyArea, sprayPuffs, sprayUsage, lotionUsage,
         powderDosage, powderForm,
      inhalerPuffs, inhalerType, inhalerTechnique, inhalerUsage;

  const PrescriptionMedicineItem({
    required this.medicineId, required this.medicineTypeId,
    required this.mediTypeName, required this.medicineName,
    required this.frequency, required this.duration, required this.timing,
    required this.tabletDosage, required this.syrupDosageMl,
    required this.injDosage, required this.injRoute, required this.dropsCount,
    required this.dropsApplication, required this.lotionApplyArea,
    required this.sprayPuffs, required this.sprayUsage, required this.lotionUsage,
     this.powderDosage, this.powderForm,
    this.inhalerPuffs, this.inhalerType,
    this.inhalerTechnique, this.inhalerUsage,
  });

  String? get extraInfo {
    if (injRoute?.trim().isNotEmpty == true) return injRoute;
    if (dropsApplication?.trim().isNotEmpty == true) return dropsApplication;
    if (lotionApplyArea?.trim().isNotEmpty == true) return lotionApplyArea;
    if (sprayUsage?.trim().isNotEmpty == true) return sprayUsage;
    if (powderForm?.trim().isNotEmpty == true)       return powderForm;        // NEW
    if (inhalerType?.trim().isNotEmpty == true)      return inhalerType;       // NEW
    if (inhalerTechnique?.trim().isNotEmpty == true) return inhalerTechnique; 
    return null;
  }

  String get doseDisplay {
    if (tabletDosage?.trim().isNotEmpty == true) return tabletDosage!;
    if (syrupDosageMl?.trim().isNotEmpty == true) return syrupDosageMl!;
    if (injDosage?.trim().isNotEmpty == true) return injDosage!;
    if (dropsCount?.trim().isNotEmpty == true) return dropsCount!;
    if (sprayPuffs?.trim().isNotEmpty == true) return sprayPuffs!;
    if (lotionUsage?.trim().isNotEmpty == true) return lotionUsage!;
       if (powderDosage?.trim().isNotEmpty == true)  return powderDosage!;  // NEW
    if (inhalerPuffs?.trim().isNotEmpty == true)  return inhalerPuffs!;  
    return '-';
  }

  factory PrescriptionMedicineItem.fromModel(PrescriptionMedicineModel model) =>
      PrescriptionMedicineItem(
        medicineId: model.medicineId, medicineTypeId: model.medicineTypeId ?? 1,
        mediTypeName: null, medicineName: null,
        frequency: model.frequency, duration: model.duration, timing: model.timing,
        tabletDosage: model.tabletDosage, syrupDosageMl: model.syrupDosageMl,
        injDosage: model.injDosage, injRoute: model.injRoute,
        dropsCount: model.dropsCount, dropsApplication: model.dropsApplication,
        lotionApplyArea: model.lotionApplyArea, sprayPuffs: model.sprayPuffs,
        sprayUsage: model.sprayUsage, lotionUsage: model.lotionUsage,
          powderDosage: model.powderDosage, powderForm: model.powderForm,
        inhalerPuffs: model.inhalerPuffs, inhalerType: model.inhalerType,
        inhalerTechnique: model.inhalerTechnique, inhalerUsage: model.inhalerUsage,
      );

  factory PrescriptionMedicineItem.fromFlatModel(PrescriptionModel model) =>
      PrescriptionMedicineItem(
        medicineId: model.medicineId, medicineTypeId: model.medicineTypeId ?? 1,
        mediTypeName: model.mediTypeName, medicineName: model.medicineName,
        frequency: model.frequency, duration: model.duration, timing: model.timing,
        tabletDosage: model.tabletDosage, syrupDosageMl: model.syrupDosageMl,
        injDosage: model.injDosage, injRoute: model.injRoute,
        dropsCount: model.dropsCount, dropsApplication: model.dropsApplication,
        lotionApplyArea: model.lotionApplyArea, sprayPuffs: model.sprayPuffs,
        sprayUsage: model.sprayUsage, lotionUsage: model.lotionUsage,
         powderDosage: model.powderDosage, powderForm: model.powderForm,
        inhalerPuffs: model.inhalerPuffs, inhalerType: model.inhalerType,
        inhalerTechnique: model.inhalerTechnique, inhalerUsage: model.inhalerUsage,
      );
}

// ════════════════════════════════════════════════════════════════════
//  PRESCRIPTION SKELETON
// ════════════════════════════════════════════════════════════════════
class _PrescriptionSkeletonList extends StatefulWidget {
  const _PrescriptionSkeletonList();
  @override
  State<_PrescriptionSkeletonList> createState() =>
      _PrescriptionSkeletonListState();
}

class _PrescriptionSkeletonListState extends State<_PrescriptionSkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => ListView.separated(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 30),
          itemCount: 5,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (_, __) => _PrescriptionSkeletonCard(phase: _anim.value),
        ),
      );
}

class _PrescriptionSkeletonCard extends StatelessWidget {
  final double phase;
  const _PrescriptionSkeletonCard({required this.phase});

  Widget _bar({double? width, required double height, double radius = 5}) =>
      Container(
        width: width, height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(phase - 1, 0),
            end: Alignment(phase + 1, 0),
            colors: const [
              Color(0xFFEDF2F7), Color(0xFFE2E8F0),
              Color(0xFFCBD5E0), Color(0xFFE2E8F0), Color(0xFFEDF2F7),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03),
                blurRadius: 8, offset: const Offset(0, 3))
          ],
        ),
        child: Column(children: [
          // Top strip skeleton
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8FA),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Row(children: [
              _bar(width: 70, height: 18, radius: 5),
              const SizedBox(width: 8),
              _bar(width: 80, height: 10),
              const Spacer(),
              _bar(width: 60, height: 18, radius: 5),
            ]),
          ),
          // Body skeleton
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
            child: Row(children: [
              _bar(width: 34, height: 34, radius: 9), // avatar
              const SizedBox(width: 8),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 130, height: 12),
                  _bar(width: 80, height: 10),
                ],
              )),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                _bar(width: 90, height: 12),
                _bar(width: 44, height: 16, radius: 4),
              ]),
            ]),
          ),
          // Bottom strip skeleton
          Container(
            decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder))),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(children: [
              _bar(width: 55, height: 18, radius: 5),
              const SizedBox(width: 6),
              _bar(width: 80, height: 18, radius: 5),
              const Spacer(),
              _bar(width: 52, height: 28, radius: 7),
            ]),
          ),
        ]),
      );
}
