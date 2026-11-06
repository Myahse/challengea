import 'package:flutter/material.dart';

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

  // ---------------------------------------------------------------- demo data
  void _seed(Person mePerson, List<Person> friends) {
    Person f(String id) => friends.firstWhere((p) => p.id == id);
    const bobPerson = Person('bob', 'Bob Reeze', Color(0xFF2F5D50));

    me = creators[mePerson.id] = Creator(
      mePerson,
      handle: 'moise',
      bio: 'Sudoku champion of Marcory. Challenge me if you dare.',
      followers: 864,
      following: 212,
      likes: 5400,
      tagged: 7,
      isMe: true,
    );
    final bob = creators['bob'] = Creator(
      bobPerson,
      handle: 'Boby_pop',
      bio:
          'I am a software designer at @ontariever with a great skill in designing clothes. '
          'I’m delighted to be on this platform: it is a bridge between me and my customers, '
          'so they can see my work.',
      followers: 12400,
      following: 310,
      likes: 98000,
      tagged: 45,
    );
    final melanie = creatorFor(f('melanie'));
    final brendon = creatorFor(f('brendon'));
    final marc = creatorFor(f('marc'));

    List<Comment> comments() => [
      Comment(
        f('melanie'),
        'Dayum this is really amazing, can I contact you?',
        translation: 'Waouh, c’est vraiment génial, je peux te contacter ?',
        likes: 1234,
        moreReplies: 99,
      ),
      Comment(
        f('brendon'),
        'Dayum this is really amazing, can I contact you?',
        translation: 'Waouh, c’est vraiment génial, je peux te contacter ?',
        likes: 1234,
        hasImage: true,
      ),
      Comment(
        f('marc'),
        'Where can I buy the hoodie?',
        translation: 'Où est-ce que je peux acheter le hoodie ?',
        likes: 380,
        ago: '20h',
      ),
      Comment(f('awa'), 'The colors are crazy 🔥🔥', likes: 211, ago: '18h'),
      Comment(
        f('maurice'),
        'Big up from Koumassi!',
        translation: 'Big up depuis Koumassi !',
        likes: 96,
        ago: '5h',
      )..replies.add(Comment(bobPerson, 'Thanks bro 🙏', likes: 12, ago: '4h')),
    ];

    const green = [Color(0xFFB9C9C4), Color(0xFF2F5D50), Color(0xFF1C2B27)];
    final bob1 = Post(
      id: 'bob1',
      author: bob,
      caption:
          'I am a software designer at @ontariever with a great skill in designing clothes. '
          'I make everything easier for professionals like me.',
      mentions: ['@onmymind', '@greatfitnesses', '@rogerforme'],
      tags: ['#designing', '#clothes', '#rebranding', '#cleansheet'],
      music: 'Rody on my mind - Boomsky Ronny',
      colors: green,
      likes: 4500,
      saves: 45,
      shares: 45,
      reposts: 45,
      comments: comments(),
      commentCount: 1234,
    );
    final bobLive = Post(
      id: 'bobLive',
      author: bob,
      caption: 'New drop this weekend, ask me anything!',
      tags: ['#live', '#newdrop'],
      music: 'Live audio',
      colors: const [Color(0xFFD7DEE6), Color(0xFF52606D), Color(0xFF1F2933)],
      likes: 980,
      saves: 45,
      shares: 45,
      reposts: 45,
      live: true,
      watching: 1240,
      products: const [
        Product(
          'Excess hoodie',
          45.99,
          'Designed to keep you warm and fresh all day, in heavy cotton.',
          20,
          ['S', 'M', 'L', 'XL', 'XXL'],
          [Color(0xFF3E6B5E), Color(0xFF1C2B27)],
        ),
        Product(
          'Cloud runner',
          79.99,
          'Designed to move with you, light and soft on every step.',
          8,
          ['39', '40', '41', '42', '43'],
          [Color(0xFFE7E2D8), Color(0xFF9C8F7A)],
        ),
        Product(
          'Cargo pants',
          39.99,
          'Designed for the city, with six deep pockets.',
          14,
          ['S', 'M', 'L', 'XL', 'XXL'],
          [Color(0xFF8D99AE), Color(0xFF2B2D42)],
        ),
      ],
      comments: comments(),
      commentCount: 312,
    );
    final mel1 = Post(
      id: 'mel1',
      author: melanie,
      caption: 'Saturday at the Grand Marché de Marcory with the girls',
      tags: ['#abidjan', '#marcory', '#weekend'],
      music: 'Coupé décalé mix - DJ Ankara',
      colors: const [Color(0xFFFFD6A5), Color(0xFFE76F51), Color(0xFF6D2E46)],
      likes: 2300,
      saves: 80,
      shares: 31,
      reposts: 12,
      comments: comments(),
      commentCount: 210,
    );
    final bren1 = Post(
      id: 'bren1',
      author: brendon,
      caption: 'Who wants a Rumble dash rematch? I’m waiting @marc',
      tags: ['#challengea', '#rumbledash'],
      music: 'Arcade fever - 8bit Kid',
      colors: const [Color(0xFFA0C4FF), Color(0xFF5E60CE), Color(0xFF240046)],
      likes: 870,
      saves: 9,
      shares: 14,
      reposts: 3,
      comments: comments(),
      commentCount: 64,
    );
    final marc1 = Post(
      id: 'marc1',
      author: marc,
      caption: 'Sudoku in 3 minutes 12. Beat that.',
      tags: ['#sudoku', '#challenge'],
      music: 'Focus - Lo-fi Lagoon',
      colors: const [Color(0xFFFFC8DD), Color(0xFFF06BA8), Color(0xFF7B2CBF)],
      likes: 540,
      saves: 22,
      shares: 6,
      reposts: 2,
      comments: comments(),
      commentCount: 41,
    );
    bob.posts.addAll([bob1, bobLive]);
    melanie.posts.add(mel1);
    brendon.posts.add(bren1);
    marc.posts.add(marc1);
    forYou.addAll([bob1, mel1, bobLive, bren1, marc1]);

    // Extra posts so the profile grids look full.
    const palettes = [
      [Color(0xFFCDB4DB), Color(0xFF6A4C93)],
      [Color(0xFFB5E48C), Color(0xFF1A759F)],
      [Color(0xFFFFE5B4), Color(0xFFD4A373)],
      [Color(0xFFADE8F4), Color(0xFF0077B6)],
      [Color(0xFFFFB4A2), Color(0xFFB5838D)],
      [Color(0xFFD8E2DC), Color(0xFF52796F)],
    ];
    void extra(Creator c, int n, String prefix) {
      for (var i = 0; i < n; i++) {
        c.posts.add(
          Post(
            id: '$prefix$i',
            author: c,
            kind: i % 4 == 3
                ? PostKind.story
                : (i.isEven ? PostKind.video : PostKind.photo),
            caption: 'Work in progress #$i',
            colors: palettes[(i + prefix.length) % palettes.length],
            likes: 120 + i * 37,
            saves: i * 3,
            shares: i,
            reposts: i,
            comments: comments(),
            commentCount: 10 + i,
          ),
        );
      }
    }

    extra(bob, 22, 'b');
    extra(me, 9, 'm');
    extra(melanie, 5, 'mel');
    extra(brendon, 4, 'br');
    extra(marc, 3, 'mc');
  }
}
