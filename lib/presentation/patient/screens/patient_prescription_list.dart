// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:qless/domain/models/family_member.dart';
// import 'package:qless/domain/models/prescription.dart';
// import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
// import 'package:qless/presentation/doctor/view_models/prescription_viewmodel.dart';
// import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
// import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
// import 'package:qless/core/network/token_provider.dart';

// // ── Colour palette ────────────────────────────────────────────────
// const kPrimary = Color(0xFF1A73E8);
// const kPrimaryBg = Color(0xFFE8F0FE);
// const kBg = Color(0xFFF4F6FB);
// const kCardBg = Colors.white;
// const kTextDark = Color(0xFF1F2937);
// const kTextMid = Color(0xFF6B7280);
// const kBorder = Color(0xFFE5E7EB);
// const kRed = Color(0xFFEA4335);
// const kGreen = Color(0xFF34A853);
// const kOrange = Color(0xFFF59E0B);
// const kPurple = Color(0xFF8B5CF6);
// const kCyan = Color(0xFF06B6D4);

// // ── Date filter options ───────────────────────────────────────────
// enum _DateFilter {
//   all,
//   today,
//   thisWeek,
//   thisMonth,
//   last3Months,
//   last6Months,
//   thisYear,
//   custom,
// }

// extension _DateFilterLabel on _DateFilter {
//   String get label {
//     switch (this) {
//       case _DateFilter.all:
//         return 'All Time';
//       case _DateFilter.today:
//         return 'Today';
//       case _DateFilter.thisWeek:
//         return 'This Week';
//       case _DateFilter.thisMonth:
//         return 'This Month';
//       case _DateFilter.last3Months:
//         return 'Last 3 Months';
//       case _DateFilter.last6Months:
//         return 'Last 6 Months';
//       case _DateFilter.thisYear:
//         return 'This Year';
//       case _DateFilter.custom:
//         return 'Custom Range';
//     }
//   }

//   IconData get icon {
//     switch (this) {
//       case _DateFilter.all:
//         return Icons.all_inclusive_rounded;
//       case _DateFilter.today:
//         return Icons.today_rounded;
//       case _DateFilter.thisWeek:
//         return Icons.view_week_rounded;
//       case _DateFilter.thisMonth:
//         return Icons.calendar_month_rounded;
//       case _DateFilter.last3Months:
//         return Icons.date_range_rounded;
//       case _DateFilter.last6Months:
//         return Icons.date_range_rounded;
//       case _DateFilter.thisYear:
//         return Icons.calendar_today_rounded;
//       case _DateFilter.custom:
//         return Icons.tune_rounded;
//     }
//   }
// }

// // ════════════════════════════════════════════════════════════════════
// //  PRESCRIPTION LIST SCREEN
// // ════════════════════════════════════════════════════════════════════
// class PatientPrescriptionListScreen extends ConsumerStatefulWidget {
//   const PatientPrescriptionListScreen({super.key});

//   @override
//   ConsumerState<PatientPrescriptionListScreen> createState() =>
//       _PatientPrescriptionListScreenState();
// }

// class _PatientPrescriptionListScreenState
//     extends ConsumerState<PatientPrescriptionListScreen>
//     with SingleTickerProviderStateMixin {
//   late final TabController _tabCtrl;
//   String _search = '';
//   final _searchCtrl = TextEditingController();
//   bool _hasFetched = false;
//   bool _hasFetchedFamily = false;
//   ProviderSubscription<PatientLoginState>? _patientSub;
//   ProviderSubscription<TokenState>? _tokenSub;

//   _DateFilter _dateFilter = _DateFilter.all;
//   DateTime? _customFrom;
//   DateTime? _customTo;
//   bool _sortNewestFirst = true;
//   static const int _filterAll = -1;
//   static const int _filterSelf = -2;
//   int _memberFilter = _filterAll;

//   @override
//   void initState() {
//     super.initState();
//     _tabCtrl = TabController(length: 3, vsync: this);
//     Future.microtask(() {
//       ref.read(tokenProvider.notifier).loadTokens();
//       ref.read(patientLoginViewModelProvider.notifier).loadFromStoragePatient();
//     });
//     _patientSub = ref.listenManual<PatientLoginState>(
//       patientLoginViewModelProvider,
//       (prev, next) => _tryFetch(),
//     );
//     _tokenSub = ref.listenManual<TokenState>(
//       tokenProvider,
//       (prev, next) => _tryFetch(),
//     );
//     WidgetsBinding.instance.addPostFrameCallback((_) => _tryFetch());
//   }

//   void _tryFetch() {
//     final patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
//     final tokenState = ref.read(tokenProvider);
//     final tokenReady =
//         !tokenState.isLoading && (tokenState.accessToken ?? '').isNotEmpty;
//     if (tokenReady && patientId == 0) {
//       ref.read(patientLoginViewModelProvider.notifier).loadFromStoragePatient();
//       return;
//     }
//     if (patientId > 0 && tokenReady && !_hasFetched) {
//       _hasFetched = true;
//       ref
//           .read(prescriptionViewModelProvider.notifier)
//           .patientPrescriptionList(patientId);
//     }

//     if (tokenReady && patientId > 0 && !_hasFetchedFamily) {
//       _hasFetchedFamily = true;
//       ref
//           .read(familyViewModelProvider.notifier)
//           .fetchAllFamilyMembers(patientId);
//     }
//   }

//   @override
//   void dispose() {
//     _patientSub?.close();
//     _tokenSub?.close();
//     _tabCtrl.dispose();
//     _searchCtrl.dispose();
//     super.dispose();
//   }

//   PrescriptionState get _state => ref.watch(prescriptionViewModelProvider);

//   bool _passesDateFilter(PatientPrescription p) {
//     final now = DateTime.now();
//     final d = p.prescriptionDate;
//     switch (_dateFilter) {
//       case _DateFilter.all:
//         return true;
//       case _DateFilter.today:
//         return d.year == now.year && d.month == now.month && d.day == now.day;
//       case _DateFilter.thisWeek:
//         final start = now.subtract(Duration(days: now.weekday - 1));
//         final from = DateTime(start.year, start.month, start.day);
//         return d.isAfter(from.subtract(const Duration(seconds: 1)));
//       case _DateFilter.thisMonth:
//         return d.year == now.year && d.month == now.month;
//       case _DateFilter.last3Months:
//         return d.isAfter(now.subtract(const Duration(days: 90)));
//       case _DateFilter.last6Months:
//         return d.isAfter(now.subtract(const Duration(days: 180)));
//       case _DateFilter.thisYear:
//         return d.year == now.year;
//       case _DateFilter.custom:
//         if (_customFrom != null && d.isBefore(_customFrom!)) return false;
//         if (_customTo != null &&
//             d.isAfter(_customTo!.add(const Duration(days: 1))))
//           return false;
//         return true;
//     }
//   }

//   List<PatientPrescription> _filtered(
//     List<PatientPrescription> source,
//     String statusFilter,
//     int patientId,
//     String patientName,
//     List<FamilyMember> members,
//   ) {
//     var list = source.where((p) {
//       if (statusFilter != 'all' && p.status != statusFilter) return false;
//       if (!_passesMemberFilter(p, patientId, patientName, members))
//         return false;
//       if (!_passesDateFilter(p)) return false;
//       if (_search.trim().isNotEmpty) {
//         final q = _search.toLowerCase();
//         if (!(p.diagnosis ?? '').toLowerCase().contains(q) &&
//             !p.prescriptionId.toString().contains(q) &&
//             !p.doctorName.toLowerCase().contains(q))
//           return false;
//       }
//       return true;
//     }).toList();

//     list.sort(
//       (a, b) => _sortNewestFirst
//           ? b.prescriptionDate.compareTo(a.prescriptionDate)
//           : a.prescriptionDate.compareTo(b.prescriptionDate),
//     );
//     return list;
//   }

//   bool _passesMemberFilter(
//     PatientPrescription p,
//     int patientId,
//     String patientName,
//     List<FamilyMember> members,
//   ) {
//     if (_memberFilter == _filterAll) return true;
//     if (_memberFilter == _filterSelf) {
//       if (patientId > 0 && p.patientId == patientId) return true;
//       final selfName = patientName.trim().toLowerCase();
//       return selfName.isNotEmpty && p.patientName.toLowerCase() == selfName;
//     }
//     if (_memberFilter > 0 && p.patientId == _memberFilter) return true;
//     final member = members
//         .where((m) => m.memberId == _memberFilter)
//         .cast<FamilyMember?>()
//         .firstWhere((m) => m != null, orElse: () => null);
//     final memberName = member?.memberName?.trim().toLowerCase();
//     return memberName != null &&
//         memberName.isNotEmpty &&
//         p.patientName.toLowerCase() == memberName;
//   }

//   String _fmtDate(DateTime d) {
//     const m = [
//       '',
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//     return '${d.day} ${m[d.month]} ${d.year}';
//   }

//   void _openDetail(PatientPrescription p) {
//     Navigator.push(
//       context,
//       PageRouteBuilder(
//         pageBuilder: (_, anim, __) => PatientPrescriptionViewScreen(
//           prescriptionId: p.prescriptionId,
//           fallback: p,
//           patientId: ref.read(patientLoginViewModelProvider).patientId ?? 0,
//         ),
//         transitionsBuilder: (_, anim, __, child) => SlideTransition(
//           position: Tween<Offset>(
//             begin: const Offset(1.0, 0.0),
//             end: Offset.zero,
//           ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
//           child: child,
//         ),
//         transitionDuration: const Duration(milliseconds: 300),
//       ),
//     );
//   }

//   void _showFilterSheet() {
//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.transparent,
//       builder: (_) => _DateFilterSheet(
//         current: _dateFilter,
//         customFrom: _customFrom,
//         customTo: _customTo,
//         sortNewest: _sortNewestFirst,
//         onApply: (filter, from, to, newest) {
//           setState(() {
//             _dateFilter = filter;
//             _customFrom = from;
//             _customTo = to;
//             _sortNewestFirst = newest;
//           });
//         },
//       ),
//     );
//   }

//   bool get _hasActiveFilter =>
//       _dateFilter != _DateFilter.all || !_sortNewestFirst;

//   @override
//   Widget build(BuildContext context) {
//     final patientState = ref.watch(patientLoginViewModelProvider);
//     final patientId = patientState.patientId ?? 0;
//     final patientName = patientState.name ?? 'Patient';
//     final familyState = ref.watch(familyViewModelProvider);
//     final familyMembers = familyState.allfamilyMembers.maybeWhen(
//       data: (members) => members,
//       orElse: () => const <FamilyMember>[],
//     );
//     final tokenState = ref.watch(tokenProvider);
//     final tokenReady =
//         !tokenState.isLoading && (tokenState.accessToken ?? '').isNotEmpty;
//     final waitingAuth = !tokenReady || patientId == 0;

//     final apiList =
//         _state.prescriptionsListPatient ?? const <PrescriptionModel>[];
//     final mapped = apiList
//         .map(
//           (m) => PatientPrescription.fromModel(
//             m,
//             fallbackPatientId: patientId,
//             fallbackPatientName: patientName,
//           ),
//         )
//         .toList();

//     final all = _filtered(mapped, 'all', patientId, patientName, familyMembers);
//     final active =
//         _filtered(mapped, 'active', patientId, patientName, familyMembers);
//     final past = _filtered(
//           mapped,
//           'completed',
//           patientId,
//           patientName,
//           familyMembers,
//         ) +
//         _filtered(mapped, 'expired', patientId, patientName, familyMembers);

//     return Scaffold(
//       backgroundColor: kBg,
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               _buildAppBar(all.length, patientName, familyMembers),
//               _buildSearchFilterRow(),
//               if (_hasActiveFilter) _buildActiveFilterChips(),
//               _buildTabBar(all.length, active.length, past.length),
//               Expanded(
//                 child: TabBarView(
//                   controller: _tabCtrl,
//                   children: [
//                     _buildListBody(all, waitAuth: waitingAuth),
//                     _buildListBody(active, waitAuth: waitingAuth),
//                     _buildListBody(past, waitAuth: waitingAuth),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//           if (_state.isLoading)
//             Container(
//               color: Colors.black.withOpacity(0.25),
//               child: const Center(
//                 child: CircularProgressIndicator(color: kPrimary),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   Widget _buildAppBar(
//     int total,
//     String patientName,
//     List<FamilyMember> members,
//   ) =>
//       Container(
//     decoration: const BoxDecoration(
//       color: kCardBg,
//       border: Border(bottom: BorderSide(color: kBorder, width: 0.5)),
//     ),
//     child: SafeArea(
//       bottom: false,
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(4, 4, 14, 14),
//         child: Row(
//           children: [
//             IconButton(
//               icon: const Icon(
//                 Icons.arrow_back_ios_new_rounded,
//                 color: Colors.black,
//                 size: 18,
//               ),
//               onPressed: () => Navigator.pop(context),
//             ),
//             const SizedBox(width: 2),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   const Text(
//                     'Prescriptions',
//                     style: TextStyle(
//                       color: kTextDark,
//                       fontSize: 18,
//                       fontWeight: FontWeight.w800,
//                       letterSpacing: -0.3,
//                     ),
//                   ),
//                   const SizedBox(height: 2),
//                   Text(
//                     '$total records',
//                     style: TextStyle(color: kTextMid, fontSize: 12),
//                   ),
//                 ],
//               ),
//             ),
//             _memberDropdown(patientName, members),
//           ],
//         ),
//       ),
//     ),
//   );

//   Widget _memberDropdown(String patientName, List<FamilyMember> members) {
//     final items = <DropdownMenuItem<int>>[
//       const DropdownMenuItem<int>(
//         value: _filterAll,
//         child: Text('All'),
//       ),
//       const DropdownMenuItem<int>(
//         value: _filterSelf,
//         child: Text('Self'),
//       ),
//       ...members
//           .where((m) => (m.memberId ?? 0) > 0)
//           .map(
//             (m) => DropdownMenuItem<int>(
//               value: m.memberId!,
//               child: Text(m.memberName ?? 'Member'),
//             ),
//           ),
//     ];

//     final itemValues = items.map((e) => e.value).toSet();

//     return Container(
//       constraints: const BoxConstraints(minWidth: 90, maxWidth: 160),
//       padding: const EdgeInsets.symmetric(horizontal: 8),
//       decoration: BoxDecoration(
//         color: kBg,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: kBorder),
//       ),
//       child: DropdownButtonHideUnderline(
//         child: DropdownButton<int>(
//           value: itemValues.contains(_memberFilter) ? _memberFilter : _filterAll,
//           isDense: true,
//           icon: const Icon(
//             Icons.keyboard_arrow_down_rounded,
//             color: kTextDark,
//             size: 20,
//           ),
//           style: const TextStyle(
//             fontSize: 12,
//             fontWeight: FontWeight.w700,
//             color: kTextDark,
//           ),
//           items: items,
//           onChanged: (val) => setState(() {
//             _memberFilter = val ?? _filterAll;
//           }),
//           selectedItemBuilder: (_) => [
//             const Align(
//               alignment: Alignment.centerLeft,
//               child: Text('All'),
//             ),
//             Align(
//               alignment: Alignment.centerLeft,
//               child: Text(patientName.isNotEmpty ? patientName : 'Self'),
//             ),
//             ...members
//                 .where((m) => (m.memberId ?? 0) > 0)
//                 .map(
//                   (m) => Align(
//                     alignment: Alignment.centerLeft,
//                     child: Text(m.memberName ?? 'Member'),
//                   ),
//                 ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildSearchFilterRow() => Container(
//     color: kCardBg,
//     padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
//     child: Row(
//       children: [
//         Expanded(
//           child: SizedBox(
//             height: 42,
//             child: TextField(
//               controller: _searchCtrl,
//               onChanged: (v) => setState(() => _search = v),
//               style: const TextStyle(fontSize: 13, color: kTextDark),
//               decoration: InputDecoration(
//                 hintText: 'Search diagnosis, Rx, doctor...',
//                 hintStyle: const TextStyle(
//                   fontSize: 12,
//                   color: Color(0xFFB0B8C8),
//                 ),
//                 prefixIcon: const Icon(
//                   Icons.search_rounded,
//                   color: kPrimary,
//                   size: 18,
//                 ),
//                 suffixIcon: _search.isNotEmpty
//                     ? GestureDetector(
//                         onTap: () => setState(() {
//                           _search = '';
//                           _searchCtrl.clear();
//                         }),
//                         child: const Icon(
//                           Icons.close_rounded,
//                           color: kTextMid,
//                           size: 16,
//                         ),
//                       )
//                     : null,
//                 filled: true,
//                 fillColor: kBg,
//                 contentPadding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 0,
//                 ),
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: const BorderSide(color: kBorder),
//                 ),
//                 enabledBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: const BorderSide(color: kBorder),
//                 ),
//                 focusedBorder: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(10),
//                   borderSide: const BorderSide(color: kPrimary, width: 1.5),
//                 ),
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 8),
//         GestureDetector(
//           onTap: _showFilterSheet,
//           child: Container(
//             width: 42,
//             height: 42,
//             decoration: BoxDecoration(
//               color: _hasActiveFilter ? kPrimary : kBg,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: _hasActiveFilter ? kPrimary : kBorder),
//             ),
//             child: Stack(
//               alignment: Alignment.center,
//               children: [
//                 Icon(
//                   Icons.tune_rounded,
//                   color: _hasActiveFilter ? Colors.white : kPrimary,
//                   size: 20,
//                 ),
//                 if (_hasActiveFilter)
//                   Positioned(
//                     top: 7,
//                     right: 7,
//                     child: Container(
//                       width: 7,
//                       height: 7,
//                       decoration: const BoxDecoration(
//                         color: kOrange,
//                         shape: BoxShape.circle,
//                       ),
//                     ),
//                   ),
//               ],
//             ),
//           ),
//         ),
//         const SizedBox(width: 8),
//         GestureDetector(
//           onTap: () => setState(() => _sortNewestFirst = !_sortNewestFirst),
//           child: Container(
//             width: 42,
//             height: 42,
//             decoration: BoxDecoration(
//               color: kBg,
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: kBorder),
//             ),
//             child: Icon(
//               _sortNewestFirst
//                   ? Icons.arrow_downward_rounded
//                   : Icons.arrow_upward_rounded,
//               color: kPrimary,
//               size: 18,
//             ),
//           ),
//         ),
//       ],
//     ),
//   );

//   Widget _buildActiveFilterChips() => Container(
//     color: kCardBg,
//     padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
//     child: Row(
//       children: [
//         if (_dateFilter != _DateFilter.all)
//           _filterChip(
//             icon: _dateFilter.icon,
//             label: _dateFilter == _DateFilter.custom && _customFrom != null
//                 ? '${_fmtDate(_customFrom!)} – ${_customTo != null ? _fmtDate(_customTo!) : '...'}'
//                 : _dateFilter.label,
//             onRemove: () => setState(() => _dateFilter = _DateFilter.all),
//           ),
//         if (!_sortNewestFirst) ...[
//           if (_dateFilter != _DateFilter.all) const SizedBox(width: 6),
//           _filterChip(
//             icon: Icons.arrow_upward_rounded,
//             label: 'Oldest First',
//             onRemove: () => setState(() => _sortNewestFirst = true),
//           ),
//         ],
//       ],
//     ),
//   );

//   Widget _filterChip({
//     required IconData icon,
//     required String label,
//     required VoidCallback onRemove,
//   }) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
//     decoration: BoxDecoration(
//       color: kPrimaryBg,
//       borderRadius: BorderRadius.circular(20),
//       border: Border.all(color: kPrimary.withOpacity(0.3)),
//     ),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, color: kPrimary, size: 12),
//         const SizedBox(width: 5),
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 11,
//             color: kPrimary,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         const SizedBox(width: 5),
//         GestureDetector(
//           onTap: onRemove,
//           child: const Icon(Icons.close_rounded, color: kPrimary, size: 13),
//         ),
//       ],
//     ),
//   );

//   Widget _buildTabBar(int all, int active, int past) => Container(
//     color: kCardBg,
//     child: Column(
//       children: [
//         TabBar(
//           controller: _tabCtrl,
//           labelColor: kPrimary,
//           unselectedLabelColor: kTextMid,
//           indicatorColor: kPrimary,
//           indicatorWeight: 2.5,
//           labelStyle: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w700,
//           ),
//           unselectedLabelStyle: const TextStyle(
//             fontSize: 13,
//             fontWeight: FontWeight.w500,
//           ),
//           tabs: [
//             Tab(text: 'All ($all)'),
//             Tab(text: 'Active ($active)'),
//             Tab(text: 'Past ($past)'),
//           ],
//         ),
//         const Divider(height: 1, color: kBorder),
//       ],
//     ),
//   );

//   Widget _buildListBody(
//     List<PatientPrescription> items, {
//     required bool waitAuth,
//   }) {
//     if (waitAuth) {
//       return const Center(child: CircularProgressIndicator(color: kPrimary));
//     }
//     if (_state.error != null && items.isEmpty)
//       return _errorState(_state.error!);
//     if (items.isEmpty && !_state.isLoading) return _emptyState();
//     return RefreshIndicator(
//       color: kPrimary,
//       onRefresh: () => ref
//           .read(prescriptionViewModelProvider.notifier)
//           .patientPrescriptionList(
//             ref.read(patientLoginViewModelProvider).patientId ?? 0,
//           ),
//       child: ListView.separated(
//         padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
//         itemCount: items.length,
//         separatorBuilder: (_, __) => const SizedBox(height: 8),
//         itemBuilder: (_, i) => _PrescriptionCompactCard(
//           prescription: items[i],
//           fmtDate: _fmtDate,
//           onTap: () => _openDetail(items[i]),
//         ),
//       ),
//     );
//   }

//   Widget _emptyState() => Center(
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(
//           Icons.receipt_long_outlined,
//           size: 52,
//           color: kPrimary.withOpacity(0.2),
//         ),
//         const SizedBox(height: 14),
//         const Text(
//           'No prescriptions found',
//           style: TextStyle(
//             fontSize: 15,
//             color: kTextMid,
//             fontWeight: FontWeight.w600,
//           ),
//         ),
//         const SizedBox(height: 6),
//         const Text(
//           'Try a different filter or search',
//           style: TextStyle(fontSize: 12, color: Color(0xFFB0B8C8)),
//         ),
//         if (_hasActiveFilter) ...[
//           const SizedBox(height: 16),
//           TextButton.icon(
//             onPressed: () => setState(() {
//               _dateFilter = _DateFilter.all;
//               _sortNewestFirst = true;
//             }),
//             icon: const Icon(Icons.clear_all_rounded, size: 16),
//             label: const Text('Clear Filters'),
//             style: TextButton.styleFrom(foregroundColor: kPrimary),
//           ),
//         ],
//       ],
//     ),
//   );

//   Widget _errorState(String msg) => Center(
//     child: Padding(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           const Icon(Icons.wifi_off_rounded, size: 50, color: kRed),
//           const SizedBox(height: 12),
//           Text(
//             msg,
//             textAlign: TextAlign.center,
//             style: const TextStyle(fontSize: 13, color: kTextMid),
//           ),
//           const SizedBox(height: 16),
//           ElevatedButton.icon(
//             onPressed: () => ref
//                 .read(prescriptionViewModelProvider.notifier)
//                 .patientPrescriptionList(
//                   ref.read(patientLoginViewModelProvider).patientId ?? 0,
//                 ),
//             icon: const Icon(Icons.refresh_rounded, size: 16),
//             label: const Text('Retry'),
//             style: ElevatedButton.styleFrom(
//               backgroundColor: kPrimary,
//               foregroundColor: Colors.white,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(10),
//               ),
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// // ════════════════════════════════════════════════════════════════════
// //  DATE FILTER BOTTOM SHEET
// // ════════════════════════════════════════════════════════════════════
// class _DateFilterSheet extends StatefulWidget {
//   final _DateFilter current;
//   final DateTime? customFrom;
//   final DateTime? customTo;
//   final bool sortNewest;
//   final void Function(_DateFilter, DateTime?, DateTime?, bool) onApply;

//   const _DateFilterSheet({
//     required this.current,
//     required this.customFrom,
//     required this.customTo,
//     required this.sortNewest,
//     required this.onApply,
//   });

//   @override
//   State<_DateFilterSheet> createState() => _DateFilterSheetState();
// }

// class _DateFilterSheetState extends State<_DateFilterSheet> {
//   late _DateFilter _sel;
//   late DateTime? _from;
//   late DateTime? _to;
//   late bool _newest;

//   @override
//   void initState() {
//     super.initState();
//     _sel = widget.current;
//     _from = widget.customFrom;
//     _to = widget.customTo;
//     _newest = widget.sortNewest;
//   }

//   String _fmt(DateTime d) {
//     const m = [
//       '',
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//     return '${d.day} ${m[d.month]} ${d.year}';
//   }

//   Future<void> _pickDate({required bool isFrom}) async {
//     final picked = await showDatePicker(
//       context: context,
//       initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
//       firstDate: DateTime(2020),
//       lastDate: DateTime.now().add(const Duration(days: 365)),
//       builder: (ctx, child) => Theme(
//         data: Theme.of(
//           ctx,
//         ).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
//         child: child!,
//       ),
//     );
//     if (picked != null) setState(() => isFrom ? _from = picked : _to = picked);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       padding: EdgeInsets.fromLTRB(
//         20,
//         0,
//         20,
//         MediaQuery.of(context).padding.bottom + 16,
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Center(
//             child: Container(
//               margin: const EdgeInsets.symmetric(vertical: 12),
//               width: 40,
//               height: 4,
//               decoration: BoxDecoration(
//                 color: const Color(0xFFE0E0E0),
//                 borderRadius: BorderRadius.circular(2),
//               ),
//             ),
//           ),
//           Row(
//             children: [
//               const Text(
//                 'Filter by Date',
//                 style: TextStyle(
//                   fontSize: 16,
//                   fontWeight: FontWeight.w800,
//                   color: kTextDark,
//                 ),
//               ),
//               const Spacer(),
//               TextButton(
//                 onPressed: () => setState(() {
//                   _sel = _DateFilter.all;
//                   _from = null;
//                   _to = null;
//                   _newest = true;
//                 }),
//                 child: const Text(
//                   'Reset',
//                   style: TextStyle(color: kRed, fontWeight: FontWeight.w600),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 8),
//           Wrap(
//             spacing: 8,
//             runSpacing: 8,
//             children: _DateFilter.values
//                 .where((f) => f != _DateFilter.custom)
//                 .map((f) => _optionChip(f))
//                 .toList(),
//           ),
//           const SizedBox(height: 12),
//           GestureDetector(
//             onTap: () => setState(() => _sel = _DateFilter.custom),
//             child: Container(
//               padding: const EdgeInsets.all(12),
//               decoration: BoxDecoration(
//                 color: _sel == _DateFilter.custom ? kPrimaryBg : kBg,
//                 borderRadius: BorderRadius.circular(12),
//                 border: Border.all(
//                   color: _sel == _DateFilter.custom ? kPrimary : kBorder,
//                   width: _sel == _DateFilter.custom ? 1.5 : 1,
//                 ),
//               ),
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Row(
//                     children: [
//                       Icon(
//                         Icons.tune_rounded,
//                         color: _sel == _DateFilter.custom ? kPrimary : kTextMid,
//                         size: 16,
//                       ),
//                       const SizedBox(width: 8),
//                       Text(
//                         'Custom Date Range',
//                         style: TextStyle(
//                           fontSize: 13,
//                           fontWeight: FontWeight.w700,
//                           color: _sel == _DateFilter.custom
//                               ? kPrimary
//                               : kTextMid,
//                         ),
//                       ),
//                     ],
//                   ),
//                   if (_sel == _DateFilter.custom) ...[
//                     const SizedBox(height: 12),
//                     Row(
//                       children: [
//                         Expanded(
//                           child: _datePicker(
//                             label: 'From',
//                             value: _from,
//                             onTap: () => _pickDate(isFrom: true),
//                           ),
//                         ),
//                         const SizedBox(width: 8),
//                         Expanded(
//                           child: _datePicker(
//                             label: 'To',
//                             value: _to,
//                             onTap: () => _pickDate(isFrom: false),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//           ),
//           const SizedBox(height: 16),
//           const Text(
//             'Sort Order',
//             style: TextStyle(
//               fontSize: 13,
//               fontWeight: FontWeight.w700,
//               color: kTextDark,
//             ),
//           ),
//           const SizedBox(height: 8),
//           Row(
//             children: [
//               Expanded(
//                 child: _sortBtn(
//                   label: 'Newest First',
//                   icon: Icons.arrow_downward_rounded,
//                   selected: _newest,
//                   onTap: () => setState(() => _newest = true),
//                 ),
//               ),
//               const SizedBox(width: 8),
//               Expanded(
//                 child: _sortBtn(
//                   label: 'Oldest First',
//                   icon: Icons.arrow_upward_rounded,
//                   selected: !_newest,
//                   onTap: () => setState(() => _newest = false),
//                 ),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           SizedBox(
//             width: double.infinity,
//             child: ElevatedButton(
//               onPressed: () {
//                 widget.onApply(_sel, _from, _to, _newest);
//                 Navigator.pop(context);
//               },
//               style: ElevatedButton.styleFrom(
//                 backgroundColor: kPrimary,
//                 foregroundColor: Colors.white,
//                 padding: const EdgeInsets.symmetric(vertical: 14),
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//               ),
//               child: const Text(
//                 'Apply Filter',
//                 style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _optionChip(_DateFilter f) {
//     final sel = _sel == f;
//     return GestureDetector(
//       onTap: () => setState(() => _sel = f),
//       child: Container(
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//         decoration: BoxDecoration(
//           color: sel ? kPrimary : kBg,
//           borderRadius: BorderRadius.circular(20),
//           border: Border.all(
//             color: sel ? kPrimary : kBorder,
//             width: sel ? 1.5 : 1,
//           ),
//         ),
//         child: Row(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             Icon(f.icon, color: sel ? Colors.white : kTextMid, size: 13),
//             const SizedBox(width: 5),
//             Text(
//               f.label,
//               style: TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w600,
//                 color: sel ? Colors.white : kTextMid,
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _datePicker({
//     required String label,
//     required DateTime? value,
//     required VoidCallback onTap,
//   }) => GestureDetector(
//     onTap: onTap,
//     child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: kBorder),
//       ),
//       child: Row(
//         children: [
//           const Icon(Icons.calendar_today_rounded, color: kPrimary, size: 14),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   label,
//                   style: const TextStyle(fontSize: 10, color: kTextMid),
//                 ),
//                 Text(
//                   value != null ? _fmt(value) : 'Select',
//                   style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                     color: value != null ? kTextDark : kTextMid,
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     ),
//   );

//   Widget _sortBtn({
//     required String label,
//     required IconData icon,
//     required bool selected,
//     required VoidCallback onTap,
//   }) => GestureDetector(
//     onTap: onTap,
//     child: Container(
//       padding: const EdgeInsets.symmetric(vertical: 10),
//       decoration: BoxDecoration(
//         color: selected ? kPrimary : kBg,
//         borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: selected ? kPrimary : kBorder),
//       ),
//       child: Row(
//         mainAxisAlignment: MainAxisAlignment.center,
//         children: [
//           Icon(icon, color: selected ? Colors.white : kTextMid, size: 15),
//           const SizedBox(width: 6),
//           Text(
//             label,
//             style: TextStyle(
//               fontSize: 12,
//               fontWeight: FontWeight.w600,
//               color: selected ? Colors.white : kTextMid,
//             ),
//           ),
//         ],
//       ),
//     ),
//   );
// }

// // ════════════════════════════════════════════════════════════════════
// //  COMPACT PRESCRIPTION CARD  (updated: shows doctor + patient info)
// // ════════════════════════════════════════════════════════════════════
// class _PrescriptionCompactCard extends StatelessWidget {
//   final PatientPrescription prescription;
//   final String Function(DateTime) fmtDate;
//   final VoidCallback onTap;

//   const _PrescriptionCompactCard({
//     required this.prescription,
//     required this.fmtDate,
//     required this.onTap,
//   });

//   Color get _statusColor => switch (prescription.status) {
//     'active' => kGreen,
//     'completed' => kPrimary,
//     _ => kTextMid,
//   };
//   String get _statusLabel => switch (prescription.status) {
//     'active' => 'Active',
//     'completed' => 'Completed',
//     _ => 'Expired',
//   };
//   IconData get _statusIcon => switch (prescription.status) {
//     'active' => Icons.check_circle_rounded,
//     'completed' => Icons.task_alt_rounded,
//     _ => Icons.cancel_outlined,
//   };

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       decoration: BoxDecoration(
//         color: kCardBg,
//         borderRadius: BorderRadius.circular(14),
//         boxShadow: const [
//           BoxShadow(
//             color: Color(0x0D000000),
//             blurRadius: 10,
//             offset: Offset(0, 3),
//           ),
//         ],
//         border: Border.all(
//           color: prescription.status == 'active'
//               ? kGreen.withOpacity(0.25)
//               : kBorder,
//           width: 1.1,
//         ),
//       ),
//       child: Column(
//         children: [
//           // ── Top strip: Rx · Date · Status ────────────────────────
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
//             decoration: BoxDecoration(
//               color: prescription.status == 'active'
//                   ? kGreen.withOpacity(0.04)
//                   : kBg,
//               borderRadius: const BorderRadius.vertical(
//                 top: Radius.circular(13),
//               ),
//             ),
//             child: Row(
//               children: [
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 8,
//                     vertical: 4,
//                   ),
//                   decoration: BoxDecoration(
//                     color: kPrimaryBg,
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       const Icon(
//                         Icons.receipt_rounded,
//                         color: kPrimary,
//                         size: 11,
//                       ),
//                       const SizedBox(width: 4),
//                       Text(
//                         'Rx #${prescription.prescriptionId}',
//                         style: const TextStyle(
//                           color: kPrimary,
//                           fontSize: 11,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const SizedBox(width: 6),
//                 const Icon(
//                   Icons.calendar_today_rounded,
//                   color: kTextMid,
//                   size: 11,
//                 ),
//                 const SizedBox(width: 3),
//                 Text(
//                   fmtDate(prescription.prescriptionDate),
//                   style: const TextStyle(fontSize: 11, color: kTextMid),
//                 ),
//                 const Spacer(),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 7,
//                     vertical: 3,
//                   ),
//                   decoration: BoxDecoration(
//                     color: _statusColor.withOpacity(0.1),
//                     borderRadius: BorderRadius.circular(12),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(_statusIcon, color: _statusColor, size: 10),
//                       const SizedBox(width: 3),
//                       Text(
//                         _statusLabel,
//                         style: TextStyle(
//                           color: _statusColor,
//                           fontSize: 10,
//                           fontWeight: FontWeight.w700,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ── Body ─────────────────────────────────────────────────
//           // ── Body ─────────────────────────────────────────────────
//           Padding(
//             padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 // Doctor row
//                 Row(
//                   children: [
//                     Container(
//                       width: 28,
//                       height: 28,
//                       decoration: BoxDecoration(
//                         gradient: const LinearGradient(
//                           colors: [Color(0xFF1558C0), kPrimary],
//                           begin: Alignment.topLeft,
//                           end: Alignment.bottomRight,
//                         ),
//                         borderRadius: BorderRadius.circular(7),
//                       ),
//                       child: const Icon(
//                         Icons.person_rounded,
//                         color: Colors.white,
//                         size: 15,
//                       ),
//                     ),
//                     const SizedBox(width: 7),
//                     Expanded(
//                       child: Column(
//                         crossAxisAlignment: CrossAxisAlignment.start,
//                         children: [
//                           Text(
//                             prescription.doctorName,
//                             style: const TextStyle(
//                               fontSize: 13,
//                               fontWeight: FontWeight.w700,
//                               color: kTextDark,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                           Text(
//                             prescription.specialization,
//                             style: const TextStyle(
//                               fontSize: 10,
//                               color: kTextMid,
//                             ),
//                             maxLines: 1,
//                             overflow: TextOverflow.ellipsis,
//                           ),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),

//                 const SizedBox(height: 8),

//                 // ── Patient name · Age ─────────────────────────────
//                 Row(
//                   children: [
//                     Container(
//                       width: 22,
//                       height: 22,
//                       decoration: const BoxDecoration(
//                         color: kPrimary,
//                         shape: BoxShape.circle,
//                       ),
//                       alignment: Alignment.center,
//                       child: Text(
//                         prescription.patientName
//                             .split(' ')
//                             .where((w) => w.isNotEmpty)
//                             .take(1)
//                             .map((w) => w[0].toUpperCase())
//                             .join(),
//                         style: const TextStyle(
//                           color: Colors.white,
//                           fontSize: 9,
//                           fontWeight: FontWeight.w800,
//                         ),
//                       ),
//                     ),
//                     const SizedBox(width: 5),
//                     Flexible(
//                       child: Text(
//                         prescription.patientName,
//                         style: const TextStyle(
//                           fontSize: 12,
//                           fontWeight: FontWeight.w600,
//                           color: kTextDark,
//                         ),
//                         maxLines: 1,
//                         overflow: TextOverflow.ellipsis,
//                       ),
//                     ),
//                     if (prescription.patientAge != null &&
//                         prescription.patientAge! > 0) ...[
//                       const SizedBox(width: 5),
//                       Container(
//                         padding: const EdgeInsets.symmetric(
//                           horizontal: 5,
//                           vertical: 2,
//                         ),
//                         decoration: BoxDecoration(
//                           color: kBg,
//                           borderRadius: BorderRadius.circular(4),
//                           border: Border.all(color: kBorder),
//                         ),
//                         child: Text(
//                           '${prescription.patientAge} yrs',
//                           style: const TextStyle(
//                             fontSize: 9,
//                             color: kTextMid,
//                             fontWeight: FontWeight.w600,
//                           ),
//                         ),
//                       ),
//                     ],
//                   ],
//                 ),

//                 const SizedBox(height: 8),
//               ],
//             ),
//           ),

//           // ── Single bottom row: med count · follow-up · view button ──
//           Container(
//             decoration: const BoxDecoration(
//               border: Border(top: BorderSide(color: kBorder, width: 0.8)),
//             ),
//             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
//             child: Row(
//               children: [
//                 _miniChip(
//                   icon: Icons.medication_rounded,
//                   label: '${prescription.medicines.length} Med',
//                   color: kPurple,
//                 ),
//                 if (prescription.followUpDate != null) ...[
//                   const SizedBox(width: 6),
//                   _miniChip(
//                     icon: Icons.event_rounded,
//                     label: '${fmtDate(prescription.followUpDate!)}. Follow-up',
//                     color: kOrange,
//                   ),
//                 ],
//                 const Spacer(),
//                 GestureDetector(
//                   onTap: onTap,
//                   child: Container(
//                     padding: const EdgeInsets.symmetric(
//                       horizontal: 11,
//                       vertical: 6,
//                     ),
//                     decoration: BoxDecoration(
//                       gradient: const LinearGradient(
//                         colors: [Color(0xFF1558C0), kPrimary],
//                         begin: Alignment.centerLeft,
//                         end: Alignment.centerRight,
//                       ),
//                       borderRadius: BorderRadius.circular(8),
//                     ),
//                     child: const Row(
//                       mainAxisSize: MainAxisSize.min,
//                       children: [
//                         Icon(
//                           Icons.visibility_rounded,
//                           color: Colors.white,
//                           size: 12,
//                         ),
//                         SizedBox(width: 5),
//                         Text(
//                           'View Prescription',
//                           style: TextStyle(
//                             color: Colors.white,
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             letterSpacing: 0.1,
//                           ),
//                         ),
//                         SizedBox(width: 4),
//                         Icon(
//                           Icons.arrow_forward_ios_rounded,
//                           color: Colors.white,
//                           size: 10,
//                         ),
//                       ],
//                     ),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _miniChip({
//     required IconData icon,
//     required String label,
//     required Color color,
//   }) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
//     decoration: BoxDecoration(
//       color: color.withOpacity(0.09),
//       borderRadius: BorderRadius.circular(6),
//     ),
//     child: Row(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Icon(icon, color: color, size: 10),
//         const SizedBox(width: 4),
//         Text(
//           label,
//           style: TextStyle(
//             fontSize: 10,
//             fontWeight: FontWeight.w600,
//             color: color,
//           ),
//         ),
//       ],
//     ),
//   );
// }

// // ════════════════════════════════════════════════════════════════════
// //  PRESCRIPTION VIEW SCREEN  — matches screenshot exactly
// // ════════════════════════════════════════════════════════════════════
// class PatientPrescriptionViewScreen extends ConsumerStatefulWidget {
//   final int prescriptionId;
//   final PatientPrescription fallback;
//   final int patientId;

//   const PatientPrescriptionViewScreen({
//     super.key,
//     required this.prescriptionId,
//     required this.fallback,
//     required this.patientId,
//   });

//   @override
//   ConsumerState<PatientPrescriptionViewScreen> createState() =>
//       _PatientPrescriptionViewScreenState();
// }

// class _PatientPrescriptionViewScreenState
//     extends ConsumerState<PatientPrescriptionViewScreen> {
//   late PatientPrescription _rx;

//   String _fmtDate(DateTime d) {
//     const m = [
//       '',
//       'Jan',
//       'Feb',
//       'Mar',
//       'Apr',
//       'May',
//       'Jun',
//       'Jul',
//       'Aug',
//       'Sep',
//       'Oct',
//       'Nov',
//       'Dec',
//     ];
//     return '${d.day} ${m[d.month]} ${d.year}';
//   }

//   String _fmtDateTime(DateTime d) {
//     // e.g.  15 April 2026 · 10:30 AM
//     const months = [
//       '',
//       'January',
//       'February',
//       'March',
//       'April',
//       'May',
//       'June',
//       'July',
//       'August',
//       'September',
//       'October',
//       'November',
//       'December',
//     ];
//     final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
//     final min = d.minute.toString().padLeft(2, '0');
//     final ampm = d.hour < 12 ? 'AM' : 'PM';
//     return '${d.day} ${months[d.month]} ${d.year}  ·  $h:$min $ampm';
//   }

//   static const _typeColor = {
//     1: Color(0xFF2B7FFF),
//     2: Color(0xFF8B5CF6),
//     3: Color(0xFFEF4444),
//     4: Color(0xFF06B6D4),
//     5: Color(0xFF10B981),
//     6: Color(0xFFF59E0B),
//   };
//   static const _typeLabel = {
//     1: 'Tablet',
//     2: 'Syrup',
//     3: 'Injection',
//     4: 'Drops',
//     5: 'Lotion',
//     6: 'Spray',
//   };
//   static const _typeIcon = {
//     1: Icons.medication_rounded,
//     2: Icons.local_drink_rounded,
//     3: Icons.vaccines_rounded,
//     4: Icons.water_drop_rounded,
//     5: Icons.soap_rounded,
//     6: Icons.air_rounded,
//   };

//   void _snack(String msg, Color c) =>
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Text(msg),
//           backgroundColor: c,
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//       );

//   @override
//   void initState() {
//     super.initState();
//     _rx = widget.fallback;
//     Future.microtask(() {
//       ref
//           .read(prescriptionViewModelProvider.notifier)
//           .patientPrescriptionDetails(widget.prescriptionId);
//     });
//   }

//   @override
//   Widget build(BuildContext context) {
//     final state = ref.watch(prescriptionViewModelProvider);
//     final details = state.prescriptionDetailsPatient;
//     if (details != null && details.isNotEmpty) {
//       _rx = PatientPrescription.fromFlatList(
//         details,
//         fallbackPatientId:
//             ref.read(patientLoginViewModelProvider).patientId ?? 0,
//         fallbackPatientName:
//             ref.read(patientLoginViewModelProvider).name ?? 'Patient',
//       );
//     }

//     return Scaffold(
//       backgroundColor: kBg,
//       body: Stack(
//         children: [
//           Column(
//             children: [
//               _buildHeader(),
//               Expanded(
//                 child: ListView(
//                   padding: const EdgeInsets.only(bottom: 100),
//                   children: [
//                     _buildClinicCard(), // margin 14px sides, rounded white card
//                     Padding(
//                       padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
//                       child: Column(
//                         children: [
//                           _buildPatientRow(),
//                           _vg(10),
//                           if (_rx.diagnosis?.isNotEmpty == true) ...[
//                             _buildDiagnosisCard(),
//                             _vg(10),
//                           ],
//                           if (_rx.symptoms?.isNotEmpty == true) ...[
//                             _buildSymptomsCard(),
//                             _vg(10),
//                           ],
//                           _buildMedicinesCard(),
//                           _vg(10),
//                           _buildNotesRow(),
//                           _vg(10),
//                           if (_rx.followUpDate != null) ...[
//                             _buildFollowUpCard(),
//                             _vg(10),
//                           ],
//                           _buildFooter(),
//                           _vg(10),
//                         ],
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//               _buildBottomBar(),
//             ],
//           ),
//           if (state.isLoading)
//             Container(
//               color: Colors.black.withOpacity(0.2),
//               child: const Center(
//                 child: CircularProgressIndicator(color: kPrimary),
//               ),
//             ),
//         ],
//       ),
//     );
//   }

//   // ── Fixed white top bar only ─────────────────────────────────────
//   Widget _buildHeader() => Container(
//     color: kCardBg,
//     child: SafeArea(
//       bottom: false,
//       child: Padding(
//         padding: const EdgeInsets.fromLTRB(4, 6, 14, 10),
//         child: Row(
//           children: [
//             IconButton(
//               icon: const Icon(
//                 Icons.arrow_back_ios_new_rounded,
//                 color: kTextDark,
//                 size: 18,
//               ),
//               onPressed: () => Navigator.pop(context),
//             ),
//             const SizedBox(width: 2),
//             const Text(
//               'Prescription Details',
//               style: TextStyle(
//                 color: kTextDark,
//                 fontSize: 17,
//                 fontWeight: FontWeight.w800,
//                 letterSpacing: -0.2,
//               ),
//             ),
//           ],
//         ),
//       ),
//     ),
//   );
//   Widget _buildClinicCard() => Container(
//     margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
//     decoration: BoxDecoration(
//       color: kCardBg,
//       borderRadius: BorderRadius.circular(14),
//       boxShadow: const [
//         BoxShadow(
//           color: Color(0x0D000000),
//           blurRadius: 10,
//           offset: Offset(0, 3),
//         ),
//       ],
//       border: Border.all(color: kBorder, width: 1),
//     ),
//     clipBehavior: Clip.antiAlias,
//     child: Column(
//       children: [
//         // ── Dark blue gradient: clinic info ──────────────────────
//         Container(
//           width: double.infinity,
//           decoration: const BoxDecoration(
//             gradient: LinearGradient(
//               colors: [Color(0xFF1558C0), kPrimary],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//           ),
//           padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 width: 38,
//                 height: 38,
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.22),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//                 child: const Icon(
//                   Icons.local_hospital_rounded,
//                   color: Colors.white,
//                   size: 20,
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       _rx.clinicName,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w800,
//                       ),
//                     ),
//                     const SizedBox(height: 3),
//                     Text(
//                       '${_rx.clinicAddress}  ·  Ph: ${_rx.clinicContact}',
//                       style: TextStyle(
//                         color: Colors.white.withOpacity(0.82),
//                         fontSize: 11,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//             ],
//           ),
//         ),

//         // ── Lighter blue: doctor info ─────────────────────────────
//         Container(
//           width: double.infinity,
//           color: const Color(0xFF3D8EF0),
//           padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
//           child: Row(
//             children: [
//               Expanded(
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Text(
//                       _rx.doctorName,
//                       style: const TextStyle(
//                         color: Colors.white,
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                       ),
//                     ),
//                     const SizedBox(height: 2),
//                     Text(
//                       '${_rx.qualification}  ·  ${_rx.specialization}',
//                       style: TextStyle(
//                         color: Colors.white.withOpacity(0.78),
//                         fontSize: 11,
//                       ),
//                     ),
//                     if (_rx.regNo?.isNotEmpty == true)
//                       Text(
//                         'Reg. No. ${_rx.regNo}',
//                         style: TextStyle(
//                           color: Colors.white.withOpacity(0.65),
//                           fontSize: 10,
//                         ),
//                       ),
//                   ],
//                 ),
//               ),
//               Container(
//                 padding: const EdgeInsets.symmetric(
//                   horizontal: 12,
//                   vertical: 5,
//                 ),
//                 decoration: BoxDecoration(
//                   color: Colors.white.withOpacity(0.18),
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: Colors.white.withOpacity(0.35)),
//                 ),
//                 child: Text(
//                   'Rx #${_rx.prescriptionId}',
//                   style: const TextStyle(
//                     color: Colors.white,
//                     fontSize: 13,
//                     fontWeight: FontWeight.w700,
//                     letterSpacing: 0.5,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     ),
//   );
//   Widget _buildPatientRow() => _card(
//     padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//     child: Row(
//       children: [
//         // Initials avatar
//         Container(
//           width: 44,
//           height: 44,
//           decoration: const BoxDecoration(
//             color: kPrimary,
//             shape: BoxShape.circle,
//           ),
//           alignment: Alignment.center,
//           child: Text(
//             _rx.patientName
//                 .split(' ')
//                 .map((w) => w.isNotEmpty ? w[0] : '')
//                 .take(2)
//                 .join(),
//             style: const TextStyle(
//               color: Colors.white,
//               fontSize: 15,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//         ),
//         const SizedBox(width: 12),
//         Expanded(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Text(
//                 _rx.patientName,
//                 style: const TextStyle(
//                   fontSize: 15,
//                   fontWeight: FontWeight.w700,
//                   color: kTextDark,
//                 ),
//               ),
//               const SizedBox(height: 4),
//               // Age · Gender · Token row
//               Wrap(
//                 spacing: 6,
//                 children: [
//                   if (_rx.patientAge != null && _rx.patientAge! > 0)
//                     _chip('${_rx.patientAge} yrs'),
//                   if (_rx.patientGender?.isNotEmpty == true)
//                     _chip(_rx.patientGender!),
//                   if (_rx.tokenNumber != null)
//                     _chip('Token #${_rx.tokenNumber}'),
//                 ],
//               ),
//             ],
//           ),
//         ),
//         // Date column
//         Column(
//           crossAxisAlignment: CrossAxisAlignment.end,
//           children: [
//             const Text('Date', style: TextStyle(fontSize: 10, color: kTextMid)),
//             const SizedBox(height: 2),
//             Text(
//               _fmtDate(_rx.prescriptionDate),
//               style: const TextStyle(
//                 fontSize: 13,
//                 fontWeight: FontWeight.w700,
//                 color: kTextDark,
//               ),
//             ),
//           ],
//         ),
//       ],
//     ),
//   );

//   // ── Symptoms ────────────────────────────────────────────────────
//   Widget _buildSymptomsCard() => _card(
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _sectionLabel('SYMPTOMS'),
//         const SizedBox(height: 10),
//         Container(
//           width: double.infinity,
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: const Color(0xFFFFF8E7),
//             borderRadius: BorderRadius.circular(10),
//             border: Border.all(color: const Color(0xFFFDE68A)),
//           ),
//           child: Text(
//             _rx.symptoms!,
//             style: const TextStyle(
//               fontSize: 13,
//               color: kTextDark,
//               height: 1.45,
//             ),
//           ),
//         ),
//       ],
//     ),
//   );

//   // ── Diagnosis ───────────────────────────────────────────────────
//   Widget _buildDiagnosisCard() => _card(
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _sectionLabel('DIAGNOSIS'),
//         const SizedBox(height: 10),
//         Container(
//           width: double.infinity,
//           padding: const EdgeInsets.all(12),
//           decoration: BoxDecoration(
//             color: kPrimaryBg,
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: Row(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Container(
//                 margin: const EdgeInsets.only(top: 2),
//                 padding: const EdgeInsets.all(5),
//                 decoration: BoxDecoration(
//                   color: kPrimary.withOpacity(0.12),
//                   borderRadius: BorderRadius.circular(6),
//                 ),
//                 child: const Icon(
//                   Icons.biotech_rounded,
//                   color: kPrimary,
//                   size: 14,
//                 ),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(
//                   _rx.diagnosis!,
//                   style: const TextStyle(
//                     fontSize: 13,
//                     color: kTextDark,
//                     fontWeight: FontWeight.w500,
//                     height: 1.45,
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ],
//     ),
//   );
//   // ── Replace entire _buildMedicinesCard ──────────────────────────
//   Widget _buildMedicinesCard() => _card(
//     padding: EdgeInsets.zero,
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Padding(
//           padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
//           child: _sectionLabel('MEDICINES'),
//         ),
//         // ── Table with fixed column widths ───────────────────────
//         LayoutBuilder(
//           builder: (context, constraints) {
//             final w = constraints.maxWidth - 24; // ← 24px padding subtract
//             final c1 = w * 0.28;
//             final c2 = w * 0.30;
//             final c3 = w * 0.24;
//             final c4 = w * 0.18;

//             return Column(
//               children: [
//                 // ── Header ───────────────────────────────────────
//                 Container(
//                   color: kBg,
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 12,
//                     vertical: 7,
//                   ),
//                   child: Row(
//                     children: [
//                       SizedBox(width: c1, child: const _ColHead('MEDICINE')),
                   
//                       SizedBox(
//                         width: c2,
//                         child: const Text(
//                           'FREQ/DOSE',
//                           textAlign: TextAlign.center, // ← center
//                           style: TextStyle(
//                             fontSize: 9,
//                             fontWeight: FontWeight.w700,
//                             color: kTextMid,
//                             letterSpacing: 0.3,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ), // c3 — TIMING
//                       SizedBox(
//                         width: c3,
//                         child: const Text(
//                           'TIMING',
//                           textAlign: TextAlign.center, // ← center
//                           style: TextStyle(
//                             fontSize: 9,
//                             fontWeight: FontWeight.w700,
//                             color: kTextMid,
//                             letterSpacing: 0.3,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),

//                       // c4 — DURATION
//                       SizedBox(
//                         width: c4,
//                         child: const Text(
//                           'DURATION',
//                           textAlign: TextAlign.center, // ← center
//                           style: TextStyle(
//                             fontSize: 9,
//                             fontWeight: FontWeight.w700,
//                             color: kTextMid,
//                             letterSpacing: 0.3,
//                           ),
//                           maxLines: 1,
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//                 const Divider(height: 1, color: kBorder),

//                 // ── Rows ─────────────────────────────────────────
//                 ListView.separated(
//                   shrinkWrap: true,
//                   physics: const NeverScrollableScrollPhysics(),
//                   itemCount: _rx.medicines.length,
//                   separatorBuilder: (_, __) =>
//                       const Divider(height: 1, color: kBorder, indent: 12),
//                   itemBuilder: (_, i) {
//                     final m = _rx.medicines[i];
//                     final c = _typeColor[m.medicineTypeId] ?? kTextMid;
//                     final lbl =
//                         _typeLabel[m.medicineTypeId] ??
//                         m.mediTypeName ??
//                         'Unknown';
//                     final ic =
//                         _typeIcon[m.medicineTypeId] ?? Icons.medication_rounded;
//                     return _MedRow(
//                       med: m,
//                       color: c,
//                       typeLabel: lbl,
//                       typeIcon: ic,
//                       c1: c1,
//                       c2: c2,
//                       c3: c3,
//                       c4: c4,
//                     );
//                   },
//                 ),
//               ],
//             );
//           },
//         ),
//       ],
//     ),
//   );
//   // ── Notes Row: Spray Instructions + Doctor's Advice ─────────────
//   Widget _buildNotesRow() {
//     final hasClinical = _rx.clinicalNotes?.isNotEmpty == true;
//     final hasAdvice = _rx.advice?.isNotEmpty == true;
//     if (!hasClinical && !hasAdvice) return const SizedBox.shrink();
//     return Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         if (hasClinical)
//           Expanded(
//             child: _noteBox(
//               color: const Color(0xFFF0F4FF),
//               borderColor: const Color(0xFFBFD0FF),
//               iconColor: kPrimary,
//               icon: Icons.notes_rounded,
//               title: 'CLINICAL INSTRUCTIONS',
//               text: _rx.clinicalNotes!,
//             ),
//           ),
//         if (hasClinical && hasAdvice) const SizedBox(width: 10),
//         if (hasAdvice)
//           Expanded(
//             child: _noteBox(
//               color: const Color(0xFFF0FFF4),
//               borderColor: const Color(0xFFA7F3D0),
//               iconColor: kGreen,
//               icon: Icons.medical_information_rounded,
//               title: "DOCTOR'S ADVICE",
//               text: _rx.advice!,
//             ),
//           ),
//       ],
//     );
//   }

//   Widget _noteBox({
//     required Color color,
//     required Color borderColor,
//     required Color iconColor,
//     required IconData icon,
//     required String title,
//     required String text,
//   }) => Container(
//     padding: const EdgeInsets.all(12),
//     decoration: BoxDecoration(
//       color: color,
//       borderRadius: BorderRadius.circular(12),
//       border: Border.all(color: borderColor),
//     ),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             Icon(icon, color: iconColor, size: 13),
//             const SizedBox(width: 5),
//             Text(
//               title,
//               style: TextStyle(
//                 fontSize: 10,
//                 fontWeight: FontWeight.w800,
//                 color: iconColor,
//                 letterSpacing: 0.5,
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 8),
//         Text(
//           text,
//           style: const TextStyle(fontSize: 12, color: kTextDark, height: 1.5),
//         ),
//       ],
//     ),
//   );

//   // ── Follow-up Card — date + time + room + instruction ───────────
//   Widget _buildFollowUpCard() {
//     final followDate = _rx.followUpDate!;
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: const Color(0xFFF0FFF4),
//         borderRadius: BorderRadius.circular(12),
//         border: Border.all(color: const Color(0xFFA7F3D0)),
//       ),
//       child: Row(
//         children: [
//           Container(
//             width: 44,
//             height: 44,
//             decoration: BoxDecoration(
//               color: kGreen.withOpacity(0.15),
//               borderRadius: BorderRadius.circular(12),
//             ),
//             child: const Icon(
//               Icons.event_available_rounded,
//               color: kGreen,
//               size: 22,
//             ),
//           ),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 const Text(
//                   'NEXT FOLLOW-UP',
//                   style: TextStyle(
//                     fontSize: 10,
//                     fontWeight: FontWeight.w800,
//                     color: kGreen,
//                     letterSpacing: 0.6,
//                   ),
//                 ),
//                 const SizedBox(height: 4),
//                 Text(
//                   _fmtDateTime(followDate),
//                   style: const TextStyle(
//                     fontSize: 14,
//                     fontWeight: FontWeight.w800,
//                     color: kTextDark,
//                   ),
//                 ),
//                 if (_rx.followUpRoom?.isNotEmpty == true ||
//                     _rx.followUpInstruction?.isNotEmpty == true) ...[
//                   const SizedBox(height: 3),
//                   Text(
//                     [
//                       if (_rx.followUpRoom?.isNotEmpty == true)
//                         _rx.followUpRoom!,
//                       if (_rx.followUpInstruction?.isNotEmpty == true)
//                         _rx.followUpInstruction!,
//                     ].join('  ·  '),
//                     style: const TextStyle(fontSize: 11, color: kTextMid),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ── Footer ──────────────────────────────────────────────────────
//   Widget _buildFooter() => Row(
//     crossAxisAlignment: CrossAxisAlignment.end,
//     children: [
//       const Expanded(
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               'This prescription is valid for 30 days.',
//               style: TextStyle(fontSize: 11, color: kTextMid),
//             ),
//             SizedBox(height: 3),
//             Text(
//               'Dispensed by licensed pharmacist only.',
//               style: TextStyle(fontSize: 11, color: kTextMid),
//             ),
//           ],
//         ),
//       ),
//       SizedBox(
//         width: 140,
//         child: Column(
//           children: [
//             const Divider(color: kTextDark, thickness: 0.8),
//             const SizedBox(height: 4),
//             Text(
//               _rx.doctorName,
//               style: const TextStyle(
//                 fontSize: 12,
//                 fontWeight: FontWeight.w700,
//                 color: kTextDark,
//               ),
//               textAlign: TextAlign.center,
//             ),
//             Text(
//               '${_rx.qualification}  ·  ${_rx.specialization}',
//               style: const TextStyle(fontSize: 10, color: kTextMid),
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//       ),
//     ],
//   );

//   // ── Bottom Bar — Download · Share (equal size, same gradient) ───
//   Widget _buildBottomBar() => Container(
//     padding: EdgeInsets.fromLTRB(
//       12,
//       10,
//       12,
//       MediaQuery.of(context).padding.bottom + 10,
//     ),
//     decoration: const BoxDecoration(
//       color: kCardBg,
//       boxShadow: [
//         BoxShadow(
//           color: Color(0x1A000000),
//           blurRadius: 16,
//           offset: Offset(0, -3),
//         ),
//       ],
//     ),
//     child: Row(
//       children: [
//         // Download
//         Expanded(
//           child: GestureDetector(
//             onTap: () => _snack('Downloading PDF...', kPrimary),
//             child: Container(
//               padding: const EdgeInsets.symmetric(vertical: 13),
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF1558C0), kPrimary],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.download_rounded, color: Colors.white, size: 18),
//                   SizedBox(width: 7),
//                   Text(
//                     'Download',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.w700,
//                       fontSize: 13,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//         const SizedBox(width: 10),
//         // Share
//         Expanded(
//           child: GestureDetector(
//             onTap: () => _snack('Sharing prescription...', kPrimary),
//             child: Container(
//               padding: const EdgeInsets.symmetric(vertical: 13),
//               decoration: BoxDecoration(
//                 gradient: const LinearGradient(
//                   colors: [Color(0xFF1558C0), kPrimary],
//                   begin: Alignment.centerLeft,
//                   end: Alignment.centerRight,
//                 ),
//                 borderRadius: BorderRadius.circular(12),
//               ),
//               child: const Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(Icons.share_rounded, color: Colors.white, size: 18),
//                   SizedBox(width: 7),
//                   Text(
//                     'Share',
//                     style: TextStyle(
//                       color: Colors.white,
//                       fontWeight: FontWeight.w700,
//                       fontSize: 13,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ],
//     ),
//   );

//   // ── Helpers ─────────────────────────────────────────────────────
//   Widget _card({
//     required Widget child,
//     EdgeInsetsGeometry padding = const EdgeInsets.all(14),
//   }) => Container(
//     width: double.infinity,
//     padding: padding,
//     decoration: BoxDecoration(
//       color: kCardBg,
//       borderRadius: BorderRadius.circular(14),
//       boxShadow: const [
//         BoxShadow(
//           color: Color(0x0B000000),
//           blurRadius: 10,
//           offset: Offset(0, 2),
//         ),
//       ],
//     ),
//     child: child,
//   );

//   Widget _sectionLabel(String t) => Row(
//     children: [
//       Container(
//         width: 3,
//         height: 14,
//         decoration: BoxDecoration(
//           color: kPrimary,
//           borderRadius: BorderRadius.circular(2),
//         ),
//       ),
//       const SizedBox(width: 7),
//       Text(
//         t,
//         style: const TextStyle(
//           fontSize: 11,
//           fontWeight: FontWeight.w800,
//           color: kPrimary,
//           letterSpacing: 0.8,
//         ),
//       ),
//     ],
//   );

//   Widget _chip(String t) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
//     decoration: BoxDecoration(
//       color: kBg,
//       borderRadius: BorderRadius.circular(5),
//     ),
//     child: Text(
//       t,
//       style: const TextStyle(
//         fontSize: 11,
//         fontWeight: FontWeight.w500,
//         color: kTextMid,
//       ),
//     ),
//   );

//   Widget _vg(double h) => SizedBox(height: h);
// }

// // ════════════════════════════════════════════════════════════════════
// //  MEDICINE ROW  — compact redesign
// // ════════════════════════════════════════════════════════════════════
// class _MedRow extends StatelessWidget {
//   final PrescriptionMedicineItem med;
//   final Color color;
//   final String typeLabel;
//   final IconData typeIcon;
//   final double c1, c2, c3, c4; // exact widths from LayoutBuilder

//   const _MedRow({
//     required this.med,
//     required this.color,
//     required this.typeLabel,
//     required this.typeIcon,
//     required this.c1,
//     required this.c2,
//     required this.c3,
//     required this.c4,
//   });

//   List<String> _splitSlots(String? raw, {String fallback = '-'}) {
//     final parts = (raw ?? '').split('-').map((p) => p.trim()).toList();
//     while (parts.length < 3) parts.add(fallback);
//     return parts.take(3).map((p) => p.isEmpty ? fallback : p).toList();
//   }

//   @override
//   Widget build(BuildContext context) {
//     final dose = _splitSlots(med.doseDisplay);

//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           // ── Col 1: Medicine ──────────────────────────────────
//           SizedBox(
//             width: c1,
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   med.medicineName?.isNotEmpty == true
//                       ? med.medicineName!
//                       : 'Med #${med.medicineId ?? '-'}',
//                   style: const TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w700,
//                     color: kTextDark,
//                   ),
//                   maxLines: 2,
//                   overflow: TextOverflow.ellipsis,
//                 ),
//                 if (med.extraInfo?.isNotEmpty == true) ...[
//                   const SizedBox(height: 2),
//                   Text(
//                     med.extraInfo!,
//                     style: TextStyle(fontSize: 10, color: color),
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                   ),
//                 ],
//                 const SizedBox(height: 4),
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                     horizontal: 5,
//                     vertical: 2,
//                   ),
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.12),
//                     borderRadius: BorderRadius.circular(4),
//                   ),
//                   child: Row(
//                     mainAxisSize: MainAxisSize.min,
//                     children: [
//                       Icon(typeIcon, color: color, size: 9),
//                       const SizedBox(width: 3),
//                       Flexible(
//                         child: Text(
//                           typeLabel,
//                           style: TextStyle(
//                             fontSize: 9,
//                             fontWeight: FontWeight.w700,
//                             color: color,
//                           ),
//                           overflow: TextOverflow.ellipsis,
//                         ),
//                       ),
//                     ],
//                   ),
//                 ),
//               ],
//             ),
//           ),

//           // ── Col 2: Dose table ────────────────────────────────
//           // ── Col 2: Dose table ────────────────────────────────
//           SizedBox(
//             width: c2,
//             child: Container(
//               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
//               decoration: BoxDecoration(
//                 color: kBg,
//                 borderRadius: BorderRadius.circular(8),
//                 border: Border.all(color: kBorder),
//               ),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Header: M  A  N — exactly under FREQ/DOSE header
//                   IntrinsicHeight(
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                       children: const [
//                         Expanded(child: _SlotHead('M')),
//                         Expanded(child: _SlotHead('A')),
//                         Expanded(child: _SlotHead('N')),
//                       ],
//                     ),
//                   ),
//                   const SizedBox(height: 3),
//                   const Divider(height: 1, thickness: 0.8, color: kBorder),
//                   const SizedBox(height: 3),
//                   // Values: same spaceEvenly
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                     children: [
//                       Expanded(child: _SlotVal(dose[0])),
//                       Expanded(child: _SlotVal(dose[1])),
//                       Expanded(child: _SlotVal(dose[2])),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//           // ── Col 3: Timing ────────────────────────────────────
//           // ── Col 3: Timing ────────────────────────────────────
//           SizedBox(
//             width: c3,
//             child: Text(
//               med.timing ?? '-',
//               textAlign: TextAlign.center, // ← center
//               style: const TextStyle(
//                 fontSize: 11,
//                 fontWeight: FontWeight.w600,
//                 color: kTextDark,
//               ),
//               maxLines: 2,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),

//           // ── Col 4: Duration ──────────────────────────────────
//           SizedBox(
//             width: c4,
//             child: Text(
//               med.duration ?? '-',
//               textAlign: TextAlign.center, // ← center
//               style: const TextStyle(
//                 fontSize: 11,
//                 fontWeight: FontWeight.w700,
//                 color: kTextDark,
//               ),
//               maxLines: 1,
//               overflow: TextOverflow.ellipsis,
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   Widget _doseTable(List<String> dose) {
//     return Container(
//       padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
//       decoration: BoxDecoration(
//         color: kBg,
//         borderRadius: BorderRadius.circular(8),
//         border: Border.all(color: kBorder),
//       ),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           // Header row: M  A  N
//           Row(
//             children: const [
//               Expanded(child: _SlotHead('M')),
//               Expanded(child: _SlotHead('A')),
//               Expanded(child: _SlotHead('N')),
//             ],
//           ),
//           const SizedBox(height: 4),
//           const Divider(height: 1, color: kBorder),
//           const SizedBox(height: 4),
//           // Dose row
//           Row(
//             children: [
//               Expanded(child: _SlotVal(dose[0])),
//               Expanded(child: _SlotVal(dose[1])),
//               Expanded(child: _SlotVal(dose[2])),
//             ],
//           ),
//         ],
//       ),
//     );
//   }
// }

// class _SlotHead extends StatelessWidget {
//   final String text;
//   const _SlotHead(this.text);
//   @override
//   Widget build(BuildContext context) => Text(
//     text,
//     textAlign: TextAlign.center,
//     style: const TextStyle(
//       fontSize: 10,
//       fontWeight: FontWeight.w700,
//       color: kTextMid,
//     ),
//   );
// }

// class _SlotVal extends StatelessWidget {
//   final String text;
//   const _SlotVal(this.text);
//   @override
//   Widget build(BuildContext context) => FittedBox(
//     fit: BoxFit.scaleDown,
//     alignment: Alignment.center,
//     child: Text(
//       text,
//       textAlign: TextAlign.center,
//       style: const TextStyle(
//         fontSize: 12,
//         fontWeight: FontWeight.w700,
//         color: kTextDark,
//       ),
//     ),
//   );
// }

// // ════════════════════════════════════════════════════════════════════
// //  COL HEAD
// // ════════════════════════════════════════════════════════════════════
// class _ColHead extends StatelessWidget {
//   final String text;
//   const _ColHead(this.text);
//   @override
//   Widget build(BuildContext context) => Text(
//     text,
//     style: const TextStyle(
//       fontSize: 9,
//       fontWeight: FontWeight.w700,
//       color: kTextMid,
//       letterSpacing: 0.3,
//     ),
//     maxLines: 1,
//     overflow: TextOverflow.ellipsis,
//   );
// }

// // ════════════════════════════════════════════════════════════════════
// //  ADAPTER MODELS
// // ════════════════════════════════════════════════════════════════════
// DateTime? _tryParseDate(String? raw) {
//   if (raw == null || raw.trim().isEmpty) return null;
//   return DateTime.tryParse(raw);
// }

// DateTime _parseDateOrNow(String? raw) => _tryParseDate(raw) ?? DateTime.now();

// String _statusFromFollowUp(DateTime? followUpDate) {
//   if (followUpDate == null) return 'completed';
//   return followUpDate.isAfter(DateTime.now()) ? 'active' : 'completed';
// }

// class PatientPrescription {
//   final int prescriptionId;
//   final int patientId;
//   final String patientName;
//   // ── new fields ──────────────────────────────────────────────────
//   final int? patientAge;
//   final String? patientGender;
//   final int? tokenNumber;
//   final String? regNo;
//   final String? followUpRoom;
//   final String? followUpInstruction;
//   // ────────────────────────────────────────────────────────────────
//   final String doctorName;
//   final String qualification;
//   final String specialization;
//   final String clinicName;
//   final String clinicAddress;
//   final String clinicContact;
//   final DateTime prescriptionDate;
//   final String? symptoms;
//   final String? diagnosis;
//   final String? clinicalNotes;
//   final DateTime? followUpDate;
//   final String? advice;
//   final List<PrescriptionMedicineItem> medicines;
//   final String status;

//   const PatientPrescription({
//     required this.prescriptionId,
//     required this.patientId,
//     required this.patientName,
//     this.patientAge,
//     this.patientGender,
//     this.tokenNumber,
//     this.regNo,
//     this.followUpRoom,
//     this.followUpInstruction,
//     required this.doctorName,
//     required this.qualification,
//     required this.specialization,
//     required this.clinicName,
//     required this.clinicAddress,
//     required this.clinicContact,
//     required this.prescriptionDate,
//     required this.symptoms,
//     required this.diagnosis,
//     required this.clinicalNotes,
//     required this.followUpDate,
//     required this.advice,
//     required this.medicines,
//     required this.status,
//   });

//   factory PatientPrescription.fromModel(
//     PrescriptionModel model, {
//     required int fallbackPatientId,
//     required String fallbackPatientName,
//   }) {
//     final followUp = _tryParseDate(model.followUpDate);
//     final flatMeds = (model.medicines == null || model.medicines!.isEmpty)
//         ? [
//             if (model.medicineId != null || model.medicineName != null)
//               PrescriptionMedicineItem.fromFlatModel(model),
//           ]
//         : <PrescriptionMedicineItem>[];
//     return PatientPrescription(
//       prescriptionId: model.prescriptionId ?? 0,
//       patientId: model.patientId ?? fallbackPatientId,
//       patientName: model.patientName ?? fallbackPatientName,
//       // patientAge:         model."patientAge",
//       // patientGender:      model.patientGender,
//       // tokenNumber:        model.tokenNumber,
//       // regNo:              model.regNo,
//       // followUpRoom:       model.followUpRoom,
//       //  followUpInstruction: model.followUpInstruction,
//       doctorName:
//           model.doctorName ??
//           (model.doctorId != null ? 'Doctor #${model.doctorId}' : 'Doctor'),
//       qualification: model.qualification ?? '-',
//       specialization: model.specialization ?? '-',
//       clinicName: model.clinicName ?? 'Clinic',
//       clinicAddress: model.clinicAddress ?? '-',
//       clinicContact: model.clinicContact ?? '-',
//       prescriptionDate: _parseDateOrNow(model.prescriptionDate),
//       symptoms: model.symptoms,
//       diagnosis: model.diagnosis,
//       clinicalNotes: model.clinicalNotes,
//       followUpDate: followUp,
//       advice: model.advice,
//       medicines:
//           (model.medicines ?? const <PrescriptionMedicineModel>[])
//               .map(PrescriptionMedicineItem.fromModel)
//               .toList() +
//           flatMeds,
//       status: _statusFromFollowUp(followUp),
//     );
//   }

//   factory PatientPrescription.fromFlatList(
//     List<PrescriptionModel> items, {
//     required int fallbackPatientId,
//     required String fallbackPatientName,
//   }) {
//     final first = items.first;
//     final followUp = _tryParseDate(first.followUpDate);
//     final meds = items
//         .map(PrescriptionMedicineItem.fromFlatModel)
//         .where((m) => m.medicineId != null || m.medicineName != null)
//         .toList();
//     return PatientPrescription(
//       prescriptionId: first.prescriptionId ?? 0,
//       patientId: first.patientId ?? fallbackPatientId,
//       patientName: first.patientName ?? fallbackPatientName,
//       // patientAge:         first.patientAge,
//       //  patientGender:      first.patientGender,
//       //tokenNumber:        first.tokenNumber,
//       //regNo:              first.regNo,
//       //followUpRoom:       first.followUpRoom,
//       //followUpInstruction: first.followUpInstruction,
//       doctorName:
//           first.doctorName ??
//           (first.doctorId != null ? 'Doctor #${first.doctorId}' : 'Doctor'),
//       qualification: first.qualification ?? '-',
//       specialization: first.specialization ?? '-',
//       clinicName: first.clinicName ?? 'Clinic',
//       clinicAddress: first.clinicAddress ?? '-',
//       clinicContact: first.clinicContact ?? '-',
//       prescriptionDate: _parseDateOrNow(first.prescriptionDate),
//       symptoms: first.symptoms,
//       diagnosis: first.diagnosis,
//       clinicalNotes: first.clinicalNotes,
//       followUpDate: followUp,
//       advice: first.advice,
//       medicines: meds,
//       status: _statusFromFollowUp(followUp),
//     );
//   }
// }

// class PrescriptionMedicineItem {
//   final int? medicineId;
//   final int medicineTypeId;
//   final String? mediTypeName;
//   final String? medicineName;
//   final String? frequency;
//   final String? duration;
//   final String? timing;
//   final String? tabletDosage;
//   final String? syrupDosageMl;
//   final String? injDosage;
//   final String? injRoute;
//   final String? dropsCount;
//   final String? dropsApplication;
//   final String? lotionApplyArea;
//   final String? sprayPuffs;
//   final String? sprayUsage;
//   final String? lotionUsage;

//   const PrescriptionMedicineItem({
//     required this.medicineId,
//     required this.medicineTypeId,
//     required this.mediTypeName,
//     required this.medicineName,
//     required this.frequency,
//     required this.duration,
//     required this.timing,
//     required this.tabletDosage,
//     required this.syrupDosageMl,
//     required this.injDosage,
//     required this.injRoute,
//     required this.dropsCount,
//     required this.dropsApplication,
//     required this.lotionApplyArea,
//     required this.sprayPuffs,
//     required this.sprayUsage,
//     required this.lotionUsage,  
//   });

//   String? get extraInfo {
//     if (injRoute?.trim().isNotEmpty == true) return injRoute;
//     if (dropsApplication?.trim().isNotEmpty == true) return dropsApplication;
//     if (lotionApplyArea?.trim().isNotEmpty == true) return lotionApplyArea;
//     if (sprayUsage?.trim().isNotEmpty == true) return sprayUsage;
//     return null;
//   }

//   String get doseDisplay {
//     if (tabletDosage?.trim().isNotEmpty == true) return tabletDosage!;
//     if (syrupDosageMl?.trim().isNotEmpty == true) return '$syrupDosageMl';
//     if (injDosage?.trim().isNotEmpty == true) return injDosage!;
//     if (dropsCount?.trim().isNotEmpty == true) return dropsCount!;
//     if (sprayPuffs?.trim().isNotEmpty == true) return sprayPuffs!;
//     if (lotionUsage?.trim().isNotEmpty == true) return lotionUsage!;
//     return '-';
//   }

//   factory PrescriptionMedicineItem.fromModel(PrescriptionMedicineModel model) {
//     return PrescriptionMedicineItem(
//       medicineId: model.medicineId,
//       medicineTypeId: model.medicineTypeId ?? 1,
//       mediTypeName: null,
//       medicineName: null,
//       frequency: model.frequency,
//       duration: model.duration,
//       timing: model.timing,
//       tabletDosage: model.tabletDosage,
//       syrupDosageMl: model.syrupDosageMl,
//       injDosage: model.injDosage,
//       injRoute: model.injRoute,
//       dropsCount: model.dropsCount,
//       dropsApplication: model.dropsApplication,
//       lotionApplyArea: model.lotionApplyArea,
//       sprayPuffs: model.sprayPuffs,
//       sprayUsage: model.sprayUsage,
//       lotionUsage: model.lotionUsage,
//     );
//   }

//   factory PrescriptionMedicineItem.fromFlatModel(PrescriptionModel model) {
//     return PrescriptionMedicineItem(
//       medicineId: model.medicineId,
//       medicineTypeId: model.medicineTypeId ?? 1,
//       mediTypeName: model.mediTypeName,
//       medicineName: model.medicineName,
//       frequency: model.frequency,
//       duration: model.duration,
//       timing: model.timing,
//       tabletDosage: model.tabletDosage,
//       syrupDosageMl: model.syrupDosageMl,
//       injDosage: model.injDosage,
//       injRoute: model.injRoute,
//       dropsCount: model.dropsCount,
//       dropsApplication: model.dropsApplication,
//       lotionApplyArea: model.lotionApplyArea,
//       sprayPuffs: model.sprayPuffs,
//       sprayUsage: model.sprayUsage,
//       lotionUsage: model.lotionUsage,
//     );
//   }
// }


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/prescription_viewmodel.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/core/network/token_provider.dart';

// ── Colour palette ────────────────────────────────────────────────
const kPrimary = Color(0xFF1A73E8);
const kPrimaryBg = Color(0xFFE8F0FE);
const kBg = Color(0xFFF4F6FB);
const kCardBg = Colors.white;
const kTextDark = Color(0xFF1F2937);
const kTextMid = Color(0xFF6B7280);
const kBorder = Color(0xFFE5E7EB);
const kRed = Color(0xFFEA4335);
const kGreen = Color(0xFF34A853);
const kOrange = Color(0xFFF59E0B);
const kPurple = Color(0xFF8B5CF6);
const kCyan = Color(0xFF06B6D4);

// ── Member avatar colours ─────────────────────────────────────────
const _kAvatarColors = [
  Color(0xFF1A73E8),
  Color(0xFF34A853),
  Color(0xFFF59E0B),
  Color(0xFF8B5CF6),
  Color(0xFF06B6D4),
  Color(0xFFEA4335),
];

Color _avatarColor(int index) => _kAvatarColors[index % _kAvatarColors.length];

String _initials(String name) {
  final parts = name.trim().split(' ').where((w) => w.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

// ── Date filter options ───────────────────────────────────────────
enum _DateFilter {
  all,
  today,
  thisWeek,
  thisMonth,
  last3Months,
  last6Months,
  thisYear,
  custom,
}

extension _DateFilterLabel on _DateFilter {
  String get label {
    switch (this) {
      case _DateFilter.all:
        return 'All Time';
      case _DateFilter.today:
        return 'Today';
      case _DateFilter.thisWeek:
        return 'This Week';
      case _DateFilter.thisMonth:
        return 'This Month';
      case _DateFilter.last3Months:
        return 'Last 3 Months';
      case _DateFilter.last6Months:
        return 'Last 6 Months';
      case _DateFilter.thisYear:
        return 'This Year';
      case _DateFilter.custom:
        return 'Custom Range';
    }
  }

  IconData get icon {
    switch (this) {
      case _DateFilter.all:
        return Icons.all_inclusive_rounded;
      case _DateFilter.today:
        return Icons.today_rounded;
      case _DateFilter.thisWeek:
        return Icons.view_week_rounded;
      case _DateFilter.thisMonth:
        return Icons.calendar_month_rounded;
      case _DateFilter.last3Months:
        return Icons.date_range_rounded;
      case _DateFilter.last6Months:
        return Icons.date_range_rounded;
      case _DateFilter.thisYear:
        return Icons.calendar_today_rounded;
      case _DateFilter.custom:
        return Icons.tune_rounded;
    }
  }
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
  String _search = '';
  final _searchCtrl = TextEditingController();
  bool _hasFetched = false;
  bool _hasFetchedFamily = false;
  ProviderSubscription<PatientLoginState>? _patientSub;
  ProviderSubscription<TokenState>? _tokenSub;

  _DateFilter _dateFilter = _DateFilter.all;
  DateTime? _customFrom;
  DateTime? _customTo;
  bool _sortNewestFirst = true;
  static const int _filterAll = -1;
  static const int _filterSelf = -2;
  int _memberFilter = _filterAll;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    Future.microtask(() {
      ref.read(tokenProvider.notifier).loadTokens();
      ref.read(patientLoginViewModelProvider.notifier).loadFromStoragePatient();
    });
    _patientSub = ref.listenManual<PatientLoginState>(
      patientLoginViewModelProvider,
      (prev, next) => _tryFetch(),
    );
    _tokenSub = ref.listenManual<TokenState>(
      tokenProvider,
      (prev, next) => _tryFetch(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFetch());
  }

  void _tryFetch() {
    final patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    final tokenState = ref.read(tokenProvider);
    final tokenReady =
        !tokenState.isLoading && (tokenState.accessToken ?? '').isNotEmpty;
    if (tokenReady && patientId == 0) {
      ref.read(patientLoginViewModelProvider.notifier).loadFromStoragePatient();
      return;
    }
    if (patientId > 0 && tokenReady && !_hasFetched) {
      _hasFetched = true;
      ref
          .read(prescriptionViewModelProvider.notifier)
          .patientPrescriptionList(patientId);
    }

    if (tokenReady && patientId > 0 && !_hasFetchedFamily) {
      _hasFetchedFamily = true;
      ref
          .read(familyViewModelProvider.notifier)
          .fetchAllFamilyMembers(patientId);
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

  PrescriptionState get _state => ref.watch(prescriptionViewModelProvider);

  bool _passesDateFilter(PatientPrescription p) {
    final now = DateTime.now();
    final d = p.prescriptionDate;
    switch (_dateFilter) {
      case _DateFilter.all:
        return true;
      case _DateFilter.today:
        return d.year == now.year && d.month == now.month && d.day == now.day;
      case _DateFilter.thisWeek:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final from = DateTime(start.year, start.month, start.day);
        return d.isAfter(from.subtract(const Duration(seconds: 1)));
      case _DateFilter.thisMonth:
        return d.year == now.year && d.month == now.month;
      case _DateFilter.last3Months:
        return d.isAfter(now.subtract(const Duration(days: 90)));
      case _DateFilter.last6Months:
        return d.isAfter(now.subtract(const Duration(days: 180)));
      case _DateFilter.thisYear:
        return d.year == now.year;
      case _DateFilter.custom:
        if (_customFrom != null && d.isBefore(_customFrom!)) return false;
        if (_customTo != null &&
            d.isAfter(_customTo!.add(const Duration(days: 1))))
          return false;
        return true;
    }
  }

  List<PatientPrescription> _filtered(
    List<PatientPrescription> source,
    String statusFilter,
    int patientId,
    String patientName,
    List<FamilyMember> members,
  ) {
    var list = source.where((p) {
      if (statusFilter != 'all' && p.status != statusFilter) return false;
      if (!_passesMemberFilter(p, patientId, patientName, members))
        return false;
      if (!_passesDateFilter(p)) return false;
      if (_search.trim().isNotEmpty) {
        final q = _search.toLowerCase();
        if (!(p.diagnosis ?? '').toLowerCase().contains(q) &&
            !p.prescriptionId.toString().contains(q) &&
            !p.doctorName.toLowerCase().contains(q))
          return false;
      }
      return true;
    }).toList();

    list.sort(
      (a, b) => _sortNewestFirst
          ? b.prescriptionDate.compareTo(a.prescriptionDate)
          : a.prescriptionDate.compareTo(b.prescriptionDate),
    );
    return list;
  }

  bool _passesMemberFilter(
    PatientPrescription p,
    int patientId,
    String patientName,
    List<FamilyMember> members,
  ) {
    if (_memberFilter == _filterAll) return true;
    if (_memberFilter == _filterSelf) {
      if (patientId > 0 && p.patientId == patientId) return true;
      final selfName = patientName.trim().toLowerCase();
      return selfName.isNotEmpty && p.patientName.toLowerCase() == selfName;
    }
    if (_memberFilter > 0 && p.patientId == _memberFilter) return true;
    final member = members
        .where((m) => m.memberId == _memberFilter)
        .cast<FamilyMember?>()
        .firstWhere((m) => m != null, orElse: () => null);
    final memberName = member?.memberName?.trim().toLowerCase();
    return memberName != null &&
        memberName.isNotEmpty &&
        p.patientName.toLowerCase() == memberName;
  }

  String _fmtDate(DateTime d) {
    const m = [
      '',
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  void _openDetail(PatientPrescription p) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, anim, __) => PatientPrescriptionViewScreen(
          prescriptionId: p.prescriptionId,
          fallback: p,
          patientId: ref.read(patientLoginViewModelProvider).patientId ?? 0,
        ),
        transitionsBuilder: (_, anim, __, child) => SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1.0, 0.0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DateFilterSheet(
        current: _dateFilter,
        customFrom: _customFrom,
        customTo: _customTo,
        sortNewest: _sortNewestFirst,
        onApply: (filter, from, to, newest) {
          setState(() {
            _dateFilter = filter;
            _customFrom = from;
            _customTo = to;
            _sortNewestFirst = newest;
          });
        },
      ),
    );
  }

  bool get _hasActiveFilter =>
      _dateFilter != _DateFilter.all || !_sortNewestFirst;

  // ── Resolve the label shown inside the trigger button ────────────
  String _memberLabel(String patientName, List<FamilyMember> members) {
    if (_memberFilter == _filterAll) return 'All';
    if (_memberFilter == _filterSelf) {
      return patientName.isNotEmpty ? patientName.split(' ').first : 'Self';
    }
    final m = members
        .cast<FamilyMember?>()
        .firstWhere((m) => m?.memberId == _memberFilter, orElse: () => null);
    return m?.memberName?.split(' ').first ?? 'Member';
  }

  @override
  Widget build(BuildContext context) {
    final patientState = ref.watch(patientLoginViewModelProvider);
    final patientId = patientState.patientId ?? 0;
    final patientName = patientState.name ?? 'Patient';
    final familyState = ref.watch(familyViewModelProvider);
    final familyMembers = familyState.allfamilyMembers.maybeWhen(
      data: (members) => members,
      orElse: () => const <FamilyMember>[],
    );
    final tokenState = ref.watch(tokenProvider);
    final tokenReady =
        !tokenState.isLoading && (tokenState.accessToken ?? '').isNotEmpty;
    final waitingAuth = !tokenReady || patientId == 0;

    final apiList =
        _state.prescriptionsListPatient ?? const <PrescriptionModel>[];
    final mapped = apiList
        .map(
          (m) => PatientPrescription.fromModel(
            m,
            fallbackPatientId: patientId,
            fallbackPatientName: patientName,
          ),
        )
        .toList();

    final all = _filtered(mapped, 'all', patientId, patientName, familyMembers);
    final active =
        _filtered(mapped, 'active', patientId, patientName, familyMembers);
    final past = _filtered(
          mapped,
          'completed',
          patientId,
          patientName,
          familyMembers,
        ) +
        _filtered(mapped, 'expired', patientId, patientName, familyMembers);

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Column(
            children: [
              _buildAppBar(all.length, patientName, familyMembers),
              _buildSearchFilterRow(),
              if (_hasActiveFilter) _buildActiveFilterChips(),
              _buildTabBar(all.length, active.length, past.length),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildListBody(all, waitAuth: waitingAuth),
                    _buildListBody(active, waitAuth: waitingAuth),
                    _buildListBody(past, waitAuth: waitingAuth),
                  ],
                ),
              ),
            ],
          ),
          if (_state.isLoading)
            Container(
              color: Colors.black.withOpacity(0.25),
              child: const Center(
                child: CircularProgressIndicator(color: kPrimary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppBar(
    int total,
    String patientName,
    List<FamilyMember> members,
  ) =>
      Container(
        decoration: const BoxDecoration(
          color: kCardBg,
          border: Border(bottom: BorderSide(color: kBorder, width: 0.5)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 14, 14),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Prescriptions',
                        style: TextStyle(
                          color: kTextDark,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$total records',
                        style:
                            const TextStyle(color: kTextMid, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                // ── FIXED: Custom popup member dropdown ──────────
                _MemberDropdown(
                  selected: _memberFilter,
                  patientName: patientName,
                  members: members,
                  onChanged: (val) =>
                      setState(() => _memberFilter = val),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildSearchFilterRow() => Container(
        color: kCardBg,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style:
                      const TextStyle(fontSize: 13, color: kTextDark),
                  decoration: InputDecoration(
                    hintText: 'Search diagnosis, Rx, doctor...',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFB0B8C8),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: kPrimary,
                      size: 18,
                    ),
                    suffixIcon: _search.isNotEmpty
                        ? GestureDetector(
                            onTap: () => setState(() {
                              _search = '';
                              _searchCtrl.clear();
                            }),
                            child: const Icon(
                              Icons.close_rounded,
                              color: kTextMid,
                              size: 16,
                            ),
                          )
                        : null,
                    filled: true,
                    fillColor: kBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 0,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: kBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide:
                          const BorderSide(color: kPrimary, width: 1.5),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _showFilterSheet,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _hasActiveFilter ? kPrimary : kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _hasActiveFilter ? kPrimary : kBorder),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      color: _hasActiveFilter ? Colors.white : kPrimary,
                      size: 20,
                    ),
                    if (_hasActiveFilter)
                      Positioned(
                        top: 7,
                        right: 7,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: kOrange,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () =>
                  setState(() => _sortNewestFirst = !_sortNewestFirst),
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: Icon(
                  _sortNewestFirst
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  color: kPrimary,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildActiveFilterChips() => Container(
        color: kCardBg,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
        child: Row(
          children: [
            if (_dateFilter != _DateFilter.all)
              _filterChip(
                icon: _dateFilter.icon,
                label: _dateFilter == _DateFilter.custom &&
                        _customFrom != null
                    ? '${_fmtDate(_customFrom!)} – ${_customTo != null ? _fmtDate(_customTo!) : '...'}'
                    : _dateFilter.label,
                onRemove: () =>
                    setState(() => _dateFilter = _DateFilter.all),
              ),
            if (!_sortNewestFirst) ...[
              if (_dateFilter != _DateFilter.all)
                const SizedBox(width: 6),
              _filterChip(
                icon: Icons.arrow_upward_rounded,
                label: 'Oldest First',
                onRemove: () =>
                    setState(() => _sortNewestFirst = true),
              ),
            ],
          ],
        ),
      );

  Widget _filterChip({
    required IconData icon,
    required String label,
    required VoidCallback onRemove,
  }) =>
      Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: kPrimaryBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPrimary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: kPrimary, size: 12),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: kPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 5),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(Icons.close_rounded,
                  color: kPrimary, size: 13),
            ),
          ],
        ),
      );

  Widget _buildTabBar(int all, int active, int past) => Container(
        color: kCardBg,
        child: Column(
          children: [
            TabBar(
              controller: _tabCtrl,
              labelColor: kPrimary,
              unselectedLabelColor: kTextMid,
              indicatorColor: kPrimary,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
              tabs: [
                Tab(text: 'All ($all)'),
                Tab(text: 'Active ($active)'),
                Tab(text: 'Past ($past)'),
              ],
            ),
            const Divider(height: 1, color: kBorder),
          ],
        ),
      );

  Widget _buildListBody(
    List<PatientPrescription> items, {
    required bool waitAuth,
  }) {
    if (waitAuth) {
      return const Center(
          child: CircularProgressIndicator(color: kPrimary));
    }
    if (_state.error != null && items.isEmpty)
      return _errorState(_state.error!);
    if (items.isEmpty && !_state.isLoading) return _emptyState();
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () => ref
          .read(prescriptionViewModelProvider.notifier)
          .patientPrescriptionList(
            ref.read(patientLoginViewModelProvider).patientId ?? 0,
          ),
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 30),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _PrescriptionCompactCard(
          prescription: items[i],
          fmtDate: _fmtDate,
          onTap: () => _openDetail(items[i]),
        ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 52,
              color: kPrimary.withOpacity(0.2),
            ),
            const SizedBox(height: 14),
            const Text(
              'No prescriptions found',
              style: TextStyle(
                fontSize: 15,
                color: kTextMid,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different filter or search',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFFB0B8C8)),
            ),
            if (_hasActiveFilter) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: () => setState(() {
                  _dateFilter = _DateFilter.all;
                  _sortNewestFirst = true;
                }),
                icon: const Icon(Icons.clear_all_rounded, size: 16),
                label: const Text('Clear Filters'),
                style:
                    TextButton.styleFrom(foregroundColor: kPrimary),
              ),
            ],
          ],
        ),
      );

  Widget _errorState(String msg) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded,
                  size: 50, color: kRed),
              const SizedBox(height: 12),
              Text(
                msg,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, color: kTextMid),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref
                    .read(prescriptionViewModelProvider.notifier)
                    .patientPrescriptionList(
                      ref
                              .read(patientLoginViewModelProvider)
                              .patientId ??
                          0,
                    ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  CUSTOM MEMBER DROPDOWN  (replaces the broken DropdownButton)
// ════════════════════════════════════════════════════════════════════
class _MemberDropdown extends StatelessWidget {
  final int selected;
  final String patientName;
  final List<FamilyMember> members;
  final ValueChanged<int> onChanged;

  static const int _filterAll = -1;
  static const int _filterSelf = -2;

  const _MemberDropdown({
    required this.selected,
    required this.patientName,
    required this.members,
    required this.onChanged,
  });

  String get _triggerLabel {
    if (selected == _filterAll) return 'All';
    if (selected == _filterSelf) {
      return patientName.isNotEmpty
          ? patientName.split(' ').first
          : 'Self';
    }
    final m = members
        .cast<FamilyMember?>()
        .firstWhere((m) => m?.memberId == selected,
            orElse: () => null);
    return m?.memberName?.split(' ').first ?? 'Member';
  }

  Widget _triggerAvatar() {
    if (selected == _filterAll) {
      return Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: kBg,
          shape: BoxShape.circle,
          border: Border.all(color: kBorder),
        ),
        child: const Icon(Icons.people_rounded,
            color: kTextMid, size: 12),
      );
    }
    String name;
    Color color;
    if (selected == _filterSelf) {
      name = patientName;
      color = kPrimary;
    } else {
      final m = members
          .cast<FamilyMember?>()
          .firstWhere((m) => m?.memberId == selected,
              orElse: () => null);
      name = m?.memberName ?? 'M';
      final idx =
          members.indexWhere((m) => m.memberId == selected);
      color = _avatarColor(idx + 1);
    }
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  void _show(BuildContext context) async {
    final RenderBox button =
        context.findRenderObject() as RenderBox;
    final RenderBox overlay = Navigator.of(context)
        .overlay!
        .context
        .findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        button.localToGlobal(
            button.size.bottomLeft(Offset.zero),
            ancestor: overlay),
        button.localToGlobal(
            button.size.bottomRight(Offset.zero),
            ancestor: overlay),
      ),
      Offset.zero & overlay.size,
    );

    // Build menu items
    final items = <PopupMenuEntry<int>>[
      // ── Section: All ─────────────────────────────────────────
      _MemberPopupItem(
        value: _filterAll,
        selected: selected == _filterAll,
        avatarWidget: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: kBg,
            shape: BoxShape.circle,
            border: Border.all(color: kBorder),
          ),
          child: const Icon(Icons.people_rounded,
              color: kTextMid, size: 14),
        ),
        name: 'All members',
        subtitle: null,
      ),
      const PopupMenuDivider(height: 1),
      // ── Section header ────────────────────────────────────────
      const _SectionHeader('SELF'),
      _MemberPopupItem(
        value: _filterSelf,
        selected: selected == _filterSelf,
        avatarWidget: _AvatarCircle(
            name: patientName, color: kPrimary, size: 28),
        name: patientName.isNotEmpty ? patientName : 'Self',
        subtitle: 'Self',
      ),
      if (members.isNotEmpty) ...[
        const PopupMenuDivider(height: 1),
        const _SectionHeader('FAMILY MEMBERS'),
        ...members
            .where((m) => (m.memberId ?? 0) > 0)
            .toList()
            .asMap()
            .entries
            .map((e) => _MemberPopupItem(
                  value: e.value.memberId!,
                  selected: selected == e.value.memberId,
                  avatarWidget: _AvatarCircle(
                    name: e.value.memberName ?? 'M',
                    color: _avatarColor(e.key + 1),
                    size: 28,
                  ),
                  name: e.value.memberName ?? 'Member',
                  subtitle: e.value.relationName,
                )),
      ],
    ];

    final result = await showMenu<int>(
      context: context,
      position: position,
      items: items,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: kBorder, width: 0.8),
      ),
      elevation: 8,
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
    );

    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _show(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _triggerAvatar(),
            const SizedBox(width: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 80),
              child: Text(
                _triggerLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: kTextDark,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header popup entry ────────────────────────────────────
class _SectionHeader extends PopupMenuEntry<int> {
  final String label;
  const _SectionHeader(this.label);

  @override
  double get height => 32;

  @override
  bool represents(int? value) => false;

  @override
  State<_SectionHeader> createState() => _SectionHeaderState();
}

class _SectionHeaderState extends State<_SectionHeader> {
  @override
  Widget build(BuildContext context) => Padding(
        padding:
            const EdgeInsets.fromLTRB(14, 10, 14, 4),
        child: Text(
          widget.label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: kTextMid,
            letterSpacing: 0.6,
          ),
        ),
      );
}

// ── Member popup item ─────────────────────────────────────────────
class _MemberPopupItem extends PopupMenuEntry<int> {
  final int value;
  final bool selected;
  final Widget avatarWidget;
  final String name;
  final String? subtitle;

  const _MemberPopupItem({
    required this.value,
    required this.selected,
    required this.avatarWidget,
    required this.name,
    required this.subtitle,
  });

  @override
  double get height => 54;

  @override
  bool represents(int? v) => v == value;

  @override
  State<_MemberPopupItem> createState() => _MemberPopupItemState();
}

class _MemberPopupItemState extends State<_MemberPopupItem> {
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(widget.value),
      child: Container(
        color: widget.selected
            ? kPrimaryBg
            : Colors.transparent,
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        child: Row(
          children: [
            widget.avatarWidget,
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    widget.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: widget.selected
                          ? kPrimary
                          : kTextDark,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      widget.subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: kTextMid,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (widget.selected)
              const Icon(Icons.check_rounded,
                  color: kPrimary, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── Avatar circle helper ──────────────────────────────────────────
class _AvatarCircle extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  const _AvatarCircle({
    required this.name,
    required this.color,
    required this.size,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(
          _initials(name),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.33,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  DATE FILTER BOTTOM SHEET
// ════════════════════════════════════════════════════════════════════
class _DateFilterSheet extends StatefulWidget {
  final _DateFilter current;
  final DateTime? customFrom;
  final DateTime? customTo;
  final bool sortNewest;
  final void Function(_DateFilter, DateTime?, DateTime?, bool) onApply;

  const _DateFilterSheet({
    required this.current,
    required this.customFrom,
    required this.customTo,
    required this.sortNewest,
    required this.onApply,
  });

  @override
  State<_DateFilterSheet> createState() => _DateFilterSheetState();
}

class _DateFilterSheetState extends State<_DateFilterSheet> {
  late _DateFilter _sel;
  late DateTime? _from;
  late DateTime? _to;
  late bool _newest;

  @override
  void initState() {
    super.initState();
    _sel = widget.current;
    _from = widget.customFrom;
    _to = widget.customTo;
    _newest = widget.sortNewest;
  }

  String _fmt(DateTime d) {
    const m = [
      '',
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme:
                const ColorScheme.light(primary: kPrimary)),
        child: child!,
      ),
    );
    if (picked != null)
      setState(() => isFrom ? _from = picked : _to = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        MediaQuery.of(context).padding.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin:
                  const EdgeInsets.symmetric(vertical: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE0E0E0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Text(
                'Filter by Date',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextDark,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _sel = _DateFilter.all;
                  _from = null;
                  _to = null;
                  _newest = true;
                }),
                child: const Text(
                  'Reset',
                  style: TextStyle(
                      color: kRed,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _DateFilter.values
                .where((f) => f != _DateFilter.custom)
                .map((f) => _optionChip(f))
                .toList(),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () =>
                setState(() => _sel = _DateFilter.custom),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _sel == _DateFilter.custom
                    ? kPrimaryBg
                    : kBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _sel == _DateFilter.custom
                      ? kPrimary
                      : kBorder,
                  width:
                      _sel == _DateFilter.custom ? 1.5 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.tune_rounded,
                        color: _sel == _DateFilter.custom
                            ? kPrimary
                            : kTextMid,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Custom Date Range',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _sel == _DateFilter.custom
                              ? kPrimary
                              : kTextMid,
                        ),
                      ),
                    ],
                  ),
                  if (_sel == _DateFilter.custom) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _datePicker(
                            label: 'From',
                            value: _from,
                            onTap: () =>
                                _pickDate(isFrom: true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _datePicker(
                            label: 'To',
                            value: _to,
                            onTap: () =>
                                _pickDate(isFrom: false),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sort Order',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _sortBtn(
                  label: 'Newest First',
                  icon: Icons.arrow_downward_rounded,
                  selected: _newest,
                  onTap: () => setState(() => _newest = true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _sortBtn(
                  label: 'Oldest First',
                  icon: Icons.arrow_upward_rounded,
                  selected: !_newest,
                  onTap: () => setState(() => _newest = false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_sel, _from, _to, _newest);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Apply Filter',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _optionChip(_DateFilter f) {
    final sel = _sel == f;
    return GestureDetector(
      onTap: () => setState(() => _sel = f),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel ? kPrimary : kBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: sel ? kPrimary : kBorder,
            width: sel ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(f.icon,
                color: sel ? Colors.white : kTextMid,
                size: 13),
            const SizedBox(width: 5),
            Text(
              f.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : kTextMid,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _datePicker({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today_rounded,
                  color: kPrimary, size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 10, color: kTextMid)),
                    Text(
                      value != null ? _fmt(value) : 'Select',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: value != null
                            ? kTextDark
                            : kTextMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _sortBtn({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? kPrimary : kBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: selected ? kPrimary : kBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  color:
                      selected ? Colors.white : kTextMid,
                  size: 15),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : kTextMid,
                ),
              ),
            ],
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  COMPACT PRESCRIPTION CARD
// ════════════════════════════════════════════════════════════════════
class _PrescriptionCompactCard extends StatelessWidget {
  final PatientPrescription prescription;
  final String Function(DateTime) fmtDate;
  final VoidCallback onTap;

  const _PrescriptionCompactCard({
    required this.prescription,
    required this.fmtDate,
    required this.onTap,
  });

  Color get _statusColor => switch (prescription.status) {
        'active' => kGreen,
        'completed' => kPrimary,
        _ => kTextMid,
      };
  String get _statusLabel => switch (prescription.status) {
        'active' => 'Active',
        'completed' => 'Completed',
        _ => 'Expired',
      };
  IconData get _statusIcon => switch (prescription.status) {
        'active' => Icons.check_circle_rounded,
        'completed' => Icons.task_alt_rounded,
        _ => Icons.cancel_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: prescription.status == 'active'
              ? kGreen.withOpacity(0.25)
              : kBorder,
          width: 1.1,
        ),
      ),
      child: Column(
        children: [
          // ── Top strip ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: prescription.status == 'active'
                  ? kGreen.withOpacity(0.04)
                  : kBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(13),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: kPrimaryBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_rounded,
                          color: kPrimary, size: 11),
                      const SizedBox(width: 4),
                      Text(
                        'Rx #${prescription.prescriptionId}',
                        style: const TextStyle(
                          color: kPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.calendar_today_rounded,
                    color: kTextMid, size: 11),
                const SizedBox(width: 3),
                Text(
                  fmtDate(prescription.prescriptionDate),
                  style: const TextStyle(
                      fontSize: 11, color: kTextMid),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: _statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_statusIcon,
                          color: _statusColor, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        _statusLabel,
                        style: TextStyle(
                          color: _statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Body ─────────────────────────────────────────────
          Padding(
            padding:
                const EdgeInsets.fromLTRB(12, 10, 12, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor row
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF1558C0),
                            kPrimary
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius:
                            BorderRadius.circular(7),
                      ),
                      child: const Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: 15),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(
                            prescription.doctorName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            prescription.specialization,
                            style: const TextStyle(
                                fontSize: 10,
                                color: kTextMid),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Patient row
                Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        prescription.patientName
                            .split(' ')
                            .where((w) => w.isNotEmpty)
                            .take(1)
                            .map((w) => w[0].toUpperCase())
                            .join(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        prescription.patientName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextDark,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (prescription.patientAge != null &&
                        prescription.patientAge! > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(
                          color: kBg,
                          borderRadius:
                              BorderRadius.circular(4),
                          border:
                              Border.all(color: kBorder),
                        ),
                        child: Text(
                          '${prescription.patientAge} yrs',
                          style: const TextStyle(
                            fontSize: 9,
                            color: kTextMid,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),

          // ── Bottom row ────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              border: Border(
                  top: BorderSide(
                      color: kBorder, width: 0.8)),
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 7),
            child: Row(
              children: [
                _miniChip(
                  icon: Icons.medication_rounded,
                  label:
                      '${prescription.medicines.length} Med',
                  color: kPurple,
                ),
                if (prescription.followUpDate !=
                    null) ...[
                  const SizedBox(width: 6),
                  _miniChip(
                    icon: Icons.event_rounded,
                    label:
                        '${fmtDate(prescription.followUpDate!)}. Follow-up',
                    color: kOrange,
                  ),
                ],
                const Spacer(),
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF1558C0),
                          kPrimary
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius:
                          BorderRadius.circular(8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            Icons.visibility_rounded,
                            color: Colors.white,
                            size: 12),
                        SizedBox(width: 5),
                        Text(
                          'View Prescription',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.1,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                            Icons
                                .arrow_forward_ios_rounded,
                            color: Colors.white,
                            size: 10),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip({
    required IconData icon,
    required String label,
    required Color color,
  }) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.09),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 10),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
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
    super.key,
    required this.prescriptionId,
    required this.fallback,
    required this.patientId,
  });

  @override
  ConsumerState<PatientPrescriptionViewScreen> createState() =>
      _PatientPrescriptionViewScreenState();
}

class _PatientPrescriptionViewScreenState
    extends ConsumerState<PatientPrescriptionViewScreen> {
  late PatientPrescription _rx;

  String _fmtDate(DateTime d) {
    const m = [
      '',
      'Jan','Feb','Mar','Apr','May','Jun',
      'Jul','Aug','Sep','Oct','Nov','Dec',
    ];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  String _fmtDateTime(DateTime d) {
    const months = [
      '',
      'January','February','March','April','May','June',
      'July','August','September','October','November','December',
    ];
    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final min = d.minute.toString().padLeft(2, '0');
    final ampm = d.hour < 12 ? 'AM' : 'PM';
    return '${d.day} ${months[d.month]} ${d.year}  ·  $h:$min $ampm';
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
    1: 'Tablet',
    2: 'Syrup',
    3: 'Injection',
    4: 'Drops',
    5: 'Lotion',
    6: 'Spray',
  };
  static const _typeIcon = {
    1: Icons.medication_rounded,
    2: Icons.local_drink_rounded,
    3: Icons.vaccines_rounded,
    4: Icons.water_drop_rounded,
    5: Icons.soap_rounded,
    6: Icons.air_rounded,
  };

  void _snack(String msg, Color c) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: c,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );

  @override
  void initState() {
    super.initState();
    _rx = widget.fallback;
    Future.microtask(() {
      ref
          .read(prescriptionViewModelProvider.notifier)
          .patientPrescriptionDetails(widget.prescriptionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(prescriptionViewModelProvider);
    final details = state.prescriptionDetailsPatient;
    if (details != null && details.isNotEmpty) {
      _rx = PatientPrescription.fromFlatList(
        details,
        fallbackPatientId:
            ref.read(patientLoginViewModelProvider).patientId ?? 0,
        fallbackPatientName:
            ref.read(patientLoginViewModelProvider).name ?? 'Patient',
      );
    }

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 100),
                  children: [
                    _buildClinicCard(),
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(14, 10, 14, 0),
                      child: Column(
                        children: [
                          _buildPatientRow(),
                          _vg(10),
                          if (_rx.diagnosis?.isNotEmpty == true) ...[
                            _buildDiagnosisCard(),
                            _vg(10),
                          ],
                          if (_rx.symptoms?.isNotEmpty == true) ...[
                            _buildSymptomsCard(),
                            _vg(10),
                          ],
                          _buildMedicinesCard(),
                          _vg(10),
                          _buildNotesRow(),
                          _vg(10),
                          if (_rx.followUpDate != null) ...[
                            _buildFollowUpCard(),
                            _vg(10),
                          ],
                          _buildFooter(),
                          _vg(10),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _buildBottomBar(),
            ],
          ),
          if (state.isLoading)
            Container(
              color: Colors.black.withOpacity(0.2),
              child: const Center(
                child:
                    CircularProgressIndicator(color: kPrimary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() => Container(
        color: kCardBg,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(4, 6, 14, 10),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: kTextDark,
                      size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 2),
                const Text(
                  'Prescription Details',
                  style: TextStyle(
                    color: kTextDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      );

  Widget _buildClinicCard() => Container(
        margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0D000000),
                blurRadius: 10,
                offset: Offset(0, 3)),
          ],
          border: Border.all(color: kBorder, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1558C0), kPrimary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              padding:
                  const EdgeInsets.fromLTRB(14, 14, 14, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                        Icons.local_hospital_rounded,
                        color: Colors.white,
                        size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rx.clinicName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${_rx.clinicAddress}  ·  Ph: ${_rx.clinicContact}',
                          style: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.82),
                              fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: double.infinity,
              color: const Color(0xFF3D8EF0),
              padding:
                  const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          _rx.doctorName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_rx.qualification}  ·  ${_rx.specialization}',
                          style: TextStyle(
                              color:
                                  Colors.white.withOpacity(0.78),
                              fontSize: 11),
                        ),
                        if (_rx.regNo?.isNotEmpty == true)
                          Text(
                            'Reg. No. ${_rx.regNo}',
                            style: TextStyle(
                                color: Colors.white
                                    .withOpacity(0.65),
                                fontSize: 10),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              Colors.white.withOpacity(0.35)),
                    ),
                    child: Text(
                      'Rx #${_rx.prescriptionId}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildPatientRow() => _card(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                  color: kPrimary, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                _rx.patientName
                    .split(' ')
                    .map((w) => w.isNotEmpty ? w[0] : '')
                    .take(2)
                    .join(),
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _rx.patientName,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextDark),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      if (_rx.patientAge != null &&
                          _rx.patientAge! > 0)
                        _chip('${_rx.patientAge} yrs'),
                      if (_rx.patientGender?.isNotEmpty ==
                          true)
                        _chip(_rx.patientGender!),
                      if (_rx.tokenNumber != null)
                        _chip('Token #${_rx.tokenNumber}'),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Date',
                    style: TextStyle(
                        fontSize: 10, color: kTextMid)),
                const SizedBox(height: 2),
                Text(
                  _fmtDate(_rx.prescriptionDate),
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: kTextDark),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _buildSymptomsCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('SYMPTOMS'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E7),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                _rx.symptoms!,
                style: const TextStyle(
                    fontSize: 13,
                    color: kTextDark,
                    height: 1.45),
              ),
            ),
          ],
        ),
      );

  Widget _buildDiagnosisCard() => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('DIAGNOSIS'),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: kPrimaryBg,
                  borderRadius: BorderRadius.circular(10)),
              child: Row(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: kPrimary.withOpacity(0.12),
                      borderRadius:
                          BorderRadius.circular(6),
                    ),
                    child: const Icon(
                        Icons.biotech_rounded,
                        color: kPrimary,
                        size: 14),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _rx.diagnosis!,
                      style: const TextStyle(
                          fontSize: 13,
                          color: kTextDark,
                          fontWeight: FontWeight.w500,
                          height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _buildMedicinesCard() => _card(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: _sectionLabel('MEDICINES'),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                final w = constraints.maxWidth - 24;
                final c1 = w * 0.28;
                final c2 = w * 0.30;
                final c3 = w * 0.24;
                final c4 = w * 0.18;
                return Column(
                  children: [
                    Container(
                      color: kBg,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        children: [
                          SizedBox(
                              width: c1,
                              child:
                                  const _ColHead('MEDICINE')),
                          SizedBox(
                            width: c2,
                            child: const Text(
                              'FREQ/DOSE',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: kTextMid,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: c3,
                            child: const Text(
                              'TIMING',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: kTextMid,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                          SizedBox(
                            width: c4,
                            child: const Text(
                              'DURATION',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: kTextMid,
                                letterSpacing: 0.3,
                              ),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(
                        height: 1, color: kBorder),
                    ListView.separated(
                      shrinkWrap: true,
                      physics:
                          const NeverScrollableScrollPhysics(),
                      itemCount: _rx.medicines.length,
                      separatorBuilder: (_, __) =>
                          const Divider(
                              height: 1,
                              color: kBorder,
                              indent: 12),
                      itemBuilder: (_, i) {
                        final m = _rx.medicines[i];
                        final c = _typeColor[
                                m.medicineTypeId] ??
                            kTextMid;
                        final lbl = _typeLabel[
                                m.medicineTypeId] ??
                            m.mediTypeName ??
                            'Unknown';
                        final ic = _typeIcon[
                                m.medicineTypeId] ??
                            Icons.medication_rounded;
                        return _MedRow(
                          med: m,
                          color: c,
                          typeLabel: lbl,
                          typeIcon: ic,
                          c1: c1,
                          c2: c2,
                          c3: c3,
                          c4: c4,
                        );
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      );

  Widget _buildNotesRow() {
    final hasClinical = _rx.clinicalNotes?.isNotEmpty == true;
    final hasAdvice = _rx.advice?.isNotEmpty == true;
    if (!hasClinical && !hasAdvice) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasClinical)
          Expanded(
            child: _noteBox(
              color: const Color(0xFFF0F4FF),
              borderColor: const Color(0xFFBFD0FF),
              iconColor: kPrimary,
              icon: Icons.notes_rounded,
              title: 'CLINICAL INSTRUCTIONS',
              text: _rx.clinicalNotes!,
            ),
          ),
        if (hasClinical && hasAdvice)
          const SizedBox(width: 10),
        if (hasAdvice)
          Expanded(
            child: _noteBox(
              color: const Color(0xFFF0FFF4),
              borderColor: const Color(0xFFA7F3D0),
              iconColor: kGreen,
              icon: Icons.medical_information_rounded,
              title: "DOCTOR'S ADVICE",
              text: _rx.advice!,
            ),
          ),
      ],
    );
  }

  Widget _noteBox({
    required Color color,
    required Color borderColor,
    required Color iconColor,
    required IconData icon,
    required String title,
    required String text,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 13),
                const SizedBox(width: 5),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: iconColor,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              text,
              style: const TextStyle(
                  fontSize: 12,
                  color: kTextDark,
                  height: 1.5),
            ),
          ],
        ),
      );

  Widget _buildFollowUpCard() {
    final followDate = _rx.followUpDate!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FFF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: kGreen.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.event_available_rounded,
                color: kGreen, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'NEXT FOLLOW-UP',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kGreen,
                      letterSpacing: 0.6),
                ),
                const SizedBox(height: 4),
                Text(
                  _fmtDateTime(followDate),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: kTextDark),
                ),
                if (_rx.followUpRoom?.isNotEmpty == true ||
                    _rx.followUpInstruction?.isNotEmpty ==
                        true) ...[
                  const SizedBox(height: 3),
                  Text(
                    [
                      if (_rx.followUpRoom?.isNotEmpty ==
                          true)
                        _rx.followUpRoom!,
                      if (_rx.followUpInstruction
                              ?.isNotEmpty ==
                          true)
                        _rx.followUpInstruction!,
                    ].join('  ·  '),
                    style: const TextStyle(
                        fontSize: 11, color: kTextMid),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('This prescription is valid for 30 days.',
                    style: TextStyle(
                        fontSize: 11, color: kTextMid)),
                SizedBox(height: 3),
                Text(
                    'Dispensed by licensed pharmacist only.',
                    style: TextStyle(
                        fontSize: 11, color: kTextMid)),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            child: Column(
              children: [
                const Divider(
                    color: kTextDark, thickness: 0.8),
                const SizedBox(height: 4),
                Text(
                  _rx.doctorName,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextDark),
                  textAlign: TextAlign.center,
                ),
                Text(
                  '${_rx.qualification}  ·  ${_rx.specialization}',
                  style: const TextStyle(
                      fontSize: 10, color: kTextMid),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      );

  Widget _buildBottomBar() => Container(
        padding: EdgeInsets.fromLTRB(
          12,
          10,
          12,
          MediaQuery.of(context).padding.bottom + 10,
        ),
        decoration: const BoxDecoration(
          color: kCardBg,
          boxShadow: [
            BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 16,
                offset: Offset(0, -3)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    _snack('Downloading PDF...', kPrimary),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1558C0), kPrimary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 7),
                      Text('Download',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    _snack('Sharing prescription...', kPrimary),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 13),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1558C0), kPrimary],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(Icons.share_rounded,
                          color: Colors.white, size: 18),
                      SizedBox(width: 7),
                      Text('Share',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) =>
      Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
                color: Color(0x0B000000),
                blurRadius: 10,
                offset: Offset(0, 2)),
          ],
        ),
        child: child,
      );

  Widget _sectionLabel(String t) => Row(
        children: [
          Container(
            width: 3,
            height: 14,
            decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 7),
          Text(
            t,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: kPrimary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      );

  Widget _chip(String t) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Text(
          t,
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: kTextMid),
        ),
      );

  Widget _vg(double h) => SizedBox(height: h);
}

// ════════════════════════════════════════════════════════════════════
//  MEDICINE ROW
// ════════════════════════════════════════════════════════════════════
class _MedRow extends StatelessWidget {
  final PrescriptionMedicineItem med;
  final Color color;
  final String typeLabel;
  final IconData typeIcon;
  final double c1, c2, c3, c4;

  const _MedRow({
    required this.med,
    required this.color,
    required this.typeLabel,
    required this.typeIcon,
    required this.c1,
    required this.c2,
    required this.c3,
    required this.c4,
  });

  List<String> _splitSlots(String? raw,
      {String fallback = '-'}) {
    final parts =
        (raw ?? '').split('-').map((p) => p.trim()).toList();
    while (parts.length < 3) parts.add(fallback);
    return parts
        .take(3)
        .map((p) => p.isEmpty ? fallback : p)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final dose = _splitSlots(med.doseDisplay);

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: c1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  med.medicineName?.isNotEmpty == true
                      ? med.medicineName!
                      : 'Med #${med.medicineId ?? '-'}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kTextDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (med.extraInfo?.isNotEmpty == true) ...[
                  const SizedBox(height: 2),
                  Text(
                    med.extraInfo!,
                    style: TextStyle(
                        fontSize: 10, color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, color: color, size: 9),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          typeLabel,
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: color),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: c2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 5),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: const [
                        Expanded(child: _SlotHead('M')),
                        Expanded(child: _SlotHead('A')),
                        Expanded(child: _SlotHead('N')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Divider(
                      height: 1,
                      thickness: 0.8,
                      color: kBorder),
                  const SizedBox(height: 3),
                  Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceEvenly,
                    children: [
                      Expanded(child: _SlotVal(dose[0])),
                      Expanded(child: _SlotVal(dose[1])),
                      Expanded(child: _SlotVal(dose[2])),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: c3,
            child: Text(
              med.timing ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextDark),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: c4,
            child: Text(
              med.duration ?? '-',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kTextDark),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotHead extends StatelessWidget {
  final String text;
  const _SlotHead(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: kTextMid),
      );
}

class _SlotVal extends StatelessWidget {
  final String text;
  const _SlotVal(this.text);
  @override
  Widget build(BuildContext context) => FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.center,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kTextDark),
        ),
      );
}

class _ColHead extends StatelessWidget {
  final String text;
  const _ColHead(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: kTextMid,
          letterSpacing: 0.3,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
}

// ════════════════════════════════════════════════════════════════════
//  ADAPTER MODELS  (unchanged)
// ════════════════════════════════════════════════════════════════════
DateTime? _tryParseDate(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  return DateTime.tryParse(raw);
}

DateTime _parseDateOrNow(String? raw) =>
    _tryParseDate(raw) ?? DateTime.now();

String _statusFromFollowUp(DateTime? followUpDate) {
  if (followUpDate == null) return 'completed';
  return followUpDate.isAfter(DateTime.now())
      ? 'active'
      : 'completed';
}

class PatientPrescription {
  final int prescriptionId;
  final int patientId;
  final String patientName;
  final int? patientAge;
  final String? patientGender;
  final int? tokenNumber;
  final String? regNo;
  final String? followUpRoom;
  final String? followUpInstruction;
  final String doctorName;
  final String qualification;
  final String specialization;
  final String clinicName;
  final String clinicAddress;
  final String clinicContact;
  final DateTime prescriptionDate;
  final String? symptoms;
  final String? diagnosis;
  final String? clinicalNotes;
  final DateTime? followUpDate;
  final String? advice;
  final List<PrescriptionMedicineItem> medicines;
  final String status;

  const PatientPrescription({
    required this.prescriptionId,
    required this.patientId,
    required this.patientName,
    this.patientAge,
    this.patientGender,
    this.tokenNumber,
    this.regNo,
    this.followUpRoom,
    this.followUpInstruction,
    required this.doctorName,
    required this.qualification,
    required this.specialization,
    required this.clinicName,
    required this.clinicAddress,
    required this.clinicContact,
    required this.prescriptionDate,
    required this.symptoms,
    required this.diagnosis,
    required this.clinicalNotes,
    required this.followUpDate,
    required this.advice,
    required this.medicines,
    required this.status,
  });

  factory PatientPrescription.fromModel(
    PrescriptionModel model, {
    required int fallbackPatientId,
    required String fallbackPatientName,
  }) {
    final followUp = _tryParseDate(model.followUpDate);
    final flatMeds =
        (model.medicines == null || model.medicines!.isEmpty)
            ? [
                if (model.medicineId != null ||
                    model.medicineName != null)
                  PrescriptionMedicineItem.fromFlatModel(
                      model),
              ]
            : <PrescriptionMedicineItem>[];
    return PatientPrescription(
      prescriptionId: model.prescriptionId ?? 0,
      patientId: model.patientId ?? fallbackPatientId,
      patientName:
          model.patientName ?? fallbackPatientName,
      doctorName: model.doctorName ??
          (model.doctorId != null
              ? 'Doctor #${model.doctorId}'
              : 'Doctor'),
      qualification: model.qualification ?? '-',
      specialization: model.specialization ?? '-',
      clinicName: model.clinicName ?? 'Clinic',
      clinicAddress: model.clinicAddress ?? '-',
      clinicContact: model.clinicContact ?? '-',
      prescriptionDate:
          _parseDateOrNow(model.prescriptionDate),
      symptoms: model.symptoms,
      diagnosis: model.diagnosis,
      clinicalNotes: model.clinicalNotes,
      followUpDate: followUp,
      advice: model.advice,
      medicines: (model.medicines ??
                  const <PrescriptionMedicineModel>[])
              .map(PrescriptionMedicineItem.fromModel)
              .toList() +
          flatMeds,
      status: _statusFromFollowUp(followUp),
    );
  }

  factory PatientPrescription.fromFlatList(
    List<PrescriptionModel> items, {
    required int fallbackPatientId,
    required String fallbackPatientName,
  }) {
    final first = items.first;
    final followUp = _tryParseDate(first.followUpDate);
    final meds = items
        .map(PrescriptionMedicineItem.fromFlatModel)
        .where((m) =>
            m.medicineId != null || m.medicineName != null)
        .toList();
    return PatientPrescription(
      prescriptionId: first.prescriptionId ?? 0,
      patientId: first.patientId ?? fallbackPatientId,
      patientName:
          first.patientName ?? fallbackPatientName,
      doctorName: first.doctorName ??
          (first.doctorId != null
              ? 'Doctor #${first.doctorId}'
              : 'Doctor'),
      qualification: first.qualification ?? '-',
      specialization: first.specialization ?? '-',
      clinicName: first.clinicName ?? 'Clinic',
      clinicAddress: first.clinicAddress ?? '-',
      clinicContact: first.clinicContact ?? '-',
      prescriptionDate:
          _parseDateOrNow(first.prescriptionDate),
      symptoms: first.symptoms,
      diagnosis: first.diagnosis,
      clinicalNotes: first.clinicalNotes,
      followUpDate: followUp,
      advice: first.advice,
      medicines: meds,
      status: _statusFromFollowUp(followUp),
    );
  }
}

class PrescriptionMedicineItem {
  final int? medicineId;
  final int medicineTypeId;
  final String? mediTypeName;
  final String? medicineName;
  final String? frequency;
  final String? duration;
  final String? timing;
  final String? tabletDosage;
  final String? syrupDosageMl;
  final String? injDosage;
  final String? injRoute;
  final String? dropsCount;
  final String? dropsApplication;
  final String? lotionApplyArea;
  final String? sprayPuffs;
  final String? sprayUsage;
  final String? lotionUsage;

  const PrescriptionMedicineItem({
    required this.medicineId,
    required this.medicineTypeId,
    required this.mediTypeName,
    required this.medicineName,
    required this.frequency,
    required this.duration,
    required this.timing,
    required this.tabletDosage,
    required this.syrupDosageMl,
    required this.injDosage,
    required this.injRoute,
    required this.dropsCount,
    required this.dropsApplication,
    required this.lotionApplyArea,
    required this.sprayPuffs,
    required this.sprayUsage,
    required this.lotionUsage,
  });

  String? get extraInfo {
    if (injRoute?.trim().isNotEmpty == true) return injRoute;
    if (dropsApplication?.trim().isNotEmpty == true)
      return dropsApplication;
    if (lotionApplyArea?.trim().isNotEmpty == true)
      return lotionApplyArea;
    if (sprayUsage?.trim().isNotEmpty == true) return sprayUsage;
    return null;
  }

  String get doseDisplay {
    if (tabletDosage?.trim().isNotEmpty == true)
      return tabletDosage!;
    if (syrupDosageMl?.trim().isNotEmpty == true)
      return '$syrupDosageMl';
    if (injDosage?.trim().isNotEmpty == true) return injDosage!;
    if (dropsCount?.trim().isNotEmpty == true) return dropsCount!;
    if (sprayPuffs?.trim().isNotEmpty == true) return sprayPuffs!;
    if (lotionUsage?.trim().isNotEmpty == true) return lotionUsage!;
    return '-';
  }

  factory PrescriptionMedicineItem.fromModel(
      PrescriptionMedicineModel model) {
    return PrescriptionMedicineItem(
      medicineId: model.medicineId,
      medicineTypeId: model.medicineTypeId ?? 1,
      mediTypeName: null,
      medicineName: null,
      frequency: model.frequency,
      duration: model.duration,
      timing: model.timing,
      tabletDosage: model.tabletDosage,
      syrupDosageMl: model.syrupDosageMl,
      injDosage: model.injDosage,
      injRoute: model.injRoute,
      dropsCount: model.dropsCount,
      dropsApplication: model.dropsApplication,
      lotionApplyArea: model.lotionApplyArea,
      sprayPuffs: model.sprayPuffs,
      sprayUsage: model.sprayUsage,
      lotionUsage: model.lotionUsage,
    );
  }

  factory PrescriptionMedicineItem.fromFlatModel(
      PrescriptionModel model) {
    return PrescriptionMedicineItem(
      medicineId: model.medicineId,
      medicineTypeId: model.medicineTypeId ?? 1,
      mediTypeName: model.mediTypeName,
      medicineName: model.medicineName,
      frequency: model.frequency,
      duration: model.duration,
      timing: model.timing,
      tabletDosage: model.tabletDosage,
      syrupDosageMl: model.syrupDosageMl,
      injDosage: model.injDosage,
      injRoute: model.injRoute,
      dropsCount: model.dropsCount,
      dropsApplication: model.dropsApplication,
      lotionApplyArea: model.lotionApplyArea,
      sprayPuffs: model.sprayPuffs,
      sprayUsage: model.sprayUsage,
      lotionUsage: model.lotionUsage,
    );
  }
}