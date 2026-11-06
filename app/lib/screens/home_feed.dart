import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
import '../feed.dart';
import '../games/challenge.dart';
import '../games/games.dart';
import '../stories.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/city_map.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/fake_video.dart';
import '../widgets/motion.dart';
import '../widgets/story_ring.dart';
import 'create.dart';
import 'profile_screen.dart';
import 'story_viewer.dart';
import 'video_feed.dart';

/// Home: Facebook-style feed with Snapchat-style stories on top.
class HomeFeed extends StatelessWidget {
  const HomeFeed({
    super.key,
    required this.store,
    required this.onOpenMap,
    required this.onOpenChats,
  });
  final ChatStore store;
  final VoidCallback onOpenMap;
  final VoidCallback onOpenChats;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.page,
      child: ListenableBuilder(
        listenable: Listenable.merge([store, store.feed]),
        builder: (context, _) {
          final posts = store.feed.home;
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: _TopBar(store: store, onOpenChats: onOpenChats),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(child: _StoriesRow(store: store)),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 80),
                  child: _Composer(store: store),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 140),
                  child: _GamesCard(store: store),
                ),
              ),
              SliverToBoxAdapter(
                child: FadeSlideIn(
                  delay: const Duration(milliseconds: 200),
                  child: _NearbyCard(store: store, onOpenMap: onOpenMap),
                ),
              ),
              SliverList.builder(
                itemCount: posts.length,
                itemBuilder: (context, i) => FadeSlideIn(
                  key: ValueKey(posts[i].id),
                  delay: Duration(milliseconds: i < 4 ? 240 + i * 60 : 0),
                  child: PostCard(store: store, post: posts[i]),
                ),
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 110),
              ), // room for the floating menu
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------- top bar
class _TopBar extends StatelessWidget {
  const _TopBar({required this.store, required this.onOpenChats});
  final ChatStore store;
  final VoidCallback onOpenChats;

  @override
  Widget build(BuildContext context) {
    final unread = store.nodes.where((b) => b.unread > 0).length;
    final requests = store.online?.incoming.length ?? 0;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 8,
        8,
        8,
      ),
      child: Row(
        children: [
          Pressable(
            onTap: () => ProfileScreen.open(context, store, store.feed.me),
            child: PersonAvatar(store.me, diameter: 38),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ShaderMask(
                shaderCallback: (r) => const LinearGradient(
                  colors: [Color(0xFF111111), Color(0xFF444444)],
                ).createShader(r),
                child: Text(
                  'Challengea',
                  style: tx(
                    26,
                    weight: FontWeight.w800,
                    color: Colors.white,
                  ).copyWith(letterSpacing: -1),
                ),
              ),
            ),
          ),
          const Spacer(),
          _RoundAction(
            icon: Icons.search_rounded,
            onTap: () => _soon(context, 'Search'),
          ),
          _RoundAction(
            icon: Icons.notifications_none_rounded,
            badge: requests,
            onTap: () => _notifications(context),
          ),
          _RoundAction(
            icon: Icons.chat_bubble_outline_rounded,
            badge: unread,
            onTap: onOpenChats,
          ),
        ],
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
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                'Notifications',
                style: tx(22, weight: FontWeight.w800),
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
                          style: tx(14, weight: FontWeight.w700),
                        ),
                        TextSpan(text: ' ${items[i].$3}', style: tx(14)),
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

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.onTap, this.badge = 0});
  final IconData icon;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.page,
        ),
        child: Badge(
          isLabelVisible: badge > 0,
          label: Text('$badge'),
          backgroundColor: const Color(0xFFFF3D7F),
          child: Icon(icon, size: 22, color: AppColors.ink),
        ),
      ),
    );
  }
}

void _soon(BuildContext context, String what) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text('$what: coming soon', style: tx(14, color: Colors.white)),
      ),
    );
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
    return Container(
      color: Colors.white,
      height: 118,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          _StoryTile(
            label: 'Your story',
            onTap: () => store.myStory.items.isEmpty
                ? openStoryCreator(context, store)
                : StoryViewer.open(context, store, [store.myStory], 0),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                StoryRing(
                  person: store.me,
                  hasStory: store.myStory.items.isNotEmpty,
                  size: 66,
                ),
                Positioned(
                  right: -2,
                  bottom: -2,
                  child: GestureDetector(
                    onTap: () => openStoryCreator(context, store),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: AppColors.brandGradient,
                        ),
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (var i = 0; i < stories.length; i++)
            FadeSlideIn(
              delay: Duration(milliseconds: 60 * i),
              offset: const Offset(30, 0),
              scale: .8,
              child: _StoryTile(
                label: stories[i].person.firstName,
                onTap: () => StoryViewer.open(context, store, stories, i),
                child: StoryRing(
                  person: stories[i].person,
                  seen: stories[i].seen,
                  size: 66,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryTile extends StatelessWidget {
  const _StoryTile({
    required this.label,
    required this.child,
    required this.onTap,
  });
  final String label;
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            child,
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tx(12, weight: FontWeight.w500),
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
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        children: [
          Row(
            children: [
              PersonAvatar(store.me, diameter: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Pressable(
                  scale: .98,
                  onTap: () => openPostComposer(context, store),
                  child: Container(
                    height: 42,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(
                      'What’s on your mind, ${store.me.firstName}?',
                      style: tx(15, color: AppColors.muted),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 18, color: AppColors.line),
          Row(
            children: [
              _ComposerChip(
                icon: Icons.photo_library_rounded,
                color: const Color(0xFF45BD62),
                label: 'Photo',
                onTap: () => openPostComposer(context, store, pickPhoto: true),
              ),
              _ComposerChip(
                icon: Icons.auto_awesome_rounded,
                color: const Color(0xFFFF3D7F),
                label: 'Story',
                onTap: () => openStoryCreator(context, store),
              ),
              _ComposerChip(
                icon: Icons.sports_esports_rounded,
                color: const Color(0xFF8B6CF6),
                label: 'Challenge',
                onTap: () => challengeWithGame(context, store, fourInRow),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ComposerChip extends StatelessWidget {
  const _ComposerChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Pressable(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: tx(
                  14,
                  weight: FontWeight.w600,
                  color: const Color(0xFF555555),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ------------------------------------------------------------------ games
class _GamesCard extends StatelessWidget {
  const _GamesCard({required this.store});
  final ChatStore store;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(0, 14, 0, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, size: 20),
                const SizedBox(width: 6),
                Text('Tales', style: tx(17, weight: FontWeight.w800)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    '· challenge a friend',
                    style: tx(13, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 128,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: allGames.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final g = allGames[i];
                return Pressable(
                  onTap: () => challengeWithGame(context, store, g),
                  child: Container(
                    width: 112,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: g.colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(g.icon, color: Colors.white, size: 30),
                            const Spacer(),
                            if (!g.playable)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'soon',
                                  style: tx(
                                    10,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          g.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tx(
                            15,
                            weight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          g.playable ? '1 vs 1' : 'Coming soon',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tx(11, color: Colors.white70),
                        ),
                      ],
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
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      child: Pressable(
        scale: .98,
        onTap: onOpenMap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: SizedBox(
            height: 150,
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
                  for (final s in spots)
                    Positioned(
                      left:
                          (box.maxWidth / 2 +
                                  (s.position.dx - store.myPosition.dx) * .32 -
                                  18)
                              .clamp(6.0, box.maxWidth - 42),
                      top:
                          (75 +
                                  (s.position.dy - store.myPosition.dy) * .32 -
                                  18)
                              .clamp(6.0, 60.0),
                      child: PersonAvatar(s.person, diameter: 36, border: 2.5),
                    ),
                  Positioned(
                    left: 12,
                    bottom: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFFFF3D7F),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${spots.length} friends nearby',
                              style: tx(15, weight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            'Open map',
                            style: tx(
                              13,
                              weight: FontWeight.w700,
                              color: AppColors.like,
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
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- posts
/// A post in the home feed: who, text, photo/video, reactions, comment, share.
class PostCard extends StatelessWidget {
  const PostCard({super.key, required this.store, required this.post});
  final ChatStore store;
  final Post post;

  @override
  Widget build(BuildContext context) {
    final a = post.author;
    final feed = store.feed;
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
            child: Row(
              children: [
                Pressable(
                  onTap: () => ProfileScreen.open(context, store, a),
                  child: PersonAvatar(a.person, diameter: 42),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.person.name,
                        style: tx(15, weight: FontWeight.w700),
                      ),
                      Row(
                        children: [
                          Text(
                            '${post.ago} · ',
                            style: tx(12, color: AppColors.muted),
                          ),
                          Icon(
                            post.live
                                ? Icons.sensors_rounded
                                : Icons.public_rounded,
                            size: 13,
                            color: post.live
                                ? const Color(0xFFE5484D)
                                : AppColors.muted,
                          ),
                          if (post.live)
                            Text(
                              ' LIVE',
                              style: tx(
                                11,
                                weight: FontWeight.w800,
                                color: const Color(0xFFE5484D),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => _soon(context, 'Post options'),
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
          ),
          if (post.caption.isNotEmpty && !post.textCard)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: Text.rich(
                TextSpan(
                  children: [
                    for (final w
                        in '${post.caption} ${post.tags.join(' ')}'
                            .trim()
                            .split(' '))
                      TextSpan(
                        text: '$w ',
                        style: w.startsWith('@') || w.startsWith('#')
                            ? tx(
                                15,
                                weight: FontWeight.w600,
                                color: AppColors.like,
                              )
                            : tx(15),
                      ),
                  ],
                ),
              ),
            ),
          _media(context),
          // Counts.
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Row(
              children: [
                _ReactionStack(post: post),
                const SizedBox(width: 6),
                AnimatedSwitcher(
                  duration: Motion.fast,
                  child: Text(
                    compact(post.likes),
                    key: ValueKey(post.likes),
                    style: tx(13, color: AppColors.muted),
                  ),
                ),
                const Spacer(),
                Flexible(
                  child: Text(
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    '${compact(post.commentCount)} comments · ${compact(post.shares)} shares',
                    style: tx(13, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
          const Divider(
            height: 1,
            indent: 14,
            endIndent: 14,
            color: AppColors.line,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            child: Row(
              children: [
                Expanded(
                  child: ReactionButton(post: post, feed: feed),
                ),
                Expanded(
                  child: _Action(
                    icon: Icons.mode_comment_outlined,
                    label: 'Comment',
                    onTap: () => showComments(context, feed, post),
                  ),
                ),
                Expanded(
                  child: _Action(
                    icon: Icons.near_me_outlined,
                    label: 'Share',
                    onTap: () => _share(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _media(BuildContext context) {
    if (post.textCard) {
      return AspectRatio(
        aspectRatio: 1.25,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: post.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                post.caption,
                textAlign: TextAlign.center,
                style: tx(28, weight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
        ),
      );
    }
    if (post.photo != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Image.memory(
          post.photo!,
          fit: BoxFit.cover,
          width: double.infinity,
        ),
      );
    }
    if (post.colors.isEmpty) return const SizedBox.shrink();
    final video = post.kind == PostKind.video;
    return GestureDetector(
      onTap: video ? () => VideoFeed.open(context, store, [post], 0) : null,
      onDoubleTap: () {
        HapticFeedback.lightImpact();
        if (post.reaction == null) store.feed.react(post, '❤️');
      },
      child: AspectRatio(
        aspectRatio: video ? 4 / 5 : 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FakeVideo(post: post, t: (post.id.hashCode % 100) / 100),
            if (video)
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: .35),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            if (video && post.music.isNotEmpty)
              Positioned(
                left: 12,
                bottom: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
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
                      Text(post.music, style: tx(12, color: Colors.white)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _share(BuildContext context) {
    final friends = store.friends.take(8).toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text('Send to', style: tx(20, weight: FontWeight.w800)),
            ),
            SizedBox(
              height: 96,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final p in friends)
                    Pressable(
                      onTap: () {
                        Navigator.pop(ctx);
                        store.send(
                          store.nodeFor(p),
                          '📎 ${post.author.person.firstName}’s post: ${post.caption}',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sent to ${p.firstName}',
                              style: tx(14, color: Colors.white),
                            ),
                          ),
                        );
                      },
                      child: SizedBox(
                        width: 76,
                        child: Column(
                          children: [
                            PersonAvatar(p, diameter: 56),
                            const SizedBox(height: 6),
                            Text(
                              p.firstName,
                              style: tx(12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: const Color(0xFF555555)),
          const SizedBox(width: 6),
          Text(
            label,
            style: tx(
              14,
              weight: FontWeight.w600,
              color: const Color(0xFF555555),
            ),
          ),
        ],
      ),
    ),
  );
}

const _reactions = ['👍', '❤️', '😂', '😮', '😢', '😡'];
const _reactionNames = {
  '👍': 'Like',
  '❤️': 'Love',
  '😂': 'Haha',
  '😮': 'Wow',
  '😢': 'Sad',
  '😡': 'Angry',
};
const _reactionColors = {
  '👍': AppColors.like,
  '❤️': Color(0xFFF33E58),
  '😂': Color(0xFFF7B125),
  '😮': Color(0xFFF7B125),
  '😢': Color(0xFFF7B125),
  '😡': Color(0xFFE9710F),
};

/// Like button: tap = 👍, long-press = pick a reaction (they pop up in a row).
class ReactionButton extends StatefulWidget {
  const ReactionButton({super.key, required this.post, required this.feed});
  final Post post;
  final FeedData feed;

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
            top: origin.dy - 64,
            child: FadeSlideIn(
              duration: Motion.normal,
              offset: const Offset(0, 16),
              scale: .7,
              child: Material(
                elevation: 8,
                shadowColor: Colors.black26,
                borderRadius: BorderRadius.circular(32),
                color: Colors.white,
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
                          scale: .3,
                          duration: const Duration(milliseconds: 380),
                          child: Pressable(
                            scale: 1.3,
                            onTap: () {
                              widget.feed.react(widget.post, _reactions[i]);
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
    final color = r == null ? const Color(0xFF555555) : _reactionColors[r]!;
    return GestureDetector(
      onLongPress: _open,
      child: Pressable(
        onTap: () => widget.feed.react(widget.post, r ?? '👍'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (c, a) => ScaleTransition(
                  scale: CurvedAnimation(parent: a, curve: Curves.elasticOut),
                  child: c,
                ),
                child: r == null
                    ? const Icon(
                        Icons.thumb_up_alt_outlined,
                        size: 20,
                        color: Color(0xFF555555),
                        key: ValueKey('none'),
                      )
                    : Text(
                        r,
                        key: ValueKey(r),
                        style: const TextStyle(fontSize: 19),
                      ),
              ),
              const SizedBox(width: 6),
              Text(
                r == null ? 'Like' : _reactionNames[r]!,
                style: tx(14, weight: FontWeight.w600, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The little pile of reaction emojis next to the count.
class _ReactionStack extends StatelessWidget {
  const _ReactionStack({required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    final shown = <String>{
      if (post.reaction != null) post.reaction!,
      '👍',
      '❤️',
      if (post.likes > 500) '😂',
    }.take(3).toList();
    return SizedBox(
      width: 14.0 * shown.length + 8,
      height: 22,
      child: Stack(
        children: [
          for (var i = 0; i < shown.length; i++)
            Positioned(
              left: i * 14.0,
              child: Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Text(shown[i], style: const TextStyle(fontSize: 13)),
              ),
            ),
        ],
      ),
    );
  }
}

/// Opens the story viewer on someone's story if they have one.
void openStoryOf(BuildContext context, ChatStore store, Story s) =>
    StoryViewer.open(context, store, [s], 0);
