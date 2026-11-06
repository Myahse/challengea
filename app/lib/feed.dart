import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'mock/posts.dart';
import 'models.dart';

enum PostKind { video, photo, story }

/// Facebook-style reactions and their names on the server.
const reactionTypes = {
  '👍': 'like',
  '❤️': 'love',
  '😂': 'haha',
  '😮': 'wow',
  '😢': 'sad',
  '😡': 'angry',
};

/// "now", "5m", "3h", "2d".
String shortAgo(DateTime time) {
  final d = DateTime.now().difference(time);
  if (d.inMinutes < 1) return 'now';
  if (d.inHours < 1) return '${d.inMinutes}m';
  if (d.inDays < 1) return '${d.inHours}h';
  return '${d.inDays}d';
}

class Product {
  const Product(
    this.name,
    this.price,
    this.description,
    this.left,
    this.sizes,
    this.colors,
  );
  final String name;
  final double price;
  final String description;
  final int left;
  final List<String> sizes;
  final List<Color> colors; // placeholder image
}

class Comment {
  Comment(
    this.author,
    this.text, {
    this.translation,
    String ago = '1d',
    this.likes = 0,
    this.hasImage = false,
    this.moreReplies = 0,
    this.serverId,
    this.time,
  }) : _ago = ago;
  final Person author;
  final String text;
  final String? translation;
  final String _ago;
  int likes;

  /// Null in the demo and while the comment is being sent.
  int? serverId;
  DateTime? time;
  String get ago => time == null ? _ago : shortAgo(time!);
  bool liked = false;
  final bool hasImage;
  final int moreReplies;
  final List<Comment> replies = [];
}

class Post {
  Post({
    required this.id,
    required this.author,
    required this.caption,
    required this.colors,
    this.kind = PostKind.video,
    this.mentions = const [],
    this.tags = const [],
    this.music = '',
    this.likes = 0,
    this.saves = 0,
    this.shares = 0,
    this.reposts = 0,
    this.live = false,
    this.watching = 0,
    this.products = const [],
    List<Comment>? comments,
    this.commentCount = 0,
    this.photo,
    this.photoUrl,
    String ago = '2h',
    this.textCard = false,
    this.serverId,
    this.time,
  }) : comments = comments ?? [],
       _ago = ago;

  /// Short text shown big on a coloured background (Facebook-style).
  final bool textCard;

  /// A photo posted from this phone (home feed).
  final Uint8List? photo;

  /// A photo stored on the server.
  final String? photoUrl;

  ImageProvider? get image => photo != null
      ? MemoryImage(photo!)
      : (photoUrl != null ? NetworkImage(photoUrl!) : null);

  /// Null in the demo and while the post is being sent.
  int? serverId;

  /// Finishes when a post from this phone has reached the server.
  Future<void>? saving;
  DateTime? time;

  /// When it was posted, as shown on the card ("2h", "Just now").
  final String _ago;
  String get ago => time == null ? _ago : shortAgo(time!);

  /// For gradients, which need at least two colours.
  List<Color> get shownColors => colors.length >= 2
      ? colors
      : const [Color(0xFF2C2C2E), Color(0xFF000000)];

  /// My Facebook-style reaction (👍 ❤️ 😂 😮 😢 😡), or null.
  String? reaction;

  final String id;
  final Creator author;
  final PostKind kind;
  String caption;
  final List<String> mentions;
  final List<String> tags;
  final String music;
  final List<Color> colors; // placeholder for the video / photo
  int likes;
  int saves;
  final int shares;
  int reposts;
  bool liked = false;
  bool saved = false;
  bool reposted = false;
  final bool live;
  final int watching;
  final List<Product> products;
  final List<Comment> comments;
  int commentCount;
}

class Creator {
  Creator(
    this.person, {
    required this.handle,
    this.bio = '',
    this.followers = 0,
    this.following = 0,
    this.likes = 0,
    this.tagged = 0,
    this.isMe = false,
  });
  Person person;
  final String handle;
  String bio;
  int followers;
  final int following;
  final int likes;
  final int tagged;
  final bool isMe;
  bool followed = false;
  final List<Post> posts = [];

  int count(PostKind k) => posts.where((p) => p.kind == k).length;
}

String compact(int n) {
  if (n >= 1000000) {
    return '${(n / 1000000).toStringAsFixed(n >= 10000000 ? 0 : 1)}M';
  }
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(n >= 10000 ? 0 : 1)}k';
  return '$n';
}

/// Saves what happens in the feed. Set when signed in.
abstract interface class FeedRemote {
  void publishPost(Post p);
  void react(Post p);
  void comment(Post p, Comment c, Comment? thread);
  void loadComments(Post p);
  void loadMorePosts();
  void editPost(Post p);
  void deletePost(Post p);
  void hidePost(Post p);
  void reportPost(Post p, String reason);
}

/// Profiles, videos and comments. Signed in, the home feed comes from the
/// server; the Videos page stays on demo content until real videos exist.
class FeedData extends ChangeNotifier {
  FeedData({required Person me, required List<Person> friends}) {
    _seed(me, friends);
  }

  final Map<String, Creator> creators = {};
  final List<Post> forYou = [];

  /// Posts I wrote from the composer (top of the home feed).
  final List<Post> created = [];

  FeedRemote? remote;

  /// Sorts above every server id. Not a shift: the web build has 32-bit shifts.
  static const _sending = 9007199254740991;

  /// Signed in: my friends' posts and mine, newest first.
  final List<Post> timeline = [];

  /// Switches from the demo profile to the signed-in account.
  void goOnline(FeedRemote r, Person person, String handle, String bio) {
    remote = r;
    creators.remove(me.person.id);
    me = creators[person.id] = Creator(
      person,
      handle: handle,
      bio: bio,
      isMe: true,
    );
    notifyListeners();
  }

  /// For the sync layer (notifyListeners is protected).
  void notifyChanged() => notifyListeners();

  Post? byServerId(int id) =>
      timeline.where((p) => p.serverId == id).firstOrNull;

  /// Adds posts from the server; ones being sent stay on top.
  void merge(Iterable<Post> posts) {
    for (final p in posts) {
      if (!timeline.contains(p)) {
        timeline.add(p);
        if (!p.author.posts.contains(p)) p.author.posts.add(p);
      }
    }
    int newest(Post a, Post b) =>
        (b.serverId ?? _sending).compareTo(a.serverId ?? _sending);
    timeline.sort(newest);
    for (final c in creators.values) {
      if (c.posts.any((p) => p.serverId != null)) c.posts.sort(newest);
    }
    notifyListeners();
  }

  /// Takes away a post (it couldn't be sent, or I can no longer see it).
  void removePost(Post p) {
    timeline.remove(p);
    p.author.posts.remove(p);
    notifyListeners();
  }

  void loadComments(Post p) {
    if (p.serverId != null) remote?.loadComments(p);
  }

  void editPost(Post p, String text) {
    p.caption = text;
    notifyListeners();
    if (p.serverId != null) remote?.editPost(p);
  }

  void _forget(Post p) {
    timeline.remove(p);
    created.remove(p);
    forYou.remove(p);
    for (final c in creators.values) {
      c.posts.remove(p);
    }
    notifyListeners();
  }

  /// Takes a post away after the server said it's gone.
  void forget(Post p) => _forget(p);

  void deletePost(Post p) {
    _forget(p);
    if (p.serverId != null) remote?.deletePost(p);
  }

  void hidePost(Post p) {
    _forget(p);
    if (p.serverId != null) remote?.hidePost(p);
  }

  void reportPost(Post p, String reason) {
    _forget(p);
    if (p.serverId != null) remote?.reportPost(p, reason);
  }

  /// The end of the feed is in sight.
  void loadMore() => remote?.loadMorePosts();

  /// The home feed: my new posts, then friends' videos and photos.
  List<Post> get home {
    if (remote != null) return timeline;
    final seen = <String>{};
    final out = <Post>[];
    void add(Post p) {
      if (seen.add(p.id)) out.add(p);
    }

    created.forEach(add);
    final pool = [
      ...forYou,
      for (final c in creators.values)
        if (!c.isMe) ...c.posts.where((p) => p.kind != PostKind.story).take(3),
    ];
    pool.forEach(add);
    return out;
  }

  /// Videos from the people in [ids] (the "Following" tab).
  List<Post> following(Set<String> ids) => [
    for (final c in creators.values)
      if (!c.isMe && ids.contains(c.person.id))
        ...c.posts.where((p) => p.kind == PostKind.video),
  ];

  void addPost(Post p) {
    (remote != null ? timeline : created).insert(0, p);
    me.posts.insert(0, p);
    notifyListeners();
    remote?.publishPost(p);
  }

  /// Facebook reactions: tapping the same one again removes it.
  void react(Post p, String? emoji) {
    final had = p.reaction != null;
    p.reaction = p.reaction == emoji ? null : emoji;
    p.liked = p.reaction != null;
    p.likes += (p.reaction != null ? 1 : 0) - (had ? 1 : 0);
    notifyListeners();
    if (p.serverId != null || p.saving != null) remote?.react(p);
  }

  late Creator me;

  Creator creatorFor(Person p) => creators[p.id] ??= Creator(
    p,
    handle: p.firstName.toLowerCase(),
    followers: 120,
    following: 80,
    likes: 900,
  );

  void toggleLike(Post p) {
    if (p.serverId != null) return react(p, p.reaction ?? '👍');
    p.liked = !p.liked;
    p.likes += p.liked ? 1 : -1;
    notifyListeners();
  }

  void like(Post p) {
    if (!p.liked) {
      toggleLike(p);
    }
  }

  void toggleSave(Post p) {
    p.saved = !p.saved;
    p.saves += p.saved ? 1 : -1;
    notifyListeners();
  }

  void toggleRepost(Post p) {
    p.reposted = !p.reposted;
    p.reposts += p.reposted ? 1 : -1;
    notifyListeners();
  }

  void toggleFollow(Creator c) {
    c.followed = !c.followed;
    c.followers += c.followed ? 1 : -1;
    notifyListeners();
  }

  void toggleCommentLike(Comment c) {
    c.liked = !c.liked;
    c.likes += c.liked ? 1 : -1;
    notifyListeners();
  }

  void addComment(Post p, String text, {Comment? replyTo}) {
    final c = Comment(me.person, text, ago: 'now');
    // Replies are one level deep: answering a reply joins its thread.
    final thread = replyTo == null
        ? null
        : p.comments.firstWhere(
            (t) => t == replyTo || t.replies.contains(replyTo),
            orElse: () => replyTo,
          );
    if (thread != null) {
      thread.replies.add(c);
    } else {
      p.comments.insert(0, c);
    }
    p.commentCount++;
    notifyListeners();
    if (p.serverId != null || p.saving != null) {
      remote?.comment(p, c, thread);
    }
  }

  void _seed(Person mePerson, List<Person> friends) {
    seedMockPosts(this, mePerson, friends);
  }
}
