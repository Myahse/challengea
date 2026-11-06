import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../feed.dart';
import '../games/challenge.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/fake_video.dart';
import '../widgets/glass.dart';
import '../widgets/moments.dart';
import '../widgets/motion.dart';
import '../widgets/post_actions.dart';
import 'account_screen.dart';
import 'chat_screen.dart';
import 'video_feed.dart';

/// A person: their bubble, name and numbers, then what they shared.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.store,
    required this.creator,
    this.pushed = false,
  });
  final ChatStore store;
  final Creator creator;
  final bool pushed;

  static Future<void> open(
    BuildContext context,
    ChatStore store,
    Creator creator,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ProfileScreen(store: store, creator: creator, pushed: true),
      ),
    );
  }

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _scroll = ScrollController();
  final _gridKey = GlobalKey();
  final _followKey = GlobalKey();
  int _tab = 0;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Creator get c => widget.creator;
  FeedData get feed => widget.store.feed;

  void _selectTab(int i) {
    setState(() => _tab = i);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _gridKey.currentContext;
      if (target == null || !target.mounted) return;
      Scrollable.ensureVisible(
        target,
        alignment: 0.05,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    });
  }

  List<Post> get _shown => switch (_tab) {
    1 => c.posts.where((p) => p.kind == PostKind.video).toList(),
    2 => c.posts.where((p) => p.kind == PostKind.story).toList(),
    3 =>
      c.posts
          .where((p) => p.kind != PostKind.story)
          .toList()
          .reversed
          .toList(), // tagged (demo)
    _ => c.posts,
  };

  void _message() {
    final node = widget.store.nodeFor(c.person);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(store: widget.store, node: node),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.page,
      body: ListenableBuilder(
        listenable: feed,
        builder: (context, _) {
          final shown = _shown;
          return Stack(
            children: [
              CustomScrollView(
                controller: _scroll,
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabsHeader(
                      leftInset: widget.pushed ? 56 : 0,
                      top: top,
                      tabs: _tabLabels(),
                      selected: _tab,
                      onSelect: _selectTab,
                    ),
                  ),
                  SliverToBoxAdapter(child: SizedBox(key: _gridKey, height: 1)),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      12,
                      8,
                      12,
                      MediaQuery.paddingOf(context).bottom + 110,
                    ),
                    sliver: shown.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Text(
                                'Nothing here yet',
                                textAlign: TextAlign.center,
                                style: tx(17, color: AppColors.muted),
                              ),
                            ),
                          )
                        : SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                ),
                            itemCount: shown.length,
                            // Tiles pop in one after another (first rows only).
                            itemBuilder: (context, i) => FadeSlideIn(
                              key: ValueKey('$_tab-$i'),
                              delay: Duration(
                                milliseconds: 40 * (i < 15 ? i : 15),
                              ),
                              scale: .94,
                              child: Pressable(
                                onTap: () => VideoFeed.open(
                                  context,
                                  widget.store,
                                  shown,
                                  i,
                                ),
                                child: PostThumb(post: shown[i]),
                              ),
                            ),
                          ),
                  ),
                ],
              ),
              if (c.isMe)
                Positioned(
                  right: 12,
                  top: top + 8,
                  child: Glass(
                    radius: 24,
                    child: IconButton(
                      tooltip: 'Account and settings',
                      onPressed: () =>
                          AccountScreen.open(context, widget.store),
                      icon: const Icon(Icons.settings_outlined, size: 22),
                    ),
                  ),
                ),
              if (widget.pushed)
                Positioned(
                  left: 12,
                  top: top + 8,
                  child: Glass(
                    radius: 24,
                    child: IconButton(
                      tooltip: 'Back',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 20,
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

  List<String> _tabLabels() => [
    '${c.posts.length} ${c.posts.length == 1 ? 'post' : 'posts'}',
    '${c.count(PostKind.video)} Videos',
    '${c.count(PostKind.story)} Stories',
    '${c.tagged} tags',
  ];

  Widget _header() {
    final p = c.person;
    final top = MediaQuery.paddingOf(context).top;
    return Padding(
      padding: EdgeInsets.fromLTRB(12, top + 24, 12, 12),
      child: Column(
        children: [
          Floaty(
            distance: 8,
            seconds: 6,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: p.color.withValues(alpha: .3),
                    blurRadius: 40,
                    offset: const Offset(0, 24),
                  ),
                ],
              ),
              child: PersonAvatar(p, diameter: 132),
            ),
          ),
          const SizedBox(height: 22),
          FadeSlideIn(
            child: Column(
              children: [
                Text(
                  p.name,
                  textAlign: TextAlign.center,
                  style: tx(44, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text('@${c.handle}', style: tx(17, color: AppColors.muted)),
                if (c.bio.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: _bio(),
                  ),
                const SizedBox(height: 4),
                _actions(),
              ],
            ),
          ),
          const SizedBox(height: 14),
          FadeSlideIn(
            delay: const Duration(milliseconds: 120),
            child: _numbers(),
          ),
        ],
      ),
    );
  }

  Widget _actions() {
    if (c.isMe) {
      return TextLink(
        label: 'Edit profile',
        onTap: () => showEditProfile(
          context,
          widget.store,
          onSaved: () => setState(() {}),
        ),
      );
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Pressable(
          onTap: () {
            final pill = _followKey.currentContext;
            if (!c.followed && pill != null) Burst.on(pill);
            feed.toggleFollow(c);
          },
          child: AnimatedContainer(
            key: _followKey,
            duration: Motion.fast,
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 22),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.followed ? AppColors.bubble : AppColors.accent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Text(
              c.followed ? 'Following' : 'Follow',
              style: tx(
                16,
                weight: FontWeight.w500,
                color: c.followed ? AppColors.ink : Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        TextLink(label: 'Message', onTap: _message),
      ],
    );
  }

  /// One big number on black, two smaller ones on white.
  Widget _numbers() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
          decoration: BoxDecoration(
            color: AppColors.hero,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Followers', style: tx(15, color: AppColors.nightMuted)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: CountUp(
                  value: c.followers,
                  format: compact,
                  style: tx(
                    72,
                    weight: FontWeight.w600,
                    color: AppColors.nightInk,
                  ),
                ),
              ),
              c.isMe
                  ? TextLink(
                      label: 'Share profile',
                      dark: true,
                      onTap: () => showSendTo(
                        context,
                        widget.store,
                        title: 'Share my profile',
                        text: profileShareText(c.person, c.handle),
                      ),
                    )
                  : TextLink(
                      label: 'Challenge ${c.person.firstName}',
                      dark: true,
                      onTap: () =>
                          challengeFriend(context, widget.store, c.person),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            _stat(c.following, 'Following'),
            const SizedBox(width: 10),
            _stat(c.likes, 'Likes'),
          ],
        ),
      ],
    );
  }

  Widget _stat(int value, String label) => Expanded(
    child: Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CountUp(
            value: value,
            format: compact,
            style: tx(40, weight: FontWeight.w600),
          ),
          Text(label, style: tx(15, color: AppColors.muted)),
        ],
      ),
    ),
  );

  Widget _bio() => Text.rich(
    TextSpan(
      children: [
        for (final w in c.bio.split(' '))
          TextSpan(
            text: '$w ',
            style: tx(
              17,
              color: w.startsWith('@') ? AppColors.link : AppColors.muted,
            ),
          ),
      ],
    ),
    textAlign: TextAlign.center,
  );
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader({
    required this.top,
    required this.tabs,
    required this.selected,
    required this.onSelect,
    this.leftInset = 0,
  });
  final double top;
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onSelect;

  /// Room for the back button once the tabs stick to the top.
  final double leftInset;

  @override
  double get minExtent => 60 + top;
  @override
  double get maxExtent => 60 + top;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // Status-bar space only matters once the tabs stick to the top.
    final pinned = shrinkOffset > 0 || overlapsContent;
    return Container(
      height: maxExtent,
      color: AppColors.page,
      padding: EdgeInsets.only(
        top: pinned ? top : 0,
        bottom: pinned ? 0 : top,
        left: pinned ? leftInset + 8 : 8,
        right: 8,
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: Pressable(
                onTap: () => onSelect(i),
                child: AnimatedContainer(
                  duration: Motion.fast,
                  height: 44,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == selected ? AppColors.ink : Colors.transparent,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tabs[i],
                      style: tx(
                        15,
                        color: i == selected ? AppColors.onInk : AppColors.ink,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(_TabsHeader old) =>
      old.selected != selected ||
      old.leftInset != leftInset ||
      old.tabs.join() != tabs.join() ||
      old.top != top;
}
