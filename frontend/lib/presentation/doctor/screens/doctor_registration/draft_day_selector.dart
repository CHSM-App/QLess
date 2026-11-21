part of '../doctor_registration.dart';

// Moved verbatim from _DoctorProfileSetupScreenState (F1 split); an extension so these
// builders keep using the state's fields. None of them calls setState.
extension _DraftDaySelectorView on _DoctorProfileSetupScreenState {
  Widget _buildDraftDaySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _days.asMap().entries.map((e) {
        final i = e.key;
        final day = e.value;
        final sel = _draftDays.contains(i);
        return GestureDetector(
          onTap: () => _toggleDraftDay(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: sel
                  ? const LinearGradient(colors: [kPrimary, kPrimaryDark])
                  : null,
              color: sel ? null : kBgSoft,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: sel ? kPrimary : kBorderStrong),
            ),
            child: Column(
              children: [
                Text(
                  day.shortName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: sel ? Colors.white : kTextSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  day.isEnabled ? 'Set' : 'Off',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white70 : kTextMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBlockSummaryCard(int index, _ScheduleBlock block) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: kPrimary.withValues(alpha: 0.45), width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(_modeIcon(block.bookingMode),
                size: 16, color: kPrimaryDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtBlockDays(block),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtTimeDisplay(block.startTime)} - '
                  '${_fmtTimeDisplay(block.endTime)}  •  '
                  '${_modeLabel(block.bookingMode)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: kPrimaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _removeBlock(index),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: kRedLight,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded, size: 14, color: kError),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftScheduleConfig() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBgSoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: kBorderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimeRangePicker(
            start: _fmtTimeDisplay(_draftStart),
            end: _fmtTimeDisplay(_draftEnd),
            onTap: _pickDraftTimeRange,
          ),
          const SizedBox(height: 12),
          const Text(
            'Booking Mode',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: BookingMode.values.asMap().entries.map((e) {
              final mode = e.value;
              final isLast = e.key == BookingMode.values.length - 1;
              final sel = _draftMode == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _setDraftMode(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: EdgeInsets.only(right: isLast ? 0 : 7),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? const LinearGradient(
                              colors: [kPrimary, kPrimaryDark])
                          : null,
                      color: sel ? null : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? kPrimary : kBorderStrong),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: kPrimary.withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_modeIcon(mode),
                            size: 13,
                            color: sel ? Colors.white : kTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _modeLabel(mode),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_draftMode == BookingMode.queue ||
              _draftMode == BookingMode.both) ...[
            const SizedBox(height: 12),
            const Text(
              'Max Queue Length',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kTextSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderStrong),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 11),
                  const Icon(Icons.people_alt_rounded,
                      size: 16, color: kPrimaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _draftQueueCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D2E)),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'e.g. 20',
                        hintStyle:
                            TextStyle(fontSize: 13.5, color: kTextMuted),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _setDraftMaxQueue,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(7)),
                    child: const Text(
                      'patients',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDarker,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_draftMode == BookingMode.slots ||
              _draftMode == BookingMode.both) ...[
            const SizedBox(height: 12),
            const Text(
              'Slot Duration',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kTextSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 7),
            _SlotDurationPicker(
              value: _draftSlotDuration,
              onChanged: _setDraftSlotDuration,
            ),
          ],
        ],
      ),
    );
  }

  // ─── Field Builders ───────────────────────────────────────────────────────
  Widget _buildField(
    String label,
    TextEditingController controller, {
    String hint = '',
    TextInputType keyboard = TextInputType.text,
    bool required = false,
    IconData? icon,
    ValueChanged<String>? onChanged,
    String? errorText,
    Widget? prefixWidget,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboard,
            onChanged: onChanged,
            inputFormatters: inputFormatters,
            validator: validator,
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1D2E),
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 13.5),
              prefixIcon: prefixWidget ??
                  (icon != null
                      ? Icon(icon, color: kTextMuted, size: 19)
                      : null),
              filled: true,
              fillColor: kBgSoft,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kBorderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: errorText != null
                    ? const BorderSide(color: kError)
                    : const BorderSide(color: kBorderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: errorText != null
                    ? const BorderSide(color: kError, width: 1.6)
                    : const BorderSide(color: kPrimary, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kError),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kError, width: 1.6),
              ),
              errorStyle: const TextStyle(
                  fontSize: 9.5, color: kError, fontWeight: FontWeight.w600),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 13, color: kError),
              const SizedBox(width: 5),
              Expanded(
                child: Text(errorText,
                    style: const TextStyle(
                        fontSize: 9.5,
                        color: kError,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildTextArea(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool required = false,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 3,
            validator: validator,
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1D2E),
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 13.5),
              filled: true,
              fillColor: kBgSoft,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kBorderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kBorderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kPrimary, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kError),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kError, width: 1.6),
              ),
              errorStyle: const TextStyle(
                  fontSize: 9.5, color: kError, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    final hasLocation = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Container(
              height: 50,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: hasLocation ? kPrimaryLight : kBgSoft,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: hasLocation ? kPrimary : kBorderStrong,
                  width: hasLocation ? 1.6 : 1,
                ),
              ),
              child: Row(children: [
                Icon(
                  hasLocation
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  size: 17,
                  color: hasLocation ? kPrimaryDark : kTextMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLocation
                        ? '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                        : 'No location selected',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasLocation ? kPrimaryDarker : kTextMuted,
                      fontWeight: hasLocation
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          _LocationButton(
            icon: Icons.my_location_rounded,
            tooltip: 'Use GPS',
            onTap: _getCurrentLocation,
          ),
          const SizedBox(width: 8),
          _LocationButton(
            icon: Icons.map_outlined,
            tooltip: 'Pick on map',
            onTap: _selectFromMap,
          ),
        ]),
      ],
    );
  }
}
