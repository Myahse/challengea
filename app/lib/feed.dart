import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'mock/posts.dart';
import 'models.dart';

enum PostKind { video, photo, story }

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
    this.ago = '1d',
    this.likes = 0,
    this.hasImage = false,
    this.moreReplies = 0,
  });
  final Person author;
  final String text;
  final String? translation;
  final String ago;
  int likes;
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
    this.ago = '2h',
    this.textCard = false,
  }) : comments = comments ?? [];

  /// Short text shown big on a coloured background (Facebook-style).
  final bool textCard;

  /// A photo posted from this phone (home feed).
  final Uint8List? photo;

  /// When it was posted, as shown on the card ("2h", "Just now").
  final String ago;

  /// My Facebook-style reaction (👍 ❤️ 😂 😮 😢 😡), or null.
  String? reaction;

  final String id;
  final Creator author;
  final PostKind kind;
  final String caption;
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
  final Person person;
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

/// Profiles, videos and comments (in memory for the prototype).
class FeedData extends ChangeNotifier {
  FeedData({required Person me, required List<Person> friends}) {
    _seed(me, friends);
  }

  final Map<String, Creator> creators = {};
  final List<Post> forYou = [];

  /// Posts I wrote from the composer (top of the home feed).
  final List<Post> created = [];

  /// The home feed: my new posts, then friends' videos and photos.
  List<Post> get home {
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
    created.insert(0, p);
    me.posts.insert(0, p);
    notifyListeners();
  }

  /// Facebook reactions: tapping the same one again removes it.
  void react(Post p, String? emoji) {
    final had = p.reaction != null;
    p.reaction = p.reaction == emoji ? null : emoji;
    p.liked = p.reaction != null;
    p.likes += (p.reaction != null ? 1 : 0) - (had ? 1 : 0);
    notifyListeners();
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
    if (replyTo != null) {
      replyTo.replies.add(c);
    } else {
      p.comments.insert(0, c);
    }
    p.commentCount++;
    notifyListeners();
  }

  void _seed(Person mePerson, List<Person> friends) {
    seedMockPosts(this, mePerson, friends);
  }
}
