import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/bubble_field.dart';
import 'chat_screen.dart';

/// Figma: "Chat page" (node 28:144).
class ChatHome extends StatefulWidget {
  const ChatHome({super.key, required this.store});
  final ChatStore store;

  @override
  State<ChatHome> createState() => _ChatHomeState();
}

class _ChatHomeState extends State<ChatHome> {
  ChatStore get store => widget.store;

  void _open(BubbleNode n) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    store.markRead(n);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(store: store, node: n),
      ),
    );
  }

  void _onMerged(
    BubbleNode group,
    bool created,
    BubbleNode dragged,
    BubbleNode target,
  ) {
    final m = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    final added = dragged.isGroup && !target.isGroup ? target : dragged;
    m.showSnackBar(
      SnackBar(
        content: Text(
          created
              ? 'Group created: ${group.displayName}'
              : '${added.displayName} added to ${group.displayName}',
          style: tx(14, color: Colors.white),
        ),
        action: SnackBarAction(
          label: created ? 'Name it' : 'Open',
          onPressed: () => created ? _rename(group) : _open(group),
        ),
      ),
    );
  }

  Future<void> _rename(BubbleNode group) async {
    final ctrl = TextEditingController(text: group.name ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Group name', style: tx(18, weight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: group.members.map((m) => m.firstName).join(', '),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) store.rename(group, name);
  }

  void _longPress(BubbleNode n) {
    if (!n.isGroup) {
      _open(n);
      return;
    }
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => ListenableBuilder(
        listenable: store,
        builder: (ctx, _) {
          if (!store.nodes.contains(n)) return const SizedBox(height: 40);
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: GroupAvatar(n.members, diameter: 44),
                  title: Text(
                    n.displayName,
                    style: tx(18, weight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${n.members.length} members',
                    style: tx(13, color: AppColors.muted),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => _rename(n),
                  ),
                ),
                const Divider(height: 1),
                for (final p in n.members)
                  ListTile(
                    leading: PersonAvatar(p, diameter: 36),
                    title: Text(p.name, style: tx(15, weight: FontWeight.w500)),
                    trailing: IconButton(
                      tooltip: 'Remove from group',
                      icon: const Icon(
                        Icons.remove_circle_outline,
                        color: Colors.redAccent,
                      ),
                      onPressed: () {
                        store.removeMember(n, p);
                        if (!store.nodes.contains(n)) Navigator.pop(ctx);
                      },
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.call_split),
                          label: const Text('Split group'),
                          onPressed: () {
                            store.dissolve(n);
                            Navigator.pop(ctx);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.ink,
                          ),
                          icon: const Icon(Icons.chat_bubble_rounded, size: 18),
                          label: const Text('Open chat'),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _open(n);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(me: store.me),
            const SizedBox(height: 14),
            const _TalesRow(),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 0),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_rounded, size: 26),
                  const SizedBox(width: 6),
                  Text('Chats', style: tx(17, weight: FontWeight.w700)),
                  const Spacer(),
                  const Icon(Icons.more_horiz, size: 26),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
              child: Text(
                'Drag a bubble onto another to make a group',
                style: tx(12, color: AppColors.muted),
              ),
            ),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
                      child: BubbleField(
                        store: store,
                        onOpen: _open,
                        onLongPress: _longPress,
                        onMerged: _onMerged,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 28,
                    bottom: 46,
                    child: Material(
                      color: AppColors.bubble,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          final n = store.addFriend();
                          if (n == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'No more demo friends',
                                  style: tx(14, color: Colors.white),
                                ),
                              ),
                            );
                          }
                        },
                        child: const SizedBox(
                          width: 50,
                          height: 50,
                          child: Icon(Icons.add, size: 32),
                        ),
                      ),
                    ),
                  ),
                  const Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: _PageDots(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.me});
  final Person me;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 20, 0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bubble,
            ),
            child: PersonAvatar(me, diameter: 42),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(me.name, style: tx(16, weight: FontWeight.w700)),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.online,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Online',
                    style: tx(
                      12,
                      weight: FontWeight.w500,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          const Icon(Icons.card_giftcard_rounded, size: 24),
          const SizedBox(width: 12),
          const Icon(Icons.storefront_rounded, size: 24),
        ],
      ),
    );
  }
}

/// "Tales" = the games row. Tiles are placeholders until the final game art.
class _TalesRow extends StatelessWidget {
  const _TalesRow();

  static const _games = [
    ('Sudoku', Icons.grid_view_rounded, [Color(0xFF3FD0FF), Color(0xFFFF4FA3)]),
    (
      'Arcade',
      Icons.sports_esports_rounded,
      [Color(0xFFFFE066), Color(0xFF2DBE60)],
    ),
    (
      'Rumble dash',
      Icons.directions_run_rounded,
      [Color(0xFF3D7BFF), Color(0xFFFFB13D)],
    ),
    (
      'Purple raw',
      Icons.favorite_rounded,
      [Color(0xFFFFC94D), Color(0xFF7A2BC2)],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, size: 24),
              const SizedBox(width: 4),
              Text('Tales', style: tx(17, weight: FontWeight.w700)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.ink),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Text('Explore', style: tx(13, weight: FontWeight.w600)),
                    const Icon(Icons.chevron_right, size: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 104,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _games.length + 1,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, i) {
              if (i == _games.length) {
                return Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.bubble,
                    borderRadius: BorderRadius.circular(18),
                  ),
                );
              }
              final (name, icon, colors) = _games[i];
              return Column(
                children: [
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Icon(icon, size: 44, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(name, style: tx(10, weight: FontWeight.w500)),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < 4; i++)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == 0 ? AppColors.muted : AppColors.bubble,
            ),
          ),
      ],
    );
  }
}
