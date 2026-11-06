import 'dart:math';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../theme.dart';

/// Frosted surface for things that float over content: the menu, top bars,
/// controls on photos and videos.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.radius = 22,
    this.dark = false,
    this.shadow = false,
    this.tint,
  });
  final Widget child;
  final double radius;
  final bool dark;
  final bool shadow;

  /// Overrides the background (for the frost itself keep some transparency).
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final shape = BorderRadius.circular(radius);
    final dark = this.dark || AppColors.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: shape,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: dark ? .35 : .13),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: shape,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            decoration: BoxDecoration(
              color:
                  tint ??
                  (dark
                      ? const Color(0xB82C2C2E)
                      : Colors.white.withValues(alpha: .74)),
              borderRadius: shape,
              border: Border.all(
                color: Colors.white.withValues(alpha: dark ? .1 : .6),
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// The body of a glossy bubble: lit from the top left, falling into shadow.
BoxDecoration orbBody(Color c, {bool shadow = false, double glow = 0}) {
  return BoxDecoration(
    shape: BoxShape.circle,
    gradient: RadialGradient(
      center: const Alignment(0, .18),
      radius: .82,
      colors: [
        Color.lerp(c, Colors.white, .32)!,
        c,
        Color.lerp(c, Colors.black, .62)!,
      ],
      stops: const [0, .68, 1],
    ),
    boxShadow: [
      if (shadow)
        BoxShadow(
          color: Color.lerp(c, Colors.black, .45)!.withValues(alpha: .32),
          blurRadius: 18,
          offset: const Offset(0, 10),
        ),
      if (glow > 0)
        BoxShadow(
          color: c.withValues(alpha: .34),
          blurRadius: glow,
          offset: const Offset(0, 12),
        ),
    ],
  );
}

/// The reflection on top of a bubble.
const orbShine = BoxDecoration(
  shape: BoxShape.circle,
  gradient: RadialGradient(
    center: Alignment(-.34, -.5),
    radius: .52,
    colors: [Color(0xE6FFFFFF), Color(0x00FFFFFF)],
  ),
);

/// A glossy sphere with no person in it, used as a hero object.
class Orb extends StatelessWidget {
  const Orb({
    super.key,
    required this.color,
    required this.diameter,
    this.glow = 0,
  });
  final Color color;
  final double diameter;
  final double glow;

  @override
  Widget build(BuildContext context) => Container(
    width: diameter,
    height: diameter,
    decoration: orbBody(color, glow: glow),
    foregroundDecoration: orbShine,
  );
}

/// Slow up-and-down drift. Bubbles feel alive without calling for attention.
class Floaty extends StatefulWidget {
  const Floaty({
    super.key,
    required this.child,
    this.distance = 6,
    this.seconds = 5,
    this.phase = 0,
  });
  final Widget child;
  final double distance;
  final int seconds;
  final double phase;

  @override
  State<Floaty> createState() => _FloatyState();
}

class _FloatyState extends State<Floaty> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: Duration(seconds: widget.seconds),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.stop();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _clock,
        child: widget.child,
        builder: (context, child) => Transform.translate(
          offset: Offset(
            0,
            sin((_clock.value + widget.phase) * 2 * pi) * widget.distance,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// "Reply ›": the app's text link. Works on light and dark grounds.
class TextLink extends StatelessWidget {
  const TextLink({
    super.key,
    required this.label,
    required this.onTap,
    this.dark = false,
    this.size = 16,
    this.chevron = true,
  });
  final String label;
  final VoidCallback onTap;
  final bool dark;
  final double size;
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        highlightShape: BoxShape.rectangle,
        radius: 0,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: Text(
              chevron ? '$label ›' : label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx(
                size,
                color: dark ? AppColors.nightLink : AppColors.link,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
