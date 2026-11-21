part of '../patient_home_screen.dart';

class _LocationSheetState extends State<_LocationSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _isLoadingGPS = false;
  bool _isSearching = false;

  static const _apiKey = 'AIzaSyDTRL5VzQ9UAwsCB9uCbSNj5wZasYHjFKA';

  // predictions from Google Places
  List<Map<String, dynamic>> _predictions = [];
  // fallback static list when search is empty
  List<String> _staticSuggestions = _allCities;

  bool get _hasQuery => _ctrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onType);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onType);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onType() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _predictions = [];
        _staticSuggestions = _allCities;
      });
      return;
    }
    // also filter static list as fallback
    setState(() {
      _staticSuggestions = _allCities
          .where((c) => c.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
    _fetchPredictions(q);
  }

  Future<void> _fetchPredictions(String query) async {
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:in'
        '&language=en'
        '&types=(cities)' // only city-level results
        '&key=$_apiKey',
      );
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(data['predictions']);
        });
      } else {
        debugPrint('Places status: ${data['status']}');
        setState(() => _predictions = []);
      }
    } catch (e) {
      debugPrint('Places error: $e');
      setState(() => _predictions = []);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _pick(String loc) {
    widget.onSelected(loc);
    Navigator.pop(context);
  }

  Future<void> _useGPS() async {
    setState(() => _isLoadingGPS = true);
    try {
      final current = await LocationService.getCurrentAddress();
      if (!mounted) return;
      final hasIssue =
          current.toLowerCase().contains('location disabled') ||
          current.toLowerCase().contains('permission');
      widget.onSelected(current);
      if (!hasIssue) {
        await LocationStorage.saveLocation(current, isManual: false);
        if (!mounted) return;
        Navigator.pop(context);
      } else {
        setState(() => _isLoadingGPS = false);
        _snack();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingGPS = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to detect location')),
      );
    }
  }

  void _snack() {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isWindows
              ? 'Enable Windows location services'
              : 'Enable phone location services',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: kPrimary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose Location',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                          ),
                        ),
                        if (widget.currentLocation.isNotEmpty)
                          Text(
                            'Current: ${widget.currentLocation}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Search field ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search city or place…',
                    hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                    prefixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(11),
                            child: SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kPrimary,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.search_rounded,
                            color: kTextMuted,
                            size: 17,
                          ),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _ctrl.clear();
                              _focus.requestFocus();
                            },
                            child: const Icon(
                              Icons.clear_rounded,
                              color: kTextMuted,
                              size: 15,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                  onSubmitted: (val) {
                    final v = val.trim();
                    if (v.isEmpty) return;
                    if (_predictions.isNotEmpty) {
                      _pick(_predictions.first['description'] ?? v);
                    } else if (_staticSuggestions.isNotEmpty) {
                      _pick(_staticSuggestions.first);
                    } else {
                      _pick(v);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── GPS button ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _isLoadingGPS ? null : _useGPS,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryLight.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isLoadingGPS
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoadingGPS
                                  ? 'Detecting…'
                                  : 'Use Current Location',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary,
                              ),
                            ),
                            const Text(
                              'Auto-detect via GPS',
                              style: TextStyle(fontSize: 10, color: kTextMuted),
                            ),
                          ],
                        ),
                      ),
                      if (!_isLoadingGPS)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: kPrimary,
                          size: 17,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Clear location ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  await LocationStorage.clearLocation();
                  if (!context.mounted) return;
                  widget.onSelected('');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location cache cleared')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: kTextMuted,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Clear Saved Location',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Section label ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(child: Divider(color: kBorder, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      !_hasQuery
                          ? 'POPULAR CITIES'
                          : _predictions.isNotEmpty
                          ? 'SUGGESTIONS'
                          : 'RESULTS',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: kBorder, height: 1)),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ── Results list ─────────────────────────────────────────
            Flexible(
              child: _hasQuery && _predictions.isNotEmpty
                  // Google Places predictions
                  ? ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      itemCount: _predictions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: kBorder, height: 1),
                      itemBuilder: (_, i) {
                        final p = _predictions[i];
                        final mainText =
                            p['structured_formatting']?['main_text'] ??
                            p['description'] ??
                            '';
                        final secondText =
                            p['structured_formatting']?['secondary_text'] ?? '';
                        final fullDesc = p['description'] ?? mainText;
                        return GestureDetector(
                          onTap: () => _pick(fullDesc),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: kPrimaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: kPrimary,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mainText,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: kTextPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (secondText.isNotEmpty) ...[
                                        const SizedBox(height: 1),
                                        Text(
                                          secondText,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: kTextMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.north_west_rounded,
                                  color: kBorder,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  // Static / filtered city list
                  : _staticSuggestions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 28,
                            color: kTextMuted,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'No cities found',
                            style: TextStyle(color: kTextMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      itemCount: _staticSuggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: kBorder, height: 1),
                      itemBuilder: (_, i) {
                        final loc = _staticSuggestions[i];
                        final isActive = loc == widget.currentLocation;
                        return GestureDetector(
                          onTap: () => _pick(loc),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? kPrimary
                                        : const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isActive
                                        ? Icons.location_on_rounded
                                        : Icons.location_city_rounded,
                                    color: isActive ? Colors.white : kTextMuted,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    loc,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isActive ? kPrimary : kTextPrimary,
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kPrimaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: kPrimary,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: kBorder,
                                    size: 15,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HERO BOOK CARD
//  Flat teal banner that replaces the old "highlighted quick action" tile.
//  Two soft decorative circles give it depth without shadows/gradients.
// ════════════════════════════════════════════════════════════════════
class _HeroBookCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroBookCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: -26,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned(
            right: 26,
            bottom: -34,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Feeling unwell?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 210,
                child: Text(
                  'Book a doctor and skip the waiting room queue.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Book appointment',
                        style: TextStyle(
                          color: kPrimaryDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: kPrimaryDark,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HEADER BUTTON
// ════════════════════════════════════════════════════════════════════
// When `badge: true`, the button watches `notificationProvider` and shows the
// unread count as a numeric badge. The bell icon also performs a periodic
// shake animation while there are unread notifications — borrowed from the
// Instagram/Practo header pattern — and falls silent once everything is read.
class _HeaderBtn extends ConsumerStatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  const _HeaderBtn({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  @override
  ConsumerState<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends ConsumerState<_HeaderBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    // ~3s cycle. The actual shake plays in the first ~25% of the timeline
    // (a TweenSequence wobble), the remaining ~75% is a flat 0 hold so the
    // bell pulses every few seconds instead of wobbling continuously — same
    // cadence Instagram uses for its activity bell.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.25), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: -0.25), weight: 6),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.18), weight: 6),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: -0.12), weight: 5),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.0), weight: 4),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 75),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Start/stop the loop based on unread count. Run after the current frame
  // so we don't mutate animation state from inside build().
  void _syncAnimation(int unread) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (unread > 0 && !_ctrl.isAnimating) {
        _ctrl.repeat();
      } else if (unread == 0 && _ctrl.isAnimating) {
        _ctrl.stop();
        _ctrl.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.badge
        ? ref.watch(notificationProvider).where((n) => !n.isRead).length
        : 0;
    _syncAnimation(unread);

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: _neoBox(radius: 10),
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _shake,
              builder: (_, child) => Transform.rotate(
                angle: _shake.value,
                // Pivot from the top so the bell swings like it's hanging.
                alignment: Alignment.topCenter,
                child: child,
              ),
              child: Icon(
                widget.icon,
                color: const Color(0xFFE53935),
                size: 20,
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: kWarning,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
