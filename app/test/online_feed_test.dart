import 'dart:convert';

import 'package:challengea/api/api_client.dart';
import 'package:challengea/api/online.dart';
import 'package:challengea/chat_store.dart';
import 'package:challengea/feed.dart';
import 'package:challengea/games/games.dart';
import 'package:challengea/models.dart';
import 'package:challengea/stories.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _user(int id, String name) => {
  'id': id,
  'displayName': name,
  'handle': name.toLowerCase(),
  'bio': null,
  'color': '#112233',
};

Map<String, dynamic> _post(
  int id, {
  String body = 'Hello',
  int reactions = 0,
  String? mine,
  String? background,
  String? mediaUrl,
}) => {
  'id': id,
  'author': _user(2, 'Marc'),
  'body': body,
  'mediaUrl': mediaUrl,
  'background': background,
  'reactions': reactions,
  'myReaction': mine,
  'commentCount': 1,
  'createdAt': '2026-11-06T10:00:00Z',
};

/// A store signed in to a fake server. [handler] answers each request.
({ChatStore store, OnlineSync sync}) _online(
  Future<http.Response> Function(http.Request) handler,
) {
  final store = ChatStore();
  final api = ApiClient('http://api', token: 't', client: MockClient(handler));
  final sync = OnlineSync(store, api, 1);
  final me = Person('u1', 'Moise', Colors.orange);
  store.goOnline(sync, me);
  store.feed.goOnline(sync, me, 'moise', '');
  return (store: store, sync: sync);
}

http.Response _json(Object? body, [int status = 200]) => http.Response.bytes(
  utf8.encode(jsonEncode(body)),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  test('signed in, the home feed and stories hold no demo content', () {
    final s = _online((_) async => _json([]));
    expect(s.store.feed.home, isEmpty);
    expect(s.store.stories, isEmpty);
  });

  test('posts from the server fill the feed, newest first', () async {
    final s = _online(
      (_) async => _json([
        _post(9, reactions: 3, mine: 'love', background: '#112233,#445566'),
        _post(7, mediaUrl: '/api/media/abc'),
      ]),
    );
    await s.sync.refreshFeed();
    final home = s.store.feed.home;
    expect(home.map((p) => p.serverId), [9, 7]);
    expect(home[0].reaction, '❤️');
    expect(home[0].likes, 3);
    expect(home[0].textCard, isTrue);
    expect(home[0].colors, hasLength(2));
    expect(home[1].photoUrl, 'http://api/api/media/abc');
    expect(home[1].author.handle, 'marc');
    // Loading again updates the same objects.
    await s.sync.refreshFeed();
    expect(s.store.feed.home, hasLength(2));
  });

  test('a post that disappears from the server leaves the feed', () async {
    var page = [_post(9), _post(8), _post(7)];
    final s = _online((_) async => _json(page));
    await s.sync.refreshFeed();
    page = [_post(9), _post(7)];
    await s.sync.refreshFeed();
    expect(s.store.feed.home.map((p) => p.serverId), [9, 7]);
  });

  test('reactions go out in order and the last tap wins', () async {
    final sent = <Object?>[];
    final s = _online((r) async {
      if (r.method == 'PUT') {
        final type = (jsonDecode(r.body) as Map)['type'];
        sent.add(type);
        return _json(_post(5, reactions: type == null ? 0 : 1, mine: type));
      }
      return _json([_post(5)]);
    });
    await s.sync.refreshFeed();
    final post = s.store.feed.home.single;
    s.store.feed.react(post, '👍');
    s.store.feed.react(post, '😂');
    s.store.feed.react(post, '😂'); // same again: removed
    await pumpEventQueue();
    expect(sent, ['like', 'haha', null]);
    expect(post.reaction, isNull);
    expect(post.likes, 0);
  });

  test('a reaction the server refuses is taken back', () async {
    final s = _online((r) async {
      if (r.method == 'PUT') {
        return _json({'error': 'not_found', 'message': 'Post not found'}, 404);
      }
      return _json([_post(5)]);
    });
    await s.sync.refreshFeed();
    final post = s.store.feed.home.single;
    s.store.feed.react(post, '👍');
    expect(post.likes, 1);
    await pumpEventQueue();
    expect(post.reaction, isNull);
    expect(post.likes, 0);
  });

  test('a new post appears at once and survives a refresh', () async {
    final s = _online((r) async {
      if (r.method == 'POST') return _json(_post(11, body: 'Mine'), 201);
      return _json([_post(11, body: 'Mine')]);
    });
    final feed = s.store.feed;
    feed.addPost(
      Post(id: 'mine', author: feed.me, caption: 'Mine', colors: const []),
    );
    expect(feed.home.single.serverId, isNull);
    await s.sync.refreshFeed(); // the server answers before the post returns
    await feed.home.first.saving;
    await pumpEventQueue();
    expect(feed.home.map((p) => p.serverId), [11]);
  });

  test('a post the server refuses is removed and explained', () async {
    final notices = <String>[];
    final s = _online(
      (_) async => _json({'error': 'x', 'message': 'Too long'}, 400),
    );
    s.sync.onNotice = notices.add;
    final feed = s.store.feed;
    feed.addPost(
      Post(id: 'mine', author: feed.me, caption: 'Hi', colors: const []),
    );
    await pumpEventQueue();
    expect(feed.home, isEmpty);
    expect(feed.me.posts, isEmpty);
    expect(notices.single, contains('Too long'));
  });

  test('comments load into threads and a reply keeps its parent', () async {
    final sent = <Map>[];
    final s = _online((r) async {
      if (r.url.path.endsWith('/comments')) {
        if (r.method == 'POST') {
          sent.add(jsonDecode(r.body) as Map);
          return _json({
            'id': 30,
            'author': _user(1, 'Moise'),
            'body': 'Yes',
            'createdAt': '2026-11-06T10:00:00Z',
          }, 201);
        }
        Map<String, dynamic> c(int id, int? parent, String body) => {
          'id': id,
          'parentId': parent,
          'author': _user(2, 'Marc'),
          'body': body,
          'createdAt': '2026-11-06T10:00:00Z',
        };
        return _json([
          c(20, null, 'First'),
          c(21, null, 'Second'),
          c(22, 20, 'Reply'),
        ]);
      }
      return _json([_post(5)]);
    });
    await s.sync.refreshFeed();
    final feed = s.store.feed;
    final post = feed.home.single;
    feed.loadComments(post);
    await pumpEventQueue();
    expect(post.comments.map((c) => c.text), ['Second', 'First']);
    expect(post.comments[1].replies.single.text, 'Reply');
    expect(post.commentCount, 3);

    // Answering a reply joins its thread.
    feed.addComment(post, 'Yes', replyTo: post.comments[1].replies.single);
    await pumpEventQueue();
    expect(sent.single['parentId'], 20);
    expect(post.comments[1].replies, hasLength(2));
    expect(post.comments[1].replies.last.serverId, 30);
  });

  test('live events update the feed', () async {
    final s = _online((_) async => _json([_post(5)]));
    await s.sync.refreshFeed();
    final post = s.store.feed.home.single;
    s.sync.handleEvent('post.new', _post(6));
    expect(s.store.feed.home.first.serverId, 6);
    s.sync.handleEvent('post.reaction', {
      'postId': 5,
      'userId': 2,
      'type': 'wow',
      'reactions': 4,
    });
    expect(post.likes, 4);
    expect(post.reaction, isNull); // not mine
    s.sync.handleEvent('post.comment', {
      'commentCount': 2,
      'comment': {
        'id': 1,
        'postId': 5,
        'author': _user(2, 'Marc'),
        'body': 'Hi',
      },
    });
    expect(post.commentCount, 2);
  });

  test('stories split into mine and friends and track seen slides', () async {
    final viewed = <String>[];
    Map<String, dynamic> item(int id, {bool seen = false}) => {
      'id': id,
      'body': 'Slide $id',
      'mediaUrl': null,
      'background': '#112233,#445566',
      'createdAt': '2026-11-06T10:00:00Z',
      'seen': seen,
    };
    final s = _online((r) async {
      if (r.method == 'POST') {
        viewed.add(r.url.path);
        return http.Response('', 204);
      }
      return _json([
        {
          'user': _user(2, 'Marc'),
          'items': [item(1, seen: true), item(2)],
        },
        {
          'user': _user(1, 'Moise'),
          'items': [item(3)],
        },
      ]);
    });
    await s.sync.refreshStories();
    final store = s.store;
    expect(store.myStory.items.single.serverId, 3);
    final marc = store.stories.single;
    expect(marc.seen, isFalse);
    store.markStorySeen(marc, marc.items[1]);
    expect(marc.seen, isTrue);
    await pumpEventQueue();
    expect(viewed, ['/api/stories/items/2/view']);

    // My own slides are not reported as views.
    store.markStorySeen(store.myStory, store.myStory.items.single);
    await pumpEventQueue();
    expect(viewed, hasLength(1));
  });

  test('a story slide the server refuses is removed', () async {
    final s = _online((_) async => _json({'error': 'x', 'message': 'No'}, 400));
    s.store.addToMyStory(StoryItem(text: 'Hi'));
    expect(s.store.myStory.items, hasLength(1));
    await pumpEventQueue();
    expect(s.store.myStory.items, isEmpty);
  });

  test('a phone never calls itself: localhost becomes the server', () {
    expect(
      OnlineSync.reachableUrl('ws://localhost:7880', 'http://10.0.2.2:8081'),
      'ws://10.0.2.2:7880',
    );
    expect(
      OnlineSync.reachableUrl(
        'wss://calls.example.com',
        'http://10.0.2.2:8081',
      ),
      'wss://calls.example.com',
    );
    expect(
      OnlineSync.reachableUrl('ws://localhost:7880', 'http://localhost:8080'),
      'ws://localhost:7880',
    );
  });

  test('post options reach the server and take the post away', () async {
    final calls = <String>[];
    final s = _online((r) async {
      if (r.method != 'GET') calls.add('${r.method} ${r.url.path} ${r.body}');
      return r.method == 'GET'
          ? _json([_post(9), _post(8), _post(7)])
          : http.Response('', 204);
    });
    await s.sync.refreshFeed();
    final feed = s.store.feed;
    final [a, b, c] = feed.home.toList();
    feed.editPost(a, 'Changed');
    feed.hidePost(b);
    feed.reportPost(c, 'spam');
    await pumpEventQueue();
    expect(a.caption, 'Changed');
    expect(feed.home, [a]);
    feed.deletePost(a);
    await pumpEventQueue();
    expect(feed.home, isEmpty);
    expect(calls, [
      'PATCH /api/posts/9 {"body":"Changed"}',
      'POST /api/posts/8/hide ',
      'POST /api/posts/7/report {"reason":"spam"}',
      'DELETE /api/posts/9 ',
    ]);
  });

  test('a post deleted elsewhere leaves the feed', () async {
    final s = _online((_) async => _json([_post(9)]));
    await s.sync.refreshFeed();
    s.sync.handleEvent('post.updated', {'postId': 9, 'body': 'New text'});
    expect(s.store.feed.home.single.caption, 'New text');
    s.sync.handleEvent('post.deleted', {'postId': 9});
    expect(s.store.feed.home, isEmpty);
  });

  test('friends going live appear and leave', () {
    final s = _online((_) async => _json([]));
    s.sync.handleEvent('live.started', {
      'id': 4,
      'host': _user(2, 'Marc'),
      'title': 'Hello',
    });
    expect(s.sync.lives.single.host.name, 'Marc');
    s.sync.handleEvent('live.ended', {'liveId': 4});
    expect(s.sync.lives, isEmpty);
  });

  test('every game can be played', () {
    expect(allGames.every((g) => g.playable), isTrue);
  });

  test('the demo keeps its own feed and stories', () {
    final store = ChatStore();
    expect(store.feed.home, isNotEmpty);
    expect(store.stories, isNotEmpty);
    final post = store.feed.home.first;
    final likes = post.likes;
    store.feed.react(post, '👍');
    expect(post.likes, likes + 1);
  });
}
