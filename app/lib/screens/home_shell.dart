import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
import '../games/challenge.dart';
import '../games/games.dart';
import '../widgets/glass.dart';
import '../widgets/moments.dart';
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
      online.onFriendAccepted = (person) {
        if (mounted) {
          showMeet(
            context,
            a: widget.store.me,
            b: person,
            title: 'You’re friends',
            subtitle: 'You and ${person.firstName} can chat and play now',
          );
        }
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
    final darkBars = onDark || AppColors.dark;
    final inset = MediaQuery.paddingOf(context).bottom;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkBars ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: onDark ? AppColors.night : AppColors.page,
        body: Stack(
          children: [
            PageView(
              controller: _pages,
              // Tabs change from the menu (each page owns its drags: bubbles, map, videos).
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (p) => setState(() => _page = p),
              children: [
                HomeFeed(store: store, onOpenMap: () => _go(_map)),
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
              left: 22,
              right: 22,
              bottom: inset + 12,
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
      ),
    );
  }
}

/// Floating glass menu. A soft pill slides to the page you are on.
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
    (Icons.bubble_chart_outlined, Icons.bubble_chart_rounded, 'Chats'),
    (Icons.add_rounded, Icons.add_rounded, 'Create'),
    (Icons.smart_display_outlined, Icons.smart_display_rounded, 'Videos'),
    (Icons.explore_outlined, Icons.explore_rounded, 'Map'),
  ];

  @override
  Widget build(BuildContext context) {
    final fg = onDark ? AppColors.nightInk : AppColors.ink;
    final active = onDark ? AppColors.nightLink : AppColors.link;
    return Glass(
      radius: 32,
      dark: onDark,
      shadow: true,
      child: SizedBox(
        height: 64,
        child: Stack(
          children: [
            // The pill follows the page and stretches like liquid on the way.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: index.toDouble(), end: index.toDouble()),
              duration: const Duration(milliseconds: 460),
              curve: Motion.ease,
              builder: (context, v, _) {
                final stretch = sin((v - v.floor()) * pi);
                return Align(
                  alignment: Alignment(-1 + v / 2, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / _items.length,
                    child: OverflowBox(
                      minWidth: 0,
                      maxWidth: 200,
                      child: Center(
                        child: Container(
                          width: 52 + 44 * stretch,
                          height: 52 - 10 * stretch,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(26),
                            color: active.withValues(alpha: .13),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            Row(
              children: [
                for (var i = 0; i < _items.length; i++)
                  Expanded(
                    child: i == 2
                        ? _create(fg)
                        : _item(i, i == index ? active : fg),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _create(Color fg) => Center(
    child: Tooltip(
      message: _items[2].$3,
      child: Pressable(
        scale: .88,
        onTap: () => onSelect(2),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
          child: Icon(
            Icons.add_rounded,
            size: 26,
            color: onDark ? AppColors.night : AppColors.onInk,
          ),
        ),
      ),
    ),
  );

  Widget _item(int i, Color color) => Tooltip(
    message: _items[i].$3,
    child: Pressable(
      scale: .88,
      onTap: () => onSelect(i),
      child: SizedBox.expand(
        child: Center(
          child: Badge(
            isLabelVisible: i == 1 && unread > 0,
            label: Text('$unread'),
            backgroundColor: AppColors.accent,
            child: AnimatedScale(
              scale: i == index ? 1.14 : 1,
              duration: Motion.normal,
              curve: const Cubic(.2, 1.9, .4, 1),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                child: Icon(
                  i == index ? _items[i].$2 : _items[i].$1,
                  key: ValueKey(i == index),
                  color: color,
                  size: 25,
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
