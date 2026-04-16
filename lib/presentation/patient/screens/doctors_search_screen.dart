import 'package:flutter/material.dart';


// ─── Color Palette ─────────────────────────────────────────────────────────
class _C {
  _C._();
  static const teal        = Color(0xFF26C6B0);
  static const tealDark    = Color(0xFF2BB5A0);
  static const tealLight   = Color(0xFFD9F5F1);
  static const tealLighter = Color(0xFFF2FCFA);

  static const textPrimary = Color(0xFF2D3748);
  static const textSlate   = Color(0xFF718096);
  static const textMuted   = Color(0xFFA0AEC0);

  static const border  = Color(0xFFEDF2F7);
  static const divider = Color(0xFFE5E7EB);
  static const bg      = Colors.white;
  static const card    = Colors.white;

  static const green  = Color(0xFF68D391);
  static const amber  = Color(0xFFF6AD55);
  static const red    = Color(0xFFFC8181);
  static const purple = Color(0xFF9F7AEA);
  static const indigo = Color(0xFF7F9CF5);

  static const darkSurface = Color(0xFF1E2A28);
  static const darkBg      = Color(0xFF0F1F1D);
}

// ─── Helpers ──────────────────────────────────────────────────────────────
String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

const _specialtyAccent = <String, Color>{
  'cardiology'   : _C.red,
  'dermatology'  : _C.amber,
  'pediatrics'   : _C.green,
  'orthopedics'  : _C.purple,
  'neurology'    : _C.indigo,
  'general'      : _C.teal,
  'gynecology'   : _C.purple,
  'ophthalmology': _C.indigo,
};

const _specialtyBg = <String, Color>{
  'cardiology'   : Color(0xFFFFF5F5),
  'dermatology'  : Color(0xFFFFFBEB),
  'pediatrics'   : Color(0xFFF0FFF8),
  'orthopedics'  : Color(0xFFFAF5FF),
  'neurology'    : Color(0xFFEBF8FF),
  'general'      : _C.tealLighter,
  'gynecology'   : Color(0xFFFAF5FF),
  'ophthalmology': Color(0xFFEBF8FF),
};

Color _accentFor(String? s) => _specialtyAccent[s?.toLowerCase()] ?? _C.teal;
Color _bgFor(String? s)     => _specialtyBg[s?.toLowerCase()]     ?? _C.tealLighter;

// ─── Mock Data Models ─────────────────────────────────────────────────────
enum QueueState { unavailable, opensSoon, full, empty, hasQueue }

class MockDoctor {
  final int id;
  final String name;
  final String specialization;
  final String clinic;
  final String address;
  final double fee;
  final int experience;
  final QueueState queueState;
  final int currentQueue;
  final int maxQueue;
  final bool isFavorite;
  final String? opensAt;

  const MockDoctor({
    required this.id,
    required this.name,
    required this.specialization,
    required this.clinic,
    required this.address,
    required this.fee,
    required this.experience,
    this.queueState = QueueState.hasQueue,
    this.currentQueue = 0,
    this.maxQueue = 20,
    this.isFavorite = false,
    this.opensAt,
  });
}

const _mockDoctors = <MockDoctor>[
  MockDoctor(
    id: 1, name: 'Aisha Mehta', specialization: 'cardiology',
    clinic: 'Heart Care Centre', address: 'Bandra West',
    fee: 800, experience: 12,
    queueState: QueueState.hasQueue, currentQueue: 3, maxQueue: 15,
    isFavorite: true,
  ),
  MockDoctor(
    id: 2, name: 'Rajan Patel', specialization: 'pediatrics',
    clinic: 'Little Stars Clinic', address: 'Andheri East',
    fee: 600, experience: 8,
    queueState: QueueState.empty,
  ),
  MockDoctor(
    id: 3, name: 'Sunita Rao', specialization: 'dermatology',
    clinic: 'Skin & Glow', address: 'Juhu',
    fee: 1200, experience: 15,
    queueState: QueueState.full,
  ),
  MockDoctor(
    id: 4, name: 'Vikram Singh', specialization: 'orthopedics',
    clinic: 'Bone & Joint Clinic', address: 'Malad',
    fee: 1000, experience: 20,
    queueState: QueueState.opensSoon, opensAt: '10:00 AM',
    isFavorite: true,
  ),
  MockDoctor(
    id: 5, name: 'Priya Nair', specialization: 'neurology',
    clinic: 'Neuro Specialists', address: 'Dadar',
    fee: 1500, experience: 18,
    queueState: QueueState.hasQueue, currentQueue: 7, maxQueue: 20,
  ),
  MockDoctor(
    id: 6, name: 'Amit Shah', specialization: 'general',
    clinic: 'Family Health Clinic', address: 'Borivali',
    fee: 400, experience: 5,
    queueState: QueueState.unavailable,
  ),
  MockDoctor(
    id: 7, name: 'Kavita Desai', specialization: 'gynecology',
    clinic: 'Women\'s Wellness', address: 'Vile Parle',
    fee: 900, experience: 11,
    queueState: QueueState.hasQueue, currentQueue: 2, maxQueue: 10,
    isFavorite: true,
  ),
  MockDoctor(
    id: 8, name: 'Suresh Iyer', specialization: 'ophthalmology',
    clinic: 'Eye Care Centre', address: 'Chembur',
    fee: 700, experience: 9,
    queueState: QueueState.empty,
  ),
];

const _mockMembers = ['Rahul (Son)', 'Meera (Wife)', 'Dad'];

// ─── Queue Status Model ────────────────────────────────────────────────────
class _QueueStatus {
  final bool isVisible, canBook, tintCard;
  final String label, btnLabel;
  final Color color;
  final IconData icon;
  final double? progress;

  const _QueueStatus({
    required this.isVisible, required this.canBook, required this.tintCard,
    required this.label, required this.btnLabel,
    required this.color, required this.icon, this.progress,
  });

  factory _QueueStatus.from(MockDoctor d) {
    switch (d.queueState) {
      case QueueState.unavailable:
        return const _QueueStatus(isVisible: true, canBook: false, tintCard: true,
            label: 'Queue unavailable', btnLabel: 'Unavailable',
            color: _C.red, icon: Icons.block_rounded);
      case QueueState.opensSoon:
        return _QueueStatus(isVisible: true, canBook: false, tintCard: false,
            label: d.opensAt != null ? 'Opens ${d.opensAt}' : 'Opens soon',
            btnLabel: 'Soon', color: _C.amber, icon: Icons.schedule_rounded);
      case QueueState.full:
        return const _QueueStatus(isVisible: true, canBook: false, tintCard: true,
            label: 'Queue full', btnLabel: 'Full',
            color: _C.red, icon: Icons.group_off_rounded);
      case QueueState.empty:
        return const _QueueStatus(isVisible: true, canBook: true, tintCard: false,
            label: 'Queue open', btnLabel: 'Book',
            color: _C.teal, icon: Icons.event_available_rounded);
      case QueueState.hasQueue:
        final prog = (d.currentQueue / d.maxQueue).clamp(0.0, 1.0);
        return _QueueStatus(
          isVisible: true, canBook: true, tintCard: false,
          label: '${d.currentQueue} / ${d.maxQueue} in queue',
          btnLabel: 'Book',
          color: d.currentQueue > 5 ? _C.red : _C.amber,
          icon: Icons.people_alt_rounded, progress: prog,
        );
    }
  }

  Color get dot => canBook ? _C.teal : _C.red;
}

// ─── Main Screen ──────────────────────────────────────────────────────────
class DoctorSearchScreen extends StatefulWidget {
  const DoctorSearchScreen({super.key});
  @override
  State<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends State<DoctorSearchScreen>
    with SingleTickerProviderStateMixin {
  final _search = TextEditingController();
  String? _specialty;
  String? _selectedMember;
  bool _favOnly  = false;
  bool _loading  = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 450));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 100), () => _fadeCtrl.forward());
  }

  @override
  void dispose() {
    _search.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  List<MockDoctor> get _filtered {
    return _mockDoctors.where((d) {
      if (_favOnly && !d.isFavorite) return false;
      final q = _search.text.toLowerCase();
      final matchQ = q.isEmpty ||
          d.name.toLowerCase().contains(q) ||
          d.specialization.toLowerCase().contains(q) ||
          d.clinic.toLowerCase().contains(q);
      final matchS = _specialty == null || d.specialization == _specialty;
      return matchQ && matchS;
    }).toList();
  }

  List<String> get _specialties {
    final seen = <String>{};
    return _mockDoctors.map((d) => d.specialization).where(seen.add).toList();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final docs = _filtered;

    return Scaffold(
      backgroundColor: _C.bg,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _TopBar(
                favOnly: _favOnly,
                favCount: _mockDoctors.where((d) => d.isFavorite).length,
                onFavTap: () => setState(() {
                  _favOnly = !_favOnly;
                  if (!_favOnly) _specialty = null;
                }),
              ),
              _BookingRow(
                members: _mockMembers,
                selected: _selectedMember,
                onChanged: (v) => setState(() => _selectedMember = v),
              ),
              _SearchBar(
                controller: _search,
                onChanged: (_) => setState(() {}),
              ),
              if (!_favOnly)
                _SpecialtyChips(
                  specialties: _specialties,
                  selected: _specialty,
                  onTap: (s) => setState(
                    () => _specialty = s == _specialty ? null : s,
                  ),
                )
              else
                _FavFilter(onClear: () => setState(() => _favOnly = false)),

              if (!_loading)
                _CountBadge(count: docs.length, isFav: _favOnly),

              Expanded(
                child: _loading
                    ? const _LoadingShimmer()
                    : _DoctorListView(
                        doctors: docs,
                        isFavMode: _favOnly,
                        selectedMember: _selectedMember,
                        onRefresh: _refresh,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Top Bar ──────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final bool favOnly;
  final int favCount;
  final VoidCallback onFavTap;
  const _TopBar({required this.favOnly, required this.favCount, required this.onFavTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
      child: Row(
        children: [
          Container(
            width: 3, height: 26,
            decoration: BoxDecoration(color: _C.teal, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  favOnly ? 'Favorites' : 'Find a Doctor',
                  style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w800,
                    letterSpacing: -0.4, color: _C.textPrimary,
                  ),
                ),
                Text(
                  favOnly ? 'Your saved doctors' : 'Book your appointment',
                  style: const TextStyle(fontSize: 10.5, color: _C.textMuted),
                ),
              ],
            ),
          ),
          // Notifications bell
          Container(
            width: 34, height: 34,
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: _C.tealLighter,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _C.teal.withOpacity(0.2)),
            ),
            child: const Icon(Icons.notifications_none_rounded, color: _C.teal, size: 16),
          ),
          // Favorites toggle
          GestureDetector(
            onTap: onFavTap,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: favOnly ? _C.red.withOpacity(0.1) : _C.tealLighter,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: favOnly ? _C.red.withOpacity(0.3) : _C.teal.withOpacity(0.2),
                    ),
                  ),
                  child: Icon(
                    favOnly ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                    color: favOnly ? _C.red : _C.teal, size: 16,
                  ),
                ),
                if (!favOnly && favCount > 0)
                  Positioned(
                    top: -3, right: -3,
                    child: Container(
                      width: 15, height: 15,
                      decoration: const BoxDecoration(color: _C.red, shape: BoxShape.circle),
                      child: Center(
                        child: Text('$favCount',
                            style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w700)),
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
}

// ─── Booking Row ──────────────────────────────────────────────────────────
class _BookingRow extends StatelessWidget {
  final List<String> members;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _BookingRow({required this.members, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: _C.tealLighter,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.teal.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, color: _C.teal, size: 13),
          const SizedBox(width: 5),
          const Text('Booking for:', style: TextStyle(fontSize: 10.5, color: _C.textSlate)),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String?>(
                value: selected,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: _C.teal),
                dropdownColor: Colors.white,
                hint: const Text('Myself',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.teal)),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: _MemberOption(label: 'Myself', sub: 'Self', color: _C.teal),
                  ),
                  ...members.map((m) => DropdownMenuItem<String?>(
                        value: m,
                        child: _MemberOption(label: m.split(' ').first, sub: m.split(' ').last, color: _C.purple),
                      )),
                ],
                onChanged: onChanged,
                selectedItemBuilder: (ctx) => [
                  const _DropSelected('Myself'),
                  ...members.map((m) => _DropSelected(m.split(' ').first)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberOption extends StatelessWidget {
  final String label, sub;
  final Color color;
  const _MemberOption({required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: color.withOpacity(0.15),
            child: Text(label[0], style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(width: 7),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _C.textPrimary)),
              Text(sub, style: const TextStyle(fontSize: 9.5, color: _C.textMuted)),
            ],
          ),
        ],
      );
}

class _DropSelected extends StatelessWidget {
  final String text;
  const _DropSelected(this.text);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _C.teal)),
      );
}

// ─── Search Bar ───────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _C.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Icon(Icons.search_rounded, color: _C.textMuted, size: 16),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: const TextStyle(fontSize: 13, color: _C.textPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Doctor, specialty, clinic…',
                  hintStyle: TextStyle(fontSize: 13, color: _C.textMuted),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            controller.text.isNotEmpty
                ? GestureDetector(
                    onTap: () { controller.clear(); onChanged(''); },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Container(
                        width: 17, height: 17,
                        decoration: BoxDecoration(color: _C.textMuted.withOpacity(0.15), shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 11, color: _C.textSlate),
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Container(
                      width: 26, height: 26,
                      decoration: BoxDecoration(color: _C.teal, borderRadius: BorderRadius.circular(7)),
                      child: const Icon(Icons.tune_rounded, color: Colors.white, size: 13),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

// ─── Specialty Chips ──────────────────────────────────────────────────────
class _SpecialtyChips extends StatelessWidget {
  final List<String> specialties;
  final String? selected;
  final ValueChanged<String> onTap;
  const _SpecialtyChips({required this.specialties, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 3, 12, 0),
        children: [
          _SpecChip(label: 'All', selected: selected == null, accent: _C.teal, bg: _C.tealLighter, onTap: () => onTap('__all__')),
          ...specialties.map((s) => _SpecChip(
                label: _cap(s), selected: selected == s,
                accent: _accentFor(s), bg: _bgFor(s),
                onTap: () => onTap(s),
              )),
        ],
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent, bg;
  final VoidCallback onTap;
  const _SpecChip({required this.label, required this.selected, required this.accent, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 5),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: selected ? accent : bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? accent : accent.withOpacity(0.3), width: 1),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: selected ? Colors.white : accent)),
      ),
    );
  }
}

// ─── Favorites Filter Strip ───────────────────────────────────────────────
class _FavFilter extends StatelessWidget {
  final VoidCallback onClear;
  const _FavFilter({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _C.red.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.red.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: _C.red, size: 12),
          const SizedBox(width: 6),
          const Expanded(child: Text('Showing favorites only',
              style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: _C.red))),
          GestureDetector(
            onTap: onClear,
            child: const Text('Show all', style: TextStyle(
                fontSize: 10.5, fontWeight: FontWeight.w600, color: _C.teal,
                decoration: TextDecoration.underline)),
          ),
        ],
      ),
    );
  }
}

// ─── Count Badge ──────────────────────────────────────────────────────────
class _CountBadge extends StatelessWidget {
  final int count;
  final bool isFav;
  const _CountBadge({required this.count, required this.isFav});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
      child: Row(
        children: [
          Container(width: 5, height: 5, decoration: const BoxDecoration(color: _C.teal, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(
            isFav ? '$count favorite${count == 1 ? '' : 's'}' : '$count doctors available',
            style: const TextStyle(fontSize: 10.5, color: _C.textSlate, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─── Doctor List ──────────────────────────────────────────────────────────
class _DoctorListView extends StatelessWidget {
  final List<MockDoctor> doctors;
  final bool isFavMode;
  final String? selectedMember;
  final Future<void> Function() onRefresh;

  const _DoctorListView({
    required this.doctors, required this.isFavMode,
    required this.selectedMember, required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (doctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(color: _C.tealLighter, borderRadius: BorderRadius.circular(14)),
              child: Icon(isFavMode ? Icons.favorite_border_rounded : Icons.search_off_rounded,
                  size: 26, color: _C.teal),
            ),
            const SizedBox(height: 10),
            Text(isFavMode ? 'No favorites yet' : 'No results found',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _C.textPrimary)),
            const SizedBox(height: 3),
            const Text('Try a different search', style: TextStyle(fontSize: 11, color: _C.textMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _C.teal,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        itemCount: doctors.length,
        itemBuilder: (_, i) => _DoctorCard(doctor: doctors[i], selectedMember: selectedMember),
      ),
    );
  }
}

// ─── Doctor Card ──────────────────────────────────────────────────────────
class _DoctorCard extends StatefulWidget {
  final MockDoctor doctor;
  final String? selectedMember;
  const _DoctorCard({required this.doctor, required this.selectedMember});

  @override
  State<_DoctorCard> createState() => _DoctorCardState();
}

class _DoctorCardState extends State<_DoctorCard> with SingleTickerProviderStateMixin {
  late bool _fav;
  late AnimationController _heartCtrl;
  late Animation<double> _heartScale;

  @override
  void initState() {
    super.initState();
    _fav = widget.doctor.isFavorite;
    _heartCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 250));
    _heartScale = TweenSequence([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));
  }

  @override
  void dispose() { _heartCtrl.dispose(); super.dispose(); }

  void _toggleFav() {
    setState(() => _fav = !_fav);
    _heartCtrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    final qs = _QueueStatus.from(d);
    final accent = _accentFor(d.specialization);
    final specBg = _bgFor(d.specialization);
    final init = d.name[0].toUpperCase();
    final clinicText = '${d.clinic} · ${d.address}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qs.tintCard ? _C.red.withOpacity(0.28) : _C.border,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12, offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ──
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withOpacity(0.2), width: 1.5),
                ),
                child: Center(
                  child: Text(init, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: accent)),
                ),
              ),
              // Fav heart
              Positioned(
                top: -4, right: -4,
                child: GestureDetector(
                  onTap: _toggleFav,
                  child: ScaleTransition(
                    scale: _heartScale,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: _C.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 3)],
                      ),
                      child: Icon(
                        _fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        size: 9.5, color: _fav ? _C.red : _C.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
              // Online dot
              Positioned(
                bottom: 1, right: 1,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: qs.dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(width: 11),

          // ── Info ──
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Dr. ${d.name}',
                        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _C.textPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    _FeeTag(fee: d.fee),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _SpecTag(label: _cap(d.specialization), accent: accent, bg: specBg),
                    const SizedBox(width: 6),
                    _ExpTag(years: d.experience),
                    const Spacer(),
                    _RatingDot(),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 10, color: _C.textMuted),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(clinicText,
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: _C.textMuted)),
                    ),
                  ],
                ),
                if (qs.isVisible) ...[
                  const SizedBox(height: 5),
                  _QueuePill(status: qs),
                ],
              ],
            ),
          ),

          const SizedBox(width: 8),

          // ── Book Button ──
          _BookButton(status: qs),
        ],
      ),
    );
  }
}

// ─── Sub-components ───────────────────────────────────────────────────────
class _FeeTag extends StatelessWidget {
  final double fee;
  const _FeeTag({required this.fee});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(color: _C.tealLighter, borderRadius: BorderRadius.circular(6)),
        child: Text('₹${fee.toStringAsFixed(0)}',
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _C.teal)),
      );
}

class _SpecTag extends StatelessWidget {
  final String label;
  final Color accent, bg;
  const _SpecTag({required this.label, required this.accent, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(label, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: accent)),
      );
}

class _ExpTag extends StatelessWidget {
  final int years;
  const _ExpTag({required this.years});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded, size: 10, color: _C.amber),
          const SizedBox(width: 2),
          Text('${years}y exp', style: const TextStyle(fontSize: 10, color: _C.textMuted)),
        ],
      );
}

class _RatingDot extends StatelessWidget {
  const _RatingDot();
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 10, color: _C.amber),
          const SizedBox(width: 2),
          const Text('4.8', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _C.textSlate)),
        ],
      );
}

class _QueuePill extends StatelessWidget {
  final _QueueStatus status;
  const _QueuePill({required this.status});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
          decoration: BoxDecoration(
            color: status.color.withOpacity(0.09),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(status.icon, size: 10, color: status.color),
              const SizedBox(width: 4),
              Text(status.label,
                  style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600, color: status.color)),
            ],
          ),
        ),
        if (status.progress != null) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 55,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: status.progress,
                minHeight: 3,
                backgroundColor: _C.border,
                valueColor: AlwaysStoppedAnimation<Color>(status.color),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _BookButton extends StatelessWidget {
  final _QueueStatus status;
  const _BookButton({required this.status});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 66,
          height: 36,
          child: ElevatedButton(
            onPressed: status.canBook ? () => _showConfirmSnack(context) : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: status.canBook ? _C.teal : status.color.withOpacity(0.1),
              foregroundColor: status.canBook ? Colors.white : status.color,
              disabledBackgroundColor: status.color.withOpacity(0.1),
              disabledForegroundColor: status.color,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
            child: Text(status.btnLabel),
          ),
        ),
        if (status.canBook) ...[
          const SizedBox(height: 3),
          const Text('~15 min', style: TextStyle(fontSize: 8.5, color: _C.textMuted)),
        ],
      ],
    );
  }

  void _showConfirmSnack(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: const Text('Opening appointment screen…', style: TextStyle(fontSize: 12)),
        backgroundColor: _C.teal,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      ),
    );
  }
}

// ─── Loading Shimmer ──────────────────────────────────────────────────────
class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();
  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 20),
        itemCount: 5,
        itemBuilder: (_, __) => _ShimmerCard(phase: _anim.value),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double phase;
  const _ShimmerCard({required this.phase});

  Color get _s1 => Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFF7F9FC), phase)!;
  Color get _s2 => Color.lerp(const Color(0xFFF1F5F9), const Color(0xFFE2E8F0), phase)!;

  Widget _bar(double w, double h) => Container(
        width: w, height: h, margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          color: _s1,
          gradient: LinearGradient(colors: [_s1, _s2, _s1], stops: [0, 0.5 + phase * 0.3, 1]),
          borderRadius: BorderRadius.circular(4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(color: _s1, shape: BoxShape.circle),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _bar(140, 14), _bar(90, 10), _bar(110, 10),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            width: 66, height: 36,
            decoration: BoxDecoration(color: _s1, borderRadius: BorderRadius.circular(10)),
          ),
        ],
      ),
    );
  }
}