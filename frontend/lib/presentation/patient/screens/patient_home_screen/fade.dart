part of '../patient_home_screen.dart';

// Moved verbatim from _HomeScreenState (F1 split); an extension so these
// builders keep using the state's fields. None of them calls setState.
extension _FadeView on _HomeScreenState {
  Widget _fade(int i, Widget child) => AnimatedBuilder(
    animation: _anims[i],
    builder: (_, w) => Opacity(
      opacity: _anims[i].value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - _anims[i].value)),
        child: w,
      ),
    ),
    child: child,
  );

  Widget _buildAppointmentsSection() {
    final vmState = ref.watch(appointmentViewModelProvider);
    final async = vmState.patientAppointmentsList;
    final offline = vmState.offlineDoctors;
    if (async == null || async is AsyncLoading) {
      return _apptShell(loading: true);
    }
    return async.when(
      loading: () => _apptShell(loading: true),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        DateTime? apptTime(AppointmentList a) =>
            _timeTodayFromRaw(a.startTime) ??
            _timeTodayFromRaw(a.estimatedArrivalTime);

        final today = list.where(_isToday).where(_isActiveAppt).toList()
          ..sort((a, b) {
            final ta = apptTime(a)?.millisecondsSinceEpoch;
            final tb = apptTime(b)?.millisecondsSinceEpoch;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });
        final upcoming = list.where(_isUpcoming).where(_isActiveAppt).toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a.appointmentDate ?? '');
            final db = DateTime.tryParse(b.appointmentDate ?? '');
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
        final combined = [...today, ...upcoming];
        final shown = combined.take(3).toList();
        final hasMore = combined.length > 3;

        if (!_popupShown) {
          final todayActive = today.where((a) {
            final s = a.status?.toLowerCase().trim() ?? '';
            return s != 'cancelled' &&
                s != 'cancled' &&
                s != 'completed' &&
                s != 'complete';
          }).toList();
          if (todayActive.isNotEmpty) {
            final now = DateTime.now();
            DateTime? resolveTime(AppointmentList a) =>
                _timeTodayFromRaw(a.startTime) ??
                _timeTodayFromRaw(a.estimatedArrivalTime);

            todayActive.sort((a, b) {
              final ta = resolveTime(a)?.millisecondsSinceEpoch;
              final tb = resolveTime(b)?.millisecondsSinceEpoch;
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return ta.compareTo(tb);
            });

            final nowMinutes = now.hour * 60 + now.minute;
            AppointmentList? next;
            for (final a in todayActive) {
              final t = resolveTime(a);
              if (t == null) continue;
              final apptMinutes = t.hour * 60 + t.minute;
              if (apptMinutes >= nowMinutes) {
                next = a;
                break;
              }
            }
            if (next == null) {
              for (final a in todayActive.reversed) {
                if (resolveTime(a) != null) {
                  next = a;
                  break;
                }
              }
            }
            final popupAppointment = next ?? todayActive.first;
            _popupShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTodayAppointmentPopup(popupAppointment);
            });
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              'Upcoming Appointments',
              action: hasMore ? 'See All' : null,
              onAction: () => widget.onSeeAllAppointments != null
                  ? widget.onSeeAllAppointments!()
                  : widget.onTabChange(2),
            ),
            const SizedBox(height: 10),
            if (shown.isEmpty)
              _EmptyNote('No upcoming appointments')
            else
              ...shown.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ApptCard(
                    // Stable identity per appointment. Without it the socket's
                    // silent refetch tears down and recreates every card, so
                    // the State is lost and didUpdateWidget never sees the
                    // isMyTurn false→true transition — the "your turn" haptic
                    // was landing in initState, which is deliberately silent.
                    key: ValueKey(e.value.appointmentId ?? e.key),
                    appointment: e.value,
                    isToday: _isToday(e.value),
                    isNext: e.key == 0,
                    doctorOffline: offline.contains(e.value.doctorId),
                    queueEvent: vmState
                        .doctorQueueEvents['${e.value.doctorId}_${e.value.queueId}'],
                    currentServingOverride: vmState
                        .doctorCurrentServing['${e.value.doctorId}_${e.value.clinicId}'],
                    onCancel: () => _handleCancel(e.value),
                    onMarkArrived: () {
                      final familyId =
                          ref.read(patientLoginViewModelProvider).patientId ??
                          0;
                      final patientId = e.value.patientId ?? 0;
                      final appointmentId = e.value.appointmentId ?? 0;
                      if (familyId == 0 ||
                          patientId == 0 ||
                          appointmentId == 0) {
                        return Future.value(false);
                      }
                      return ref
                          .read(appointmentViewModelProvider.notifier)
                          .markArrived(appointmentId, patientId, familyId);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _apptShell({required bool loading}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        'Upcoming Appointments',
        action: 'See All',
        onAction: () => widget.onTabChange(2),
      ),
      const SizedBox(height: 10),
      if (loading) ...[
        const _ApptSkeletonCard(),
        const SizedBox(height: 8),
        const _ApptSkeletonCard(),
      ],
    ],
  );

  // Widget _buildSpecialtiesSection(List<DoctorDetails> doctors, bool isLoading) {
  //   if (doctors.isNotEmpty) {
  //     _cachedSpecialties = _buildSpecialtyList(doctors);
  //   }
  //   final specList = _cachedSpecialties;

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       _SectionTitle('Most Searched Specialties'),
  //       const SizedBox(height: 10),
  //       if (isLoading && specList.isEmpty)
  //         SizedBox(
  //           height: 98,
  //           child: ListView.separated(
  //             scrollDirection: Axis.horizontal,
  //             physics: const BouncingScrollPhysics(),
  //             itemCount: 6,
  //             separatorBuilder: (_, __) => const SizedBox(width: 10),
  //             itemBuilder: (_, __) => _SpecialtyChipSkeleton(),
  //           ),
  //         )
  //       else if (specList.isEmpty)
  //         const SizedBox.shrink()
  //       else
  //         SizedBox(
  //           height: 98,
  //           child: ListView.separated(
  //             scrollDirection: Axis.horizontal,
  //             physics: const BouncingScrollPhysics(),
  //             itemCount: specList.length,
  //             separatorBuilder: (_, __) => const SizedBox(width: 10),
  //             itemBuilder: (_, i) {
  //               final s = specList[i];
  //               return _SpecialtyChip(
  //                 icon:  s['icon']  as IconData,
  //                 label: s['name']  as String,
  //                 color: s['color'] as Color,
  //                 onTap: () => _goToSearch(specialty: s['name'] as String),
  //               );
  //             },
  //           ),
  //         ),
  //     ],
  //   );
  // }
  Widget _buildSpecialtiesSection(List<DoctorDetails> doctors, bool isLoading) {
    if (doctors.isNotEmpty) {
      _cachedSpecialties = _buildSpecialtyList(doctors);
    }
    final specList = _cachedSpecialties;
    final shown = specList.take(4).toList();
    final hasMore = specList.length > 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Specialties',
          action: hasMore ? 'View all' : null,
          onAction: hasMore ? () => requestDoctorExploreSpecialty() : null,
        ),
        const SizedBox(height: 10),
        // padding: zero — GridView applies its own default padding, which
        // showed up as dead space above and below the tiles. mainAxisExtent
        // pins each row to the pill's real height (34 icon + 10/10 padding
        // + border) instead of letting childAspectRatio derive a taller cell
        // from the screen width, which is what left the big gap below.
        if (isLoading && specList.isEmpty)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: List.generate(4, (_) => _SpecialtyPillSkeleton()),
          )
        else if (specList.isEmpty)
          const SizedBox.shrink()
        else
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 56,
                ),
            itemBuilder: (_, i) {
              final s = shown[i];
              return _SpecialtyPillCard(
                icon: s['icon'] as IconData,
                label: s['name'] as String,
                color: s['color'] as Color,
                onTap: () => _goToSearch(specialty: s['name'] as String),
              );
            },
          ),
      ],
    );
  }

  // Widget _buildTopRatedDoctorsSection(
  //     List<DoctorDetails> doctors, bool isLoading) {
  //   // Top rated = avg rating >= 3.5 AND at least 3 reviews, so a single stray
  //   // review can't push a doctor to the top. Both fields come straight from the
  //   // getDoctors response (server-aggregated) — no per-doctor review fetch.
  //   final rated = doctors
  //       .where((d) =>
  //           d.doctorId != null &&
  //           (d.rating ?? 0) >= 3.5 &&
  //           (d.reviewCount ?? 0) >= 3)
  //       .toList()
  //     ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

  //   final hasMore = rated.length > 3;
  //   final shownDoctors = rated.take(3).toList();
  //   final stillLoading = isLoading;

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       _SectionTitle(
  //         'Top Rated Doctors',
  //         action: hasMore ? 'Show all' : null,
  //         onAction: hasMore ? () => _goToSearch() : null,
  //       ),
  //       const SizedBox(height: 10),
  //       if (stillLoading && shownDoctors.isEmpty) ...[
  //         const _TopDoctorSkeletonCard(),
  //         const SizedBox(height: 8),
  //         const _TopDoctorSkeletonCard(),
  //       ] else if (shownDoctors.isEmpty)
  //         const _EmptyNote('No top rated doctors available')
  //       else
  //         ...shownDoctors.map(
  //           (doctor) => Padding(
  //             padding: const EdgeInsets.only(bottom: 8),
  //             child: _TopDoctorCard(
  //               doctor: doctor,
  //               cardRating: _clinicRatings[doctor.doctorId] ?? doctor.rating,
  //               onTap: () => _goToBook(doctor),
  //             ),
  //           ),
  //         ),
  //     ],
  //   );
  // }
  Widget _buildTopRatedDoctorsSection(
    List<DoctorDetails> doctors,
    bool isLoading,
  ) {
    final rated =
        doctors
            .where(
              (d) =>
                  d.doctorId != null &&
                  (d.rating ?? 0) >= 3.5 &&
                  (d.reviewCount ?? 0) >= 3,
            )
            .toList()
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

    final hasMore = rated.length > 6;
    final shownDoctors = rated.take(6).toList();
    final stillLoading = isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Top Rated Doctors',
          action: hasMore ? 'Show all' : null,
          onAction: hasMore ? () => _goToSearch() : null,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: stillLoading && shownDoctors.isEmpty
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, __) => const _TopDoctorSkeletonCard(),
                )
              : shownDoctors.isEmpty
              ? const _EmptyNote('No top rated doctors available')
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: shownDoctors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final doctor = shownDoctors[i];
                    return _TopDoctorCard(
                      doctor: doctor,
                      cardRating:
                          _clinicRatings[doctor.doctorId] ?? doctor.rating,
                      onTap: () => _goToBook(doctor),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
