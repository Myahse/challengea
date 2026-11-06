import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/moments.dart';
import '../widgets/motion.dart';
import 'challenge.dart';
import 'games.dart';

enum _Step { waiting, purple, score, finished }

/// Reaction duel: wait for the screen to turn purple, then tap. Five rounds.
class PurpleRawScreen extends StatefulWidget {
  const PurpleRawScreen({
    super.key,
    required this.store,
    required this.friend,
    this.match,
  });
  final ChatStore store;
  final Person friend;

  /// Online match: same delays for both, the server picks the winner.
  final OnlineMatch? match;

  @override
  State<PurpleRawScreen> createState() => _PurpleRawScreenState();
}

class _PurpleRawScreenState extends State<PurpleRawScreen> {
  static const rounds = 5;
  static const penalty = 2000; // tapping too early
  static const purple = Color(0xFF7A2BC2);

  final _rnd = Random();
  final _clock = Stopwatch();
  final List<int> _mine = [];
  List<int> _theirs = [];
  _Step _step = _Step.waiting;
  Timer? _timer;
  bool? _won;
  bool _draw = false;
  bool _tooSoon = false;

  OnlineMatch? get _m => widget.match;
  bool get _over => _won != null || _draw;

  @override
  void initState() {
    super.initState();
    _m?.addListener(_sync);
    _next();
  }

  int get _delay {
    final delays = _m?.state['delays'] as List?;
    if (delays != null && _mine.length < delays.length) {
      return (delays[_mine.length] as num).toInt();
    }
    return 1500 + _rnd.nextInt(3000);
  }

  void _next() {
    setState(() {
      _step = _Step.waiting;
      _tooSoon = false;
    });
    _timer = Timer(Duration(milliseconds: _delay), () {
      HapticFeedback.mediumImpact();
      _clock
        ..reset()
        ..start();
      setState(() => _step = _Step.purple);
    });
  }

  void _tap() {
    if (_step == _Step.waiting) {
      _timer?.cancel();
      HapticFeedback.heavyImpact();
      setState(() => _tooSoon = true);
      _record(penalty);
    } else if (_step == _Step.purple) {
      _clock.stop();
      HapticFeedback.lightImpact();
      _record(_clock.elapsedMilliseconds.clamp(80, penalty));
    }
  }

  void _record(int ms) {
    final round = _mine.length;
    setState(() {
      _mine.add(ms);
      _step = _Step.score;
    });
    if (_m != null) {
      widget.store.online?.move(_m!, {'round': round, 'ms': ms});
    } else {
      _theirs = [..._theirs, 235 + _rnd.nextInt(185)];
    }
    _timer = Timer(const Duration(milliseconds: 1300), () {
      if (!mounted) return;
      if (_mine.length < rounds) {
        _next();
      } else {
        setState(() => _step = _Step.finished);
        if (_m == null) _finishDemo();
      }
    });
  }

  void _finishDemo() {
    var me = 0, them = 0;
    for (var i = 0; i < rounds; i++) {
      if (_mine[i] < _theirs[i]) me++;
      if (_theirs[i] < _mine[i]) them++;
    }
    final won = me > them;
    setState(() {
      _draw = me == them;
      if (!_draw) _won = won;
    });
    if (won) Burst.victory(context);
    if (_draw) return;
    final f = widget.friend.firstName;
    postResult(
      widget.store,
      widget.friend,
      purpleRaw,
      won ? '⚡ I beat $f at Purple raw' : '⚡ $f beat me at Purple raw',
      won: won,
    );
  }

  void _sync() {
    final m = _m!;
    final online = widget.store.online!;
    if (!mounted) return;
    final players = m.state['players'] as Map?;
    final them = players?['${online.idOf(widget.friend)}'] as Map?;
    setState(() {
      _theirs = [
        for (final t in (them?['times'] as List?) ?? const [])
          (t as num).toInt(),
      ];
    });
    if (m.finished && !_over) {
      setState(() {
        _draw = m.winnerId == null;
        if (!_draw) _won = m.winnerId == online.myId;
        _step = _Step.finished;
      });
      if (_won == true) Burst.victory(context);
    }
  }

  void _rematch() {
    final nav = Navigator.of(context);
    final ctx = nav.context;
    nav.pop();
    startChallenge(ctx, widget.store, widget.friend, purpleRaw);
  }

  @override
  void dispose() {
    _m?.removeListener(_sync);
    _timer?.cancel();
    super.dispose();
  }

  (String, String) get _words => switch (_step) {
    _Step.waiting => ('Wait for it.', 'Tap when the screen turns purple'),
    _Step.purple => ('Now!', ''),
    _Step.score =>
      _tooSoon
          ? ('Too soon.', 'That round counts as 2 seconds')
          : ('${_mine.last} ms', 'Round ${_mine.length} of $rounds'),
    _Step.finished =>
      _draw
          ? ('A draw.', 'Exactly level')
          : (_won == true
                ? ('You won.', 'Faster on the rounds that counted')
                : (_won == false
                      ? ('${widget.friend.firstName} won.', 'So close')
                      : (
                          'Waiting for ${widget.friend.firstName}',
                          'They’re still playing',
                        ))),
  };

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    final (title, sub) = _words;
    return Scaffold(
      backgroundColor: AppColors.night,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _tap(),
        child: AnimatedContainer(
          duration: _step == _Step.purple
              ? Duration.zero
              : const Duration(milliseconds: 260),
          color: _step == _Step.purple
              ? purple
              : (_tooSoon && _step == _Step.score
                    ? const Color(0xFF4A0F18)
                    : AppColors.night),
          padding: EdgeInsets.fromLTRB(
            16,
            inset.top + 4,
            16,
            inset.bottom + 16,
          ),
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
                    'Purple raw',
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
              const Spacer(),
              AnimatedSwitcher(
                duration: Motion.fast,
                child: Text(
                  title,
                  key: ValueKey(title),
                  textAlign: TextAlign.center,
                  style: tx(
                    60,
                    weight: FontWeight.w600,
                    color: AppColors.nightInk,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: tx(17, color: AppColors.nightInk),
              ),
              const Spacer(),
              _scoreboard(),
              const SizedBox(height: 16),
              if (_over) _ending(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _scoreboard() {
    Widget line(String who, List<int> times) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            child: Text(
              who,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx(14, color: AppColors.nightInk),
            ),
          ),
          for (var i = 0; i < rounds; i++)
            Expanded(
              child: Text(
                i < times.length ? '${times[i]}' : '·',
                textAlign: TextAlign.center,
                style: tx(14, color: AppColors.nightInk),
              ),
            ),
        ],
      ),
    );
    return Column(
      children: [line('You', _mine), line(widget.friend.firstName, _theirs)],
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
