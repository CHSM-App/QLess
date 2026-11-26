import 'package:flutter/material.dart';

// Loading placeholders. Same look as the screens' private _Shimmer widgets
// (1100 ms fade 0.4 ↔ 1.0, #E2E8F0 boxes), but one animation drives a whole
// layout: wrap [SkeletonBox]es in a single [SkeletonPulse].

const _kSkeletonColor = Color(0xFFE2E8F0);

class SkeletonPulse extends StatefulWidget {
  final Widget child;
  const SkeletonPulse({super.key, required this.child});

  @override
  State<SkeletonPulse> createState() => _SkeletonPulseState();
}

class _SkeletonPulseState extends State<SkeletonPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);
  late final Animation<double> _opacity = Tween<double>(begin: 0.4, end: 1.0)
      .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: FadeTransition(opacity: _opacity, child: widget.child),
      );
}

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  const SkeletonBox({super.key, this.width, required this.height, this.radius = 8});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: _kSkeletonColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

/// A list of card placeholders (leading block + two text lines) — the shape
/// of most list screens in the app.
class SkeletonList extends StatelessWidget {
  final int count;
  final EdgeInsetsGeometry padding;
  const SkeletonList({
    super.key,
    this.count = 6,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 24),
  });

  @override
  Widget build(BuildContext context) => SkeletonPulse(
        child: ListView.separated(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          itemCount: count,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, __) => Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEDF2F7)),
            ),
            child: const Row(children: [
              SkeletonBox(width: 40, height: 40, radius: 10),
              SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  SkeletonBox(width: 140, height: 12),
                  SizedBox(height: 8),
                  SkeletonBox(width: 90, height: 10),
                ]),
              ),
            ]),
          ),
        ),
      );
}

/// Stacked blocks of the given heights — for detail pages (a header card,
/// sections, …) where a list shape would look wrong.
class SkeletonBlocks extends StatelessWidget {
  final List<double> heights;
  final EdgeInsetsGeometry padding;
  const SkeletonBlocks({
    super.key,
    required this.heights,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 24),
  });

  @override
  Widget build(BuildContext context) => SkeletonPulse(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: padding,
          children: [
            for (var i = 0; i < heights.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              SkeletonBox(height: heights[i], radius: 12),
            ],
          ],
        ),
      );
}
