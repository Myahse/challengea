import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/moments.dart';
import '../widgets/motion.dart';
import 'challenge.dart';
import 'games.dart';

/// Tap race: first to the finish line wins.
class RumbleDashScreen extends StatefulWidget {
  const RumbleDashScreen({
    super.key,
    required this.store,
    required this.friend,
    this.match,
  });
  final ChatStore store;
  final Person friend;

  /// Online match: the server counts; demo: the app plays the friend.
  final OnlineMatch? match;

  @override
  State<RumbleDashScreen> createState() => _RumbleDashScreenState();
}

class _RumbleDashScreenState extends State<RumbleDashScreen> {
  static const goal = 60;
  static const _tick = 750;
  final _rnd = Random();
  bool _ready = false; // the countdown has begun
  int _count = 3; // 3, 2, 1, then 0 = go
  int _mine = 0;
  int _theirs = 0;
  int _unsent = 0;
  bool _pressed = false;
  bool? _won; // null while racing
  bool _draw = false;
  Timer? _hold;
  Timer? _countdown;
  Timer? _friendTimer;
  Timer? _flush;

  OnlineMatch? get _m => widget.match;
  bool get _over => _won != null || _draw;

  @override
  void initState() {
    super.initState();
    _m?.addListener(_sync);
    // Online, both phones reach "Go!" at the moment the server chose.
    final startsAt = (_m?.state['startsAt'] as num?)?.toInt();
    final left = startsAt == null
        ? 0
        : startsAt - DateTime.now().millisecondsSinceEpoch;
    _hold = Timer(Duration(milliseconds: max(0, left - _tick * 3)), _begin);
  }

  void _begin() {
    if (!mounted) return;
    setState(() => _ready = true);
    _countdown = Timer.periodic(const Duration(milliseconds: _tick), (t) {
      HapticFeedback.selectionClick();
      setState(() => _count--);
      if (_count == 0) {
        t.cancel();
        _start();
      }
    });
  }

  void _start() {
    if (_m != null) {
      _flush = Timer.periodic(
        const Duration(milliseconds: 250),
        (_) => _send(),
      );
      return;
    }
    _friendTimer = Timer.periodic(const Duration(milliseconds: 170), (_) {
      if (_over) return;
      if (_rnd.nextInt(5) > 0) setState(() => _theirs++);
      if (_theirs >= goal) _finishDemo(false);
    });
  }

  void _send() {
    final n = min(_unsent, 20);
    if (n == 0 || _m == null || _over) return;
    _unsent -= n;
    widget.store.online?.move(_m!, {'taps': n});
  }

  int _tapsOf(int id) {
    final players = _m!.state['players'] as Map?;
    final p = players?['$id'] as Map?;
    return (p?['taps'] as num?)?.toInt() ?? 0;
  }

  void _sync() {
    final m = _m!;
    final online = widget.store.online!;
    if (!mounted) return;
    setState(() {
      _mine = max(_mine, _tapsOf(online.myId));
      // Answers can arrive out of order: runners only move forward.
      _theirs = max(_theirs, _tapsOf(online.idOf(widget.friend)));
    });
    if (m.finished && !_over) {
      setState(() {
        _draw = m.winnerId == null;
        if (!_draw) _won = m.winnerId == online.myId;
      });
      if (_won == true) Burst.victory(context);
    }
  }

  void _finishDemo(bool won) {
    if (_over) return;
    setState(() => _won = won);
    if (won) Burst.victory(context);
    final f = widget.friend.firstName;
    postResult(
      widget.store,
      widget.friend,
      rumbleDash,
      won ? '🏁 I beat $f at Rumble dash' : '🏁 $f beat me at Rumble dash',
      won: won,
    );
  }

  void _tap() {
    if (_count > 0 || _over || _mine >= goal) return;
    HapticFeedback.lightImpact();
    setState(() => _mine++);
    if (_m != null) {
      _unsent++;
    } else if (_mine >= goal) {
      _finishDemo(true);
    }
  }

  void _rematch() {
    final nav = Navigator.of(context);
    final ctx = nav.context;
    nav.pop();
    startChallenge(ctx, widget.store, widget.friend, rumbleDash);
  }

  @override
  void dispose() {
    _m?.removeListener(_sync);
    _hold?.cancel();
    _countdown?.cancel();
    _friendTimer?.cancel();
    _flush?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: AppColors.night,
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, inset.top + 4, 16, inset.bottom + 16),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: 'Back',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: AppColors.nightInk,
                    size: 20,
                  ),
                ),
                const Spacer(),
                Text(
                  'Rumble dash',
                  style: tx(
                    17,
                    weight: FontWeight.w600,
                    color: AppColors.nightInk,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 18),
            _Lane(person: widget.store.me, value: _mine / goal, label: 'You'),
            const SizedBox(height: 14),
            _Lane(
              person: widget.friend,
              value: _theirs / goal,
              label: widget.friend.firstName,
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: Motion.normal,
              child: Text(
                _headline(),
                key: ValueKey(_headline()),
                textAlign: TextAlign.center,
                style: tx(
                  _ready && _count > 0 ? 96 : 44,
                  weight: FontWeight.w600,
                  color: AppColors.nightInk,
                ),
              ),
            ),
            const Spacer(),
            if (_over) _ending() else _tapButton(),
          ],
        ),
      ),
    );
  }

  String _headline() {
    if (!_ready) return 'Ready?';
    if (_count > 0) return '$_count';
    if (_draw) return 'A draw.';
    if (_won == true) return 'You won.';
    if (_won == false) return '${widget.friend.firstName} won.';
    return 'Go!';
  }

  Widget _tapButton() {
    return Semantics(
      button: true,
      label: 'Tap to run',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) {
          setState(() => _pressed = true);
          _tap();
        },
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? .9 : 1,
          duration: const Duration(milliseconds: 70),
          child: Container(
            width: 220,
            height: 220,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(
                center: Alignment(-.3, -.4),
                colors: [
                  Color(0xFF8FC2FF),
                  Color(0xFF0A84FF),
                  Color(0xFF003E8A),
                ],
                stops: [0, .6, 1],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0A84FF).withValues(alpha: .45),
                  blurRadius: 60,
                  offset: const Offset(0, 18),
                ),
              ],
            ),
            child: Text(
              'TAP',
              style: tx(44, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _ending() => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.nightInk,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Back'),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: FilledButton(
          onPressed: _rematch,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            minimumSize: const Size.fromHeight(52),
          ),
          child: const Text('Rematch'),
        ),
      ),
    ],
  );
}

/// A track with a bubble running along it.
class _Lane extends StatelessWidget {
  const _Lane({required this.person, required this.value, required this.label});
  final Person person;
  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    const size = 46.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: tx(14, color: AppColors.nightMuted)),
        const SizedBox(height: 6),
        SizedBox(
          height: size,
          child: LayoutBuilder(
            builder: (context, box) => Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.nightChip,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 160),
                  curve: Curves.easeOut,
                  left: (box.maxWidth - size) * value.clamp(0.0, 1.0),
                  child: PersonAvatar(person, diameter: size),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
