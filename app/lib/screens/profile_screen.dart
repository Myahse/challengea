import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../feed.dart';
import '../theme.dart';
import '../widgets/fake_video.dart';
import 'chat_screen.dart';
import 'video_feed.dart';

/// Figma: "User profile page" frames 47:178 (top) and 50:526 (scrolled grid).
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
  int _tab = 0;

  Creator get c => widget.creator;
  FeedData get feed => widget.store.feed;

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

  void _snack(String text) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(text, style: tx(14, color: Colors.white)),
      ),
    );

  /// My profile: change name and bio; sign out (online).
  void _editProfile() {
    final online = widget.store.online;
    if (online == null) {
      _snack('Sign in to edit your profile (this is the demo)');
      return;
    }
    final name = TextEditingController(text: c.person.name);
    final bio = TextEditingController(text: c.bio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          0,
          20,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Edit profile',
              textAlign: TextAlign.center,
              style: tx(18, weight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: bio,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
            const SizedBox(height: 10),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.ink,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await online.api.patch('/me', {
                    'displayName': name.text.trim(),
                    'bio': bio.text.trim(),
                  });
                  widget.store.setMyName(name.text.trim());
                  setState(() => c.bio = bio.text.trim());
                  _snack('Profile saved');
                } catch (e) {
                  _snack('$e');
                }
              },
              child: const Text('Save'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.store.onSignOut?.call();
              },
              child: Text(
                'Sign out',
                style: tx(
                  15,
                  weight: FontWeight.w600,
                  color: const Color(0xFFE5484D),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
      backgroundColor: Colors.white,
      body: ListenableBuilder(
        listenable: feed,
        builder: (context, _) {
          final shown = _shown;
          return Stack(
            children: [
              CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabsHeader(
                      leftInset: widget.pushed ? 56 : 0,
                      top: top,
                      tabs: _tabLabels(),
                      selected: _tab,
                      onSelect: (i) => setState(() => _tab = i),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 60),
                    sliver: shown.isEmpty
                        ? SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 40),
                              child: Text(
                                'Nothing here yet',
                                textAlign: TextAlign.center,
                                style: tx(14, color: AppColors.muted),
                              ),
                            ),
                          )
                        : SliverGrid.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  mainAxisSpacing: 14,
                                  crossAxisSpacing: 14,
                                  childAspectRatio: 114 / 88,
                                ),
                            itemCount: shown.length,
                            itemBuilder: (context, i) => GestureDetector(
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
                ],
              ),
              if (widget.pushed)
                Positioned(
                  left: 12,
                  top: top + 8,
                  child: Material(
                    color: Colors.white.withValues(alpha: .85),
                    shape: const CircleBorder(),
                    child: IconButton(
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
    '${c.posts.length} posts',
    '${c.count(PostKind.video)} Videos',
    '${c.count(PostKind.story)} Stories',
    '${c.tagged} tags',
  ];

  Widget _header() {
    final p = c.person;
    return Stack(
      children: [
        // Cover: placeholder for the profile photo.
        Container(
          height: 470,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color.lerp(p.color, Colors.white, .7)!, p.color],
            ),
          ),
          alignment: const Alignment(0, -.2),
          child: Text(
            p.initials,
            style: tx(
              200,
              weight: FontWeight.w800,
              color: Colors.white.withValues(alpha: .35),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 432),
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 0),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p.name, style: tx(20, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          '@${c.handle}',
                          style: tx(15, color: const Color(0xFF555555)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: c.isMe ? _editProfile : () => feed.toggleFollow(c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 160,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: !c.isMe && !c.followed
                            ? AppColors.ink
                            : AppColors.bubble,
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: Text(
                        c.isMe
                            ? 'Edit profile'
                            : (c.followed ? 'Following' : 'Follow'),
                        style: tx(
                          15,
                          weight: FontWeight.w700,
                          color: !c.isMe && !c.followed
                              ? Colors.white
                              : AppColors.ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 46),
              Row(
                children: [
                  _stat(compact(c.followers), 'Followers'),
                  const SizedBox(width: 14),
                  _stat(compact(c.following), 'Following'),
                  const SizedBox(width: 14),
                  _stat(compact(c.likes), 'Likes'),
                ],
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: c.isMe
                    ? () => _snack('Share profile: coming soon')
                    : _message,
                child: Container(
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.bubble,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        c.isMe
                            ? Icons.ios_share_rounded
                            : Icons.chat_bubble_outline_rounded,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        c.isMe ? 'Share profile' : 'Message',
                        style: tx(16, weight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              if (c.bio.isNotEmpty) _bio(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stat(String value, String label) => Expanded(
    child: Container(
      height: 88,
      decoration: BoxDecoration(
        color: AppColors.bubble,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value, style: tx(22, weight: FontWeight.w800)),
          Text(label, style: tx(12, color: const Color(0xFF555555))),
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
            style: w.startsWith('@') ? tx(14, weight: FontWeight.w700) : tx(14),
          ),
      ],
    ),
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
  double get minExtent => 48 + top;
  @override
  double get maxExtent => 48 + top;

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
      color: Colors.white,
      padding: EdgeInsets.only(
        top: pinned ? top : 0,
        bottom: pinned ? 0 : top,
        left: pinned ? leftInset : 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (var i = 0; i < tabs.length; i++)
            Flexible(
              child: GestureDetector(
                onTap: () => onSelect(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 4,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tabs[i],
                      style: tx(
                        15,
                        weight: i == selected
                            ? FontWeight.w700
                            : FontWeight.w400,
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
