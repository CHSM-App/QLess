import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/doctor_profile_view.dart';
import 'package:qless/presentation/patient/view_models/appointment_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

// ─── Colour palette ───────────────────────────────────────────────────────────
const kPrimary   = Color(0xFF1A73E8);
const kPrimaryBg = Color(0xFFE8F0FE);
const kBg        = Color(0xFFF4F6FB);
const kCardBg    = Colors.white;
const kTextDark  = Color(0xFF1F2937);
const kTextMid   = Color(0xFF6B7280);
const kBorder    = Color(0xFFE5E7EB);
const kRed       = Color(0xFFEA4335);
const kGreen     = Color(0xFF34A853);
const kOrange    = Color(0xFFF59E0B);
const kPurple    = Color(0xFF8B5CF6);
const kCyan      = Color(0xFF06B6D4);
const kFavActive = Color(0xFFE53E3E); // heart red

const _kDarkSurface = Color(0xFF1E293B);
const _kDarkBg      = Color(0xFF0F172A);

// ─── Specialty colours ────────────────────────────────────────────────────────
const _baAccentMap = <String, Color>{
  'cardiology':    Color(0xFFEF4444),
  'dermatology':   Color(0xFFF59E0B),
  'pediatrics':    Color(0xFF10B981),
  'orthopedics':   Color(0xFF8B5CF6),
  'neurology':     Color(0xFF8B5CF6),
  'general':       Color(0xFF06B6D4),
  'gynecology':    Color(0xFFEC4899),
  'ophthalmology': Color(0xFF14B8A6),
};
const _baBgMap = <String, Color>{
  'cardiology':    Color(0xFFFEE2E2),
  'dermatology':   Color(0xFFFEF3C7),
  'pediatrics':    Color(0xFFD1FAE5),
  'orthopedics':   Color(0xFFEDE9FE),
  'neurology':     Color(0xFFEDE9FE),
  'general':       Color(0xFFCFFAFE),
  'gynecology':    Color(0xFFFCE7F3),
  'ophthalmology': Color(0xFFCCFBF1),
};

Color _baAccent(String? s) => _baAccentMap[s?.toLowerCase()] ?? kPrimary;
Color _baBg(String? s)     => _baBgMap[s?.toLowerCase()] ?? kPrimaryBg;
String _baCap(String s)    => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

// ─── Date helpers ─────────────────────────────────────────────────────────────
const _baMonths     = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const _baFullMonths = ['January','February','March','April','May','June','July','August','September','October','November','December'];
const _baDayAbbr    = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

bool _baIsToday(DateTime dt) {
  final n = DateTime.now();
  return dt.year == n.year && dt.month == n.month && dt.day == n.day;
}
String _baFmtFull(DateTime dt) {
  if (_baIsToday(dt)) return 'Today';
  return '${_baDayAbbr[dt.weekday - 1]}, ${dt.day} ${_baMonths[dt.month - 1]}';
}
bool _baBookable(int? mode, bool isToday) {
  switch (mode) {
    case 1: return isToday;
    case 2: return true;
    case 3: return true;
    default: return false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAVORITE BUTTON WIDGET  ← NEW
// ─────────────────────────────────────────────────────────────────────────────
class _FavoriteButton extends StatefulWidget {
  final bool   initialFav;
  final bool   isDark;
  final void Function(bool) onToggle;

  const _FavoriteButton({
    required this.initialFav,
    required this.isDark,
    required this.onToggle,
  });

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late bool _isFav;
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    _isFav = widget.initialFav;
    _ctrl  = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale  = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.06)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 15),
    ]).animate(_ctrl);
    _bounce = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() => _isFav = !_isFav);
    widget.onToggle(_isFav);
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) => Transform.scale(
          scale: _scale.value,
          child: child,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isFav
                ? kFavActive.withOpacity(0.12)
                : (widget.isDark
                    ? Colors.white.withOpacity(0.08)
                    : const Color(0xFFF3F4F6)),
            border: Border.all(
              color: _isFav
                  ? kFavActive.withOpacity(0.45)
                  : (widget.isDark
                      ? Colors.white.withOpacity(0.12)
                      : kBorder),
              width: 1.2,
            ),
            boxShadow: _isFav
                ? [
                    BoxShadow(
                      color: kFavActive.withOpacity(0.25),
                      blurRadius: 10,
                      spreadRadius: 0,
                    )
                  ]
                : [],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) => ScaleTransition(
                scale: anim, child: child,
              ),
              child: Icon(
                _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                key: ValueKey(_isFav),
                size: 18,
                color: _isFav ? kFavActive : kTextMid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOK APPOINTMENT SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class BookAppointmentScreen extends ConsumerStatefulWidget {
  final DoctorDetails doctor;
  final int?          bookingForMemberId;
  final bool          initialFavorite;   // ← pass from parent

  const BookAppointmentScreen({
    super.key,
    required this.doctor,
    this.bookingForMemberId,
    this.initialFavorite = false,
  });

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState
    extends ConsumerState<BookAppointmentScreen> {
  DateTime? _selectedDate;
  int?      _selectedSlotId;
  String?   _selectedTime;
  bool      _isBooking   = false;
  int?      _selectedMemberId;
  bool      _isFavorite  = false;   // ← favorite state

  @override
  void initState() {
    super.initState();
    _isFavorite      = widget.initialFavorite;
    _selectedMemberId = widget.bookingForMemberId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.doctor.doctorId;
      if (id != null) {
        ref.read(doctorsViewModelProvider.notifier).getDoctorAvailability(id);
        ref.read(appointmentViewModelProvider.notifier).getBookedSlots(id);
      }
      final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (pid > 0) {
        ref.read(familyViewModelProvider.notifier).fetchAllFamilyMembers(pid);
      }
    });
  }

  String _fmtDateApi(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}';

  String _toApiTime(String display) {
    final parts = display.trim().split(' ');
    final hm    = parts[0].split(':');
    int h       = int.parse(hm[0]);
    final m     = hm[1];
    final isPm  = parts.length > 1 && parts[1].toUpperCase() == 'PM';
    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;
    return '${h.toString().padLeft(2,'0')}:$m';
  }

  TimeOfDay _parseTime(String? iso) {
    if (iso == null) return const TimeOfDay(hour: 9, minute: 0);
    final dt = DateTime.tryParse(iso);
    if (dt == null) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  String _fmtTime(String? iso) {
    final t  = _parseTime(iso);
    final sf = t.hour < 12 ? 'AM' : 'PM';
    final h  = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    return '${h.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')} $sf';
  }

  List<String> _buildSlots(DoctorAvailabilityModel avail) {
    final start = _parseTime(avail.startTime);
    final end   = _parseTime(avail.endTime);
    final dur   = avail.slotDuration ?? 10;
    final slots = <String>[];
    int cur     = start.hour * 60 + start.minute;
    final endM  = end.hour * 60 + end.minute;
    while (cur + dur <= endM) {
      final h  = cur ~/ 60;
      final m  = cur % 60;
      final sf = h < 12 ? 'AM' : 'PM';
      final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      slots.add('${dh.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')} $sf');
      cur += dur;
    }
    return slots;
  }

  Map<String, List<DoctorAvailabilityModel>> _grouped(
      List<DoctorAvailabilityModel> all) {
    final map = <String, List<DoctorAvailabilityModel>>{};
    for (final a in all) {
      final day = a.dayOfWeek ?? '';
      if (day.isEmpty) continue;
      map.putIfAbsent(day, () => []).add(a);
    }
    return map;
  }

  void _pickDate(DateTime date, List<DoctorAvailabilityModel> sessions) {
    final isToday  = _baIsToday(date);
    final bookable = sessions.where((s) => _baBookable(s.bookingMode, isToday)).toList();
    setState(() {
      _selectedDate   = date;
      _selectedSlotId = bookable.length == 1 ? bookable.first.slotId : null;
      _selectedTime   = null;
    });
    if (widget.doctor.doctorId != null) {
      ref.read(appointmentViewModelProvider.notifier).getAppointmentAvailability(
        AppointmentRequestModel(
          doctorId:        widget.doctor.doctorId,
          appointmentDate: _fmtDateApi(date),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state      = ref.watch(doctorsViewModelProvider);
    final apptState  = ref.watch(appointmentViewModelProvider);
    final patState   = ref.watch(patientLoginViewModelProvider);
    final famState   = ref.watch(familyViewModelProvider);
    final isDark     = Theme.of(context).brightness == Brightness.dark;
    final members    = famState.allfamilyMembers.maybeWhen(
      data: (m) => m, orElse: () => <FamilyMember>[],
    );

    final bookedTimes = <String>{};
    if (_selectedDate != null) {
      final ds = _fmtDateApi(_selectedDate!);
      for (final s in apptState.bookedSlots) {
        if (s.bookingDate != null && s.bookingDate!.startsWith(ds) && s.startTime != null) {
          bookedTimes.add(_fmtTime(s.startTime));
        }
      }
    }

    ref.listen<AppointmentState>(appointmentViewModelProvider, (prev, next) {
      if (next.bookingResponse != null &&
          next.bookingResponse != prev?.bookingResponse &&
          !next.isLoading) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.bookingResponse!.message ?? 'Appointment booked!'),
          backgroundColor: kGreen,
        ));
        setState(() => _isBooking = false);
        Navigator.pop(context, true);
        return;
      }
      if (next.error != null && next.error != prev?.error && !next.isLoading && _isBooking) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: kRed),
        );
        setState(() => _isBooking = false);
      }
    });

    final enabled      = state.doctorAvailabilities.where((a) => a.isEnabled == true).toList();
    final grouped      = _grouped(enabled);
    final selAvail     = _selectedSlotId == null
        ? null
        : enabled.firstWhere((a) => a.slotId == _selectedSlotId,
            orElse: () => DoctorAvailabilityModel());
    final dayIsToday   = _selectedDate != null && _baIsToday(_selectedDate!);
    final mode         = selAvail?.bookingMode ?? 0;
    final isQueue      = mode == 1 || (mode == 3 && dayIsToday);
    final canConfirm   = selAvail != null &&
        _baBookable(mode, dayIsToday) &&
        (isQueue || _selectedTime != null);

    return Scaffold(
      backgroundColor: isDark ? _kDarkBg : kBg,
      body: CustomScrollView(
        slivers: [
          _BaAppBar(
            doctor:     widget.doctor,
            isDark:     isDark,
            isFavorite: _isFavorite,
            onBack:     () => Navigator.pop(context),
            onFavToggle: (v) {
              setState(() => _isFavorite = v);
              _showFavSnack(v);
            },
          ),
          SliverToBoxAdapter(
            child: _DoctorStatsRow(doctor: widget.doctor, isDark: isDark),
          ),
          SliverToBoxAdapter(
            child: _BaBookingFor(
              patState:         patState,
              members:          members,
              selectedMemberId: _selectedMemberId,
              onSelected:       (id) => setState(() => _selectedMemberId = id),
              isDark:           isDark,
            ),
          ),
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: kPrimary)),
            )
          else if (grouped.isEmpty)
            SliverFillRemaining(
              child: _BaNoAvail(onBack: () => Navigator.pop(context)),
            )
          else
            SliverToBoxAdapter(
              child: _BaBody(
                isDark:            isDark,
                grouped:           grouped,
                enabled:           enabled,
                selectedDate:      _selectedDate,
                selectedSlotId:    _selectedSlotId,
                selectedTime:      _selectedTime,
                selectedAvail:     selAvail,
                dayIsToday:        dayIsToday,
                bookedTimes:       bookedTimes,
                onPickDate:        _pickDate,
                onPickSession:     (id) => setState(() {
                  _selectedSlotId = id;
                  _selectedTime   = null;
                }),
                onPickTime:        (t) => setState(() => _selectedTime = t),
                buildSlots:        _buildSlots,
                fmtTime:           _fmtTime,
              ),
            ),
        ],
      ),
      bottomNavigationBar: canConfirm
          ? _BaConfirmBar(
              isDark:       isDark,
              isQueue:      isQueue,
              selectedDate: _selectedDate,
              selectedSlot: _selectedTime,
              fee:          widget.doctor.consultationFee,
              isLoading:    _isBooking,
              onConfirm:    _onConfirm,
            )
          : null,
    );
  }

  void _showFavSnack(bool added) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: added ? kFavActive : kTextDark,
        duration: const Duration(seconds: 2),
        content: Row(children: [
          Icon(
            added ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: Colors.white, size: 16,
          ),
          const SizedBox(width: 10),
          Text(
            added
                ? 'Dr. ${widget.doctor.name ?? ''} added to favourites'
                : 'Removed from favourites',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ]),
      ),
    );
  }

  void _onConfirm() {
    if (_isBooking || _selectedDate == null) return;
    final ps          = ref.read(patientLoginViewModelProvider);
    final isForMember = _selectedMemberId != null;
    final patientId   = isForMember ? _selectedMemberId : ps.patientId;
    final userType    = isForMember ? 2 : 1;
    final ds          = ref.read(doctorsViewModelProvider);
    final avail       = _selectedSlotId == null
        ? null
        : ds.doctorAvailabilities.cast<DoctorAvailabilityModel?>()
            .firstWhere((a) => a?.slotId == _selectedSlotId, orElse: () => null);
    final isToday = _baIsToday(_selectedDate!);
    final mode    = avail?.bookingMode ?? 0;
    final isQueue = mode == 1 || (mode == 3 && isToday);
    final start   = isQueue ? null : (_selectedTime != null ? _toApiTime(_selectedTime!) : null);

    setState(() => _isBooking = true);
    ref.read(appointmentViewModelProvider.notifier).bookAppointment(
      AppointmentRequestModel(
        doctorId:        widget.doctor.doctorId,
        patientId:       patientId,
        appointmentDate: _fmtDateApi(_selectedDate!),
        startTime:       start,
        userType:        userType,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR (SliverAppBar)  ← updated with favorite button
// ─────────────────────────────────────────────────────────────────────────────
class _BaAppBar extends StatelessWidget {
  final DoctorDetails         doctor;
  final bool                  isDark;
  final bool                  isFavorite;
  final VoidCallback          onBack;
  final void Function(bool)   onFavToggle;

  const _BaAppBar({
    required this.doctor,
    required this.isDark,
    required this.isFavorite,
    required this.onBack,
    required this.onFavToggle,
  });

  @override
  Widget build(BuildContext context) {
    final accent  = _baAccent(doctor.specialization);
    final specBg  = _baBg(doctor.specialization);
    final initial = (doctor.name?.isNotEmpty ?? false) ? doctor.name![0].toUpperCase() : 'D';

    return SliverAppBar(
      expandedHeight:  160,
      pinned:          true,
      backgroundColor: isDark ? _kDarkSurface : kCardBg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18,
            color: isDark ? Colors.white : kTextDark),
        onPressed: onBack,
      ),
      title: Text(
        'Book Appointment',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white : kTextDark,
        ),
      ),
      // ── Favourite button in collapsed app-bar ──
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: _FavoriteButton(
            initialFav: isFavorite,
            isDark:     isDark,
            onToggle:   onFavToggle,
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: kBorder),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          color: isDark ? _kDarkSurface : kCardBg,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          alignment: Alignment.bottomLeft,
          child: Row(
            children: [
              // ── Doctor avatar ──
              Stack(
                children: [
                  CircleAvatar(
                    radius: 29,
                    backgroundColor: accent,
                    child: Text(initial, style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  // ── Small fav indicator on avatar ──
                  if (isFavorite)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: kFavActive,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? _kDarkSurface : kCardBg,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dr. ${doctor.name ?? 'Unknown'}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : kTextDark)),
                    const SizedBox(height: 4),
                    Row(children: [
                      if (doctor.specialization != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: specBg, borderRadius: BorderRadius.circular(5)),
                          child: Text(_baCap(doctor.specialization!),
                            style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: accent)),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (doctor.clinicName != null)
                        Flexible(child: Text(doctor.clinicName!,
                          style: const TextStyle(fontSize: 11, color: kTextMid),
                          overflow: TextOverflow.ellipsis)),
                    ]),
                  ],
                ),
              ),
              if (doctor.consultationFee != null)
                Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('₹${doctor.consultationFee!.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: kGreen)),
                    const Text('consult fee', style: TextStyle(fontSize: 9.5, color: kTextMid)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCTOR STATS ROW  (experience · rating · patients · view profile)
// ─────────────────────────────────────────────────────────────────────────────
class _DoctorStatsRow extends StatelessWidget {
  final DoctorDetails doctor;
  final bool          isDark;
  const _DoctorStatsRow({required this.doctor, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? _kDarkSurface : kCardBg,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
      child: Row(
        children: [
          _StatBox(
            label: 'Experience',
            value: doctor.experience != null ? '${doctor.experience} yrs' : '--',
          ),
          const SizedBox(width: 8),
          _StatBox(
            label: 'Rating',
            widget: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: kOrange, size: 14),
                const SizedBox(width: 2),
                Text('4.8', style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatBox(label: 'Patients', value: '1.2k+'),
          const SizedBox(width: 8),
          // View Profile button
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DoctorProfileScreen(doctor: doctor),
                ),
              ),
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  color: kPrimaryBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPrimary.withOpacity(0.3)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outlined, color: kPrimary, size: 16),
                    SizedBox(height: 3),
                    Text('Profile', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600, color: kPrimary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String  label;
  final String? value;
  final Widget? widget;
  const _StatBox({required this.label, this.value, this.widget});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: kTextMid)),
            const SizedBox(height: 4),
            if (widget != null)
              widget!
            else
              Text(value ?? '--',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING FOR DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────
class _BaBookingFor extends StatelessWidget {
  final PatientLoginState  patState;
  final List<FamilyMember> members;
  final int?               selectedMemberId;
  final ValueChanged<int?> onSelected;
  final bool               isDark;
  const _BaBookingFor({
    required this.patState, required this.members,
    required this.selectedMemberId, required this.onSelected, required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(
        value: null,
        child: Row(children: [
          CircleAvatar(radius: 13, backgroundColor: kPrimary.withOpacity(0.15),
            child: Text((patState.name?.isNotEmpty ?? false)
                ? patState.name![0].toUpperCase() : 'M',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary))),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(patState.name ?? 'Me', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : kTextDark)),
            Text('You', style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : kTextMid)),
          ]),
        ]),
      ),
      ...members.map((m) => DropdownMenuItem<int?>(
        value: m.memberId,
        child: Row(children: [
          CircleAvatar(radius: 13, backgroundColor: kPrimary.withOpacity(0.12),
            child: Text(m.memberName?.isNotEmpty == true ? m.memberName![0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimary))),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            Text(m.memberName ?? '?', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : kTextDark)),
            if (m.relationName?.isNotEmpty == true)
              Text(m.relationName!, style: TextStyle(fontSize: 10,
                  color: isDark ? Colors.white38 : kTextMid)),
          ]),
        ]),
      )),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: kPrimaryBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kPrimary.withOpacity(0.3)),
      ),
      child: Row(children: [
        const Icon(Icons.location_on_outlined, color: kPrimary, size: 16),
        const SizedBox(width: 8),
        Text('Booking for', style: TextStyle(fontSize: 12,
            color: isDark ? Colors.white54 : kTextMid)),
        const SizedBox(width: 4),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedMemberId, isDense: true, isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kPrimary),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary),
              dropdownColor: isDark ? _kDarkSurface : Colors.white,
              items: items,
              onChanged: onSelected,
              selectedItemBuilder: (_) => [
                Align(alignment: Alignment.centerLeft,
                  child: Text(patState.name ?? 'Me', style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary))),
                ...members.map((m) => Align(alignment: Alignment.centerLeft,
                  child: Text(m.memberName ?? 'Member', style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)))),
              ],
            ),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING BODY
// ─────────────────────────────────────────────────────────────────────────────
class _BaBody extends StatelessWidget {
  final bool isDark;
  final Map<String, List<DoctorAvailabilityModel>> grouped;
  final List<DoctorAvailabilityModel> enabled;
  final DateTime?  selectedDate;
  final int?       selectedSlotId;
  final String?    selectedTime;
  final DoctorAvailabilityModel? selectedAvail;
  final bool       dayIsToday;
  final Set<String> bookedTimes;
  final void Function(DateTime, List<DoctorAvailabilityModel>) onPickDate;
  final ValueChanged<int?>   onPickSession;
  final ValueChanged<String> onPickTime;
  final List<String> Function(DoctorAvailabilityModel) buildSlots;
  final String Function(String?) fmtTime;

  const _BaBody({
    required this.isDark, required this.grouped, required this.enabled,
    required this.selectedDate, required this.selectedSlotId, required this.selectedTime,
    required this.selectedAvail, required this.dayIsToday, required this.bookedTimes,
    required this.onPickDate, required this.onPickSession, required this.onPickTime,
    required this.buildSlots, required this.fmtTime,
  });

  String _dayName(int w) {
    const n = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return n[(w - 1).clamp(0, 6)];
  }

  @override
  Widget build(BuildContext context) {
    final sessions = selectedDate == null ? <DoctorAvailabilityModel>[]
        : (grouped[_dayName(selectedDate!.weekday)] ?? [])
            .where((s) => _baBookable(s.bookingMode, dayIsToday)).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _BaCalendarStrip(
          grouped:        grouped,
          selectedDate:   selectedDate,
          onDateSelected: (date) {
            final dn = _dayName(date.weekday);
            onPickDate(date, grouped[dn] ?? []);
          },
        ),
        if (selectedDate != null) ...[
          const SizedBox(height: 14),
          _BaDateBadge(date: selectedDate!),
        ],
        if (sessions.length > 1) ...[
          const SizedBox(height: 20),
          _baLabel('Select Session'),
          const SizedBox(height: 10),
          _BaSessionRow(sessions: sessions, selectedSlotId: selectedSlotId,
              onSelected: onPickSession, fmtTime: fmtTime),
        ],
        if (selectedAvail != null) ...[
          const SizedBox(height: 24),
          if (selectedAvail!.bookingMode == 1 ||
              (selectedAvail!.bookingMode == 3 && dayIsToday))
            _BaQueueCard(avail: selectedAvail!)
          else
            _BaSlotPicker(
              slots:       buildSlots(selectedAvail!),
              selected:    selectedTime,
              isDark:      isDark,
              bookedTimes: bookedTimes,
              onSelected:  onPickTime,
            ),
        ],
      ]),
    );
  }
}

Widget _baLabel(String text) => Text(
  text.toUpperCase(),
  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
      color: kTextMid, letterSpacing: 1.1),
);

// ─────────────────────────────────────────────────────────────────────────────
// CALENDAR STRIP
// ─────────────────────────────────────────────────────────────────────────────
class _BaCalendarStrip extends StatefulWidget {
  final Map<String, List<DoctorAvailabilityModel>> grouped;
  final DateTime?              selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  const _BaCalendarStrip({required this.grouped, required this.selectedDate, required this.onDateSelected});
  @override State<_BaCalendarStrip> createState() => _BaCalendarStripState();
}

class _BaCalendarStripState extends State<_BaCalendarStrip> {
  final _scroll = ScrollController();
  static const _cw = 52.0, _gap = 6.0, _days = 28;

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final today = DateTime.now();
      for (int i = 0; i < _days; i++) {
        final d = today.add(Duration(days: i));
        if (_avail(d)) {
          final off = i * (_cw + _gap) - 16;
          if (_scroll.hasClients) {
            _scroll.animateTo(off.clamp(0.0, _scroll.position.maxScrollExtent),
                duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
          }
          break;
        }
      }
    });
  }

  bool _avail(DateTime dt) {
    const n = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final s = widget.grouped[n[(dt.weekday-1).clamp(0,6)]];
    if (s == null || s.isEmpty) return false;
    return s.any((a) => _baBookable(a.bookingMode, _baIsToday(dt)));
  }

  Color? _dot(DateTime dt) {
    const n = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final s = widget.grouped[n[(dt.weekday-1).clamp(0,6)]];
    if (s == null) return null;
    final isToday = _baIsToday(dt);
    final b = s.where((a) => _baBookable(a.bookingMode, isToday)).toList();
    if (b.isEmpty) return null;
    if (b.any((a) => a.bookingMode == 1) && isToday) return kOrange;
    if (b.any((a) => a.bookingMode == 3)) return isToday ? kOrange : kPrimary;
    return kPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final items = <_CalItem>[];
    DateTime? lastM;
    for (int i = 0; i < _days; i++) {
      final d = today.add(Duration(days: i));
      if (lastM == null || d.month != lastM.month) {
        items.add(_CalItem.header('${_baFullMonths[d.month-1]} ${d.year}'));
        lastM = d;
      }
      items.add(_CalItem.date(d));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baLabel('Select Date'),
      const SizedBox(height: 10),
      SizedBox(
        height: 88,
        child: ListView.builder(
          controller: _scroll, scrollDirection: Axis.horizontal, itemCount: items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            if (item.isHeader) return _BaMonthLabel(label: item.label!);
            final dt      = item.dt!;
            final avail   = _avail(dt);
            final dot     = _dot(dt);
            final isSel   = widget.selectedDate?.year == dt.year &&
                widget.selectedDate?.month == dt.month &&
                widget.selectedDate?.day == dt.day;

            return Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: GestureDetector(
                onTap: avail ? () => widget.onDateSelected(dt) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: _cw,
                  decoration: BoxDecoration(
                    color: isSel ? kTextDark : (avail ? kCardBg : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isSel ? null : (avail ? Border.all(color: kBorder) : null),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text(_baDayAbbr[dt.weekday-1], style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white.withOpacity(0.7)
                          : (avail ? (dt.weekday >= 6 ? kPrimary : kTextMid) : kTextMid.withOpacity(0.3)),
                    )),
                    const SizedBox(height: 4),
                    Text('${dt.day}', style: TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: isSel ? Colors.white : (avail ? kTextDark : kTextMid.withOpacity(0.3)),
                    )),
                    const SizedBox(height: 5),
                    Container(width: 6, height: 6, decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSel ? Colors.white.withOpacity(0.6) : (dot ?? Colors.transparent),
                    )),
                  ]),
                ),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _CalItem {
  final bool isHeader; final String? label; final DateTime? dt;
  const _CalItem._({required this.isHeader, this.label, this.dt});
  factory _CalItem.header(String l) => _CalItem._(isHeader: true, label: l);
  factory _CalItem.date(DateTime d) => _CalItem._(isHeader: false, dt: d);
}

class _BaMonthLabel extends StatelessWidget {
  final String label;
  const _BaMonthLabel({required this.label});
  @override
  Widget build(BuildContext context) => Container(
    alignment: Alignment.bottomLeft,
    padding: const EdgeInsets.only(right: 10, bottom: 10),
    child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextMid)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// DATE BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _BaDateBadge extends StatelessWidget {
  final DateTime date;
  const _BaDateBadge({required this.date});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
    decoration: BoxDecoration(
      color: kPrimaryBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kPrimary.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.event_rounded, size: 15, color: kPrimary),
      const SizedBox(width: 8),
      Text(_baFmtFull(date), style: const TextStyle(
          fontSize: 13, fontWeight: FontWeight.w700, color: kPrimary)),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SESSION ROW
// ─────────────────────────────────────────────────────────────────────────────
class _BaSessionRow extends StatelessWidget {
  final List<DoctorAvailabilityModel> sessions;
  final int?                 selectedSlotId;
  final ValueChanged<int?>   onSelected;
  final String Function(String?) fmtTime;
  const _BaSessionRow({required this.sessions, required this.selectedSlotId,
      required this.onSelected, required this.fmtTime});

  Color _modeColor(int? m) {
    switch (m) { case 1: return kOrange; case 2: return kPrimary; case 3: return kGreen; default: return kTextMid; }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: sessions.map((s) {
      final sel   = selectedSlotId == s.slotId;
      final color = _modeColor(s.bookingMode);
      return GestureDetector(
        onTap: () => onSelected(s.slotId),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: sel ? kTextDark : kCardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: sel ? kTextDark : kBorder, width: sel ? 1.5 : 0.5),
          ),
          child: Row(children: [
            Icon(Icons.access_time_rounded, size: 15, color: sel ? Colors.white : kPrimary),
            const SizedBox(width: 10),
            Expanded(child: Text('${fmtTime(s.startTime)}  –  ${fmtTime(s.endTime)}',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
                  color: sel ? Colors.white : kTextDark))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: sel ? Colors.white.withOpacity(0.15) : color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(s.bookingMode == 1 ? 'Queue' : s.bookingMode == 2 ? 'Slots' : 'Queue + Slots',
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : color)),
            ),
          ]),
        ),
      );
    }).toList(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE CARD
// ─────────────────────────────────────────────────────────────────────────────
class _BaQueueCard extends StatelessWidget {
  final DoctorAvailabilityModel avail;
  const _BaQueueCard({required this.avail});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kOrange.withOpacity(0.07),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kOrange.withOpacity(0.3)),
    ),
    child: Row(children: [
      Container(width: 48, height: 48,
        decoration: BoxDecoration(color: kOrange.withOpacity(0.15), shape: BoxShape.circle),
        child: const Icon(Icons.confirmation_number_rounded, size: 22, color: kOrange)),
      const SizedBox(width: 14),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Walk-in Queue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 3),
        Text('Show up today · ${avail.slotDuration ?? 10} min per patient',
          style: const TextStyle(fontSize: 12, color: kTextMid)),
      ])),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SLOT PICKER
// ─────────────────────────────────────────────────────────────────────────────
class _BaSlotPicker extends StatelessWidget {
  final List<String>         slots;
  final String?              selected;
  final bool                 isDark;
  final Set<String>          bookedTimes;
  final ValueChanged<String> onSelected;
  const _BaSlotPicker({required this.slots, required this.selected,
      required this.isDark, required this.bookedTimes, required this.onSelected});

  int _mins(String slot) {
    final p = slot.split(':');
    final h = int.tryParse(p[0]) ?? 0;
    final r = p[1].split(' ');
    final m = int.tryParse(r[0]) ?? 0;
    final s = r[1];
    var hr  = h;
    if (s == 'PM' && hr != 12) hr += 12;
    if (s == 'AM' && hr == 12) hr = 0;
    return hr * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(child: Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('No slots available', style: TextStyle(color: kTextMid, fontSize: 13)),
      ));
    }
    final morning   = slots.where((s) => _mins(s) < 720).toList();
    final afternoon = slots.where((s) { final m = _mins(s); return m >= 720 && m < 1020; }).toList();
    final evening   = slots.where((s) => _mins(s) >= 1020).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _baLabel('Select Time Slot'),
      const SizedBox(height: 12),
      if (morning.isNotEmpty) ...[
        _SlotHeader(icon: Icons.wb_sunny_outlined, label: 'Morning'),
        const SizedBox(height: 8),
        _SlotGrid(slots: morning, selected: selected, isDark: isDark,
            booked: bookedTimes, onSelected: onSelected),
        const SizedBox(height: 14),
      ],
      if (afternoon.isNotEmpty) ...[
        _SlotHeader(icon: Icons.wb_twilight_outlined, label: 'Afternoon'),
        const SizedBox(height: 8),
        _SlotGrid(slots: afternoon, selected: selected, isDark: isDark,
            booked: bookedTimes, onSelected: onSelected),
        const SizedBox(height: 14),
      ],
      if (evening.isNotEmpty) ...[
        _SlotHeader(icon: Icons.nights_stay_outlined, label: 'Evening'),
        const SizedBox(height: 8),
        _SlotGrid(slots: evening, selected: selected, isDark: isDark,
            booked: bookedTimes, onSelected: onSelected),
      ],
    ]);
  }
}

class _SlotHeader extends StatelessWidget {
  final IconData icon; final String label;
  const _SlotHeader({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, size: 13, color: kTextMid),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid)),
  ]);
}

class _SlotGrid extends StatelessWidget {
  final List<String>         slots;
  final String?              selected;
  final bool                 isDark;
  final Set<String>          booked;
  final ValueChanged<String> onSelected;
  const _SlotGrid({required this.slots, required this.selected,
      required this.isDark, required this.booked, required this.onSelected});

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8, runSpacing: 8,
    children: slots.map((slot) {
      final isSel    = selected == slot;
      final isBooked = booked.contains(slot);
      return GestureDetector(
        onTap: isBooked ? null : () => onSelected(slot),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isBooked
                ? (isDark ? _kDarkSurface : const Color(0xFFF3F4F6))
                : isSel ? kPrimary
                : (isDark ? _kDarkSurface : kCardBg),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: isBooked ? const Color(0xFFD1D5DB) : (isSel ? kPrimary : kBorder)),
          ),
          child: Text(slot, style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: isBooked ? const Color(0xFFD1D5DB)
                : (isSel ? Colors.white : kTextDark),
            decoration: isBooked ? TextDecoration.lineThrough : null,
            decorationColor: const Color(0xFFD1D5DB),
          )),
        ),
      );
    }).toList(),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM BAR
// ─────────────────────────────────────────────────────────────────────────────
class _BaConfirmBar extends StatelessWidget {
  final bool         isDark;
  final bool         isQueue;
  final DateTime?    selectedDate;
  final String?      selectedSlot;
  final double?      fee;
  final bool         isLoading;
  final VoidCallback onConfirm;
  const _BaConfirmBar({required this.isDark, required this.isQueue,
      required this.selectedDate, required this.selectedSlot, required this.fee,
      required this.isLoading, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final dateStr = selectedDate != null ? _baFmtFull(selectedDate!) : '';
    final label   = isQueue ? 'Confirm Queue  ·  $dateStr' : '$selectedSlot  ·  $dateStr';
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? _kDarkSurface : kCardBg,
        border: const Border(top: BorderSide(color: kBorder, width: 0.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (selectedSlot != null || isQueue)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Selected slot', style: TextStyle(fontSize: 10.5, color: kTextMid)),
                Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark),
                    overflow: TextOverflow.ellipsis),
              ]),
              const Spacer(),
              if (fee != null) Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                const Text('Consult fee', style: TextStyle(fontSize: 10.5, color: kTextMid)),
                Text('₹${fee!.toStringAsFixed(0)}', style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: kGreen)),
              ]),
            ]),
          ),
        SizedBox(
          width: double.infinity, height: 50,
          child: ElevatedButton(
            onPressed: isLoading ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white,
              disabledBackgroundColor: kPrimary.withOpacity(0.6),
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: isLoading
                ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(isQueue ? Icons.confirmation_number_rounded : Icons.calendar_month_rounded, size: 17),
                    const SizedBox(width: 8),
                    const Text('Confirm Appointment', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ]),
          ),
        ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NO AVAILABILITY
// ─────────────────────────────────────────────────────────────────────────────
class _BaNoAvail extends StatelessWidget {
  final VoidCallback onBack;
  const _BaNoAvail({required this.onBack});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: const BoxDecoration(color: kPrimaryBg, shape: BoxShape.circle),
          child: const Icon(Icons.event_busy_rounded, size: 32, color: kPrimary)),
        const SizedBox(height: 16),
        const Text('No availability found', style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 8),
        const Text('This doctor has no available slots at the moment.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: kTextMid, height: 1.5)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onBack,
          style: ElevatedButton.styleFrom(backgroundColor: kPrimary, foregroundColor: Colors.white,
            elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Go Back'),
        ),
      ]),
    ),
  );
}