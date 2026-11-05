import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import 'avatar.dart';

/// The free-floating friends area of the chat home.
///
/// * Bubbles float gently and push each other apart.
/// * Drag a bubble anywhere to rearrange it.
/// * Drop it ON another bubble to merge them into a group (or add to a group).
/// * Tap opens the chat, long-press a group opens its options.
class BubbleField extends StatefulWidget {
  const BubbleField({
    super.key,
    required this.store,
    required this.onOpen,
    required this.onLongPress,
    required this.onMerged,
  });

  final ChatStore store;
  final void Function(BubbleNode node) onOpen;
  final void Function(BubbleNode node) onLongPress;
  final void Function(
    BubbleNode group,
    bool created,
    BubbleNode dragged,
    BubbleNode target,
  )
  onMerged;

  @override
  State<BubbleField> createState() => _BubbleFieldState();
}

class _BubbleFieldState extends State<BubbleField>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  Size _size = Size.zero;

  BubbleNode? _dragging;
  BubbleNode? _hover;
  Offset _grab = Offset.zero;

  static const _labelSpace = 18.0; // room under each bubble for the name
  static const _gap = 10.0;

  List<BubbleNode> get _nodes => widget.store.nodes;
  double get _s => _size.width / 430; // Figma frame width -> screen scale
  double _r(BubbleNode n) => n.radius * _s;

  /// Minimum center distance between two bubbles; vertical neighbours need
  /// extra room for the name label under the upper bubble.
  double _minDist(BubbleNode a, BubbleNode b, Offset dir) {
    final dist = dir.distance;
    final vertical = dist < 0.001 ? 1.0 : (dir.dy.abs() / dist);
    return _r(a) + _r(b) + (_gap + _labelSpace * vertical) * _s;
  }

  Offset _homePx(BubbleNode n) =>
      Offset(n.home.dx * _size.width, n.home.dy * _size.height);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- physics
  void _tick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 30);
    _last = elapsed;
    _time += dt;
    if (_size.isEmpty) return;

    for (final n in _nodes) {
      if (n.pos == null) _place(n);
      n.spawn = min(1, n.spawn + dt * 1.8);
      if (identical(n, _dragging)) continue;
      // Spring towards the resting spot + damping.
      final f = (_homePx(n) - n.pos!) * 30;
      n.vel = (n.vel + f * dt) * pow(0.0008, dt).toDouble();
      n.pos = n.pos! + n.vel * dt;
    }

    // Keep bubbles from overlapping.
    for (var i = 0; i < _nodes.length; i++) {
      for (var j = i + 1; j < _nodes.length; j++) {
        final a = _nodes[i], b = _nodes[j];
        // The bubble under the finger never pushes others away, otherwise
        // the one you aim for would run off before you can drop onto it.
        if (identical(a, _dragging) || identical(b, _dragging)) continue;
        final d = b.pos! - a.pos!;
        final dist = d.distance;
        final minD = _minDist(a, b, d);
        if (dist >= minD || dist < 0.001) continue;
        final push = d / dist * (minD - dist) * 0.35;
        a.pos = a.pos! - push;
        b.pos = b.pos! + push;
      }
    }
    for (final n in _nodes) {
      n.pos = _clamp(n.pos!, _r(n));
    }
    setState(() {});
  }

  Offset _clamp(Offset p, double r) => Offset(
    p.dx.clamp(r, max(r, _size.width - r)),
    p.dy.clamp(r, max(r, _size.height - r - _labelSpace * _s)),
  );

  /// Gives a new bubble a free resting spot near its requested home.
  void _place(BubbleNode n, {Offset? near}) {
    final spot = _freeSpot(near ?? _homePx(n), n);
    n.home = Offset(spot.dx / _size.width, spot.dy / _size.height);
    n.pos ??= spot;
  }

  Offset _freeSpot(Offset near, BubbleNode self) {
    final r = _r(self);
    for (var ring = 0; ring < 40; ring++) {
      final steps = ring == 0 ? 1 : 10 + ring * 2;
      for (var k = 0; k < steps; k++) {
        final c = _clamp(
          near + Offset.fromDirection(k * 2 * pi / steps, ring * 9.0 * _s),
          r,
        );
        final free = _nodes.every(
          (o) =>
              identical(o, self) ||
              o.pos == null ||
              (c - _homePx(o)).distance >= _minDist(self, o, c - _homePx(o)),
        );
        if (free) return c;
      }
    }
    return _clamp(near, r);
  }

  // --------------------------------------------------------------- gestures
  BubbleNode? _hit(Offset p) {
    for (final n in _nodes.reversed) {
      if (n.pos != null && (p - n.pos!).distance <= _r(n) + 4) return n;
    }
    return null;
  }

  void _onPanStart(DragStartDetails d) {
    final n = _hit(d.localPosition);
    if (n == null) return;
    _dragging = n;
    _grab = n.pos! - d.localPosition;
    _nodes
      ..remove(n)
      ..add(n); // draw on top
    HapticFeedback.selectionClick();
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final n = _dragging;
    if (n == null) return;
    n.pos = d.localPosition + _grab;
    n.vel = Offset.zero;
    BubbleNode? best;
    var bestDist = double.infinity;
    for (final o in _nodes) {
      if (identical(o, n) || o.pos == null || !widget.store.canMerge(n, o)) {
        continue;
      }
      final dist = (o.pos! - n.pos!).distance;
      if (dist < _r(o) + _r(n) * .55 && dist < bestDist) {
        best = o;
        bestDist = dist;
      }
    }
    if (!identical(best, _hover)) {
      _hover = best;
      if (best != null) HapticFeedback.lightImpact();
    }
  }

  void _onPanEnd([DragEndDetails? _]) {
    final n = _dragging, target = _hover;
    _dragging = null;
    _hover = null;
    if (n == null) return;

    if (target != null) {
      HapticFeedback.mediumImpact();
      final result = widget.store.merge(n, target);
      final group = result.group;
      if (result.created) {
        // New group pops out of the merge point; the dragged friend floats home.
        group.pos = target.pos;
        _place(group, near: target.pos);
      } else {
        group.pos ??= target.pos;
        _place(group, near: group.pos);
      }
      _relocateOverlapping(group);
      widget.onMerged(group, result.created, n, target);
    } else {
      // Plain drop: this becomes the bubble's new resting spot.
      final p = _clamp(n.pos!, _r(n));
      n.home = Offset(p.dx / _size.width, p.dy / _size.height);
      _relocateOverlapping(n);
    }
  }

  /// Other bubbles whose resting spot collides with [n] move to a free spot.
  void _relocateOverlapping(BubbleNode n) {
    for (final o in _nodes) {
      if (identical(o, n) || o.pos == null) continue;
      final d = _homePx(o) - _homePx(n);
      if (d.distance < _minDist(o, n, d)) {
        _place(o, near: _homePx(o));
      }
    }
  }

  // ------------------------------------------------------------------ build
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        _size = c.biggest;
        return RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
                  () => TapGestureRecognizer(debugOwner: this),
                  (r) => r.onTapUp = (d) {
                    final n = _hit(d.localPosition);
                    if (n != null) widget.onOpen(n);
                  },
                ),
            LongPressGestureRecognizer:
                GestureRecognizerFactoryWithHandlers<
                  LongPressGestureRecognizer
                >(
                  () => LongPressGestureRecognizer(debugOwner: this),
                  (r) => r.onLongPressStart = (d) {
                    final n = _hit(d.localPosition);
                    if (n != null) {
                      HapticFeedback.heavyImpact();
                      widget.onLongPress(n);
                    }
                  },
                ),
            // Only claims drags that start ON a bubble, so swiping on empty
            // space still changes page (chats <-> map).
            _BubblePanRecognizer:
                GestureRecognizerFactoryWithHandlers<_BubblePanRecognizer>(
                  () => _BubblePanRecognizer(
                    isOnBubble: (p) => _hit(p) != null,
                    debugOwner: this,
                  ),
                  (r) => r
                    ..onStart = _onPanStart
                    ..onUpdate = _onPanUpdate
                    ..onEnd = _onPanEnd
                    ..onCancel = _onPanEnd,
                ),
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              for (final n in _nodes)
                if (n.pos != null) _bubble(n),
            ],
          ),
        );
      },
    );
  }

  Widget _bubble(BubbleNode n) {
    final r = _r(n);
    final dragging = identical(n, _dragging);
    final target = identical(n, _hover);
    final pop = Curves.elasticOut.transform(n.spawn.clamp(0.0, 1.0));
    final scale = (0.3 + 0.7 * pop) * (target ? 1.14 : (dragging ? 1.08 : 1.0));
    final bob = dragging
        ? Offset.zero
        : Offset(sin(_time * .9 + n.phase), cos(_time * .7 + n.phase * 1.3)) *
              2.5 *
              _s;
    final center = n.pos! + bob;
    final labelSize = (n.radius >= 45 ? 15.0 : 9.0) * _s;
    final width = max(r * 2, 120 * _s);

    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - r,
      width: width,
      child: IgnorePointer(
        child: Opacity(
          // See-through while hovering a target so its green highlight shows.
          opacity: dragging && _hover != null ? .6 : 1,
          child: Transform.scale(
            scale: scale,
            alignment: Alignment(0, -1 + 2 * r / (2 * r + labelSize * 1.6)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: r * 2,
                  height: r * 2,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.bubble,
                          border: target
                              ? Border.all(
                                  color: AppColors.mergeTarget,
                                  width: 3 * _s,
                                )
                              : (n.storyRing
                                    ? Border.all(
                                        color: AppColors.storyRing,
                                        width: 3 * _s,
                                      )
                                    : null),
                          boxShadow: [
                            if (dragging)
                              BoxShadow(
                                color: Colors.black.withValues(alpha: .18),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            if (target)
                              BoxShadow(
                                color: AppColors.mergeTarget.withValues(
                                  alpha: .35,
                                ),
                                blurRadius: 22,
                                spreadRadius: 2,
                              ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: n.isGroup
                            ? GroupAvatar(n.members, diameter: r * 1.75)
                            : PersonAvatar(
                                n.members.first,
                                diameter: r * (n.storyRing ? 1.55 : 1.62),
                              ),
                      ),
                      if (target)
                        Positioned.fill(
                          child: Center(
                            child: Container(
                              width: r * .7,
                              height: r * .7,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.mergeTarget.withValues(
                                  alpha: .9,
                                ),
                              ),
                              child: Icon(
                                Icons.group_add_rounded,
                                color: Colors.white,
                                size: r * .4,
                              ),
                            ),
                          ),
                        ),
                      if (n.unread > 0)
                        Positioned(
                          right: -r * .1,
                          top: r * .55,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 9 * _s,
                              vertical: 3 * _s,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.badge,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${n.unread}',
                              style: tx(13 * _s, weight: FontWeight.w700),
                            ),
                          ),
                        ),
                      if (n.tag != null)
                        Positioned(
                          right: -r * .02,
                          top: r * .05,
                          child: Container(
                            width: 30 * _s,
                            height: 30 * _s,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.bubble,
                            ),
                            child: Icon(n.tag, size: 17 * _s),
                          ),
                        ),
                      if (n.isGroup)
                        Positioned(
                          right: -r * .02,
                          bottom: r * .1,
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 6 * _s,
                              vertical: 2 * _s,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.ink,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${n.members.length}',
                              style: tx(
                                10 * _s,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(height: 3 * _s),
                Text(
                  n.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: tx(labelSize, weight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BubblePanRecognizer extends PanGestureRecognizer {
  _BubblePanRecognizer({required this.isOnBubble, super.debugOwner});
  final bool Function(Offset localPosition) isOnBubble;

  @override
  bool isPointerAllowed(PointerEvent event) =>
      isOnBubble(event.localPosition) && super.isPointerAllowed(event);
}
