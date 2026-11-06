import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models.dart';
import '../theme.dart';
import 'avatar.dart';
import 'motion.dart';

/// Little bubbles bursting out of a point. The app's "that worked!".
class Burst {
  Burst._();

  /// From the middle of the widget that owns [context].
  static void on(
    BuildContext context, {
    List<Color>? colors,
    int count = 12,
    double spread = 80,
    String? emoji,
  }) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    at(
      context,
      box.localToGlobal(box.size.center(Offset.zero)),
      colors: colors,
      count: count,
      spread: spread,
      emoji: emoji,
    );
  }

  static void at(
    BuildContext context,
    Offset center, {
    List<Color>? colors,
    int count = 12,
    double spread = 80,
    String? emoji,
  }) {
    if (MediaQuery.disableAnimationsOf(context)) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BurstLayer(
        center: center,
        colors: colors ?? [AppColors.accent, const Color(0xFF7DB8FF)],
        count: count,
        spread: spread,
        emoji: emoji,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  /// A big one, for winning.
  static void victory(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final rnd = Random();
    const colors = [
      Color(0xFF0A84FF),
      Color(0xFFFF5C8A),
      Color(0xFFFFC53D),
      Color(0xFF34C759),
    ];
    HapticFeedback.heavyImpact();
    for (var i = 0; i < 5; i++) {
      Future.delayed(Duration(milliseconds: 170 * i), () {
        if (!context.mounted) return;
        at(
          context,
          Offset(
            size.width * (.15 + rnd.nextDouble() * .7),
            size.height * (.2 + rnd.nextDouble() * .4),
          ),
          colors: colors,
          count: 22,
          spread: 170,
        );
      });
    }
  }
}

class _Particle {
  _Particle(Random r, this.color)
    : angle = r.nextDouble() * 2 * pi,
      speed = .45 + r.nextDouble() * .55,
      size = 3 + r.nextDouble() * 6,
      lag = r.nextDouble() * .12;
  final double angle, speed, size, lag;
  final Color color;
}

class _BurstLayer extends StatefulWidget {
  const _BurstLayer({
    required this.center,
    required this.colors,
    required this.count,
    required this.spread,
    required this.onDone,
    this.emoji,
  });
  final Offset center;
  final List<Color> colors;
  final int count;
  final double spread;
  final String? emoji;
  final VoidCallback onDone;

  @override
  State<_BurstLayer> createState() => _BurstLayerState();
}

class _BurstLayerState extends State<_BurstLayer>
    with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 850),
  );
  late final List<_Particle> _particles;

  @override
  void initState() {
    super.initState();
    final r = Random();
    _particles = [
      for (var i = 0; i < widget.count; i++)
        _Particle(r, widget.colors[i % widget.colors.length]),
    ];
    _clock.forward().whenComplete(() {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _BurstPainter(
            _clock,
            widget.center,
            _particles,
            widget.spread,
            widget.emoji,
          ),
        ),
      ),
    );
  }
}

class _BurstPainter extends CustomPainter {
  _BurstPainter(this.t, this.center, this.particles, this.spread, this.emoji)
    : super(repaint: t);
  final Animation<double> t;
  final Offset center;
  final List<_Particle> particles;
  final double spread;
  final String? emoji;

  @override
  void paint(Canvas canvas, Size size) {
    final v = t.value;
    // Shock ring.
    final ring = Curves.easeOutCubic.transform((v / .55).clamp(0.0, 1.0));
    if (ring < 1) {
      canvas.drawCircle(
        center,
        spread * .75 * ring,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1 - ring) + .5
          ..color = particles.first.color.withValues(alpha: .55 * (1 - ring)),
      );
    }
    for (final p in particles) {
      final local = ((v - p.lag) / (1 - p.lag)).clamp(0.0, 1.0);
      final out = Curves.easeOutCubic.transform(local);
      final fall = local * local * 46; // they drift down at the end
      final at =
          center +
          Offset(cos(p.angle), sin(p.angle)) * spread * p.speed * out +
          Offset(0, fall);
      final r = p.size * (1 - Curves.easeIn.transform(local));
      if (r <= .1) continue;
      canvas.drawCircle(at, r, Paint()..color = p.color);
      canvas.drawCircle(
        at - Offset(r * .3, r * .35),
        r * .32,
        Paint()..color = Colors.white.withValues(alpha: .8),
      );
    }
    if (emoji != null) {
      final rise = Curves.easeOutCubic.transform(v);
      final text = TextPainter(
        text: TextSpan(
          text: emoji,
          style: TextStyle(fontSize: 26 + 26 * rise),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.saveLayer(
        Rect.fromCircle(center: center, radius: 200),
        Paint()
          ..color = Colors.white.withValues(
            alpha: (1 - Curves.easeInCubic.transform(v)).clamp(0.0, 1.0),
          ),
      );
      text.paint(
        canvas,
        center - Offset(text.width / 2, text.height / 2 + 90 * rise),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => false;
}

/// Two people's bubbles fly in from the edges, collide and fuse, and the
/// words appear. For the moments that deserve the whole screen.
Future<void> showMeet(
  BuildContext context, {
  required Person a,
  required Person b,
  required String title,
  String? subtitle,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null || MediaQuery.disableAnimationsOf(context)) {
    return Future.value();
  }
  final done = Completer<void>();
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Meet(
      a: a,
      b: b,
      title: title,
      subtitle: subtitle,
      onDone: () {
        entry.remove();
        done.complete();
      },
    ),
  );
  overlay.insert(entry);
  return done.future;
}

class _Meet extends StatefulWidget {
  const _Meet({
    required this.a,
    required this.b,
    required this.title,
    required this.onDone,
    this.subtitle,
  });
  final Person a, b;
  final String title;
  final String? subtitle;
  final VoidCallback onDone;

  @override
  State<_Meet> createState() => _MeetState();
}

class _MeetState extends State<_Meet> with SingleTickerProviderStateMixin {
  static const _impact = .3;
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  bool _hit = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _clock.addListener(() {
      if (!_hit && _clock.value >= _impact) {
        _hit = true;
        HapticFeedback.heavyImpact();
      }
    });
    _clock.forward().whenComplete(_close);
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    widget.onDone();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double _span(double from, double to, [Curve curve = Curves.linear]) =>
      curve.transform(((_clock.value - from) / (to - from)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    const size = 128.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _close,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final fade = _span(0, .1) * (1 - _span(.9, 1));
            final fly = _span(0, _impact, Curves.easeInCubic);
            // After the hit they recoil a little, then rest overlapping.
            final recoil = _span(_impact, .52, Motion.spring);
            final rest = size * .36;
            final gap = _hit
                ? rest + (1 - recoil) * -size * .22
                : (width / 2 + size) * (1 - fly) + rest * fly;
            final squash = _hit ? 1 + .22 * (1 - recoil) : 1.0;
            final ring = _span(_impact, .68, Curves.easeOutCubic);
            final words = _span(.42, .6, Motion.ease);
            final centerColor = Color.lerp(widget.a.color, widget.b.color, .5)!;
            return Opacity(
              opacity: fade,
              child: ColoredBox(
                color: Colors.black.withValues(alpha: .86),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 240,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          if (_hit)
                            Container(
                              width: 120 + 340 * ring,
                              height: 120 + 340 * ring,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: .55 * (1 - ring),
                                  ),
                                  width: 2,
                                ),
                                color: centerColor.withValues(
                                  alpha: .22 * (1 - ring),
                                ),
                              ),
                            ),
                          for (final (person, side) in [
                            (widget.a, -1.0),
                            (widget.b, 1.0),
                          ])
                            Transform.translate(
                              offset: Offset(side * gap, 0),
                              child: Transform.scale(
                                scaleX: 1 / squash,
                                scaleY: squash,
                                child: PersonAvatar(person, diameter: size),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Opacity(
                      opacity: words,
                      child: Transform.translate(
                        offset: Offset(0, 24 * (1 - words)),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Column(
                            children: [
                              Text(
                                widget.title,
                                textAlign: TextAlign.center,
                                style: tx(
                                  40,
                                  weight: FontWeight.w600,
                                  color: AppColors.nightInk,
                                ),
                              ),
                              if (widget.subtitle != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  widget.subtitle!,
                                  textAlign: TextAlign.center,
                                  style: tx(17, color: AppColors.nightMuted),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// A button that shows its own story: the label shrinks into a spinner, a
/// check draws itself with a burst, then it settles on the new state.
class MorphButton extends StatefulWidget {
  const MorphButton({
    super.key,
    required this.label,
    required this.doneLabel,
    required this.onPressed,
    this.width = 96,
    this.doneWidth = 116,
    this.startDone = false,
  });
  final String label;
  final String doneLabel;
  final double width;
  final double doneWidth;
  final bool startDone;

  /// Returns true when it worked; false shakes the button and resets it.
  final Future<bool> Function() onPressed;

  @override
  State<MorphButton> createState() => _MorphButtonState();
}

enum _Phase { idle, busy, check, done }

class _MorphButtonState extends State<MorphButton> {
  late _Phase _phase = widget.startDone ? _Phase.done : _Phase.idle;
  int _shakes = 0;

  Future<void> _tap() async {
    if (_phase != _Phase.idle) return;
    HapticFeedback.selectionClick();
    setState(() => _phase = _Phase.busy);
    final started = DateTime.now();
    final ok = await widget.onPressed();
    // Long enough to see the button change shape, even on a fast network.
    final left =
        const Duration(milliseconds: 420) - DateTime.now().difference(started);
    if (left > Duration.zero) await Future<void>.delayed(left);
    if (!mounted) return;
    if (!ok) {
      HapticFeedback.heavyImpact();
      setState(() {
        _phase = _Phase.idle;
        _shakes++;
      });
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() => _phase = _Phase.check);
    Burst.on(context, count: 14, spread: 70);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _phase = _Phase.done);
  }

  @override
  Widget build(BuildContext context) {
    final round = _phase == _Phase.busy || _phase == _Phase.check;
    final done = _phase == _Phase.done;
    return TweenAnimationBuilder<double>(
      key: ValueKey(_shakes),
      tween: Tween(begin: _shakes == 0 ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 420),
      builder: (context, v, child) => Transform.translate(
        offset: Offset(sin(v * pi * 5) * 7 * (1 - v), 0),
        child: child,
      ),
      child: Pressable(
        onTap: _phase == _Phase.idle ? _tap : null,
        haptic: false,
        child: AnimatedContainer(
          duration: Motion.normal,
          curve: Motion.spring,
          width: round ? 44 : (done ? widget.doneWidth : widget.width),
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _phase == _Phase.check
                ? AppColors.online
                : (done ? AppColors.bubble : AppColors.accent),
            borderRadius: BorderRadius.circular(22),
          ),
          child: AnimatedSwitcher(
            duration: Motion.fast,
            child: switch (_phase) {
              _Phase.busy => const SizedBox(
                key: ValueKey('busy'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              ),
              _Phase.check => const _DrawnCheck(key: ValueKey('check')),
              _ => FittedBox(
                key: ValueKey(_phase),
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    done ? widget.doneLabel : widget.label,
                    maxLines: 1,
                    style: tx(
                      15,
                      weight: FontWeight.w500,
                      color: done ? AppColors.ink : Colors.white,
                    ),
                  ),
                ),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _DrawnCheck extends StatelessWidget {
  const _DrawnCheck({super.key});

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: const Duration(milliseconds: 360),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) =>
        CustomPaint(size: const Size(22, 22), painter: _CheckPainter(v)),
  );
}

class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size s) {
    final path = Path()
      ..moveTo(s.width * .16, s.height * .54)
      ..lineTo(s.width * .4, s.height * .78)
      ..lineTo(s.width * .86, s.height * .24);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = 3
        ..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

/// How a message lands: it grows out of the list, pushing the others up
/// smoothly. Mine shoot up from the box; theirs swing in from the side.
class MessageArrival extends StatelessWidget {
  const MessageArrival({super.key, required this.mine, required this.child});
  final bool mine;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 520),
      curve: Curves.linear,
      child: child,
      builder: (context, v, child) {
        final grow = Motion.ease.transform(v);
        final pop = Curves.easeOutBack.transform(v);
        return ClipRect(
          clipper: _NoClip(),
          child: Align(
            alignment: Alignment.bottomCenter,
            heightFactor: grow,
            child: Opacity(
              opacity: (v * 4).clamp(0.0, 1.0),
              child: Transform.translate(
                offset: mine
                    ? Offset(0, 46 * (1 - grow))
                    : Offset(-36 * (1 - grow), 8 * (1 - grow)),
                child: Transform.scale(
                  alignment: mine
                      ? Alignment.bottomRight
                      : Alignment.bottomLeft,
                  scale: .55 + .45 * pop,
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NoClip extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) => const Rect.fromLTRB(-200, -200, 2000, 2000);

  @override
  bool shouldReclip(_NoClip old) => false;
}

/// A quick-reaction emoji that shoots upward when tapped.
class EmojiShot extends StatelessWidget {
  const EmojiShot({super.key, required this.emoji, required this.onTap});
  final String emoji;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    scale: .7,
    onTap: () {
      Burst.on(context, emoji: emoji, count: 8, spread: 56);
      onTap();
    },
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Text(emoji, style: const TextStyle(fontSize: 30)),
    ),
  );
}
