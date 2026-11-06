import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../games/challenge.dart';
import '../games/games.dart';
import '../widgets/motion.dart';
import '../theme.dart';
import 'chat_home.dart';
import 'chat_screen.dart';
import 'create.dart';
import 'home_feed.dart';
import 'incoming_call_screen.dart';
import 'map_screen.dart';
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

  static const _chats = 1, _videos = 2, _map = 3, _count = 4;

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

  /// Menu index (0 Home, 1 Chats, 2 = create, 3 Videos, 4 Map) -> page.
  static int _pageOf(int menu) => menu < 2 ? menu : menu - 1;
  static int _menuOf(int page) => page < 2 ? page : page + 1;

  void _onMenu(int menu) {
    if (menu == 2) {
      showCreateMenu(
        context,
        widget.store,
        onChallenge: () => challengeWithGame(context, widget.store, fourInRow),
        onNewGroup: () => _go(_chats),
      );
      return;
    }
    _go(_pageOf(menu));
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final onDark = _page == _videos;
    final inset = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: onDark ? Colors.black : AppColors.page,
      body: Stack(
        children: [
          PageView(
            controller: _pages,
            // Tabs change from the menu (each page owns its drags: bubbles, map, videos).
            physics: const NeverScrollableScrollPhysics(),
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              HomeFeed(
                store: store,
                onOpenMap: () => _go(_map),
                onOpenChats: () => _go(_chats),
              ),
              ChatHome(store: store, onOpenMap: () => _go(_map)),
              VideoFeed(
                store: store,
                posts: store.feed.forYou,
                following: store.feed.following(
                  store.friends.map((f) => f.id).toSet(),
                ),
                active: _page == _videos,
              ),
              MapScreen(store: store),
            ],
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: inset + 10,
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) => _BottomNav(
                index: _menuOf(_page),
                onDark: onDark,
                unread: store.nodes.where((n) => n.unread > 0).length,
                onSelect: _onMenu,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Floating, frosted menu with a gradient create button in the middle.
class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.index,
    required this.onDark,
    required this.unread,
    required this.onSelect,
  });

  final int index;
  final bool onDark;
  final int unread;
  final ValueChanged<int> onSelect;

  static const _items = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home_rounded, 'Home'),
    (Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded, 'Chats'),
    (Icons.add, Icons.add, ''),
    (Icons.smart_display_outlined, Icons.smart_display_rounded, 'Videos'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Map'),
  ];

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? Colors.white : AppColors.ink;
    final muted = onDark ? Colors.white60 : const Color(0xFF7A7A7A);
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: AnimatedContainer(
          duration: Motion.normal,
          height: 66,
          decoration: BoxDecoration(
            color: onDark
                ? Colors.black.withValues(alpha: .35)
                : Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: onDark
                  ? Colors.white12
                  : Colors.black.withValues(alpha: .05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              for (var i = 0; i < _items.length; i++)
                Expanded(
                  child: i == 2
                      ? Center(
                          child: Pressable(
                            scale: .85,
                            onTap: () => onSelect(2),
                            child: Container(
                              width: 50,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: const LinearGradient(
                                  colors: AppColors.brandGradient,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFFFF3D7F,
                                    ).withValues(alpha: .35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                          ),
                        )
                      : Pressable(
                          onTap: () => onSelect(i),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AnimatedScale(
                                scale: i == index ? 1.12 : 1,
                                duration: Motion.normal,
                                curve: Curves.easeOutBack,
                                child: Badge(
                                  isLabelVisible: i == 1 && unread > 0,
                                  label: Text('$unread'),
                                  backgroundColor: const Color(0xFF25D366),
                                  child: Icon(
                                    i == index ? _items[i].$2 : _items[i].$1,
                                    color: i == index ? fg : muted,
                                    size: 26,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              AnimatedDefaultTextStyle(
                                duration: Motion.fast,
                                style: tx(
                                  11,
                                  weight: i == index
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: i == index ? fg : muted,
                                ),
                                child: Text(_items[i].$3),
                              ),
                              // Little active dot.
                              AnimatedContainer(
                                duration: Motion.normal,
                                curve: Motion.ease,
                                margin: const EdgeInsets.only(top: 3),
                                width: i == index ? 16 : 0,
                                height: 3,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  gradient: const LinearGradient(
                                    colors: AppColors.brandGradient,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
