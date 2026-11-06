import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import 'four_in_row_screen.dart';
import 'games.dart';
import 'sudoku_duel_screen.dart';

/// Pick who to challenge (from a game tile).
Future<void> challengeWithGame(
  BuildContext context,
  ChatStore store,
  GameInfo game,
) async {
  if (!game.playable) return _soon(context, game);
  final friend = await showModalBottomSheet<Person>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GameHeader(game),
          const SizedBox(height: 8),
          Text('Who do you challenge?', style: tx(14, color: AppColors.muted)),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in store.friends)
                  ListTile(
                    leading: PersonAvatar(p, diameter: 38),
                    title: Text(p.name, style: tx(15, weight: FontWeight.w600)),
                    subtitle: Text(
                      p.online ? 'Online' : 'Offline',
                      style: tx(12, color: AppColors.muted),
                    ),
                    trailing: const Icon(Icons.sports_kabaddi_rounded),
                    onTap: () => Navigator.pop(ctx, p),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
  if (friend != null && context.mounted) {
    await startChallenge(context, store, friend, game);
  }
}

/// Pick a game (from a friend: map card, chat menu, call).
Future<void> challengeFriend(
  BuildContext context,
  ChatStore store,
  Person friend,
) async {
  final game = await showModalBottomSheet<GameInfo>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Challenge ${friend.firstName}',
            style: tx(18, weight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final g in allGames)
            ListTile(
              enabled: g.playable,
              leading: _GameIcon(g, size: 44),
              title: Text(g.name, style: tx(15, weight: FontWeight.w600)),
              subtitle: Text(g.tagline, style: tx(12, color: AppColors.muted)),
              trailing: g.playable ? const Icon(Icons.chevron_right) : null,
              onTap: () => Navigator.pop(ctx, g),
            ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (game != null && context.mounted) {
    await startChallenge(context, store, friend, game);
  }
}

/// Sends the challenge, waits for the friend to accept, then opens the game.
/// Prototype: friends always accept after a moment. The backend will send a
/// real invite (push notification) and start a shared match.
Future<void> startChallenge(
  BuildContext context,
  ChatStore store,
  Person friend,
  GameInfo game,
) async {
  if (!game.playable) return _soon(context, game);
  if (store.online != null) return _startOnline(context, store, friend, game);
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _WaitingDialog(friend: friend, game: game),
  );
  if (accepted != true || !context.mounted) return;
  final seed = Random().nextInt(1 << 30);
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => switch (game.id) {
        'sudoku' => SudokuDuelScreen(store: store, friend: friend, seed: seed),
        _ => FourInRowScreen(store: store, friend: friend),
      },
    ),
  );
}

/// Posts the result in the chat with [friend]; the friend answers.
void postResult(
  ChatStore store,
  Person friend,
  GameInfo game,
  String text, {
  required bool won,
}) {
  final node = store.nodeFor(friend);
  store.post(node, Message(text, game: game));
  Future.delayed(const Duration(milliseconds: 1500), () {
    final replies = won
        ? ['GG 👏', 'Rematch now!', 'You got lucky 😤']
        : ['Too easy 😎', 'GG!', 'Again?'];
    store.post(
      node,
      Message(replies[Random().nextInt(replies.length)], sender: friend),
    );
  });
}

void _soon(BuildContext context, GameInfo game) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          '${game.name} is coming soon',
          style: tx(14, color: Colors.white),
        ),
      ),
    );
}

class _GameIcon extends StatelessWidget {
  const _GameIcon(this.game, {this.size = 56});
  final GameInfo game;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(size * .22),
      gradient: LinearGradient(
        colors: game.colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Icon(game.icon, color: Colors.white, size: size * .5),
  );
}

class _GameHeader extends StatelessWidget {
  const _GameHeader(this.game);
  final GameInfo game;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _GameIcon(game),
      const SizedBox(height: 6),
      Text(game.name, style: tx(18, weight: FontWeight.w700)),
      Text(game.tagline, style: tx(13, color: AppColors.muted)),
    ],
  );
}

class _WaitingDialog extends StatefulWidget {
  const _WaitingDialog({required this.friend, required this.game});
  final Person friend;
  final GameInfo game;

  @override
  State<_WaitingDialog> createState() => _WaitingDialogState();
}

class _WaitingDialogState extends State<_WaitingDialog> {
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (!mounted) return;
      setState(() => _accepted = true);
      Future.delayed(const Duration(milliseconds: 800), () {
        if (mounted) Navigator.pop(context, true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GameIcon(widget.game, size: 48),
              const SizedBox(width: 12),
              const Icon(Icons.bolt_rounded, size: 30),
              const SizedBox(width: 12),
              PersonAvatar(widget.friend, diameter: 48),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _accepted
                ? '${widget.friend.firstName} accepted!'
                : 'Challenging ${widget.friend.firstName}…',
            style: tx(17, weight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(widget.game.name, style: tx(13, color: AppColors.muted)),
          const SizedBox(height: 16),
          if (!_accepted)
            LinearProgressIndicator(color: AppColors.ink)
          else
            const Icon(Icons.check_circle, color: AppColors.online, size: 30),
        ],
      ),
      actions: [
        if (!_accepted)
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
      ],
    );
  }
}

// ------------------------------------------------------------------ online
/// Online: sends the challenge, waits for the friend to accept on their phone.
Future<void> _startOnline(
  BuildContext context,
  ChatStore store,
  Person friend,
  GameInfo game,
) async {
  final online = store.online!;
  final match = await online.challenge(friend, game);
  if (match == null || !context.mounted) return;
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) =>
        _OnlineWaitingDialog(online: online, match: match, friend: friend),
  );
  if (!context.mounted) return;
  if (accepted == true) {
    openMatch(context, store, match);
  } else if (match.status == 'declined') {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${friend.firstName} declined',
          style: tx(14, color: Colors.white),
        ),
      ),
    );
  }
}

/// Opens the game screen for an active online match.
void openMatch(BuildContext context, ChatStore store, OnlineMatch m) {
  final online = store.online!;
  final friend = online.myId == m.challengerId ? m.opponent! : m.challenger!;
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => switch (m.gameId) {
        'sudoku' => SudokuDuelScreen(
          store: store,
          friend: friend,
          seed: 0,
          match: m,
        ),
        _ => FourInRowScreen(store: store, friend: friend, match: m),
      },
    ),
  );
}

/// A friend challenged me (live event): accept or decline.
Future<void> showInvite(
  BuildContext context,
  ChatStore store,
  OnlineMatch m,
) async {
  final online = store.online!;
  final from = m.challenger!;
  HapticFeedback.heavyImpact();
  final accept = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PersonAvatar(from, diameter: 52),
              const SizedBox(width: 12),
              const Icon(Icons.bolt_rounded, size: 30),
              const SizedBox(width: 12),
              _GameIcon(m.game, size: 52),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${from.firstName} challenges you!',
            textAlign: TextAlign.center,
            style: tx(18, weight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(m.game.name, style: tx(14, color: AppColors.muted)),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.accent),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Play'),
        ),
      ],
    ),
  );
  if (accept == true) {
    await online.accept(m);
    if (context.mounted && m.status == 'active') openMatch(context, store, m);
  } else if (accept == false) {
    await online.decline(m);
  }
}

class _OnlineWaitingDialog extends StatefulWidget {
  const _OnlineWaitingDialog({
    required this.online,
    required this.match,
    required this.friend,
  });
  final OnlineSync online;
  final OnlineMatch match;
  final Person friend;

  @override
  State<_OnlineWaitingDialog> createState() => _OnlineWaitingDialogState();
}

class _OnlineWaitingDialogState extends State<_OnlineWaitingDialog> {
  @override
  void initState() {
    super.initState();
    widget.match.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.match.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (!mounted) return;
    final s = widget.match.status;
    if (s == 'active') {
      setState(() {});
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) Navigator.pop(context, true);
      });
    } else if (s == 'declined' || s == 'cancelled') {
      Navigator.pop(context, false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accepted = widget.match.status == 'active';
    return AlertDialog(
      backgroundColor: AppColors.card,
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _GameIcon(widget.match.game, size: 48),
              const SizedBox(width: 12),
              const Icon(Icons.bolt_rounded, size: 30),
              const SizedBox(width: 12),
              PersonAvatar(widget.friend, diameter: 48),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              accepted
                  ? '${widget.friend.firstName} accepted!'
                  : 'Waiting for ${widget.friend.firstName}…',
              key: ValueKey(accepted),
              style: tx(17, weight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'They got a notification on their phone',
            style: tx(12, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          accepted
              ? const Icon(
                  Icons.check_circle,
                  color: AppColors.online,
                  size: 30,
                )
              : LinearProgressIndicator(color: AppColors.ink),
        ],
      ),
      actions: [
        if (!accepted)
          TextButton(
            onPressed: () async {
              await widget.online.decline(widget.match); // cancels my challenge
              if (context.mounted) Navigator.pop(context, false);
            },
            child: const Text('Cancel'),
          ),
      ],
    );
  }
}
