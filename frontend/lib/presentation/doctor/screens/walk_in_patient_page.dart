// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:qless/core/network/dio_provider.dart';
// import 'package:qless/core/storage/token_storage.dart';
// import 'package:qless/data/api/api_service.dart';
// import 'package:qless/domain/models/appointment_request_model.dart';
// import 'package:qless/domain/models/doctor_availability_model.dart';
// import 'package:qless/domain/models/doctor_details.dart';
// import 'package:qless/domain/models/doctor_leave_model.dart';
// import 'package:qless/domain/models/doctor_schedule_model.dart';
// import 'package:qless/domain/models/family_member.dart';
// import 'package:qless/domain/models/patients.dart';
// import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
// import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

// // ── Colours ─────────────────────────────────────────────────────────────────
// const _kPrimary      = Color(0xFF26C6B0);
// const _kPrimaryDark  = Color(0xFF2BB5A0);
// const _kPrimaryLight = Color(0xFFD9F5F1);
// const _kTextPrimary  = Color(0xFF2D3748);
// const _kTextSec      = Color(0xFF718096);
// const _kTextMuted    = Color(0xFFA0AEC0);
// const _kBorder       = Color(0xFFEDF2F7);
// const _kError        = Color(0xFFFC8181);
// const _kErrorDark    = Color(0xFFC53030);
// const _kErrorLight   = Color(0xFFFFF5F5);
// const _kAmber        = Color(0xFFF6AD55);
// const _kGreen        = Color(0xFF68D391);
// const _kGreenLight   = Color(0xFFDCFCE7);
// const _kInfo         = Color(0xFF3B82F6);
// const _kInfoLight    = Color(0xFFDBEAFE);

// // ── Day / month helpers ──────────────────────────────────────────────────────
// const _kDayNames  = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
// const _kDayAbbr   = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
// const _kMonths    = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
// const _kFullMonths= ['January','February','March','April','May','June',
//                      'July','August','September','October','November','December'];

// bool _isToday(DateTime d) {
//   final n = DateTime.now();
//   return d.year == n.year && d.month == n.month && d.day == n.day;
// }

// bool _bookable(int? mode, bool isToday) =>
//     switch (mode) { 1 => isToday, 2 => true, 3 => true, _ => false };

// bool _sessionEndedToday(DoctorAvailabilityModel s) {
//   if (s.endTime == null) return false;
//   final end = _parseTime(s.endTime);
//   final now = DateTime.now();
//   return now.hour * 60 + now.minute >= end.hour * 60 + end.minute;
// }

// String _fmtDateApi(DateTime dt) =>
//     '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';

// String _fmtFull(DateTime dt) {
//   if (_isToday(dt)) return 'Today';
//   return '${_kDayAbbr[dt.weekday - 1]}, ${dt.day} ${_kMonths[dt.month - 1]}';
// }

// TimeOfDay _parseTime(String? iso) {
//   if (iso == null || iso.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
//   final dt = DateTime.tryParse(iso);
//   if (dt != null) return TimeOfDay(hour: dt.hour, minute: dt.minute);
//   final p = iso.split(':');
//   return TimeOfDay(hour: int.tryParse(p[0]) ?? 9,
//       minute: p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0);
// }

// String _fmtTime(String? iso) {
//   final t  = _parseTime(iso);
//   final sf = t.hour < 12 ? 'AM' : 'PM';
//   final h  = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
//   return '${h.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')} $sf';
// }

// String _toApiTime(String display) {
//   final parts = display.trim().split(' ');
//   final hm    = parts[0].split(':');
//   int h       = int.parse(hm[0]);
//   final m     = hm[1];
//   final isPm  = parts.length > 1 && parts[1].toUpperCase() == 'PM';
//   if (isPm && h != 12) h += 12;
//   if (!isPm && h == 12) h = 0;
//   return '${h.toString().padLeft(2,'0')}:$m';
// }

// int _slotMins(String slot) {
//   final p  = slot.split(':');
//   final h  = int.tryParse(p[0]) ?? 0;
//   final r  = p[1].split(' ');
//   final m  = int.tryParse(r[0]) ?? 0;
//   final sf = r[1];
//   var hr   = h;
//   if (sf == 'PM' && hr != 12) hr += 12;
//   if (sf == 'AM' && hr == 12) hr = 0;
//   return hr * 60 + m;
// }

// List<String> _buildTimeSlots(DoctorAvailabilityModel avail) {
//   final start = _parseTime(avail.startTime);
//   final end   = _parseTime(avail.endTime);
//   final dur   = avail.slotDuration ?? 10;
//   final slots = <String>[];
//   int cur     = start.hour * 60 + start.minute;
//   final endM  = end.hour * 60 + end.minute;
//   while (cur + dur <= endM) {
//     final h  = cur ~/ 60;
//     final m  = cur % 60;
//     final sf = h < 12 ? 'AM' : 'PM';
//     final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
//     slots.add('${dh.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')} $sf');
//     cur += dur;
//   }
//   return slots;
// }

// Map<String, List<DoctorAvailabilityModel>> _scheduleToGrouped(DoctorScheduleModel schedule) {
//   final map = <String, List<DoctorAvailabilityModel>>{};
//   for (final day in schedule.schedule ?? []) {
//     final dayName = day.day;
//     if (dayName == null || dayName.isEmpty) continue;
//     if (day.isEnabled == 0) continue;
//     final slots = (day.slots ?? []).map((s) => DoctorAvailabilityModel(
//       dayOfWeek: dayName, isEnabled: day.isEnabled != 0,
//       slotId: s.slotId, startTime: s.startTime, endTime: s.endTime,
//       bookingMode: s.bookingMode, slotDuration: s.slotDuration,
//     )).toList();
//     if (slots.isNotEmpty) map[dayName] = slots;
//   }
//   return map;
// }

// Map<String, List<DoctorAvailabilityModel>> _availToGrouped(List<DoctorAvailabilityModel> avails) {
//   final map = <String, List<DoctorAvailabilityModel>>{};
//   for (final a in avails) {
//     final day = a.dayOfWeek ?? '';
//     if (day.isEmpty) continue;
//     if (a.isEnabled == false) continue;
//     map.putIfAbsent(day, () => []).add(a);
//   }
//   return map;
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  WALK-IN PATIENT PAGE
// // ════════════════════════════════════════════════════════════════════════════
// class WalkInPatientPage extends ConsumerStatefulWidget {
//   const WalkInPatientPage({super.key});

//   @override
//   ConsumerState<WalkInPatientPage> createState() => _WalkInPatientPageState();
// }

// class _WalkInPatientPageState extends ConsumerState<WalkInPatientPage> {
//   final _formKey     = GlobalKey<FormState>();
//   final _nameCtr     = TextEditingController();
//   final _mobileCtr   = TextEditingController();
//   final _symptomsCtr = TextEditingController();

//   bool   _initLoading = true;
//   String? _initError;

//   DoctorDetails?                              _doctor;
//   Map<String, List<DoctorAvailabilityModel>>  _grouped    = {};
//   List<LeaveRange>                            _leaveRanges = [];

//   DateTime? _selectedDate;
//   int?      _selectedSlotId;
//   DoctorAvailabilityModel? _selectedAvail;
//   String?   _selectedTime;
//   Set<String> _bookedTimes = {};

//   String? _estimatedWaitTime;
//   bool    _isEstimateLoading = false;

//   bool    _booking  = false;
//   String? _bookError;

//   // ── Patient lookup (Practo-style) ────────────────────────────────────────
//   Patients? _foundPatient;         // existing patient found by mobile
//   bool      _checkingMobile = false;
//   int?      _resolvedPatientId;    // existing patient selected for self-booking
//   int?      _familyMemberId;       // existing family member's member_id (→ patient_id in appt)
//   int?      _familyHeadPatientId;  // primary patient's id when adding NEW family member
//   int?      _familyGenderId;       // gender selected when adding new family member

//   @override
//   void initState() {
//     super.initState();
//     _mobileCtr.addListener(_onMobileChanged);
//     WidgetsBinding.instance.addPostFrameCallback((_) => _init());
//   }

//   @override
//   void dispose() {
//     _mobileCtr.removeListener(_onMobileChanged);
//     _nameCtr.dispose();
//     _mobileCtr.dispose();
//     _symptomsCtr.dispose();
//     super.dispose();
//   }

//   // ── Mobile lookup ─────────────────────────────────────────────────────────
//   void _onMobileChanged() {
//     final digits = _mobileCtr.text.trim().replaceAll(RegExp(r'\D'), '');
//     if (digits.length == 10) {
//       _lookupMobile(digits);
//     } else if (_foundPatient != null || _resolvedPatientId != null || _familyMemberId != null || _familyHeadPatientId != null || _familyGenderId != null) {
//       setState(() { _foundPatient = null; _resolvedPatientId = null; _familyMemberId = null; _familyHeadPatientId = null; _familyGenderId = null; });
//     }
//   }

//   Future<void> _lookupMobile(String mobile) async {
//     final api = _api;
//     if (api == null) return;
//     setState(() { _checkingMobile = true; });
//     try {
//       final results = await api.checkPhonePatient(mobile);
//       if (!mounted) return;
//       if (results.isNotEmpty) {
//         setState(() { _foundPatient = results.first; _checkingMobile = false; });
//         _showPatientSheet(results.first);
//       } else {
//         setState(() { _foundPatient = null; _resolvedPatientId = null; _checkingMobile = false; });
//       }
//     } catch (_) {
//       if (mounted) setState(() { _checkingMobile = false; });
//     }
//   }

//   void _showPatientSheet(Patients patient) {
//     final familyNameCtr = TextEditingController();
//     int? selectedGender = 1;
//     final api = _api;
//     final membersFuture = (api != null && patient.patientId != null)
//         ? api.fetchFamilyMembers(patient.patientId!)
//         : Future.value(<FamilyMember>[]);

//     showModalBottomSheet(
//       context: context,
//       isScrollControlled: true,
//       backgroundColor: Colors.white,
//       shape: const RoundedRectangleBorder(
//         borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//       ),
//       builder: (ctx) => StatefulBuilder(
//         builder: (ctx, setSheet) => Padding(
//           padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
//           child: SingleChildScrollView(
//             child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
//               // Handle
//               Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _kBorder, borderRadius: BorderRadius.circular(2)))),
//               const SizedBox(height: 16),
//               const Text('Patient Found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextPrimary)),
//               const SizedBox(height: 4),
//               Text('${patient.name} · ${patient.mobileNo}',
//                   style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextSec)),
//               const SizedBox(height: 16),

//               // Book for primary patient
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   onPressed: () {
//                     setState(() {
//                       _resolvedPatientId   = patient.patientId;
//                       _familyMemberId      = null;
//                       _familyHeadPatientId = null;
//                       _familyGenderId      = null;
//                       _foundPatient        = null;
//                       _nameCtr.text        = patient.name ?? _nameCtr.text;
//                     });
//                     Navigator.pop(ctx);
//                     if (_canBook) _book();
//                   },
//                   style: ElevatedButton.styleFrom(
//                     backgroundColor: _kPrimary, foregroundColor: Colors.white,
//                     elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                   ),
//                   child: Text('Book for ${patient.name}',
//                       style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
//                 ),
//               ),
//               const SizedBox(height: 16),
//               const Divider(height: 1, color: _kBorder),
//               const SizedBox(height: 12),
//               const Text('Family Members', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kTextSec)),
//               const SizedBox(height: 8),

//               // Existing family members list
//               FutureBuilder<List<FamilyMember>>(
//                 future: membersFuture,
//                 builder: (_, snap) {
//                   if (snap.connectionState == ConnectionState.waiting) {
//                     return const Padding(
//                       padding: EdgeInsets.symmetric(vertical: 12),
//                       child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary)),
//                     );
//                   }
//                   final members = snap.data ?? [];
//                   if (members.isEmpty) {
//                     return const Padding(
//                       padding: EdgeInsets.only(bottom: 4),
//                       child: Text('No family members yet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted)),
//                     );
//                   }
//                   return Column(
//                     children: members.map((m) => _FamilyMemberTile(
//                       member: m,
//                       onBook: () {
//                         setState(() {
//                           _familyMemberId      = m.memberId!;
//                           _familyHeadPatientId = null;
//                           _familyGenderId      = null;
//                           _resolvedPatientId   = null;
//                           _foundPatient        = null;
//                           _nameCtr.text        = m.memberName ?? '';
//                         });
//                         Navigator.pop(ctx);
//                         if (_canBook) _book();
//                       },
//                     )).toList(),
//                   );
//                 },
//               ),
//               const SizedBox(height: 12),
//               const Divider(height: 1, color: _kBorder),
//               const SizedBox(height: 12),

//               // Add new family member
//               const Text('Add new family member:', style: TextStyle(fontSize: 12, color: _kTextSec)),
//               const SizedBox(height: 8),
//               TextField(
//                 controller: familyNameCtr,
//                 textCapitalization: TextCapitalization.words,
//                 style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
//                 decoration: InputDecoration(
//                   hintText: 'Name',
//                   contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//                   border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
//                       borderSide: const BorderSide(color: _kBorder)),
//                   enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
//                       borderSide: const BorderSide(color: _kBorder)),
//                 ),
//               ),
//               const SizedBox(height: 8),
//               Row(children: [
//                 _GenderChip(label: 'Male',   value: 1, selected: selectedGender == 1, onTap: () => setSheet(() => selectedGender = 1)),
//                 const SizedBox(width: 8),
//                 _GenderChip(label: 'Female', value: 2, selected: selectedGender == 2, onTap: () => setSheet(() => selectedGender = 2)),
//                 const SizedBox(width: 8),
//                 _GenderChip(label: 'Other',  value: 3, selected: selectedGender == 3, onTap: () => setSheet(() => selectedGender = 3)),
//               ]),
//               const SizedBox(height: 12),
//               SizedBox(
//                 width: double.infinity,
//                 child: OutlinedButton(
//                   onPressed: () async {
//                     final memberName = familyNameCtr.text.trim();
//                     if (memberName.isEmpty) return;
//                     Navigator.pop(ctx);
//                     if (!mounted) return;
//                     setState(() {
//                       _foundPatient        = null;
//                       _resolvedPatientId   = null;
//                       _familyMemberId      = null;
//                       _familyHeadPatientId = patient.patientId;
//                       _familyGenderId      = selectedGender;
//                       _nameCtr.text        = memberName;
//                     });
//                     if (_canBook) {
//                       await _book();
//                     } else {
//                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//                         content: Text('Booking for $memberName — select date & session, then press Book'),
//                         backgroundColor: _kInfo,
//                         behavior: SnackBarBehavior.floating,
//                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//                       ));
//                     }
//                   },
//                   style: OutlinedButton.styleFrom(
//                     foregroundColor: _kPrimary,
//                     side: const BorderSide(color: _kPrimary),
//                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//                     padding: const EdgeInsets.symmetric(vertical: 14),
//                   ),
//                   child: const Text('Add & Book Family Member',
//                       style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
//                 ),
//               ),
//             ]),
//           ),
//         ),
//       ),
//     );
//   }

//   ApiService? get _api {
//     final dio = ref.read(dioProvider).value;
//     if (dio == null) return null;
//     return ApiService(dio);
//   }

//   Future<void> _init() async {
//     setState(() { _initLoading = true; _initError = null; });

//     final recepState = ref.read(receptionistLoginViewModelProvider);
//     final doctorId   = recepState.doctorId;

//     if (doctorId == null) {
//       setState(() { _initLoading = false; _initError = 'Doctor not linked to this receptionist'; });
//       return;
//     }

//     final api = _api;
//     if (api == null) {
//       setState(() { _initLoading = false; _initError = 'Network not ready'; });
//       return;
//     }

//     Map<String, List<DoctorAvailabilityModel>> grouped = {};
//     List<LeaveRange> leaves = [];

//     try {
//       final avails = await api.getDoctorAvailability(doctorId);
//       grouped = _availToGrouped(avails);
//     } catch (_) {}

//     if (grouped.isEmpty) {
//       try {
//         final schedule = await api.getDoctorSchedule(doctorId);
//         grouped = _scheduleToGrouped(schedule);
//       } catch (_) {}
//     }

//     try {
//       final raw = await api.getDoctorLeaveDates(doctorId);
//       leaves = ((raw as List?) ?? const [])
//           .whereType<Map>()
//           .map((e) => LeaveRange.fromJson(Map<String, dynamic>.from(e)))
//           .toList();
//     } catch (_) {}

//     if (grouped.isEmpty) {
//       if (!mounted) return;
//       setState(() { _initLoading = false; _initError = 'Schedule not set up for this doctor.\nAsk the doctor to configure their availability.'; });
//       return;
//     }

//     DoctorDetails? doc;
//     try {
//       final clinicId = recepState.clinicId?.isNotEmpty == true
//           ? recepState.clinicId!
//           : await TokenStorage.getValue('recep_clinic_id')
//               ?? await TokenStorage.getValue('clinic_id');
//       if (clinicId != null && clinicId.isNotEmpty) {
//         final doctors = await api.getDoctorsByClinic(clinicId);
//         doc = doctors.cast<DoctorDetails?>()
//             .firstWhere((d) => d?.doctorId == doctorId, orElse: () => null);
//       }
//     } catch (_) {}

//     if (!mounted) return;
//     setState(() {
//       _doctor      = doc;
//       _grouped     = grouped;
//       _leaveRanges = leaves;
//       _initLoading = false;
//     });

//     // Auto-select today so receptionist lands directly on today's sessions.
//     _pickDate(DateTime.now());
//   }

//   bool _isQueueSession(DoctorAvailabilityModel avail) {
//     final isToday = _selectedDate != null && _isToday(_selectedDate!);
//     return avail.bookingMode == 1 || (avail.bookingMode == 3 && isToday);
//   }

//   Future<void> _fetchQueueEstimate() async {
//     final api      = _api;
//     final doctorId = ref.read(receptionistLoginViewModelProvider).doctorId;
//     if (api == null || doctorId == null || !mounted) return;

//     setState(() { _isEstimateLoading = true; _estimatedWaitTime = null; });

//     try {
//       final result = await api.queuePreviewEstimate(
//         AppointmentRequestModel(doctorId: doctorId, slotId: _selectedSlotId),
//       );
//       if (!mounted) return;
//       final mins    = result.estimatedMinutes;
//       final arrival = result.estimatedArrivalTime;
//       final ahead   = result.patientsAhead;
//       String? label;
//       if (mins != null && arrival != null) {
//         label = '~$mins min  ·  arrives around $arrival'
//             '${ahead != null ? '  ($ahead ahead)' : ''}';
//       } else if (mins != null) {
//         label = '~$mins min wait${ahead != null ? '  ($ahead ahead)' : ''}';
//       } else if (ahead != null) {
//         label = '$ahead patient${ahead == 1 ? '' : 's'} ahead';
//       }
//       setState(() { _estimatedWaitTime = label; _isEstimateLoading = false; });
//     } catch (_) {
//       if (mounted) setState(() { _isEstimateLoading = false; });
//     }
//   }

//   Future<void> _fetchBookedSlots() async {
//     final doctorId = ref.read(receptionistLoginViewModelProvider).doctorId;
//     if (doctorId == null || _selectedDate == null) return;
//     final api = _api;
//     if (api == null) return;
//     final ds = _fmtDateApi(_selectedDate!);
//     try {
//       final slots = await api.getBookedSlots(doctorId);
//       if (!mounted) return;
//       final times = <String>{};
//       for (final s in slots) {
//         if (s.bookingDate?.startsWith(ds) == true && s.startTime != null) {
//           times.add(_fmtTime(s.startTime));
//         }
//       }
//       setState(() => _bookedTimes = times);
//     } catch (_) {}
//   }

//   void _pickDate(DateTime date) {
//     final day      = _kDayNames[(date.weekday - 1).clamp(0, 6)];
//     final isToday  = _isToday(date);
//     final sessions = (_grouped[day] ?? [])
//         .where((s) => _bookable(s.bookingMode, isToday))
//         .where((s) => !(isToday && _sessionEndedToday(s)))
//         .toList();
//     final avail    = sessions.length == 1 ? sessions.first : null;

//     setState(() {
//       _selectedDate      = date;
//       _selectedSlotId    = avail?.slotId;
//       _selectedAvail     = avail;
//       _selectedTime      = null;
//       _bookedTimes       = {};
//       _estimatedWaitTime = null;
//       _isEstimateLoading = false;
//       _bookError         = null;
//     });

//     _fetchBookedSlots();
//     if (avail != null && _isQueueSession(avail)) {
//       _fetchQueueEstimate();
//     }
//   }

//   void _pickSession(DoctorAvailabilityModel session) {
//     setState(() {
//       _selectedSlotId    = session.slotId;
//       _selectedAvail     = session;
//       _selectedTime      = null;
//       _estimatedWaitTime = null;
//       _isEstimateLoading = false;
//     });
//     if (_isQueueSession(session)) _fetchQueueEstimate();
//   }

//   Future<void> _book() async {
//     if (!(_formKey.currentState?.validate() ?? false)) return;
//     if (_selectedDate == null) {
//       setState(() { _bookError = 'Please select a date'; });
//       return;
//     }
//     if (_selectedAvail == null) {
//       setState(() { _bookError = 'Please select a session'; });
//       return;
//     }
//     final isToday = _isToday(_selectedDate!);
//     final mode    = _selectedAvail!.bookingMode ?? 0;
//     final isQueue = mode == 1 || (mode == 3 && isToday);
//     if (!isQueue && _selectedTime == null) {
//       setState(() { _bookError = 'Please select a time slot'; });
//       return;
//     }

//     final doctorId = ref.read(receptionistLoginViewModelProvider).doctorId;
//     if (doctorId == null) return;

//     setState(() { _booking = true; _bookError = null; });
//     try {
//       final isNewFamily      = _familyHeadPatientId != null;
//       final isExistingFamily = _familyMemberId != null;
//       final isFamilyBooking  = isNewFamily || isExistingFamily;
//       final body = <String, dynamic>{
//         'name':             _nameCtr.text.trim(),
//         'mobile_no':        _mobileCtr.text.trim(),
//         'doctor_id':        doctorId,
//         'appointment_date': _fmtDateApi(_selectedDate!),
//         'slot_id':          _selectedSlotId,
//         'start_time':       isQueue ? null : _toApiTime(_selectedTime!),
//         'user_type':        isFamilyBooking ? 2 : 1,
//         // existing family member → patient_id = member_id (no family record creation needed)
//         if (isExistingFamily) 'patient_id': _familyMemberId,
//         // new family member → backend creates family_members record, uses member_id for appt
//         if (isNewFamily) 'family_id': _familyHeadPatientId,
//         if (isNewFamily && _familyGenderId != null) 'gender_id': _familyGenderId,
//         // self-booking existing patient
//         if (!isFamilyBooking && _resolvedPatientId != null) 'patient_id': _resolvedPatientId,
//         if (_symptomsCtr.text.trim().isNotEmpty) 'symptoms': _symptomsCtr.text.trim(),
//       }..removeWhere((_, v) => v == null);

//       final isOnline = ref.read(connectivityNotifierProvider).isOnline;
//       final resp = await ref.read(receptionistLoginViewModelProvider.notifier)
//           .walkInBook(body, isOnline: isOnline);
//       if (!mounted) return;

//       if (resp.success == true) {
//         final isOfflineQueued = resp.message?.contains('offline') == true;
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(
//             content: Text(resp.message ?? 'Walk-in patient booked successfully'),
//             backgroundColor: isOfflineQueued ? _kAmber : _kPrimary,
//             behavior: SnackBarBehavior.floating,
//             shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
//           ),
//         );
//         setState(() { _foundPatient = null; _resolvedPatientId = null; _familyMemberId = null; _familyHeadPatientId = null; _familyGenderId = null; });
//         Navigator.of(context).pop();
//       } else {
//         setState(() { _bookError = resp.message ?? 'Booking failed'; });
//       }
//     } catch (e) {
//       if (!mounted) return;
//       setState(() { _bookError = e.toString().replaceFirst('Exception: ', ''); });
//     } finally {
//       if (mounted) setState(() { _booking = false; });
//     }
//   }

//   // ── Derived state ──────────────────────────────────────────────────────────
//   bool get _dayIsToday => _selectedDate != null && _isToday(_selectedDate!);
//   int  get _mode       => _selectedAvail?.bookingMode ?? 0;
//   bool get _isQueue    => _mode == 1 || (_mode == 3 && _dayIsToday);

//   bool get _isSlotSessionEnded {
//     if (_isQueue || !_dayIsToday || _selectedAvail == null) return false;
//     final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
//     final end    = _parseTime(_selectedAvail!.endTime);
//     return nowMin >= end.hour * 60 + end.minute;
//   }

//   bool get _isQueueOpen {
//     if (!_isQueue || !_dayIsToday || _selectedAvail == null) return true;
//     final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
//     final end    = _parseTime(_selectedAvail!.endTime);
//     return nowMin < end.hour * 60 + end.minute;
//   }

//   bool get _canBook =>
//       !_initLoading && _initError == null &&
//       _selectedDate != null && _selectedAvail != null &&
//       (_isQueue || (_selectedTime != null && !_isSlotSessionEnded)) &&
//       (!_isQueue || !_dayIsToday || _isQueueOpen);

//   Widget _buildBody() {
//     final day      = _selectedDate != null ? _kDayNames[(_selectedDate!.weekday - 1).clamp(0, 6)] : null;
//     final sessions = day == null ? <DoctorAvailabilityModel>[] :
//         (_grouped[day] ?? [])
//             .where((s) => _bookable(s.bookingMode, _dayIsToday))
//             .where((s) => !(_dayIsToday && _sessionEndedToday(s)))
//             .toList();

//     return SingleChildScrollView(
//       padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
//       child: Form(
//         key: _formKey,
//         child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           // ── Today badge (auto-selected, no calendar needed) ──────────
//           if (_selectedDate != null) _DateBadge(date: _selectedDate!),

//           // ── No sessions for day ──────────────────────────────────────
//           if (_selectedDate != null && sessions.isEmpty) ...[
//             const SizedBox(height: 14),
//             _infoBox(color: _kErrorLight, border: _kError.withOpacity(0.3),
//               icon: Icons.event_busy_rounded, iconColor: _kErrorDark,
//               text: 'No sessions available for this date', textColor: _kErrorDark),
//           ],

//           // ── Session selector (multiple sessions) ─────────────────────
//           if (sessions.length > 1) ...[
//             const SizedBox(height: 18),
//             _label('Select Session'),
//             const SizedBox(height: 8),
//             ...sessions.map((s) => _SessionTile(
//               session: s,
//               selected: _selectedSlotId == s.slotId,
//               onTap: () => _pickSession(s),
//             )),
//           ],

//           // ── Queue / Slot section ─────────────────────────────────────
//           if (_selectedAvail != null) ...[
//             const SizedBox(height: 18),
//             if (_isQueue)
//               _QueueSection(
//                 avail:             _selectedAvail!,
//                 isToday:           _dayIsToday,
//                 isQueueOpen:       _isQueueOpen,
//                 estimatedWaitTime: _estimatedWaitTime,
//                 isEstimateLoading: _isEstimateLoading,
//                 symptomsController: _symptomsCtr,
//               )
//             else if (_isSlotSessionEnded) ...[
//               _infoBox(color: _kErrorLight, border: _kError.withOpacity(0.3),
//                 icon: Icons.event_busy_rounded, iconColor: _kErrorDark,
//                 text: 'Slot booking has ended for this session', textColor: _kErrorDark),
//             ] else ...[
//               _SlotPicker(
//                 slots:      _buildTimeSlots(_selectedAvail!),
//                 selected:   _selectedTime,
//                 isToday:    _dayIsToday,
//                 booked:     _bookedTimes,
//                 onSelected: (t) => setState(() => _selectedTime = t),
//               ),
//               const SizedBox(height: 16),
//               _SymptomsBox(controller: _symptomsCtr),
//             ],
//           ],

//           // ── Patient details ──────────────────────────────────────────
//           const SizedBox(height: 18),
//           _label('Patient Details'),
//           const SizedBox(height: 8),
//           _Field(
//             controller: _nameCtr, label: 'Patient Name',
//             icon: Icons.person_outline_rounded,
//             validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
//             inputType: TextInputType.name,
//             capitalization: TextCapitalization.words,
//           ),
//           const SizedBox(height: 10),
//           _Field(
//             controller: _mobileCtr, label: 'Mobile Number',
//             icon: Icons.phone_outlined,
//             validator: (v) {
//               if (v == null || v.trim().isEmpty) return 'Mobile is required';
//               if (v.trim().length < 10) return 'Enter valid 10-digit number';
//               return null;
//             },
//             inputType: TextInputType.phone,
//             maxLength: 10,
//             formatters: [FilteringTextInputFormatter.digitsOnly],
//           ),

//           // ── Patient lookup result ────────────────────────────────────
//           if (_checkingMobile) ...[
//             const SizedBox(height: 8),
//             const Row(children: [
//               SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _kPrimary)),
//               SizedBox(width: 8),
//               Text('Checking...', style: TextStyle(fontSize: 12, color: _kTextSec)),
//             ]),
//           ] else if (_foundPatient != null && _resolvedPatientId == null) ...[
//             const SizedBox(height: 8),
//             GestureDetector(
//               onTap: () => _showPatientSheet(_foundPatient!),
//               child: Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//                 decoration: BoxDecoration(
//                   color: _kPrimaryLight,
//                   borderRadius: BorderRadius.circular(10),
//                   border: Border.all(color: _kPrimary.withValues(alpha: 0.4)),
//                 ),
//                 child: Row(children: [
//                   const Icon(Icons.person_rounded, size: 16, color: _kPrimary),
//                   const SizedBox(width: 8),
//                   Expanded(child: Text(
//                     '${_foundPatient!.name} found on this number — tap to select',
//                     style: const TextStyle(fontSize: 12, color: _kPrimary, fontWeight: FontWeight.w500),
//                   )),
//                   const Icon(Icons.chevron_right_rounded, size: 18, color: _kPrimary),
//                 ]),
//               ),
//             ),
//           ] else if (_resolvedPatientId != null) ...[
//             const SizedBox(height: 8),
//             Container(
//               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//               decoration: BoxDecoration(
//                 color: _kGreenLight,
//                 borderRadius: BorderRadius.circular(10),
//                 border: Border.all(color: _kGreen.withValues(alpha: 0.5)),
//               ),
//               child: Row(children: [
//                 const Icon(Icons.check_circle_rounded, size: 16, color: Color(0xFF38A169)),
//                 const SizedBox(width: 8),
//                 Text('Booking for ${_nameCtr.text}',
//                     style: const TextStyle(fontSize: 12, color: Color(0xFF38A169), fontWeight: FontWeight.w500)),
//               ]),
//             ),
//           ],

//           // ── Error ────────────────────────────────────────────────────
//           if (_bookError != null) ...[
//             const SizedBox(height: 12),
//             _infoBox(color: _kErrorLight, border: _kError.withOpacity(0.3),
//               icon: Icons.error_outline_rounded, iconColor: _kErrorDark,
//               text: _bookError!, textColor: _kErrorDark),
//           ],
//         ]),
//       ),
//     );
//   }

//   Widget _label(String t) => Text(
//     t.toUpperCase(),
//     style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted, letterSpacing: 0.8),
//   );

//   Widget _infoBox({
//     required Color color, required Color border,
//     required IconData icon, required Color iconColor,
//     required String text, required Color textColor,
//   }) =>
//       Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10), border: Border.all(color: border)),
//         child: Row(children: [
//           Icon(icon, size: 15, color: iconColor),
//           const SizedBox(width: 8),
//           Expanded(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: textColor))),
//         ]),
//       );

//   @override
//   Widget build(BuildContext context) {
//     // Sync pending walk-in bookings when connectivity is restored.
//     ref.listen<ConnectivityState>(connectivityNotifierProvider, (prev, next) {
//       if ((prev?.isOffline ?? false) && next.isOnline) {
//         ref.read(receptionistLoginViewModelProvider.notifier).syncPendingWalkIns();
//       }
//     });

//     return Scaffold(
//       backgroundColor: const Color(0xFFF7FDFC),
//       appBar: AppBar(
//         backgroundColor: Colors.white,
//         elevation: 0,
//         centerTitle: false,
//         leading: IconButton(
//           icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: _kTextPrimary),
//           onPressed: () => Navigator.of(context).pop(),
//         ),
//         title: const Text('Walk-in Patient',
//             style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _kTextPrimary)),
//         bottom: PreferredSize(
//           preferredSize: const Size.fromHeight(1),
//           child: Container(height: 1, color: _kBorder),
//         ),
//       ),
//       bottomNavigationBar: _canBook ? _buildConfirmBar() : null,
//       body: _initLoading
//           ? const Center(child: CircularProgressIndicator(color: _kPrimary, strokeWidth: 2))
//           : _initError != null
//               ? _ErrorBody(error: _initError!, onRetry: _init)
//               : _buildBody(),
//     );
//   }

//   Widget _buildConfirmBar() {
//     final dateStr = _selectedDate != null ? _fmtFull(_selectedDate!) : '';
//     final label   = _isQueue ? 'Queue  ·  $dateStr' : '${_selectedTime ?? ''}  ·  $dateStr';

//     return Container(
//       padding: EdgeInsets.fromLTRB(14, 10, 14, 10 + MediaQuery.of(context).padding.bottom),
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         border: Border(top: BorderSide(color: _kBorder)),
//       ),
//       child: Column(mainAxisSize: MainAxisSize.min, children: [
//         Padding(
//           padding: const EdgeInsets.only(bottom: 10),
//           child: Row(children: [
//             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//               const Text('Selected slot', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted)),
//               Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextPrimary)),
//             ]),
//           ]),
//         ),
//         SizedBox(
//           width: double.infinity,
//           height: 48,
//           child: ElevatedButton(
//             onPressed: _booking ? null : _book,
//             style: ElevatedButton.styleFrom(
//               backgroundColor: _kPrimary,
//               foregroundColor: Colors.white,
//               disabledBackgroundColor: _kPrimaryLight,
//               elevation: 0,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             ),
//             child: _booking
//                 ? const SizedBox(height: 18, width: 18,
//                     child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
//                 : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
//                     Icon(_isQueue ? Icons.confirmation_number_rounded : Icons.calendar_month_rounded, size: 17),
//                     const SizedBox(width: 8),
//                     const Text('Book Walk-in Patient', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
//                   ]),
//           ),
//         ),
//       ]),
//     );
//   }
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  DOCTOR CARD
// // ════════════════════════════════════════════════════════════════════════════
// class _DoctorCard extends StatelessWidget {
//   final DoctorDetails? doctor;
//   const _DoctorCard({required this.doctor});

//   @override
//   Widget build(BuildContext context) {
//     final d = doctor;
//     return Container(
//       padding: const EdgeInsets.all(14),
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: const Color(0xFFB2EBE4)),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
//       ),
//       child: Row(children: [
//         Container(
//           width: 44, height: 44,
//           decoration: BoxDecoration(color: _kPrimaryLight, borderRadius: BorderRadius.circular(12),
//               border: Border.all(color: const Color(0xFFB2EBE4))),
//           alignment: Alignment.center,
//           child: const Icon(Icons.medical_services_rounded, size: 20, color: _kPrimaryDark),
//         ),
//         const SizedBox(width: 12),
//         Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           Text(d?.name != null ? 'Dr. ${d!.name}' : 'Doctor',
//               style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _kTextPrimary)),
//           if (d?.specialization != null) ...[
//             const SizedBox(height: 2),
//             Text(d!.specialization!, style: const TextStyle(fontSize: 12, color: _kTextSec)),
//           ],
//           if (d?.clinicName != null) ...[
//             const SizedBox(height: 2),
//             Row(children: [
//               const Icon(Icons.location_on_outlined, size: 12, color: _kTextMuted),
//               const SizedBox(width: 3),
//               Flexible(child: Text(d!.clinicName!,
//                   style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted),
//                   maxLines: 1, overflow: TextOverflow.ellipsis)),
//             ]),
//           ],
//         ])),
//       ]),
//     );
//   }
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  CALENDAR STRIP  (same as booking screen — month headers, dot colours)
// // ════════════════════════════════════════════════════════════════════════════
// class _WalkCalendarStrip extends StatefulWidget {
//   final Map<String, List<DoctorAvailabilityModel>> grouped;
//   final List<LeaveRange>       leaveRanges;
//   final DateTime?              selectedDate;
//   final ValueChanged<DateTime> onDateSelected;

//   const _WalkCalendarStrip({
//     required this.grouped, required this.leaveRanges,
//     required this.selectedDate, required this.onDateSelected,
//   });

//   @override
//   State<_WalkCalendarStrip> createState() => _WalkCalendarStripState();
// }

// class _WalkCalendarStripState extends State<_WalkCalendarStrip> {
//   final _scroll = ScrollController();
//   static const _cw = 52.0, _gap = 6.0, _days = 28;

//   @override
//   void dispose() { _scroll.dispose(); super.dispose(); }

//   @override
//   void didChangeDependencies() {
//     super.didChangeDependencies();
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final today = DateTime.now();
//       for (int i = 0; i < _days; i++) {
//         final d = today.add(Duration(days: i));
//         if (_avail(d)) {
//           final off = i * (_cw + _gap) - 16;
//           if (_scroll.hasClients) {
//             _scroll.animateTo(
//               off.clamp(0.0, _scroll.position.maxScrollExtent),
//               duration: const Duration(milliseconds: 300), curve: Curves.easeOut,
//             );
//           }
//           break;
//         }
//       }
//     });
//   }

//   bool _onLeave(DateTime dt) => widget.leaveRanges.any((r) => r.contains(dt));

//   bool _avail(DateTime dt) {
//     if (_onLeave(dt)) return false;
//     final s = widget.grouped[_kDayNames[(dt.weekday - 1).clamp(0, 6)]];
//     return s?.any((a) => _bookable(a.bookingMode, _isToday(dt))) == true;
//   }

//   // Same dot-colour logic as patient booking screen
//   Color? _dot(DateTime dt) {
//     final s = widget.grouped[_kDayNames[(dt.weekday - 1).clamp(0, 6)]];
//     if (s == null) return null;
//     final isToday = _isToday(dt);
//     final b = s.where((a) => _bookable(a.bookingMode, isToday)).toList();
//     if (b.isEmpty) return null;
//     if (b.any((a) => a.bookingMode == 1) && isToday) return _kAmber;
//     if (b.any((a) => a.bookingMode == 3)) return isToday ? _kAmber : _kPrimary;
//     return _kPrimary;
//   }

//   @override
//   Widget build(BuildContext context) {
//     final today = DateTime.now();

//     // Build items with month headers (same as patient booking screen)
//     final items = <_CalItem>[];
//     DateTime? lastM;
//     for (int i = 0; i < _days; i++) {
//       final d = today.add(Duration(days: i));
//       if (lastM == null || d.month != lastM.month) {
//         items.add(_CalItem.header('${_kFullMonths[d.month - 1]} ${d.year}'));
//         lastM = d;
//       }
//       items.add(_CalItem.date(d));
//     }

//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Text('SELECT DATE'.toUpperCase(),
//           style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted, letterSpacing: 0.8)),
//       const SizedBox(height: 10),
//       SizedBox(
//         height: 86,
//         child: ListView.builder(
//           controller:      _scroll,
//           scrollDirection: Axis.horizontal,
//           itemCount:       items.length,
//           itemBuilder: (_, i) {
//             final item = items[i];
//             if (item.isHeader) {
//               return Container(
//                 alignment: Alignment.bottomLeft,
//                 padding: const EdgeInsets.only(right: 10, bottom: 10),
//                 child: Text(item.label!,
//                     style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted)),
//               );
//             }
//             final dt    = item.dt!;
//             final avail = _avail(dt);
//             final dot   = _dot(dt);
//             final isSel = widget.selectedDate?.year == dt.year &&
//                 widget.selectedDate?.month == dt.month &&
//                 widget.selectedDate?.day == dt.day;

//             return Padding(
//               padding: const EdgeInsets.only(right: _gap),
//               child: GestureDetector(
//                 onTap: avail ? () => widget.onDateSelected(dt) : null,
//                 child: AnimatedContainer(
//                   duration: const Duration(milliseconds: 180),
//                   width: _cw,
//                   decoration: BoxDecoration(
//                     color: isSel ? _kPrimary : (avail ? Colors.white : Colors.transparent),
//                     borderRadius: BorderRadius.circular(12),
//                     border: isSel ? null : (avail ? Border.all(color: _kBorder) : null),
//                     boxShadow: isSel
//                         ? [BoxShadow(color: _kPrimary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
//                         : null,
//                   ),
//                   child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
//                     Text(_kDayAbbr[dt.weekday - 1],
//                         style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
//                           color: isSel ? Colors.white.withOpacity(0.8)
//                               : (avail ? (dt.weekday >= 6 ? _kPrimary : _kTextMuted) : _kTextMuted.withOpacity(0.3)))),
//                     const SizedBox(height: 4),
//                     Text('${dt.day}',
//                         style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
//                           color: isSel ? Colors.white : (avail ? _kTextPrimary : _kTextMuted.withOpacity(0.3)))),
//                     const SizedBox(height: 4),
//                     Container(width: 5, height: 5,
//                         decoration: BoxDecoration(shape: BoxShape.circle,
//                           color: isSel ? Colors.white.withOpacity(0.7) : (dot ?? Colors.transparent))),
//                   ]),
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     ]);
//   }
// }

// class _CalItem {
//   final bool isHeader; final String? label; final DateTime? dt;
//   const _CalItem._({required this.isHeader, this.label, this.dt});
//   factory _CalItem.header(String l) => _CalItem._(isHeader: true, label: l);
//   factory _CalItem.date(DateTime d)  => _CalItem._(isHeader: false, dt: d);
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  DATE BADGE
// // ════════════════════════════════════════════════════════════════════════════
// class _DateBadge extends StatelessWidget {
//   final DateTime date;
//   const _DateBadge({required this.date});

//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//     decoration: BoxDecoration(color: _kPrimaryLight, borderRadius: BorderRadius.circular(10),
//         border: Border.all(color: _kPrimary.withOpacity(0.3))),
//     child: Row(children: [
//       const Icon(Icons.event_rounded, size: 14, color: _kPrimary),
//       const SizedBox(width: 8),
//       Text(_fmtFull(date), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kPrimary)),
//     ]),
//   );
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  SESSION TILE
// // ════════════════════════════════════════════════════════════════════════════
// class _SessionTile extends StatelessWidget {
//   final DoctorAvailabilityModel session;
//   final bool         selected;
//   final VoidCallback onTap;
//   const _SessionTile({required this.session, required this.selected, required this.onTap});

//   String _modeLabel(int? m) => switch (m) { 1 => 'Queue', 2 => 'Slots', 3 => 'Queue + Slots', _ => 'Session' };
//   Color  _modeColor(int? m) => switch (m) { 1 => _kAmber, 2 => _kPrimary, 3 => _kGreen, _ => _kTextMuted };

//   @override
//   Widget build(BuildContext context) {
//     final color = _modeColor(session.bookingMode);
//     return GestureDetector(
//       onTap: onTap,
//       child: AnimatedContainer(
//         duration: const Duration(milliseconds: 160),
//         margin: const EdgeInsets.only(bottom: 8),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
//         decoration: BoxDecoration(
//           color: selected ? _kPrimary : Colors.white,
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: selected ? _kPrimary : _kBorder, width: selected ? 1.5 : 1),
//         ),
//         child: Row(children: [
//           Icon(Icons.access_time_rounded, size: 15, color: selected ? Colors.white : _kPrimary),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Text('${_fmtTime(session.startTime)}  –  ${_fmtTime(session.endTime)}',
//                 style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
//                     color: selected ? Colors.white : _kTextPrimary)),
//           ),
//           Container(
//             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//             decoration: BoxDecoration(
//               color: selected ? Colors.white.withOpacity(0.15) : color.withOpacity(0.1),
//               borderRadius: BorderRadius.circular(6),
//             ),
//             child: Text(_modeLabel(session.bookingMode),
//                 style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
//                     color: selected ? Colors.white : color)),
//           ),
//         ]),
//       ),
//     );
//   }
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  QUEUE SECTION  (with estimate banner — same as booking screen)
// // ════════════════════════════════════════════════════════════════════════════
// class _QueueSection extends StatelessWidget {
//   final DoctorAvailabilityModel  avail;
//   final bool                     isToday;
//   final bool                     isQueueOpen;
//   final String?                  estimatedWaitTime;
//   final bool                     isEstimateLoading;
//   final TextEditingController    symptomsController;

//   const _QueueSection({
//     required this.avail,
//     required this.isToday,
//     required this.isQueueOpen,
//     required this.symptomsController,
//     this.estimatedWaitTime,
//     this.isEstimateLoading = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final noteColor = isQueueOpen ? _kGreen : _kError;
//     final noteBg    = isQueueOpen ? _kGreenLight.withOpacity(0.4) : _kErrorLight.withOpacity(0.4);
//     final noteIcon  = isQueueOpen ? Icons.check_circle_rounded : Icons.access_time_rounded;
//     final noteText  = isQueueOpen
//         ? 'Queue booking is open  ·  ${_fmtTime(avail.startTime)} – ${_fmtTime(avail.endTime)}'
//         : 'Queue has ended for today';

//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Text('QUEUE BOOKING'.toUpperCase(),
//           style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted, letterSpacing: 0.8)),
//       const SizedBox(height: 8),

//       // Open / closed status
//       Container(
//         width: double.infinity,
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
//         decoration: BoxDecoration(color: noteBg, borderRadius: BorderRadius.circular(10),
//             border: Border.all(color: noteColor.withOpacity(0.3))),
//         child: Row(children: [
//           Icon(noteIcon, size: 15, color: noteColor),
//           const SizedBox(width: 8),
//           Expanded(child: Text(noteText,
//               style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: noteColor))),
//         ]),
//       ),
//       const SizedBox(height: 8),

//       // Estimated wait banner
//       AnimatedSwitcher(
//         duration: const Duration(milliseconds: 250),
//         transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
//         child: isEstimateLoading
//             ? _EstimateBanner.loading(key: const ValueKey('loading'))
//             : (estimatedWaitTime?.isNotEmpty == true)
//                 ? _EstimateBanner.value(key: const ValueKey('value'), text: estimatedWaitTime!)
//                 : const SizedBox.shrink(key: ValueKey('empty')),
//       ),

//       if (estimatedWaitTime?.isNotEmpty == true || isEstimateLoading)
//         const SizedBox(height: 8),

//       const SizedBox(height: 12),

//       // Symptoms field
//       _SymptomsBox(controller: symptomsController),
//     ]);
//   }
// }

// class _EstimateBanner extends StatelessWidget {
//   final bool    _isLoading;
//   final String? _text;

//   const _EstimateBanner.loading({super.key}) : _isLoading = true, _text = null;
//   const _EstimateBanner.value({super.key, required String text}) : _isLoading = false, _text = text;

//   @override
//   Widget build(BuildContext context) => Container(
//     width: double.infinity,
//     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
//     decoration: BoxDecoration(
//       color: _kInfoLight.withOpacity(0.4),
//       borderRadius: BorderRadius.circular(10),
//       border: Border.all(color: _kInfo.withOpacity(0.25)),
//     ),
//     child: Row(children: [
//       if (_isLoading)
//         const SizedBox(width: 14, height: 14,
//             child: CircularProgressIndicator(strokeWidth: 1.8, color: _kInfo))
//       else
//         const Icon(Icons.hourglass_top_rounded, size: 14, color: _kInfo),
//       const SizedBox(width: 8),
//       if (_isLoading)
//         const Text('Fetching estimated wait time…', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted))
//       else
//         Expanded(
//           child: RichText(
//             text: TextSpan(
//               style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kInfo),
//               children: [
//                 const TextSpan(text: 'Estimated wait: '),
//                 TextSpan(text: _text, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
//               ],
//             ),
//           ),
//         ),
//     ]),
//   );
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  SLOT PICKER  (morning / afternoon / evening groups + past-slot disabled)
// // ════════════════════════════════════════════════════════════════════════════
// class _SlotPicker extends StatelessWidget {
//   final List<String>         slots;
//   final String?              selected;
//   final bool                 isToday;
//   final Set<String>          booked;
//   final ValueChanged<String> onSelected;

//   const _SlotPicker({
//     required this.slots, required this.selected,
//     required this.onSelected, this.isToday = false,
//     this.booked = const {},
//   });

//   @override
//   Widget build(BuildContext context) {
//     if (slots.isEmpty) {
//       return Container(
//         padding: const EdgeInsets.all(12),
//         decoration: BoxDecoration(color: _kErrorLight, borderRadius: BorderRadius.circular(10),
//             border: Border.all(color: _kError.withOpacity(0.3))),
//         child: const Row(children: [
//           Icon(Icons.info_outline_rounded, size: 14, color: _kErrorDark),
//           SizedBox(width: 8),
//           Text('No time slots available', style: TextStyle(fontSize: 12, color: _kErrorDark)),
//         ]),
//       );
//     }

//     final nowMins  = isToday ? DateTime.now().hour * 60 + DateTime.now().minute : -1;
//     final morning  = slots.where((s) => _slotMins(s) < 720).toList();
//     final afternoon = slots.where((s) { final m = _slotMins(s); return m >= 720 && m < 1020; }).toList();
//     final evening  = slots.where((s) => _slotMins(s) >= 1020).toList();

//     return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       Text('SELECT TIME SLOT'.toUpperCase(),
//           style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _kTextMuted, letterSpacing: 0.8)),
//       const SizedBox(height: 12),
//       if (morning.isNotEmpty) ...[
//         _SlotGroupHeader(icon: Icons.wb_sunny_outlined, label: 'Morning'),
//         const SizedBox(height: 8),
//         _SlotGrid(slots: morning, selected: selected, nowMins: nowMins, booked: booked, onSelected: onSelected),
//         const SizedBox(height: 14),
//       ],
//       if (afternoon.isNotEmpty) ...[
//         _SlotGroupHeader(icon: Icons.wb_twilight_outlined, label: 'Afternoon'),
//         const SizedBox(height: 8),
//         _SlotGrid(slots: afternoon, selected: selected, nowMins: nowMins, booked: booked, onSelected: onSelected),
//         const SizedBox(height: 14),
//       ],
//       if (evening.isNotEmpty) ...[
//         _SlotGroupHeader(icon: Icons.nights_stay_outlined, label: 'Evening'),
//         const SizedBox(height: 8),
//         _SlotGrid(slots: evening, selected: selected, nowMins: nowMins, booked: booked, onSelected: onSelected),
//       ],
//     ]);
//   }
// }

// class _SlotGroupHeader extends StatelessWidget {
//   final IconData icon;
//   final String   label;
//   const _SlotGroupHeader({required this.icon, required this.label});

//   @override
//   Widget build(BuildContext context) => Row(children: [
//     Icon(icon, size: 13, color: _kTextMuted),
//     const SizedBox(width: 5),
//     Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted)),
//   ]);
// }

// class _SlotGrid extends StatelessWidget {
//   final List<String>         slots;
//   final String?              selected;
//   final int                  nowMins;
//   final Set<String>          booked;
//   final ValueChanged<String> onSelected;

//   const _SlotGrid({required this.slots, required this.selected, required this.nowMins, required this.onSelected, this.booked = const {}});

//   @override
//   Widget build(BuildContext context) => Wrap(
//     spacing: 8, runSpacing: 8,
//     children: slots.map((slot) {
//       final isSel     = selected == slot;
//       final isPast    = nowMins >= 0 && _slotMins(slot) <= nowMins;
//       final isBooked  = booked.contains(slot);
//       final disabled  = isPast || isBooked;

//       return GestureDetector(
//         onTap: disabled ? null : () => onSelected(slot),
//         child: AnimatedContainer(
//           duration: const Duration(milliseconds: 140),
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
//           decoration: BoxDecoration(
//             color: disabled ? const Color(0xFFF7F8FA) : (isSel ? _kPrimary : Colors.white),
//             borderRadius: BorderRadius.circular(8),
//             border: Border.all(color: disabled ? _kBorder : (isSel ? _kPrimary : _kBorder)),
//           ),
//           child: Text(
//             isBooked ? '$slot ✕' : slot,
//             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
//                 color: disabled ? _kTextMuted : (isSel ? Colors.white : _kTextPrimary)),
//           ),
//         ),
//       );
//     }).toList(),
//   );
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  SYMPTOMS BOX
// // ════════════════════════════════════════════════════════════════════════════
// class _SymptomsBox extends StatelessWidget {
//   final TextEditingController controller;
//   const _SymptomsBox({required this.controller});

//   @override
//   Widget build(BuildContext context) => Container(
//     padding: const EdgeInsets.all(14),
//     decoration: BoxDecoration(
//       color: _kPrimaryLight.withOpacity(0.4),
//       borderRadius: BorderRadius.circular(12),
//       border: Border.all(color: _kPrimary.withOpacity(0.2)),
//     ),
//     child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//       RichText(text: const TextSpan(
//         style: TextStyle(fontSize: 13, color: _kTextPrimary),
//         children: [
//           TextSpan(text: 'Symptoms ', style: TextStyle(fontWeight: FontWeight.w600)),
//           TextSpan(text: '(optional)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextSec)),
//         ],
//       )),
//       const SizedBox(height: 10),
//       TextField(
//         controller: controller,
//         maxLines: 3, maxLength: 300,
//         style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
//         decoration: InputDecoration(
//           hintText: 'e.g. Fever since 2 days, headache…',
//           hintStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted),
//           filled: true, fillColor: Colors.white,
//           counterStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextMuted),
//           contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
//               borderSide: BorderSide(color: _kPrimary.withOpacity(0.25))),
//           enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
//               borderSide: BorderSide(color: _kPrimary.withOpacity(0.2))),
//           focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
//               borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
//         ),
//       ),
//     ]),
//   );
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  PATIENT FORM FIELD
// // ════════════════════════════════════════════════════════════════════════════
// class _Field extends StatelessWidget {
//   final TextEditingController controller;
//   final String label;
//   final IconData icon;
//   final String? Function(String?) validator;
//   final TextInputType inputType;
//   final TextCapitalization capitalization;
//   final int? maxLength;
//   final List<TextInputFormatter>? formatters;

//   const _Field({
//     required this.controller, required this.label, required this.icon,
//     required this.validator,
//     this.inputType = TextInputType.text,
//     this.capitalization = TextCapitalization.none,
//     this.maxLength, this.formatters,
//   });

//   @override
//   Widget build(BuildContext context) => TextFormField(
//     controller: controller,
//     keyboardType: inputType,
//     textCapitalization: capitalization,
//     maxLength: maxLength,
//     inputFormatters: formatters,
//     validator: validator,
//     style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
//     decoration: InputDecoration(
//       labelText: label,
//       labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextSec),
//       prefixIcon: Icon(icon, size: 16, color: _kTextSec),
//       counterText: '',
//       filled: true, fillColor: Colors.white,
//       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
//       border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
//       enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kBorder)),
//       focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kPrimary, width: 1.5)),
//       errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _kError)),
//     ),
//   );
// }

// // ════════════════════════════════════════════════════════════════════════════
// //  ERROR BODY
// // ════════════════════════════════════════════════════════════════════════════
// class _ErrorBody extends StatelessWidget {
//   final String error;
//   final VoidCallback onRetry;
//   const _ErrorBody({required this.error, required this.onRetry});

//   @override
//   Widget build(BuildContext context) => Center(
//     child: Padding(
//       padding: const EdgeInsets.all(24),
//       child: Column(mainAxisSize: MainAxisSize.min, children: [
//         const Icon(Icons.error_outline_rounded, size: 40, color: _kError),
//         const SizedBox(height: 12),
//         Text(error, textAlign: TextAlign.center,
//             style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _kTextSec)),
//         const SizedBox(height: 16),
//         ElevatedButton.icon(
//           onPressed: onRetry,
//           icon: const Icon(Icons.refresh_rounded, size: 16),
//           label: const Text('Retry'),
//           style: ElevatedButton.styleFrom(
//               backgroundColor: _kPrimary, foregroundColor: Colors.white, elevation: 0,
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
//         ),
//       ]),
//     ),
//   );
// }

// class _GenderChip extends StatelessWidget {
//   final String label;
//   final int    value;
//   final bool   selected;
//   final VoidCallback onTap;
//   const _GenderChip({required this.label, required this.value, required this.selected, required this.onTap});

//   @override
//   Widget build(BuildContext context) => GestureDetector(
//     onTap: onTap,
//     child: Container(
//       padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
//       decoration: BoxDecoration(
//         color:        selected ? _kPrimary : Colors.white,
//         borderRadius: BorderRadius.circular(20),
//         border:       Border.all(color: selected ? _kPrimary : _kBorder),
//       ),
//       child: Text(label,
//         style: TextStyle(
//           fontSize:   13,
//           fontWeight: FontWeight.w600,
//           color:      selected ? Colors.white : _kTextSec,
//         ),
//       ),
//     ),
//   );
// }

// class _FamilyMemberTile extends StatelessWidget {
//   final FamilyMember member;
//   final VoidCallback onBook;
//   const _FamilyMemberTile({required this.member, required this.onBook});

//   @override
//   Widget build(BuildContext context) => Container(
//     margin: const EdgeInsets.only(bottom: 8),
//     decoration: BoxDecoration(
//       border: Border.all(color: _kBorder),
//       borderRadius: BorderRadius.circular(10),
//     ),
//     child: ListTile(
//       leading: CircleAvatar(
//         backgroundColor: _kPrimaryLight,
//         child: Text(
//           member.avatarLetter,
//           style: const TextStyle(color: _kPrimary, fontWeight: FontWeight.w700, fontSize: 14),
//         ),
//       ),
//       title: Text(member.memberName ?? '', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: _kTextPrimary)),
//       subtitle: Text(
//         [member.genderName, member.relationName].where((s) => s != null && s.isNotEmpty).join(' · '),
//         style: const TextStyle(fontSize: 12, color: _kTextSec),
//       ),
//       trailing: TextButton(
//         onPressed: onBook,
//         style: TextButton.styleFrom(foregroundColor: _kPrimary),
//         child: const Text('Book', style: TextStyle(fontWeight: FontWeight.w700)),
//       ),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
//     ),
//   );
// }
