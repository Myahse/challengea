import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
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
/// Demo: friends always accept after a moment.
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
    return _ChallengeCard(
      person: widget.friend,
      game: widget.game,
      title: _accepted
          ? '${widget.friend.firstName} accepted'
          : 'Challenging ${widget.friend.firstName}',
      subtitle: widget.game.name,
      done: _accepted,
      actions: [
        if (!_accepted)
          _CardButton(
            label: 'Cancel challenge',
            onTap: () => Navigator.pop(context, false),
          ),
      ],
    );
  }
}

/// The dialogs around a challenge: who, which game, and where it stands.
class _ChallengeCard extends StatelessWidget {
  const _ChallengeCard({
    required this.person,
    required this.game,
    required this.title,
    required this.subtitle,
    required this.actions,
    this.done = false,
    this.waiting = true,
  });
  final Person person;
  final GameInfo game;
  final String title;
  final String subtitle;
  final bool done;
  final bool waiting;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.card,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 126,
              height: 76,
              child: Stack(
                children: [
                  Positioned(left: 0, child: _GameIcon(game, size: 76)),
                  Positioned(
                    right: 0,
                    child: Floaty(child: PersonAvatar(person, diameter: 76)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AnimatedSwitcher(
              duration: Motion.normal,
              child: Text(
                title,
                key: ValueKey(title),
                textAlign: TextAlign.center,
                style: tx(26, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: tx(16, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            if (waiting)
              SizedBox(
                height: 30,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Motion.normal,
                    child: done
                        ? const Icon(
                            Icons.check_circle_rounded,
                            key: ValueKey('done'),
                            color: AppColors.online,
                            size: 30,
                          )
                        : ClipRRect(
                            key: const ValueKey('waiting'),
                            borderRadius: BorderRadius.circular(2),
                            child: SizedBox(
                              width: 120,
                              child: LinearProgressIndicator(
                                minHeight: 4,
                                color: AppColors.accent,
                                backgroundColor: AppColors.bubble,
                              ),
                            ),
                          ),
                  ),
                ),
              ),
            for (final a in actions) ...[const SizedBox(height: 8), a],
          ],
        ),
      ),
    );
  }
}

class _CardButton extends StatelessWidget {
  const _CardButton({
    required this.label,
    required this.onTap,
    this.primary = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 50,
        width: double.infinity,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? AppColors.accent : AppColors.bubble,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Text(
          label,
          style: tx(
            17,
            weight: FontWeight.w500,
            color: primary ? Colors.white : AppColors.ink,
          ),
        ),
      ),
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
    builder: (ctx) => _ChallengeCard(
      person: from,
      game: m.game,
      title: '${from.firstName} challenges you',
      subtitle: m.game.name,
      waiting: false,
      actions: [
        _CardButton(
          label: 'Play',
          primary: true,
          onTap: () => Navigator.pop(ctx, true),
        ),
        _CardButton(label: 'Not now', onTap: () => Navigator.pop(ctx, false)),
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
  bool _closed = false;
  bool _cancelling = false;

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

  /// The server's answer and my button can both end this dialog: it must only
  /// close once, or it would also close the page underneath.
  void _close(bool accepted) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.pop(context, accepted);
  }

  void _onChange() {
    if (!mounted) return;
    final s = widget.match.status;
    if (s == 'active') {
      setState(() {});
      Future.delayed(const Duration(milliseconds: 700), () => _close(true));
    } else if (s == 'declined' || s == 'cancelled') {
      _close(false);
    }
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    await widget.online.decline(widget.match);
    if (!mounted) return;
    // They may have accepted at the same moment: then the game starts.
    if (widget.match.status == 'active') return;
    _close(false);
  }

  @override
  Widget build(BuildContext context) {
    final accepted = widget.match.status == 'active';
    return _ChallengeCard(
      person: widget.friend,
      game: widget.match.game,
      title: accepted
          ? '${widget.friend.firstName} accepted'
          : 'Waiting for ${widget.friend.firstName}',
      subtitle: accepted ? 'Starting the game' : widget.match.game.name,
      done: accepted,
      actions: [
        if (!accepted)
          _CardButton(
            label: _cancelling ? 'Cancelling' : 'Cancel challenge',
            onTap: _cancelling ? null : _cancel,
          ),
      ],
    );
  }
}
