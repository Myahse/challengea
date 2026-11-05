import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../chat_store.dart';
import '../feed.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/comments_sheet.dart';
import '../widgets/fake_video.dart';
import '../widgets/product_sheet.dart';
import 'profile_screen.dart';

/// Figma: video frames 48:261 / 48:331, live with products 57:220.
/// Swipe up for the next video, double-tap to like, tap to pause.
class VideoFeed extends StatefulWidget {
  const VideoFeed({
    super.key,
    required this.store,
    required this.posts,
    this.initialIndex = 0,
    this.pushed = false,
    this.active = true,
  });
  final ChatStore store;
  final List<Post> posts;
  final int initialIndex;

  /// Opened from a profile (shows a back button).
  final bool pushed;

  /// False when the page is not on screen (videos pause).
  final bool active;

  static Future<void> open(
    BuildContext context,
    ChatStore store,
    List<Post> posts,
    int index,
  ) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoFeed(
          store: store,
          posts: posts,
          initialIndex: index,
          pushed: true,
        ),
      ),
    );
  }

  @override
  State<VideoFeed> createState() => _VideoFeedState();
}

class _VideoFeedState extends State<VideoFeed> {
  late final _pages = PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final current = widget.posts[_index];
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            scrollDirection: Axis.vertical,
            itemCount: widget.posts.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _VideoPage(
              store: widget.store,
              post: widget.posts[i],
              playing: widget.active && i == _index,
              bottomInset: widget.pushed ? 12 : 34,
            ),
          ),
          // Header: Live badge or back button, title, search.
          Positioned(
            left: 0,
            right: 0,
            top: top + 8,
            child: Row(
              children: [
                const SizedBox(width: 12),
                if (widget.pushed)
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                    ),
                  )
                else
                  const SizedBox(width: 48),
                if (current.live) ...[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFE5484D),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Live',
                    style: tx(16, weight: FontWeight.w600, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${compact(current.watching)} watching',
                    style: tx(11, color: Colors.white70),
                  ),
                ],
                const Spacer(),
                IconButton(
                  tooltip: 'Search',
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Search comes with the backend',
                        style: tx(14, color: Colors.white),
                      ),
                    ),
                  ),
                  icon: const Icon(
                    Icons.search_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
          if (!current.live)
            Positioned(
              left: 0,
              right: 0,
              top: top + 20,
              child: IgnorePointer(
                child: Text(
                  'Video',
                  textAlign: TextAlign.center,
                  style: tx(16, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPage extends StatefulWidget {
  const _VideoPage({
    required this.store,
    required this.post,
    required this.playing,
    required this.bottomInset,
  });
  final ChatStore store;
  final Post post;
  final bool playing;
  final double bottomInset;

  @override
  State<_VideoPage> createState() => _VideoPageState();
}

class _VideoPageState extends State<_VideoPage> with TickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );
  late final _heart = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  Offset _heartAt = Offset.zero;
  bool _paused = false;
  bool _expanded = false;

  Post get post => widget.post;
  FeedData get feed => widget.store.feed;

  @override
  void initState() {
    super.initState();
    _sync();
  }

  @override
  void didUpdateWidget(_VideoPage old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (widget.playing && !_paused) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _heart.dispose();
    super.dispose();
  }

  void _togglePause() {
    setState(() => _paused = !_paused);
    _sync();
  }

  void _doubleTap(TapDownDetails d) {
    HapticFeedback.lightImpact();
    feed.like(post);
    setState(() => _heartAt = d.localPosition);
    _heart.forward(from: 0);
  }

  void _openProfile() => ProfileScreen.open(context, widget.store, post.author);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: feed,
      builder: (context, _) => Stack(
        fit: StackFit.expand,
        children: [
          GestureDetector(
            onTap: _togglePause,
            onDoubleTapDown: _doubleTap,
            onDoubleTap: () {},
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => FakeVideo(post: post, t: _clock.value),
            ),
          ),
          // Darken the bottom so white text stays readable.
          const IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(0, .1),
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xAA000000)],
                ),
              ),
            ),
          ),
          if (_paused)
            const IgnorePointer(
              child: Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  size: 90,
                  color: Colors.white70,
                ),
              ),
            ),
          _heartBurst(),
          Positioned(
            right: 10,
            bottom: widget.bottomInset + (post.products.isEmpty ? 230 : 300),
            child: _actions(),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: widget.bottomInset,
            child: _bottom(),
          ),
          // Progress bar.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnimatedBuilder(
              animation: _clock,
              builder: (context, _) => LinearProgressIndicator(
                value: post.live ? null : _clock.value,
                minHeight: 2,
                backgroundColor: Colors.white24,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heartBurst() {
    return AnimatedBuilder(
      animation: _heart,
      builder: (context, _) {
        if (!_heart.isAnimating) return const SizedBox.shrink();
        final t = _heart.value;
        return Positioned(
          left: _heartAt.dx - 50,
          top: _heartAt.dy - 50 - 40 * t,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - t * t).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -.25 + .1 * sin(t * pi),
                child: Transform.scale(
                  scale: Curves.elasticOut.transform(min(1, t * 1.6)),
                  child: const Icon(
                    Icons.favorite,
                    size: 100,
                    color: Color(0xFFFF3B5C),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _actions() {
    Widget action(
      IconData icon,
      String count,
      VoidCallback onTap, {
      Color color = Colors.white,
      String? label,
    }) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Semantics(
          button: true,
          label: label,
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 38,
                  shadows: const [Shadow(color: Colors.black38, blurRadius: 8)],
                ),
                Text(
                  count,
                  style: tx(12, weight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        action(
          post.liked ? Icons.favorite : Icons.favorite_border_rounded,
          compact(post.likes),
          () => feed.toggleLike(post),
          color: post.liked ? const Color(0xFFFF3B5C) : Colors.white,
          label: 'Like',
        ),
        action(
          Icons.sms_outlined,
          compact(post.commentCount),
          () => showComments(context, feed, post),
          label: 'Comments',
        ),
        action(Icons.send_rounded, compact(post.shares), () {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Share to a chat: coming soon',
                style: tx(14, color: Colors.white),
              ),
            ),
          );
        }, label: 'Share'),
        action(
          post.saved ? Icons.bookmark : Icons.bookmark_border_rounded,
          compact(post.saves),
          () => feed.toggleSave(post),
          label: 'Save',
        ),
        action(
          Icons.repeat_rounded,
          compact(post.reposts),
          () => feed.toggleRepost(post),
          color: post.reposted ? AppColors.accent : Colors.white,
          label: 'Repost',
        ),
      ],
    );
  }

  Widget _bottom() {
    final author = post.author;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 80, 0),
          child: Row(
            children: [
              GestureDetector(
                onTap: _openProfile,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: PersonAvatar(author.person, diameter: 58),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: GestureDetector(
                  onTap: _openProfile,
                  child: Text(
                    '@${author.handle}',
                    overflow: TextOverflow.ellipsis,
                    style: tx(16, weight: FontWeight.w500, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              if (!author.isMe)
                GestureDetector(
                  onTap: () => feed.toggleFollow(author),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: author.followed
                          ? Colors.white24
                          : const Color(0xFFE3E3E3),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      author.followed ? 'Following' : 'Follow',
                      style: tx(
                        13,
                        weight: FontWeight.w700,
                        color: author.followed ? Colors.white : AppColors.ink,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 80, 0),
          child: GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: _caption(),
          ),
        ),
        if (post.products.isNotEmpty) ...[
          const SizedBox(height: 10),
          _products(),
          const SizedBox(height: 10),
          _liveComposer(),
        ] else ...[
          const SizedBox(height: 14),
          _music(),
        ],
      ],
    );
  }

  Widget _caption() {
    final white = tx(13, color: Colors.white);
    final bold = tx(13, weight: FontWeight.w700, color: Colors.white);
    List<InlineSpan> words(String text) => [
      for (final w in text.split(' '))
        TextSpan(
          text: '$w ',
          style: w.startsWith('@') || w.startsWith('#') ? bold : white,
        ),
    ];
    if (!_expanded) {
      return Text.rich(
        TextSpan(
          children: [
            ...words(post.caption),
            if (post.tags.isNotEmpty)
              TextSpan(text: post.tags.first, style: bold),
          ],
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }
    return Text.rich(
      TextSpan(
        children: [
          ...words(post.caption),
          for (final m in post.mentions) TextSpan(text: '\n$m', style: bold),
          for (final t in post.tags) TextSpan(text: '\n$t', style: bold),
        ],
      ),
    );
  }

  Widget _music() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(36, 0, 22, 0),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _clock,
            builder: (context, _) => Transform.rotate(
              angle: _clock.value * 2 * pi * 3,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(
                    colors: [
                      const Color(0xFFDDDDDD),
                      post.colors.last,
                      const Color(0xFFDDDDDD),
                    ],
                  ),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              post.music,
              overflow: TextOverflow.ellipsis,
              style: tx(15, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _products() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: post.products.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, i) {
          final p = post.products[i];
          return GestureDetector(
            onTap: () => showProduct(context, p),
            child: Container(
              width: 290,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: LinearGradient(colors: p.colors),
                    ),
                    child: const Icon(
                      Icons.checkroom_rounded,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                p.name,
                                overflow: TextOverflow.ellipsis,
                                style: tx(14, weight: FontWeight.w700),
                              ),
                            ),
                            Text(
                              '\$${p.price.toStringAsFixed(2)}',
                              style: tx(13, weight: FontWeight.w700),
                            ),
                          ],
                        ),
                        Text(
                          p.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tx(12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Left: ${p.left}',
                          style: tx(12, color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(width: 10, color: AppColors.ink),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _liveComposer() {
    return GestureDetector(
      onTap: () => showComments(context, feed, post),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text('Say something…', style: tx(14, color: Colors.white70)),
      ),
    );
  }
}
