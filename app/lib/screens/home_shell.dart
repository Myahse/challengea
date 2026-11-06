import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../games/challenge.dart';
import '../theme.dart';
import 'chat_home.dart';
import 'map_screen.dart';
import 'profile_screen.dart';
import 'video_feed.dart';

/// Swipeable pages with the 4 dots from Figma: Chats, Map, Videos, Profile.
/// On the map, drags move the map, so the dots (or the screen edges) change
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

  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    // Online: live invites and notices from other phones.
    final online = widget.store.online;
    if (online != null) {
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
    final bottom = MediaQuery.paddingOf(context).bottom;
    final store = widget.store;
    final onDark = _page == _videos;
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pages,
            physics: _page == _map
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
            left: 0,
            right: 0,
            bottom: bottom + 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _count; i++)
                  GestureDetector(
                    onTap: () => _go(i),
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: i == _page ? 18 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: i == _page
                              ? (onDark ? Colors.white : AppColors.ink)
                              : (onDark
                                    ? Colors.white54
                                    : AppColors.muted.withValues(alpha: .4)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
