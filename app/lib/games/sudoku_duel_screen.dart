import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'challenge.dart';
import 'games.dart';
import 'sudoku_logic.dart';

/// Sudoku duel: you and your friend fill the same grid. First to finish wins;
/// 3 mistakes and you lose. The friend's progress is simulated for now.
class SudokuDuelScreen extends StatefulWidget {
  const SudokuDuelScreen({
    super.key,
    required this.store,
    required this.friend,
    required this.seed,
    this.match,
  });
  final ChatStore store;
  final Person friend;
  final int seed;

  /// Online match: the server holds the grid's solution and checks each answer.
  final OnlineMatch? match;

  @override
  State<SudokuDuelScreen> createState() => _SudokuDuelScreenState();
}

class _SudokuDuelScreenState extends State<SudokuDuelScreen> {
  late final SudokuPuzzle _puzzle = SudokuPuzzle.generate(
    seed: widget.seed,
  ); // demo only
  OnlineMatch? get _m => widget.match;
  late final List<List<int>> _givens = _m == null
      ? _puzzle.givens
      : [
          for (var r = 0; r < 9; r++)
            [
              for (var c = 0; c < 9; c++)
                ((_m!.state['givens'] as List)[r * 9 + c] as num).toInt(),
            ],
        ];
  late final List<List<int>> _grid = [
    for (final r in _givens) [...r],
  ];
  final Set<int> _wrong = {}; // cell index of wrong entries
  late final int _toFill = _m == null
      ? _puzzle.blanks
      : (_m!.state['toFill'] as num).toInt();
  int? _selected;
  int _mistakes = 0;
  late int _hints = _m == null
      ? 3
      : 0; // no hints online: the phone doesn't know the solution
  int _serverFilled = 0;
  int _friendFilled = 0;
  final _started = DateTime.now();
  Timer? _clock;
  Timer? _friendTimer;
  final _rnd = Random();
  bool _over = false;

  static const maxMistakes = 3;

  Map<String, dynamic> _progress(int userId) =>
      ((_m!.state['players'] as Map?)?['$userId'] as Map?)
          ?.cast<String, dynamic>() ??
      {};

  int get _filled {
    if (_m != null) return _serverFilled;
    var n = 0;
    for (var i = 0; i < 81; i++) {
      final r = i ~/ 9, c = i % 9;
      if (_puzzle.givens[r][c] == 0 && _grid[r][c] == _puzzle.solution[r][c]) {
        n++;
      }
    }
    return n;
  }

  String get _elapsed {
    final d = DateTime.now().difference(_started);
    return '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_over) setState(() {});
    });
    if (_m != null) {
      _m!.addListener(_onMatch);
      _onMatch();
    } else {
      _scheduleFriend();
    }
  }

  /// Server update (my answers, the friend's progress, the end).
  void _onMatch() {
    final online = widget.store.online!;
    final mine = _progress(online.myId);
    final theirs = _progress(online.idOf(widget.friend));
    setState(() {
      _serverFilled = (mine['filled'] as num?)?.toInt() ?? 0;
      _mistakes = (mine['mistakes'] as num?)?.toInt() ?? 0;
      _friendFilled = (theirs['filled'] as num?)?.toInt() ?? 0;
    });
    if (_m!.finished && !_over) {
      final won = _m!.winnerId == online.myId;
      final reason = won
          ? 'Solved in $_elapsed'
          : (_mistakes >= maxMistakes
                ? '$maxMistakes mistakes'
                : '${widget.friend.firstName} finished first');
      _finish(won: won, reason: reason);
    }
  }

  void _scheduleFriend() {
    // About 5 seconds per cell: a full grid takes the friend ~3.5 minutes.
    _friendTimer = Timer(Duration(milliseconds: 3000 + _rnd.nextInt(4500)), () {
      if (!mounted || _over) return;
      setState(() => _friendFilled++);
      if (_friendFilled >= _toFill) {
        _finish(
          won: false,
          reason: '${widget.friend.firstName} finished first',
        );
      } else {
        _scheduleFriend();
      }
    });
  }

  @override
  void dispose() {
    _m?.removeListener(_onMatch);
    _clock?.cancel();
    _friendTimer?.cancel();
    super.dispose();
  }

  void _enter(int v) {
    final s = _selected;
    if (_over || s == null) return;
    final r = s ~/ 9, c = s % 9;
    if (_givens[r][c] != 0) return;
    if (_m != null) {
      _enterOnline(s, v);
      return;
    }
    setState(() {
      _grid[r][c] = v;
      if (v != 0 && v != _puzzle.solution[r][c]) {
        _wrong.add(s);
        _mistakes++;
        HapticFeedback.heavyImpact();
      } else {
        _wrong.remove(s);
        if (v != 0) HapticFeedback.selectionClick();
      }
    });
    if (_mistakes >= maxMistakes) {
      _finish(won: false, reason: '$maxMistakes mistakes');
    } else if (_filled == _toFill) {
      _finish(won: true, reason: 'Solved in $_elapsed');
    }
  }

  Future<void> _enterOnline(int cell, int v) async {
    final online = widget.store.online!;
    final mine = ((_progress(online.myId)['cells'] as List?) ?? []).map(
      (e) => (e as num).toInt(),
    );
    if (mine.contains(cell)) return; // already solved, locked
    setState(() => _grid[cell ~/ 9][cell % 9] = v);
    if (v == 0) {
      setState(() => _wrong.remove(cell));
      return;
    }
    final error = await online.move(_m!, {'cell': cell, 'value': v});
    if (!mounted || error != null) return;
    final solved = ((_progress(online.myId)['cells'] as List?) ?? [])
        .map((e) => (e as num).toInt())
        .contains(cell);
    setState(() => solved ? _wrong.remove(cell) : _wrong.add(cell));
    solved ? HapticFeedback.selectionClick() : HapticFeedback.heavyImpact();
  }

  void _hint() {
    if (_over || _hints == 0) return;
    final empty = [
      for (var i = 0; i < 81; i++)
        if (_grid[i ~/ 9][i % 9] != _puzzle.solution[i ~/ 9][i % 9]) i,
    ];
    if (empty.isEmpty) return;
    final pick = _selected != null && empty.contains(_selected)
        ? _selected!
        : empty[_rnd.nextInt(empty.length)];
    setState(() {
      _hints--;
      _selected = pick;
    });
    _enter(_puzzle.solution[pick ~/ 9][pick % 9]);
  }

  void _finish({required bool won, required String reason}) {
    if (_over) return;
    _over = true;
    _friendTimer?.cancel();
    final f = widget.friend.firstName;
    // Online, the server posts the result in your chat.
    if (_m == null) {
      postResult(
        widget.store,
        widget.friend,
        sudokuDuel,
        won
            ? '🏆 I won our Sudoku duel in $_elapsed'
            : '😅 $f won our Sudoku duel ($reason)',
        won: won,
      );
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(
          won ? 'You win! 🏆' : '$f wins',
          textAlign: TextAlign.center,
          style: tx(24, weight: FontWeight.w800),
        ),
        content: Text(reason, textAlign: TextAlign.center, style: tx(15)),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Back'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
            onPressed: () {
              Navigator.pop(ctx);
              if (_m != null) {
                final nav = Navigator.of(context)..pop();
                startChallenge(
                  nav.context,
                  widget.store,
                  widget.friend,
                  sudokuDuel,
                );
                return;
              }
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => SudokuDuelScreen(
                    store: widget.store,
                    friend: widget.friend,
                    seed: _rnd.nextInt(1 << 30),
                  ),
                ),
              );
            },
            child: const Text('Rematch'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Column(
          children: [
            Text('Sudoku duel', style: tx(16, weight: FontWeight.w700)),
            Text(_elapsed, style: tx(12, color: AppColors.muted)),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Row(
                children: [
                  Expanded(child: _player(widget.store.me, 'You', _filled)),
                  const SizedBox(width: 12),
                  Text('VS', style: tx(16, weight: FontWeight.w800)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _player(
                      widget.friend,
                      widget.friend.firstName,
                      _friendFilled,
                      right: true,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < maxMistakes; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Icon(
                      i < _mistakes
                          ? Icons.close_rounded
                          : Icons.favorite_rounded,
                      size: 18,
                      color: i < _mistakes
                          ? AppColors.danger
                          : const Color(0xFFFF8FA3),
                    ),
                  ),
                const SizedBox(width: 6),
                Text(
                  'Mistakes $_mistakes/$maxMistakes',
                  style: tx(12, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: _board(),
                ),
              ),
            ),
            _pad(),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _player(Person p, String name, int filled, {bool right = false}) {
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: filled / _toFill,
        minHeight: 7,
        backgroundColor: AppColors.bubble,
        color: right ? p.color : AppColors.accent,
      ),
    );
    final info = Expanded(
      child: Column(
        crossAxisAlignment: right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(
            '$name · $filled/$_toFill',
            style: tx(12, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          bar,
        ],
      ),
    );
    final avatar = PersonAvatar(p, diameter: 34);
    return Row(
      children: right
          ? [info, const SizedBox(width: 8), avatar]
          : [avatar, const SizedBox(width: 8), info],
    );
  }

  Widget _board() {
    final sel = _selected;
    final selValue = sel == null ? 0 : _grid[sel ~/ 9][sel % 9];
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.ink, width: 2),
        ),
        child: Column(
          children: [
            for (var r = 0; r < 9; r++)
              Expanded(
                child: Row(
                  children: [
                    for (var c = 0; c < 9; c++)
                      Expanded(child: _cell(r, c, sel, selValue)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _cell(int r, int c, int? sel, int selValue) {
    final i = r * 9 + c;
    final v = _grid[r][c];
    final given = _givens[r][c] != 0;
    final selected = sel == i;
    final related =
        sel != null &&
        (sel ~/ 9 == r ||
            sel % 9 == c ||
            (sel ~/ 27 == r ~/ 3 && sel % 9 ~/ 3 == c ~/ 3));
    final same = v != 0 && v == selValue;
    final wrong = _wrong.contains(i);
    const thin = BorderSide(color: Color(0xFFCFCFCF), width: .6);
    final thick = BorderSide(color: AppColors.ink, width: 1.6);
    return GestureDetector(
      onTap: () => setState(() => _selected = i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFBDE7C6)
              : same
              ? const Color(0xFFDDF3E2)
              : related
              ? AppColors.page
              : Colors.white,
          border: Border(
            right: c == 8 ? BorderSide.none : (c % 3 == 2 ? thick : thin),
            bottom: r == 8 ? BorderSide.none : (r % 3 == 2 ? thick : thin),
          ),
        ),
        alignment: Alignment.center,
        // Digits pop in; a wrong one shakes in red.
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 320),
          transitionBuilder: (child, a) => ScaleTransition(
            scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
            child: child,
          ),
          child: v == 0
              ? const SizedBox.shrink(key: ValueKey(0))
              : FittedBox(
                  key: ValueKey('$v$wrong'),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Text(
                      '$v',
                      style: tx(
                        22,
                        weight: given ? FontWeight.w700 : FontWeight.w500,
                        color: wrong
                            ? AppColors.danger
                            : (given ? AppColors.ink : const Color(0xFF1F6FEB)),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _pad() {
    // How many of each digit are still missing (hide finished digits).
    int left(int d) =>
        9 -
        [
          for (var i = 0; i < 81; i++) _grid[i ~/ 9][i % 9],
        ].where((v) => v == d).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Column(
        children: [
          Row(
            children: [
              for (var d = 1; d <= 9; d++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: left(d) <= 0 ? AppColors.page : AppColors.bubble,
                      borderRadius: BorderRadius.circular(10),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: left(d) <= 0 ? null : () => _enter(d),
                        child: SizedBox(
                          height: 54,
                          child: Center(
                            child: Text(
                              '$d',
                              style: tx(
                                22,
                                weight: FontWeight.w700,
                                color: left(d) <= 0
                                    ? AppColors.muted
                                    : AppColors.ink,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextButton.icon(
                onPressed: () => _enter(0),
                icon: Icon(Icons.backspace_outlined, color: AppColors.ink),
                label: Text('Erase', style: tx(14, weight: FontWeight.w600)),
              ),
              if (_m == null)
                TextButton.icon(
                  onPressed: _hints == 0 ? null : _hint,
                  icon: Icon(
                    Icons.lightbulb_outline_rounded,
                    color: AppColors.ink,
                  ),
                  label: Text(
                    'Hint ($_hints)',
                    style: tx(14, weight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
