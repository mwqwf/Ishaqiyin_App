import 'package:flutter/material.dart';

/// Simple shimmer placeholder for loading states.
class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;
  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            color: Theme.of(context)
                .colorScheme
                .surfaceContainerHighest
                .withValues(alpha: 0.4 + _ctrl.value * 0.3),
          ),
        );
      },
    );
  }
}

class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        SkeletonBox(width: 140, height: 22),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SkeletonBox(
                width: double.infinity,
                height: 96,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SkeletonBox(
                width: double.infinity,
                height: 96,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
            SizedBox(width: 10),
            Expanded(
              child: SkeletonBox(
                width: double.infinity,
                height: 96,
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
            ),
          ],
        ),
        SizedBox(height: 24),
        SkeletonBox(width: 120, height: 22),
        SizedBox(height: 12),
        SkeletonBox(width: double.infinity, height: 72),
        SizedBox(height: 8),
        SkeletonBox(width: double.infinity, height: 72),
      ],
    );
  }
}
