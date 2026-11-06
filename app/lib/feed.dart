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
  }) : comments = comments ?? [];

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
