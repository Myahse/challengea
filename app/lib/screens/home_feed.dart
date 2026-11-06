import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../feed.dart';
import '../games/challenge.dart';
import '../games/games.dart';
import '../models.dart';
import '../stories.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/city_map.dart';
import '../widgets/fake_video.dart';
import '../widgets/glass.dart';
import '../widgets/moments.dart';
import '../widgets/motion.dart';
import '../widgets/post_actions.dart';
import '../widgets/story_ring.dart';
import 'create.dart';
import 'live_screen.dart';
import 'post_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'story_viewer.dart';
import 'video_feed.dart';

/// Home: a calm headline, friends as bubbles, then big tiles for what they
/// shared, with games and the map between them.
class HomeFeed extends StatelessWidget {
  const HomeFeed({super.key, required this.store, required this.onOpenMap});
  final ChatStore store;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: AppColors.page,
      child: ListenableBuilder(
        listenable: Listenable.merge([store, store.feed]),
        builder: (context, _) {
          final posts = store.feed.home;
          final count = posts.length + 2;
          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(22, top + 76, 22, 24),
                      child: FadeSlideIn(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              const TextSpan(text: 'Your people.\n'),
                              TextSpan(
                                text: 'Right now.',
                                style: tx(
                                  46,
                                  weight: FontWeight.w600,
                                  color: AppColors.muted,
                                ),
                              ),
                            ],
                          ),
                          style: tx(46, weight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 120),
                      child: _StoriesRow(store: store),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: FadeSlideIn(
                      delay: const Duration(milliseconds: 220),
                      child: _Composer(store: store),
                    ),
                  ),
                  SliverList.builder(
                    itemCount: count,
                    itemBuilder: (context, i) {
                      if (i >= count - 3) store.feed.loadMore();
                      // The first post, then games and the map, then the rest.
                      final slot = posts.isEmpty ? i + 1 : i;
                      if (slot == 1) return _GamesCard(store: store);
                      if (slot == 2) {
                        return _NearbyCard(store: store, onOpenMap: onOpenMap);
                      }
                      if (posts.isEmpty) return const _EmptyFeed();
                      final post = posts[i == 0 ? 0 : i - 2];
                      return FadeSlideIn(
                        key: ValueKey(post.id),
                        delay: Duration(milliseconds: i == 0 ? 320 : 0),
                        child: PostCard(store: store, post: post),
                      );
                    },
                  ),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: 120),
                  ), // room for the floating menu
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _TopBar(store: store),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  const _EmptyFeed();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
    child: Text(
      'Nothing here yet.\nPost something, or add a friend.',
      textAlign: TextAlign.center,
      style: tx(17, color: AppColors.muted),
    ),
  );
}

// ---------------------------------------------------------------- top bar
class _TopBar extends StatelessWidget {
  const _TopBar({required this.store});
  final ChatStore store;

  @override
  Widget build(BuildContext context) {
    final requests = store.online?.incoming.length ?? 0;
    return Glass(
      radius: 0,
      tint: AppColors.page.withValues(alpha: .72),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          MediaQuery.paddingOf(context).top + 4,
          12,
          4,
        ),
        child: Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Challengea',
                  style: tx(20, weight: FontWeight.w600),
                ),
              ),
            ),
            _BarAction(
              icon: Icons.search_rounded,
              label: 'Search',
              onTap: () => SearchScreen.open(context, store),
            ),
            _BarAction(
              icon: Icons.notifications_none_rounded,
              label: 'Notifications',
              badge: requests,
              onTap: () => _notifications(context),
            ),
            const SizedBox(width: 6),
            Tooltip(
              message: 'My profile',
              child: Pressable(
                scale: .9,
                onTap: () => ProfileScreen.open(context, store, store.feed.me),
                child: PersonAvatar(store.me, diameter: 34),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _notifications(BuildContext context) {
    final items = <(IconData, String, String)>[
      for (final p in store.online?.incoming ?? const [])
        (Icons.person_add_alt_1, p.name, 'wants to be your friend'),
      (Icons.sports_esports_rounded, 'Marc', 'challenged you to Sudoku · 12m'),
      (Icons.favorite_rounded, 'Mélanie', 'reacted ❤️ to your post · 1h'),
      (Icons.comment_rounded, 'Brendon', 'commented: "Rematch tonight!" · 2h'),
      (Icons.location_on_rounded, 'Celine May', 'is nearby, in Marcory · 3h'),
    ];
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 8),
              child: Text(
                'Notifications',
                style: tx(28, weight: FontWeight.w600),
              ),
            ),
            for (var i = 0; i < items.length; i++)
              FadeSlideIn(
                delay: Duration(milliseconds: 40 * i),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.page,
                    child: Icon(items[i].$1, color: AppColors.ink),
                  ),
                  title: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: items[i].$2,
                          style: tx(15, weight: FontWeight.w600),
                        ),
                        TextSpan(text: ' ${items[i].$3}', style: tx(15)),
                      ],
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _BarAction extends StatelessWidget {
  const _BarAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Pressable(
        scale: .88,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Badge(
              isLabelVisible: badge > 0,
              label: Text('$badge'),
              backgroundColor: AppColors.accent,
              child: Icon(icon, size: 24, color: AppColors.ink),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- stories
class _StoriesRow extends StatelessWidget {
  const _StoriesRow({required this.store});
  final ChatStore store;

  @override
  Widget build(BuildContext context) {
    // Unseen first, like Snapchat.
    final stories = [...store.stories]
      ..sort((a, b) => (a.seen ? 1 : 0) - (b.seen ? 1 : 0));
    final mine = store.myStory.items.isNotEmpty;
    return SizedBox(
      height: 118,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
        clipBehavior: Clip.none,
        children: [
          _StoryTile(
            label: 'Your story',
            muted: true,
            onTap: () => mine
                ? StoryViewer.open(context, store, [store.myStory], 0)
                : openStoryCreator(context, store),
            child: mine
                ? StoryRing(person: store.me, size: 68)
                : Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.card,
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Icon(
                      Icons.add_rounded,
                      size: 26,
                      color: AppColors.accent,
                    ),
                  ),
          ),
          for (final live in store.online?.lives ?? const <OnlineLive>[])
            if (!store.online!.isMe(live.host))
              FadeSlideIn(
                key: ValueKey('live-${live.id}'),
                offset: const Offset(28, 0),
                child: _StoryTile(
                  label: live.host.firstName,
                  onTap: () => LiveScreen.watch(context, store, live),
                  child: _LiveBubble(person: live.host),
                ),
              ),
          for (var i = 0; i < stories.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 70 * i),
              offset: const Offset(28, 0),
              child: _StoryTile(
                label: stories[i].person.firstName,
                onTap: () => StoryViewer.open(context, store, stories, i),
                child: StoryRing(
                  person: stories[i].person,
                  seen: stories[i].seen,
                  size: 68,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A friend who is live right now: a red ring and a label.
class _LiveBubble extends StatelessWidget {
  const _LiveBubble({required this.person});
  final Person person;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 68,
    height: 68,
    child: Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          padding: const EdgeInsets.all(3.5),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.danger, width: 2),
          ),
          child: PersonAvatar(person, diameter: 57),
        ),
        Positioned(
          bottom: -5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'LIVE',
              style: tx(10, weight: FontWeight.w600, color: Colors.white),
            ),
          ),
        ),
      ],
    ),
  );
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.label,
    required this.child,
    required this.onTap,
    this.muted = false,
  });
  final String label;
  final Widget child;
  final VoidCallback onTap;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 84,
        child: Column(
          children: [
            child,
            const SizedBox(height: 8),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx(12, color: muted ? AppColors.muted : AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- composer
class _Composer extends StatelessWidget {
  const _Composer({required this.store});
  final ChatStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Container(
        height: 58,
        padding: const EdgeInsets.only(left: 20, right: 6),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(29),
        ),
        child: Row(
          children: [
            Expanded(
              child: Pressable(
                scale: .98,
                onTap: () => openPostComposer(context, store),
                child: SizedBox.expand(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'What’s on your mind?',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: tx(16, color: AppColors.muted),
                    ),
                  ),
                ),
              ),
            ),
            _BarAction(
              icon: Icons.photo_outlined,
              label: 'Photo',
              onTap: () => openPostComposer(context, store, pickPhoto: true),
            ),
            _BarAction(
              icon: Icons.auto_awesome_outlined,
              label: 'Story',
              onTap: () => openStoryCreator(context, store),
            ),
            _BarAction(
              icon: Icons.sports_esports_outlined,
              label: 'Challenge',
              onTap: () => challengeWithGame(context, store, fourInRow),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ games
class _GamesCard extends StatelessWidget {
  const _GamesCard({required this.store});
  final ChatStore store;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tales', style: tx(34, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  'Challenge a friend.',
                  style: tx(17, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: allGames.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final g = allGames[i];
                return FadeSlideIn(
                  delay: Duration(milliseconds: 70 * i),
                  offset: const Offset(28, 0),
                  child: Pressable(
                    onTap: () => challengeWithGame(context, store, g),
                    child: Container(
                      width: 148,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: AppColors.hero,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            right: -44,
                            bottom: -44,
                            child: Orb(
                              color: g.colors.first,
                              diameter: 136,
                              glow: 40,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            bottom: 8,
                            child: Icon(g.icon, color: Colors.white, size: 26),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: tx(
                                    20,
                                    weight: FontWeight.w600,
                                    color: AppColors.nightInk,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  g.playable ? '1 vs 1' : 'Coming soon',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tx(13, color: AppColors.nightMuted),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ nearby card
class _NearbyCard extends StatelessWidget {
  const _NearbyCard({required this.store, required this.onOpenMap});
  final ChatStore store;
  final VoidCallback onOpenMap;

  @override
  Widget build(BuildContext context) {
    final spots = store.spots.where((s) => s.online).take(4).toList();
    if (spots.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Pressable(
        scale: .98,
        onTap: onOpenMap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: SizedBox(
            height: 220,
            child: LayoutBuilder(
              builder: (context, box) => Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: CityMapPainter(
                        focus: store.myPosition,
                        zoom: .32,
                      ),
                    ),
                  ),
                  for (var i = 0; i < spots.length; i++)
                    Positioned(
                      left:
                          (box.maxWidth / 2 +
                                  (spots[i].position.dx - store.myPosition.dx) *
                                      .32 -
                                  21)
                              .clamp(6.0, box.maxWidth - 48),
                      top:
                          (84 +
                                  (spots[i].position.dy - store.myPosition.dy) *
                                      .32 -
                                  21)
                              .clamp(10.0, 100.0),
                      child: Floaty(
                        phase: i * .23,
                        child: PersonAvatar(spots[i].person, diameter: 42),
                      ),
                    ),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Glass(
                      radius: 22,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${spots.length} friends nearby',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tx(17, weight: FontWeight.w600),
                              ),
                            ),
                            TextLink(
                              label: 'Open map',
                              size: 15,
                              onTap: onOpenMap,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- posts
/// A post as one big tile. Short text cards go black and centered with a
/// glossy bubble rising from the bottom; everything else sits on white.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.store,
    required this.post,
    this.inScreen = false,
    this.onGone,
  });
  final ChatStore store;
  final Post post;

  /// Already on the post's own page: no need to open it again.
  final bool inScreen;

  /// The post was deleted or hidden.
  final VoidCallback? onGone;

  @override
  Widget build(BuildContext context) {
    final dark = post.textCard;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? AppColors.hero : AppColors.card,
        borderRadius: BorderRadius.circular(30),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: inScreen ? null : () => PostScreen.open(context, store, post),
        child: dark ? _hero(context) : _plain(context),
      ),
    );
  }

  String get _counts {
    final parts = [
      '${compact(post.likes)} ${post.likes == 1 ? 'like' : 'likes'}',
      if (post.commentCount > 0)
        '${compact(post.commentCount)} ${post.commentCount == 1 ? 'comment' : 'comments'}',
      if (post.shares > 0) '${compact(post.shares)} shares',
    ];
    return parts.join(' · ');
  }

  Widget _byline(BuildContext context, {required bool dark}) {
    final a = post.author;
    final muted = dark ? AppColors.nightMuted : AppColors.muted;
    return Row(
      mainAxisSize: dark ? MainAxisSize.min : MainAxisSize.max,
      children: [
        if (!dark) ...[
          Pressable(
            onTap: () => ProfileScreen.open(context, store, a),
            child: PersonAvatar(a.person, diameter: 40),
          ),
          const SizedBox(width: 10),
        ],
        Flexible(
          fit: dark ? FlexFit.loose : FlexFit.tight,
          child: GestureDetector(
            onTap: () => ProfileScreen.open(context, store, a),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: a.person.name,
                    style: tx(
                      15,
                      weight: FontWeight.w600,
                      color: dark ? AppColors.nightInk : AppColors.ink,
                    ),
                  ),
                  TextSpan(
                    text: ' · ${post.ago}',
                    style: tx(15, color: muted),
                  ),
                  if (post.live)
                    TextSpan(
                      text: ' · Live',
                      style: tx(
                        15,
                        weight: FontWeight.w600,
                        color: AppColors.danger,
                      ),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Post options',
          onPressed: () =>
              showPostOptions(context, store, post, onGone: onGone),
          icon: Icon(Icons.more_horiz, color: muted),
        ),
      ],
    );
  }

  Widget _links(BuildContext context, {required bool dark}) {
    final feed = store.feed;
    return Wrap(
      alignment: dark ? WrapAlignment.center : WrapAlignment.start,
      spacing: 20,
      children: [
        ReactionButton(post: post, feed: feed, dark: dark),
        if (!inScreen)
          TextLink(
            label: 'Reply',
            dark: dark,
            chevron: false,
            onTap: () => PostScreen.open(context, store, post),
          ),
        TextLink(
          label: 'Share',
          dark: dark,
          chevron: false,
          onTap: () => showSendTo(
            context,
            store,
            text:
                '📎 ${post.author.person.firstName}’s post: ${post.caption.isEmpty ? 'a photo' : post.caption}',
          ),
        ),
        if (!post.author.isMe)
          TextLink(
            label: 'Challenge',
            dark: dark,
            chevron: false,
            onTap: () => challengeFriend(context, store, post.author.person),
          ),
      ],
    );
  }

  /// Black tile: the words are the picture.
  Widget _hero(BuildContext context) {
    final n = post.caption.length;
    final size = n <= 44 ? 38.0 : (n <= 90 ? 30.0 : 24.0);
    final ball = post.shownColors.first;
    return GestureDetector(
      onDoubleTapDown: (d) => _doubleTap(context, d.globalPosition),
      onDoubleTap: () {},
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: -112,
            child: Floaty(
              distance: 8,
              seconds: 7,
              child: Orb(color: ball, diameter: 240, glow: 80),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
            child: Column(
              children: [
                _byline(context, dark: true),
                const SizedBox(height: 6),
                Text(
                  post.caption,
                  textAlign: TextAlign.center,
                  style: tx(
                    size,
                    weight: FontWeight.w600,
                    color: AppColors.nightInk,
                  ),
                ),
                const SizedBox(height: 10),
                _links(context, dark: true),
                Text(_counts, style: tx(14, color: AppColors.nightMuted)),
                const SizedBox(height: 152),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _doubleTap(BuildContext context, Offset at) {
    HapticFeedback.lightImpact();
    Burst.at(
      context,
      at,
      emoji: '❤️',
      count: 16,
      spread: 110,
      colors: const [AppColors.danger, Color(0xFFFF9DB5)],
    );
    if (post.reaction == null) store.feed.react(post, '❤️');
  }

  Widget _plain(BuildContext context) {
    final media = _media(context);
    final hasMedia = media != null;
    final short = !hasMedia && post.caption.length <= 90;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
          child: _byline(context, dark: false),
        ),
        if (post.caption.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Text.rich(
              TextSpan(
                children: [
                  for (final w
                      in '${post.caption} ${post.tags.join(' ')}'.trim().split(
                        ' ',
                      ))
                    TextSpan(
                      text: '$w ',
                      style: tx(
                        short ? 26 : 17,
                        weight: short ? FontWeight.w600 : FontWeight.w400,
                        color: w.startsWith('@') || w.startsWith('#')
                            ? AppColors.link
                            : AppColors.ink,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ?media,
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Text(_counts, style: tx(14, color: AppColors.muted)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
          child: _links(context, dark: false),
        ),
      ],
    );
  }

  Widget? _media(BuildContext context) {
    if (post.image != null) {
      return GestureDetector(
        onDoubleTapDown: (d) => _doubleTap(context, d.globalPosition),
        onDoubleTap: () {},
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: Image(
                image: post.image!,
                fit: BoxFit.cover,
                width: double.infinity,
              ),
            ),
          ),
        ),
      );
    }
    if (post.colors.isEmpty) return null;
    final video = post.kind == PostKind.video;
    return GestureDetector(
      onTap: video ? () => VideoFeed.open(context, store, [post], 0) : null,
      onDoubleTapDown: (d) => _doubleTap(context, d.globalPosition),
      onDoubleTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: AspectRatio(
            aspectRatio: video ? 4 / 5 : 1,
            child: Stack(
              fit: StackFit.expand,
              children: [
                FakeVideo(post: post, t: (post.id.hashCode % 100) / 100),
                if (video)
                  Center(
                    child: Glass(
                      radius: 32,
                      dark: true,
                      child: const SizedBox(
                        width: 64,
                        height: 64,
                        child: Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                  ),
                if (video && post.music.isNotEmpty)
                  Positioned(
                    left: 10,
                    bottom: 10,
                    right: 10,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Glass(
                        radius: 16,
                        dark: true,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.music_note_rounded,
                                color: Colors.white,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  post.music,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tx(13, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
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
}

const _reactions = ['👍', '❤️', '😂', '😮', '😢', '😡'];
const _reactionNames = {
  '👍': 'Liked',
  '❤️': 'Loved',
  '😂': 'Haha',
  '😮': 'Wow',
  '😢': 'Sad',
  '😡': 'Angry',
};

/// Like link: tap = 👍, long-press = pick a reaction (they rise in a row).
class ReactionButton extends StatefulWidget {
  const ReactionButton({
    super.key,
    required this.post,
    required this.feed,
    this.dark = false,
  });
  final Post post;
  final FeedData feed;
  final bool dark;

  @override
  State<ReactionButton> createState() => _ReactionButtonState();
}

class _ReactionButtonState extends State<ReactionButton> {
  OverlayEntry? _picker;

  void _open() {
    HapticFeedback.mediumImpact();
    final box = context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    _picker = OverlayEntry(
      builder: (_) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Positioned(
            left: (origin.dx).clamp(
              8.0,
              MediaQuery.sizeOf(context).width - 316,
            ),
            top: origin.dy - 68,
            child: FadeSlideIn(
              duration: Motion.normal,
              offset: const Offset(0, 16),
              scale: .8,
              child: Material(
                type: MaterialType.transparency,
                child: Glass(
                  radius: 30,
                  shadow: true,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var i = 0; i < _reactions.length; i++)
                          FadeSlideIn(
                            delay: Duration(milliseconds: 30 * i),
                            offset: const Offset(0, 20),
                            scale: .5,
                            duration: Motion.normal,
                            child: Pressable(
                              scale: 1.25,
                              onTap: () {
                                widget.feed.react(widget.post, _reactions[i]);
                                Burst.on(context, emoji: _reactions[i]);
                                _close();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                ),
                                child: Text(
                                  _reactions[i],
                                  style: const TextStyle(fontSize: 34),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_picker!);
  }

  void _close() {
    _picker?.remove();
    _picker = null;
  }

  @override
  void dispose() {
    _close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.post.reaction;
    final color = widget.dark ? AppColors.nightLink : AppColors.link;
    return Semantics(
      button: true,
      label: r == null ? 'Like' : _reactionNames[r],
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: _open,
        onTap: () {
          HapticFeedback.lightImpact();
          if (r == null) Burst.on(context, emoji: '👍');
          widget.feed.react(widget.post, r ?? '👍');
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: Motion.normal,
                switchInCurve: Motion.ease,
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: Tween(begin: .4, end: 1.0).animate(a),
                  child: FadeTransition(opacity: a, child: c),
                ),
                child: r == null
                    ? const SizedBox(key: ValueKey('none'))
                    : Padding(
                        key: ValueKey(r),
                        padding: const EdgeInsets.only(right: 5),
                        child: Text(r, style: const TextStyle(fontSize: 17)),
                      ),
              ),
              Text(
                r == null ? 'Like' : _reactionNames[r]!,
                style: tx(16, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens the story viewer on someone's story if they have one.
void openStoryOf(BuildContext context, ChatStore store, Story s) =>
    StoryViewer.open(context, store, [s], 0);
