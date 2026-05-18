import 'package:flutter/material.dart';

class AppExpandableHeaderSearch extends StatefulWidget {
  final IconData? leadingIcon;
  final String title;
  final String subtitle;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final double height;
  final Color accentColor;
  final Color leadingBackgroundColor;
  final Color titleColor;
  final Color subtitleColor;
  final Color surfaceColor;
  final Color fieldColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final TextEditingController? controller;
  final FocusNode? focusNode;

  const AppExpandableHeaderSearch({
    super.key,
    this.leadingIcon,
    required this.title,
    required this.subtitle,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.height = 44,
    this.accentColor = const Color(0xFF26C6B0),
    this.leadingBackgroundColor = const Color(0xFFD9F5F1),
    this.titleColor = const Color(0xFF2D3748),
    this.subtitleColor = const Color(0xFFA0AEC0),
    this.surfaceColor = Colors.white,
    this.fieldColor = const Color(0xFFF7F8FA),
    this.borderColor = const Color(0xFFEDF2F7),
    this.iconColor = const Color(0xFFA0AEC0),
    this.textColor = const Color(0xFF2D3748),
    this.controller,
    this.focusNode,
  });

  @override
  State<AppExpandableHeaderSearch> createState() =>
      _AppExpandableHeaderSearchState();
}

class _AppExpandableHeaderSearchState
    extends State<AppExpandableHeaderSearch> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isExpanded = false;

  bool get _ownsController => widget.controller == null;
  bool get _ownsFocusNode => widget.focusNode == null;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _expand() {
    if (_isExpanded) return;
    setState(() => _isExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  void _collapse() {
    _controller.clear();
    widget.onChanged?.call('');
    _focusNode.unfocus();
    setState(() => _isExpanded = false);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        final isNarrow = width < 220;
        final isMedium = width >= 220 && width < 340;
        final isWide = width >= 340;

        final iconBoxSize = widget.height;
        final searchButtonSize = widget.height;

        final showSubtitle = !isNarrow;
        final titleAreaRightPadding = searchButtonSize + (isNarrow ? 6 : 12);

        final titleFontSize = isNarrow
            ? 13.0
            : isMedium
                ? 14.0
                : 16.0;
        final subtitleFontSize = isNarrow
            ? 10.0
            : isMedium
                ? 10.5
                : 11.0;

        return ColoredBox(
          color: widget.surfaceColor,
          child: SizedBox(
            height: widget.height,
            child: ClipRect(
              child: Stack(
                alignment: Alignment.centerRight,
                children: [
                  // ── Title area ────────────────────────────────────────
                  AnimatedOpacity(
                    duration: const Duration(milliseconds: 140),
                    opacity: _isExpanded ? 0 : 1,
                    child: IgnorePointer(
                      ignoring: _isExpanded,
                      child: Padding(
                        padding: EdgeInsets.only(right: titleAreaRightPadding),
                        child: _HeaderTitle(
                          height: iconBoxSize,
                          leadingIcon: widget.leadingIcon,
                          leadingBackgroundColor: widget.leadingBackgroundColor,
                          accentColor: widget.accentColor,
                          title: widget.title,
                          subtitle: widget.subtitle,
                          titleColor: widget.titleColor,
                          subtitleColor: widget.subtitleColor,
                          showSubtitle: showSubtitle,
                          titleFontSize: titleFontSize,
                          subtitleFontSize: subtitleFontSize,
                          showLeadingIcon: widget.leadingIcon != null && isWide,
                        ),
                      ),
                    ),
                  ),

                  // ── Search surface ─────────────────────────────────────
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: _isExpanded ? width : searchButtonSize,
                    child: _SearchSurface(
                      controller: _controller,
                      focusNode: _focusNode,
                      expanded: _isExpanded,
                      hintText: widget.hintText,
                      height: widget.height,
                      accentColor: widget.accentColor,
                      fieldColor: widget.fieldColor,
                      borderColor: widget.borderColor,
                      iconColor: widget.iconColor,
                      textColor: widget.textColor,
                      onTap: _expand,
                      onClose: _collapse,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeaderTitle
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderTitle extends StatelessWidget {
  final double height;
  final IconData? leadingIcon;
  final bool showLeadingIcon;
  final Color leadingBackgroundColor;
  final Color accentColor;
  final String title;
  final String subtitle;
  final Color titleColor;
  final Color subtitleColor;
  final bool showSubtitle;
  final double titleFontSize;
  final double subtitleFontSize;

  const _HeaderTitle({
    required this.height,
    required this.leadingIcon,
    required this.showLeadingIcon,
    required this.leadingBackgroundColor,
    required this.accentColor,
    required this.title,
    required this.subtitle,
    required this.titleColor,
    required this.subtitleColor,
    required this.showSubtitle,
    required this.titleFontSize,
    required this.subtitleFontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (showLeadingIcon && leadingIcon != null) ...[
          Container(
            width: height,
            height: height,
            decoration: BoxDecoration(
              color: leadingBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(leadingIcon, color: accentColor, size: 18),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              if (showSubtitle) ...[
                const SizedBox(height: 1),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: subtitleFontSize,
                    color: subtitleColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SearchSurface
// ─────────────────────────────────────────────────────────────────────────────

class _SearchSurface extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool expanded;
  final String hintText;
  final double height;
  final Color accentColor;
  final Color fieldColor;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final VoidCallback onTap;
  final VoidCallback onClose;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const _SearchSurface({
    required this.controller,
    required this.focusNode,
    required this.expanded,
    required this.hintText,
    required this.height,
    required this.accentColor,
    required this.fieldColor,
    required this.borderColor,
    required this.iconColor,
    required this.textColor,
    required this.onTap,
    required this.onClose,
    required this.onChanged,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final searchIconSize = height < 40 ? 15.0 : 17.0;
    final closeIconSize = height < 40 ? 16.0 : 18.0;

    return Material(
      color: fieldColor,
      borderRadius: BorderRadius.circular(10),
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: expanded ? null : onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: expanded ? accentColor : borderColor,
            ),
          ),
          // ── LayoutBuilder reads the ACTUAL rendered width on every
          //    animation frame — this is the key fix. AnimatedPositioned
          //    tweens the layout constraints each frame, so LayoutBuilder
          //    always has the true current width, unlike a passed-in value
          //    which is only a snapshot from the last setState.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final actualWidth = constraints.maxWidth;
              final hPadding = actualWidth < 260 ? 8.0 : 11.0;
              final textFontSize = actualWidth < 260 ? 12.0 : 13.0;

              // Only show the expanded row when there is genuinely enough
              // room — this prevents the RenderFlex overflow that occurs
              // while the surface is still narrow mid-animation.
              final showExpandedContent = expanded && actualWidth >= 120.0;

              if (!showExpandedContent) {
                return Center(
                  child: Icon(
                    Icons.search_rounded,
                    color: accentColor,
                    size: height * 0.43,
                  ),
                );
              }

              return Row(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPadding),
                    child: Icon(
                      Icons.search_rounded,
                      color: iconColor,
                      size: searchIconSize,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onChanged: onChanged,
                      onSubmitted: onSubmitted,
                      style: TextStyle(
                        fontSize: textFontSize,
                        color: textColor,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: hintText,
                        hintStyle: TextStyle(
                          fontSize: textFontSize,
                          color: iconColor,
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: height,
                    height: height,
                    child: IconButton(
                      tooltip: 'Close search',
                      padding: EdgeInsets.zero,
                      onPressed: onClose,
                      icon: Icon(
                        Icons.close_rounded,
                        color: iconColor,
                        size: closeIconSize,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}