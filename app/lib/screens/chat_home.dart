import 'dart:math';

import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/bubble_field.dart';
import '../widgets/friends_sheet.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';
import 'chat_screen.dart';
import 'profile_screen.dart';

/// The signature page: friends as glossy bubbles on black. Drag one onto
/// another to make a group; the list view is one tap away.
class ChatHome extends StatefulWidget {
  const ChatHome({super.key, required this.store, this.onOpenMap});
  final ChatStore store;
  final VoidCallback? onOpenMap;

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
      backgroundColor: AppColors.card,
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
                            backgroundColor: AppColors.accent,
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

  /// Alternative to dragging bubbles: pick friends from a list.
  void _newGroup() {
    final picked = <Person>{};
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(ctx).height * .7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('New group', style: tx(18, weight: FontWeight.w700)),
                Text(
                  'Tip: you can also drag a bubble onto another',
                  style: tx(12, color: AppColors.muted),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in store.friends)
                        CheckboxListTile(
                          value: picked.contains(p),
                          onChanged: (v) => setSheet(
                            () => v == true ? picked.add(p) : picked.remove(p),
                          ),
                          secondary: PersonAvatar(p, diameter: 36),
                          title: Text(
                            p.name,
                            style: tx(15, weight: FontWeight.w500),
                          ),
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.accent,
                      ),
                      onPressed: picked.length < 2
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              final g = store.createGroup(picked.toList());
                              _onMerged(g, true, g, g);
                            },
                      child: Text(
                        picked.length < 2
                            ? 'Pick at least 2 friends'
                            : 'Create group (${picked.length})',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _list = false; // Bubbles (default) or a WhatsApp-style list
  String _filter = 'All';
  String _query = '';

  List<BubbleNode> _sorted() {
    DateTime last(BubbleNode n) =>
        n.messages.isEmpty ? DateTime(2000) : n.messages.last.time;
    final q = _query.toLowerCase();
    return store.nodes.where((n) {
      if (q.isNotEmpty && !n.displayName.toLowerCase().contains(q)) {
        return false;
      }
      return switch (_filter) {
        'Unread' => n.unread > 0,
        'Groups' => n.isGroup,
        _ => true,
      };
    }).toList()..sort((a, b) => last(b).compareTo(last(a)));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.page,
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final unread = store.nodes.where((n) => n.unread > 0).length;
          final list = _list || _query.isNotEmpty;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: me, title, friends, Bubbles / List switch.
              Padding(
                padding: EdgeInsets.fromLTRB(20, top + 8, 12, 0),
                child: Row(
                  children: [
                    Tooltip(
                      message: 'My profile',
                      child: Pressable(
                        scale: .9,
                        onTap: () =>
                            ProfileScreen.open(context, store, store.feed.me),
                        child: PersonAvatar(store.me, diameter: 34),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Chats',
                      style: tx(
                        20,
                        weight: FontWeight.w600,
                        color: AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    if (store.online != null)
                      IconButton(
                        tooltip: 'Friends',
                        onPressed: () =>
                            showFriendsSheet(context, store.online!),
                        icon: Badge(
                          isLabelVisible:
                              (store.online?.incoming.length ?? 0) > 0,
                          label: Text('${store.online?.incoming.length ?? 0}'),
                          backgroundColor: AppColors.accent,
                          child: Icon(
                            Icons.person_add_alt_1_outlined,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    _ViewSwitch(
                      list: _list,
                      onChanged: (v) => setState(() => _list = v),
                    ),
                  ],
                ),
              ),
              // Bubbles: the headline. List: search and filters.
              AnimatedSize(
                duration: Motion.normal,
                curve: Motion.ease,
                alignment: Alignment.topCenter,
                child: list ? _listHeader(unread) : _hero(),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: Motion.normal,
                  switchInCurve: Motion.ease,
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(
                      scale: Tween(begin: .96, end: 1.0).animate(a),
                      child: child,
                    ),
                  ),
                  child: list
                      ? KeyedSubtree(
                          key: const ValueKey('list'),
                          child: _chatList(),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('bubbles'),
                          child: _bubbles(),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _hero() => Padding(
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
    child: FadeSlideIn(
      child: Column(
        children: [
          Text(
            'Bring them\ntogether.',
            textAlign: TextAlign.center,
            style: tx(44, weight: FontWeight.w600, color: AppColors.ink),
          ),
          const SizedBox(height: 8),
          Text(
            'Drop one friend on another.',
            textAlign: TextAlign.center,
            style: tx(17, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );

  Widget _listHeader(int unread) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: TextField(
          onChanged: (v) => setState(() => _query = v),
          style: tx(16, color: AppColors.ink),
          cursorColor: AppColors.link,
          decoration: InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.search_rounded, color: AppColors.muted),
            hintText: 'Search',
            hintStyle: tx(16, color: AppColors.muted),
            filled: true,
            fillColor: AppColors.card,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ),
      SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          children: [
            for (final f in ['All', 'Unread', 'Groups'])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Pressable(
                  onTap: () => setState(() => _filter = f),
                  child: AnimatedContainer(
                    duration: Motion.fast,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _filter == f ? AppColors.ink : AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      f == 'Unread' && unread > 0 ? 'Unread $unread' : f,
                      style: tx(
                        14,
                        weight: FontWeight.w500,
                        color: _filter == f ? AppColors.onInk : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ],
  );

  /// WhatsApp-style rows: avatar, name, last message, time, unread badge.
  Widget _chatList() {
    final chats = _sorted();
    if (chats.isEmpty) {
      return Center(
        child: Text(
          _query.isEmpty ? 'No chats here yet' : 'No match for "$_query"',
          style: tx(15, color: AppColors.muted),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 120),
      itemCount: chats.length,
      itemBuilder: (context, i) => FadeSlideIn(
        key: ValueKey(chats[i].id),
        delay: Duration(milliseconds: i < 10 ? 30 * i : 0),
        offset: const Offset(0, 14),
        child: _ChatRow(
          node: chats[i],
          onTap: () => _open(chats[i]),
          onLongPress: () => _longPress(chats[i]),
        ),
      ),
    );
  }

  /// The signature bubbles: drag one onto another to make a group.
  Widget _bubbles() {
    return Stack(
      children: [
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 96),
            child: BubbleField(
              store: store,
              onOpen: _open,
              onLongPress: _longPress,
              onMerged: _onMerged,
            ),
          ),
        ),
        // Above the bubble area so its button receives taps.
        if (store.isOnline && store.nodes.isEmpty)
          Positioned.fill(
            child: _EmptyFriends(
              onFind: () => showFriendsSheet(context, store.online!),
            ),
          ),
        Positioned(
          right: 18,
          bottom: 110,
          child: _SpeedDial(
            onMap: widget.onOpenMap,
            onAddFriend: () {
              if (store.online != null) {
                showFriendsSheet(context, store.online!);
              } else if (store.addFriend() == null) {
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
            onNewGroup: _newGroup,
          ),
        ),
      ],
    );
  }
}

/// Bubbles / List toggle.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.list, required this.onChanged});
  final bool list;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    Widget seg(IconData icon, bool selected, VoidCallback onTap, String tip) =>
        Tooltip(
          message: tip,
          child: Pressable(
            onTap: onTap,
            child: AnimatedContainer(
              duration: Motion.fast,
              width: 44,
              height: 38,
              decoration: BoxDecoration(
                color: selected ? AppColors.ink : Colors.transparent,
                borderRadius: BorderRadius.circular(19),
              ),
              child: Icon(
                icon,
                size: 19,
                color: selected ? AppColors.onInk : AppColors.ink,
              ),
            ),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          seg(
            Icons.bubble_chart_rounded,
            !list,
            () => onChanged(false),
            'Bubbles',
          ),
          seg(Icons.view_agenda_rounded, list, () => onChanged(true), 'List'),
        ],
      ),
    );
  }
}

/// One chat row, on black.
class _ChatRow extends StatelessWidget {
  const _ChatRow({
    required this.node,
    required this.onTap,
    required this.onLongPress,
  });
  final BubbleNode node;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  static String _time(DateTime t) {
    final now = DateTime.now();
    final d = DateTime(
      now.year,
      now.month,
      now.day,
    ).difference(DateTime(t.year, t.month, t.day)).inDays;
    if (d == 0) {
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    if (d == 1) return 'Yesterday';
    if (d < 7) {
      return const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][t.weekday -
          1];
    }
    return '${t.day}/${t.month}';
  }

  String _preview(Message m) {
    final who = node.isGroup && !m.isMine && m.sender != null
        ? '${m.sender!.firstName}: '
        : (m.isMine ? 'You: ' : '');
    return switch (m.kind) {
      MessageKind.image => '$who📷 Photo',
      MessageKind.voice =>
        '$who🎤 Voice note${m.duration != null ? ' (${m.duration!.inSeconds}s)' : ''}',
      MessageKind.sticker => '$who${m.text} Sticker',
      MessageKind.text => '$who${m.text}',
    };
  }

  @override
  Widget build(BuildContext context) {
    final last = node.messages.isEmpty ? null : node.messages.last;
    final bold = node.unread > 0;
    final person = node.isGroup ? null : node.members.first;
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 9, 16, 9),
        child: Row(
          children: [
            SizedBox(
              width: 54,
              height: 54,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  node.isGroup
                      ? GroupAvatar(node.members, diameter: 54)
                      : PersonAvatar(person!, diameter: 54),
                  if (person != null && person.online)
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.online,
                          border: Border.all(color: AppColors.page, width: 2.5),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          node.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tx(
                            17,
                            weight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                      if (last != null)
                        Text(
                          _time(last.time),
                          style: tx(
                            13,
                            color: bold ? AppColors.link : AppColors.muted,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (last != null &&
                          last.isMine &&
                          last.kind == MessageKind.text)
                        Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.done_all_rounded,
                            size: 16,
                            color: AppColors.link,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          last == null
                              ? (node.isGroup
                                    ? '${node.members.length} members'
                                    : 'Say hi 👋')
                              : _preview(last),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tx(
                            15,
                            color: bold ? AppColors.ink : AppColors.muted,
                          ),
                        ),
                      ),
                      if (node.unread > 0)
                        FadeSlideIn(
                          scale: .3,
                          offset: Offset.zero,
                          duration: const Duration(milliseconds: 380),
                          child: Container(
                            margin: const EdgeInsets.only(left: 8),
                            constraints: const BoxConstraints(minWidth: 22),
                            height: 22,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accent,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Text(
                              '${node.unread}',
                              style: tx(
                                12,
                                weight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
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

/// The "+" button: opens three small actions in an arc.
class _SpeedDial extends StatefulWidget {
  const _SpeedDial({
    required this.onMap,
    required this.onAddFriend,
    required this.onNewGroup,
  });
  final VoidCallback? onMap;
  final VoidCallback onAddFriend;
  final VoidCallback onNewGroup;

  @override
  State<_SpeedDial> createState() => _SpeedDialState();
}

class _SpeedDialState extends State<_SpeedDial>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
  );
  bool get _open =>
      _anim.status == AnimationStatus.forward ||
      _anim.status == AnimationStatus.completed;

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() => _open ? _anim.reverse() : _anim.forward();

  void _run(VoidCallback? action) {
    _anim.reverse();
    action?.call();
  }

  @override
  Widget build(BuildContext context) {
    final actions = [
      (Icons.map_rounded, 'Map', widget.onMap, 0.0),
      (Icons.group_add_rounded, 'New group', widget.onNewGroup, pi / 4),
      (
        Icons.person_add_alt_1_rounded,
        'Add friend',
        widget.onAddFriend,
        pi / 2,
      ),
    ];
    return SizedBox(
      width: 140,
      height: 140,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (context, _) {
          final t = Motion.spring.transform(_anim.value);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Actions fan out up and to the left of the "+" button.
              for (final (icon, label, action, angle) in actions)
                Positioned(
                  right: 3 + 80 * t * sin(angle),
                  bottom: 3 + 80 * t * cos(angle),
                  child: IgnorePointer(
                    ignoring: _anim.value < .5,
                    child: Opacity(
                      opacity: _anim.value.clamp(0.0, 1.0),
                      child: Tooltip(
                        message: label,
                        child: Material(
                          color: AppColors.bubble,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _run(action),
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: Icon(icon, size: 22, color: AppColors.ink),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: AppColors.bubble,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _toggle,
                    child: SizedBox(
                      width: 50,
                      height: 50,
                      child: Transform.rotate(
                        angle: _anim.value * pi / 4,
                        child: Icon(Icons.add, size: 28, color: AppColors.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// New account with no friends yet: floating bubbles and a clear next step.
class _EmptyFriends extends StatefulWidget {
  const _EmptyFriends({required this.onFind});
  final VoidCallback onFind;

  @override
  State<_EmptyFriends> createState() => _EmptyFriendsState();
}

class _EmptyFriendsState extends State<_EmptyFriends>
    with SingleTickerProviderStateMixin {
  late final _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const colors = [
      Color(0xFFD0468C),
      Color(0xFF2F8FE0),
      Color(0xFF36A86B),
      Color(0xFFE5A52A),
    ];
    return FadeSlideIn(
      delay: const Duration(milliseconds: 250),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 240,
            height: 140,
            child: AnimatedBuilder(
              animation: _float,
              builder: (context, _) => Stack(
                children: [
                  for (var i = 0; i < 4; i++)
                    Positioned(
                      left: 20.0 + i * 50,
                      top: 40 + 18 * sin(_float.value * 2 * pi + i * 1.4),
                      child: Orb(
                        color: colors[i],
                        diameter: 56.0 - (i.isOdd ? 12 : 0),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Text(
            'Your bubbles live here.',
            style: tx(28, weight: FontWeight.w600, color: AppColors.ink),
          ),
          const SizedBox(height: 6),
          Text(
            'Add friends: each one becomes a bubble you can\nchat with, merge into groups and challenge.',
            textAlign: TextAlign.center,
            style: tx(15, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          Pressable(
            onTap: widget.onFind,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.person_search_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Find your friends',
                    style: tx(15, weight: FontWeight.w700, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
