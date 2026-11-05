import 'dart:math';

import 'package:flutter/material.dart';

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
    backgroundColor: Colors.white,
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
    backgroundColor: Colors.white,
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
      backgroundColor: Colors.white,
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
            const LinearProgressIndicator(color: AppColors.ink)
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
