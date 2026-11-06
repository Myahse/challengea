import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../games/challenge.dart';
import '../theme.dart';
import 'chat_home.dart';
import 'chat_screen.dart';
import 'incoming_call_screen.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'video_feed.dart';

/// Swipeable pages with a floating menu: Chats, Map, Videos, Profile.
/// On the map, drags move the map, so the menu (or the screen edges) changes
/// page there.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final ChatStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _pages = PageController();
  int _page = 0;

  static const _map = 1, _videos = 2, _count = 4;

  void _go(int page) {
    final next = page.clamp(0, _count - 1);
    if (next == _page) return;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    // Online: live invites and notices from other phones.
    final online = widget.store.online;
    if (online != null) {
      online.onOpenChat = (node) {
        if (!mounted) return;
        widget.store.markRead(node);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatScreen(store: widget.store, node: node),
          ),
        );
      };
      online.onIncomingCall = (call) {
        if (mounted) IncomingCallScreen.show(context, widget.store, call);
      };
      online.onInvite = (m) {
        if (mounted) showInvite(context, widget.store, m);
      };
      online.onNotice = (text) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(text, style: tx(14, color: Colors.white)),
            ),
          );
      };
    }
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Widget _edge({required bool left}) => Positioned(
    left: left ? 0 : null,
    right: left ? null : 0,
    top: 120,
    bottom: 60,
    width: 22,
    child: GestureDetector(
      behavior: HitTestBehavior.translucent,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (left && v > 150) _go(_page - 1);
        if (!left && v < -150) _go(_page + 1);
      },
    ),
  );

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final onDark = _page == _videos;
    final inset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: onDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          PageView(
            controller: _pages,
            // Chats and the map own their drags (bubbles, the map).
            // The menu changes page there.
            physics: _page == _map || _page == 0
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              ChatHome(store: store, onOpenMap: () => _go(_map)),
              MapScreen(store: store),
              VideoFeed(
                store: store,
                posts: store.feed.forYou,
                active: _page == _videos,
              ),
              ProfileScreen(store: store, creator: store.feed.me),
            ],
          ),
          if (_page == _map) ...[_edge(left: true), _edge(left: false)],
          Positioned(
            left: 16,
            right: 16,
            bottom: inset + 10,
            child: _BottomNav(
              index: _page,
              onDark: onDark,
              onSelect: _go,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.onDark,
    required this.onSelect,
  });

  final int index;
  final bool onDark;
  final ValueChanged<int> onSelect;

  static const _items = <(IconData, String)>[
    (Icons.chat_bubble_rounded, 'Chats'),
    (Icons.map_rounded, 'Map'),
    (Icons.smart_display_rounded, 'Videos'),
    (Icons.person_rounded, 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : AppColors.ink;
    final muted = onDark ? const Color(0xFFC8C8C8) : const Color(0xFF5E5E5E);
    final wash = onDark ? Colors.white : AppColors.ink;
    return Row(
      children: [
        for (var i = 0; i < _items.length; i++)
          Expanded(
            child: _NavItem(
              icon: _items[i].$1,
              label: _items[i].$2,
              selected: i == index,
              color: i == index ? fg : muted,
              wash: wash,
              onTap: () => onSelect(i),
            ),
          ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.wash,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final Color wash;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? wash.withValues(alpha: .1) : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 22,
                color: color,
                shadows: const [
                  Shadow(color: Color(0x33000000), blurRadius: 8),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: tx(
                11,
                weight: selected ? FontWeight.w600 : FontWeight.w500,
                color: color,
              ).copyWith(
                shadows: const [
                  Shadow(color: Color(0x33000000), blurRadius: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
