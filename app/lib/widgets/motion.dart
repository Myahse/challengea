import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared motion: one feel across the app. Things arrive quickly and settle
/// slowly, with a long soft tail and no bounce.
class Motion {
  static const fast = Duration(milliseconds: 200);
  static const normal = Duration(milliseconds: 380);
  static const slow = Duration(milliseconds: 800);
  static const ease = Cubic(.16, 1, .3, 1);
  static const spring = Cubic(.2, 1.1, .3, 1);
}

/// Sinks a little while pressed and settles back: makes anything feel tappable.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = .96,
    this.haptic = true,
  });
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.selectionClick();
              widget.onTap!();
            },
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down
            ? const Duration(milliseconds: 110)
            : const Duration(milliseconds: 420),
        curve: _down ? Curves.easeOut : Motion.ease,
        child: widget.child,
      ),
    );
  }
}

/// Fades and slides its child in once, after [delay] (use index * 60 ms to stagger lists).
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = const Offset(0, 28),
    this.duration = Motion.slow,
    this.scale = 1,
  });
  final Widget child;
  final Duration delay;
  final Offset offset;
  final Duration duration;

  /// Starting scale (e.g. .9 for a small "pop").
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    final total = delay + duration;
    final start = total.inMicroseconds == 0
        ? 0.0
        : delay.inMicroseconds / total.inMicroseconds;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: total,
      builder: (context, v, child) {
        final t = Motion.ease.transform(
          ((v - start) / (1 - start)).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: offset * (1 - t),
            child: Transform.scale(
              scale: scale + (1 - scale) * t,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }
}

/// Page transition for every screen: the new page slides in a little and
/// fades; the page underneath pulls back slightly.
class SmoothPageTransitions extends PageTransitionsBuilder {
  const SmoothPageTransitions();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 520);

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final inCurve = CurvedAnimation(
      parent: animation,
      curve: Motion.ease,
      reverseCurve: Curves.easeInCubic,
    );
    final outCurve = CurvedAnimation(
      parent: secondaryAnimation,
      curve: Motion.ease,
    );
    return AnimatedBuilder(
      animation: Listenable.merge([inCurve, outCurve]),
      child: child,
      builder: (context, child) {
        final i = inCurve.value, o = outCurve.value;
        return Transform.translate(
          offset: Offset((1 - i) * 44, 0),
          child: Transform.scale(
            scale: 1 - .04 * o,
            child: Opacity(
              opacity: (i * (1 - .4 * o)).clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Animates a number counting up (followers, likes...).
class CountUp extends StatelessWidget {
  const CountUp({
    super.key,
    required this.value,
    required this.format,
    this.style,
  });
  final int value;
  final String Function(int) format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: const Duration(milliseconds: 1100),
    curve: Motion.ease,
    builder: (context, v, _) => Text(format(v.round()), style: style),
  );
}
