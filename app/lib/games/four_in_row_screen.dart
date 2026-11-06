import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/moments.dart';
import 'challenge.dart';
import 'four_logic.dart';
import 'games.dart';

/// Arcade: Four in a row, turn by turn. The friend's moves are played by the
/// app for now; online, they will come from the other phone.
class FourInRowScreen extends StatefulWidget {
  const FourInRowScreen({
    super.key,
    required this.store,
    required this.friend,
    this.iStart = true,
    this.match,
  });
  final ChatStore store;
  final Person friend;
  final bool iStart;

  /// Online match: moves go through the server, the friend plays on their phone.
  final OnlineMatch? match;

  @override
  State<FourInRowScreen> createState() => _FourInRowScreenState();
}

class _FourInRowScreenState extends State<FourInRowScreen> {
  final _board = FourBoard();
  final _rnd = Random();
  late bool _myTurn = widget.iStart;
  (int, int)? _last; // last disc, animated as it falls
  List<(int, int)>? _winLine;
  int? _winner; // 1 me, 2 friend, 0 draw
  int _moves = 0;

  static const me = AppColors.danger;
  static const friendColor = Color(0xFFFFC53D);

  @override
  void initState() {
    super.initState();
    if (widget.match != null) {
      widget.match!.addListener(_sync);
      _sync();
    } else if (!_myTurn) {
      _friendMove();
    }
  }

  @override
  void dispose() {
    widget.match?.removeListener(_sync);
    super.dispose();
  }

  /// Copies the server's board (my discs = 1, friend's = 2).
  void _sync() {
    final m = widget.match!;
    final online = widget.store.online!;
    final mine = online.myId == m.challengerId ? 1 : 2;
    final cells = (m.state['cells'] as List?) ?? [];
    var changed = false;
    for (var r = 0; r < FourBoard.rows && r < cells.length; r++) {
      final row = cells[r] as List;
      for (var c = 0; c < FourBoard.cols; c++) {
        final v = (row[c] as num).toInt();
        final local = v == 0 ? 0 : (v == mine ? 1 : 2);
        if (_board.cells[r][c] != local) changed = true;
        _board.cells[r][c] = local;
      }
    }
    final lastCol = (m.state['lastCol'] as num?)?.toInt();
    setState(() {
      if (changed && lastCol != null) {
        final top = List.generate(
          FourBoard.rows,
          (r) => r,
        ).firstWhere((r) => _board.cells[r][lastCol] != 0, orElse: () => 0);
        _last = (top, lastCol);
        if (!_myTurn && m.currentTurnId == online.myId) {
          HapticFeedback.lightImpact(); // friend played
        }
      }
      _moves = (m.state['moves'] as num?)?.toInt() ?? 0;
      _myTurn = m.currentTurnId == online.myId;
      if (m.finished) {
        final wasOpen = _winner == null;
        _winner = m.winnerId == null ? 0 : (m.winnerId == online.myId ? 1 : 2);
        if (wasOpen && _winner == 1) _celebrate();
        final line = m.state['winLine'] as List?;
        _winLine = line == null
            ? null
            : [for (final p in line) ((p as List)[0] as int, p[1] as int)];
      }
    });
  }

  Future<void> _playOnline(int col) async {
    setState(() => _myTurn = false); // wait for the server
    final error = await widget.store.online!.move(widget.match!, {'col': col});
    if (error != null && mounted) {
      _sync();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Move refused ($error)')));
    }
  }

  void _play(int col) {
    if (!_myTurn || _winner != null || !_board.canPlay(col)) return;
    HapticFeedback.selectionClick();
    if (widget.match != null) {
      _playOnline(col);
      return;
    }
    final row = _board.drop(col, 1)!;
    setState(() {
      _last = (row, col);
      _moves++;
      _myTurn = false;
    });
    if (!_checkEnd(1)) _friendMove();
  }

  void _friendMove() {
    Future.delayed(Duration(milliseconds: 650 + _rnd.nextInt(600)), () {
      if (!mounted || _winner != null) return;
      final col = _board.pickMove(_rnd);
      final row = _board.drop(col, 2)!;
      setState(() {
        _last = (row, col);
        _moves++;
        _myTurn = true;
      });
      _checkEnd(2);
    });
  }

  void _celebrate() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) Burst.victory(context);
  });

  bool _checkEnd(int player) {
    final line = _board.winLine(player);
    if (line == null && !_board.full) return false;
    setState(() {
      _winLine = line;
      _winner = line == null ? 0 : player;
      if (_winner == 1) _celebrate();
    });
    final f = widget.friend.firstName;
    final text = switch (_winner) {
      1 => '🏆 I beat you at Four in a row in $_moves moves',
      2 => '😅 $f beat me at Four in a row',
      _ => '🤝 Four in a row: draw with $f',
    };
    postResult(widget.store, widget.friend, fourInRow, text, won: _winner == 1);
    HapticFeedback.mediumImpact();
    return true;
  }

  void _rematch() {
    if (widget.match != null) {
      final nav = Navigator.of(context)..pop();
      startChallenge(nav.context, widget.store, widget.friend, fourInRow);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => FourInRowScreen(
          store: widget.store,
          friend: widget.friend,
          iStart: !widget.iStart,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    final status = switch (_winner) {
      1 => 'You win! 🏆',
      2 => '${f.firstName} wins',
      0 => 'Draw',
      _ => _myTurn ? 'Your turn: tap a column' : '${f.firstName} is thinking…',
    };
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text('Four in a row', style: tx(16, weight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Row(
                children: [
                  _player(
                    widget.store.me,
                    'You',
                    me,
                    active: _myTurn && _winner == null,
                  ),
                  const Spacer(),
                  Text('VS', style: tx(16, weight: FontWeight.w800)),
                  const Spacer(),
                  _player(
                    f,
                    f.firstName,
                    friendColor,
                    active: !_myTurn && _winner == null,
                    right: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                status,
                key: ValueKey(status),
                style: tx(18, weight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: _grid(),
                ),
              ),
            ),
            if (_winner != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Back'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accent,
                        ),
                        onPressed: _rematch,
                        child: const Text('Rematch'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _player(
    Person p,
    String name,
    Color disc, {
    required bool active,
    bool right = false,
  }) {
    final children = [
      AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? disc : Colors.transparent,
            width: 3,
          ),
        ),
        child: PersonAvatar(p, diameter: 40),
      ),
      const SizedBox(width: 8),
      Column(
        crossAxisAlignment: right
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Text(name, style: tx(14, weight: FontWeight.w700)),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(shape: BoxShape.circle, color: disc),
          ),
        ],
      ),
    ];
    return Row(children: right ? children.reversed.toList() : children);
  }

  Widget _grid() {
    return AspectRatio(
      aspectRatio: FourBoard.cols / FourBoard.rows,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: const Color(0xFF2B4ACB),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            for (var c = 0; c < FourBoard.cols; c++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _play(c),
                  child: Column(
                    children: [
                      for (var r = 0; r < FourBoard.rows; r++)
                        Expanded(child: _hole(r, c)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _hole(int r, int c) {
    final v = _board.cells[r][c];
    final winning = _winLine?.contains((r, c)) ?? false;
    final disc = v == 0
        ? null
        : Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: v == 1 ? me : friendColor,
              border: winning
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: .25),
                  blurRadius: 3,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          );
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.card,
        ),
        child: disc == null
            ? null
            : _last == (r, c)
            // The newest disc falls from the top of the board.
            ? TweenAnimationBuilder<double>(
                key: ValueKey('$r-$c-$_moves'),
                tween: Tween(begin: -(r + 1.0), end: 0),
                duration: Duration(milliseconds: 180 + r * 60),
                curve: Curves.bounceOut,
                builder: (context, y, child) => FractionalTranslation(
                  translation: Offset(0, y),
                  child: child,
                ),
                child: disc,
              )
            : disc,
      ),
    );
  }
}
