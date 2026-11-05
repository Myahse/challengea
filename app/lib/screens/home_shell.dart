import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../theme.dart';
import 'chat_home.dart';
import 'map_screen.dart';

/// Swipeable pages with the dots from Figma: Chats, then the map.
/// On the map, one-finger drags move the map, so going back to Chats is done
/// with the dots or by swiping from the left edge.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.store});
  final ChatStore store;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  final _pages = PageController();
  int _page = 0;

  static const _count = 2;

  void _go(int page) => _pages.animateToPage(
    page,
    duration: const Duration(milliseconds: 380),
    curve: Curves.easeOutCubic,
  );

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      body: Stack(
        children: [
          PageView(
            controller: _pages,
            physics: _page == 1
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            onPageChanged: (p) => setState(() => _page = p),
            children: [
              ChatHome(store: widget.store, onOpenMap: () => _go(1)),
              MapScreen(store: widget.store),
            ],
          ),
          if (_page == 1)
            Positioned(
              left: 0,
              top: 120,
              bottom: 0,
              width: 22,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 150) _go(0);
                },
              ),
            ),
          Positioned(
            left: 0,
            right: 0,
            bottom: bottom + 10,
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
                              ? AppColors.ink
                              : AppColors.muted.withValues(alpha: .4),
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
