import 'package:flutter/material.dart';

/// Default placeholder filling an ad's reserved space while the ad loads.
///
/// Uses the app's color scheme, holds still when the platform asks for reduced
/// motion, and pauses with [TickerMode] like any other animation.
class AdLoadingShimmer extends StatefulWidget {
  final BorderRadius borderRadius;

  const AdLoadingShimmer({super.key, this.borderRadius = BorderRadius.zero});

  @override
  State<AdLoadingShimmer> createState() => _AdLoadingShimmerState();
}

class _AdLoadingShimmerState extends State<AdLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = colors.surfaceContainerHighest;
    final label = Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Loading ad',
            style: theme.textTheme.labelSmall?.copyWith(
              color: colors.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
    return Semantics(
      label: 'Loading ad',
      container: true,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: widget.borderRadius,
        child: MediaQuery.disableAnimationsOf(context)
            ? ColoredBox(color: base, child: label)
            : AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [base, colors.surfaceContainerLow, base],
                      stops: const [0.35, 0.5, 0.65],
                      transform: _SlideGradient(_controller.value * 2 - 1),
                    ),
                  ),
                  child: child,
                ),
                child: label,
              ),
      ),
    );
  }
}

class _SlideGradient extends GradientTransform {
  final double offset;

  const _SlideGradient(this.offset);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) =>
      Matrix4.translationValues(bounds.width * offset, 0, 0);
}
