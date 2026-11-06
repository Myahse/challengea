import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../call.dart';
import '../chat_store.dart';
import '../feed.dart';
import '../games/games.dart';
import '../geo.dart';
import '../models.dart';
import '../stories.dart';
import 'api_client.dart';
import 'live_call.dart';
import 'push.dart';
import 'realtime.dart';
import 'session_store.dart';

/// A 1 vs 1 match as the server sees it. Screens listen to it.
class OnlineMatch extends ChangeNotifier {
  OnlineMatch(this.id);
  final int id;
  String gameId = '';
  String status = '';
  int challengerId = 0;
  int opponentId = 0;
  int? currentTurnId;
  int? winnerId;
  Map<String, dynamic> state = {};
  Person? challenger;
  Person? opponent;

  GameInfo get game => gameById(gameId);
  bool get finished => status == 'finished';

  void apply(Map<String, dynamic> d, OnlineSync sync) {
    gameId = d['gameId'] as String;
    status = d['status'] as String;
    challenger = sync.personFrom(d['challenger'] as Map<String, dynamic>);
    opponent = sync.personFrom(d['opponent'] as Map<String, dynamic>);
    challengerId = sync.idOf(challenger!);
    opponentId = sync.idOf(opponent!);
    currentTurnId = (d['currentTurnId'] as num?)?.toInt();
    winnerId = (d['winnerId'] as num?)?.toInt();
    state = (d['state'] as Map?)?.cast<String, dynamic>() ?? {};
    notifyListeners();
  }
}

/// Connects the app's data ([ChatStore]) to the backend: loads everything,
/// sends what you do, and applies live events from other phones.
class OnlineSync implements FeedRemote {
  OnlineSync(this.store, this.api, this.myId);

  final ChatStore store;
  final ApiClient api;
  final int myId;
  Realtime? _realtime;

  final Map<int, Person> _people = {};
  final List<Person> friends = [];
  final List<Person> incoming = [];
  final Map<int, OnlineMatch> matches = {};

  /// Calls that ended (so a ringing screen for them closes itself).
  final Set<int> endedCalls = {};

  /// Set by the UI: a friend challenged me / something to tell the user.
  void Function(OnlineMatch match)? onInvite;

  /// Set by the UI: open this chat (after tapping a notification).
  void Function(BubbleNode node)? onOpenChat;
  Map<String, dynamic>? _pendingOpen;

  /// A notification was tapped: show what it is about.
  void openFromNotification(Map<String, dynamic> data) {
    // Other kinds: the app simply opens on the home screen.
    if (data['type'] != 'message.new') return;
    final id = int.tryParse('${data['conversationId']}');
    final node = store.nodes.where((n) => n.serverId == id).firstOrNull;
    if (node != null && onOpenChat != null) {
      onOpenChat!(node);
    } else {
      _pendingOpen = data; // conversations not loaded yet
    }
  }

  /// Set by the UI: someone is calling me.
  void Function(IncomingCall call)? onIncomingCall;
  void Function(String text)? onNotice;

  /// The conversation currently open on screen (its messages count as read).
  BubbleNode? openNode;

  Timer? _bubbleTimer;
  final Set<BubbleNode> _movedBubbles = {};
  DateTime _lastLocationPush = DateTime(2000);
  LatLng? _lastPushed;

  // ------------------------------------------------------------- sign in
  /// Signs in with a token, loads the account and connects. Returns null if the token is no longer valid.
  static Future<OnlineSync?> resume(
    ChatStore store,
    String baseUrl,
    String token,
  ) async {
    final api = ApiClient(baseUrl, token: token);
    try {
      final me = await api.get('/me') as Map<String, dynamic>;
      return await _start(store, api, me);
    } on ApiError catch (e) {
      if (e.status == 401) await SessionStore.save(null);
      if (e.isNetwork) rethrow;
      return null;
    }
  }

  static Future<OnlineSync> fromSession(
    ChatStore store,
    String baseUrl,
    Map<String, dynamic> session,
  ) async {
    final token = session['token'] as String;
    await SessionStore.save(token);
    final api = ApiClient(baseUrl, token: token);
    return _start(store, api, session['user'] as Map<String, dynamic>);
  }

  static Future<OnlineSync> _start(
    ChatStore store,
    ApiClient api,
    Map<String, dynamic> meDto,
  ) async {
    final sync = OnlineSync(store, api, (meDto['id'] as num).toInt());
    final me = sync.personFrom(meDto);
    store.goOnline(sync, me);
    store.feed.goOnline(
      sync,
      me,
      (meDto['handle'] as String?) ?? me.firstName.toLowerCase(),
      (meDto['bio'] as String?) ?? '',
    );
    await sync.refreshAll();
    unawaited(PushService.start(sync));
    sync._realtime = Realtime(
      api.baseUrl,
      api.token!,
      sync._onEvent,
      onConnected: () {
        // Catch up on anything missed while disconnected.
        sync.refreshAll();
      },
    )..connect();
    return sync;
  }

  Future<void> signOut() async {
    await PushService.stop(this);
    close();
    await SessionStore.save(null);
  }

  void close() {
    _realtime?.close();
    _bubbleTimer?.cancel();
  }

  // ------------------------------------------------------------- mapping
  Person personFrom(Map<String, dynamic> u) {
    final id = (u['id'] as num).toInt();
    final name = u['displayName'] as String;
    final color = _color(u['color'] as String?);
    final existing = _people[id];
    if (existing != null && existing.name == name && existing.color == color) {
      return existing;
    }
    final p = Person('u$id', name, color);
    _people[id] = p;
    return p;
  }

  int idOf(Person p) => int.parse(p.id.substring(1));

  /// A person I already know, by id like "u12".
  Person? personById(String id) =>
      id.startsWith('u') ? _people[int.tryParse(id.substring(1)) ?? -1] : null;
  bool isMe(Person p) => p.id == 'u$myId';

  static Color _color(String? hex) {
    if (hex == null || !RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(hex)) {
      return const Color(0xFFFF8A3D);
    }
    return Color(int.parse('FF${hex.substring(1)}', radix: 16));
  }

  Message messageFrom(Map<String, dynamic> m) {
    final senderId = (m['senderId'] as num?)?.toInt();
    final type = m['type'] as String;
    final meta = (m['metadata'] as Map?)?.cast<String, dynamic>();
    final gameId = meta?['gameId'] as String?;
    Person? sender;
    if (senderId != null && senderId != myId) sender = _people[senderId];
    final isChallenge = type == 'system' && meta?['kind'] == 'challenge';
    var body = (m['body'] as String?) ?? (type == 'sticker' ? '🙂' : '[$type]');
    if (isChallenge && senderId == myId && gameId != null) {
      // The server text is written for the friend.
      body = 'You sent a challenge: ${gameById(gameId).name}';
    }
    final url = m['mediaUrl'] as String?;
    final kind = switch (type) {
      'image' => MessageKind.image,
      'voice' => MessageKind.voice,
      'sticker' => MessageKind.sticker,
      _ => MessageKind.text,
    };
    return Message(
      kind == MessageKind.image
          ? '📷 Photo'
          : (kind == MessageKind.voice ? '🎤 Voice note' : body),
      kind: kind,
      mediaUrl: url == null
          ? null
          : (url.startsWith('http') ? url : '${api.baseUrl}$url'),
      duration: meta?['durationMs'] is num
          ? Duration(milliseconds: (meta!['durationMs'] as num).toInt())
          : null,
      waveform: (meta?['waveform'] as List?)
          ?.map((v) => (v as num).toDouble())
          .toList(),
      isChallenge: isChallenge,
      isEvent: type == 'system' && meta?['kind'] == 'call',
      sender: senderId == myId
          ? null
          : (sender ?? Person('u$senderId', '…', const Color(0xFF999999))),
      time: DateTime.tryParse(m['createdAt'] as String? ?? '')?.toLocal(),
      game: (type == 'game_result' || type == 'system') && gameId != null
          ? gameById(gameId)
          : null,
      serverId: (m['id'] as num).toInt(),
    );
  }

  BubbleNode _nodeFrom(Map<String, dynamic> c, int index) {
    final members = [
      for (final u in (c['members'] as List))
        personFrom(u as Map<String, dynamic>),
    ];
    final others = members.where((p) => !isMe(p)).toList();
    final b = c['bubble'] as Map?;
    final home = b != null
        ? Offset((b['x'] as num).toDouble(), (b['y'] as num).toDouble())
        : _defaultHome(index);
    final last = c['lastMessage'] as Map<String, dynamic>?;
    final node = c['type'] == 'group'
        ? BubbleNode.group(
            id: 'c${c['id']}',
            members: others,
            home: home,
            name: c['title'] as String?,
          )
        : BubbleNode.person(
            others.isEmpty ? members.first : others.first,
            home: home,
            size: 48,
          );
    node.serverId = (c['id'] as num).toInt();
    node.unread = (c['unread'] as num).toInt();
    if (last != null) node.messages.add(messageFrom(last));
    return node;
  }

  /// Spreads new bubbles in a spiral so they don't start on top of each other.
  static Offset _defaultHome(int i) {
    const golden = 2.399963;
    final r = .12 + .07 * (i % 6);
    return Offset(
      .5 + r * 1.4 * math.cos(i * golden),
      .45 + r * 1.6 * math.sin(i * golden),
    );
  }

  // ------------------------------------------------------------- loading
  Future<void> refreshAll() async {
    await Future.wait([
      refreshFriends(),
      refreshConversations(),
      refreshLocations(),
      refreshMatches(),
      refreshFeed(),
      refreshStories(),
    ]);
  }

  Future<void> refreshFriends() async {
    final list = await _quiet(() => api.get('/friends'));
    final reqs = await _quiet(() => api.get('/friends/requests'));
    if (list is List) {
      friends
        ..clear()
        ..addAll(list.map((u) => personFrom(u as Map<String, dynamic>)));
    }
    if (reqs is List) {
      incoming
        ..clear()
        ..addAll(reqs.map((u) => personFrom(u as Map<String, dynamic>)));
    }
    _addFriendBubbles();
    store.notifyChanged();
  }

  /// Every friend has a bubble, even before the first message (the chat is
  /// created on the server when you open it).
  void _addFriendBubbles() {
    final withBubble = {
      for (final n in store.nodes)
        if (!n.isGroup) n.members.first.id,
    };
    var i = store.nodes.length;
    for (final f in friends) {
      if (withBubble.contains(f.id)) continue;
      store.nodes.add(
        BubbleNode.person(f, home: _defaultHome(i++), size: 48)..spawn = 0,
      );
    }
  }

  /// Creates the 1-to-1 chat on the server if this bubble doesn't have one yet.
  Future<void> _ready(BubbleNode n) {
    if (n.serverId != null) return Future.value();
    return n.pending ??= n.isGroup ? Future.value() : ensureDirect(n);
  }

  Future<void> refreshConversations() async {
    final list = await _quiet(() => api.get('/conversations'));
    if (list is! List) return;
    final fresh = <BubbleNode>[];
    for (var i = 0; i < list.length; i++) {
      final dto = list[i] as Map<String, dynamic>;
      final id = (dto['id'] as num).toInt();
      final existing = store.nodes.where((n) => n.serverId == id).firstOrNull;
      if (existing != null) {
        _refreshNode(existing, dto);
        fresh.add(existing);
      } else {
        fresh.add(_nodeFrom(dto, i)..spawn = 0);
      }
    }
    if (_pendingOpen != null) {
      final pending = _pendingOpen!;
      _pendingOpen = null;
      Future.microtask(() => openFromNotification(pending));
    }
    // Keep bubbles being created right now and friends without a chat yet.
    final directIds = {
      for (final n in fresh)
        if (!n.isGroup) n.members.first.id,
    };
    fresh.addAll(
      store.nodes.where(
        (n) =>
            n.serverId == null &&
            (n.isGroup || !directIds.contains(n.members.first.id)),
      ),
    );
    store.replaceNodes(fresh);
    _addFriendBubbles();
  }

  void _refreshNode(BubbleNode n, Map<String, dynamic> c) {
    final members = [
      for (final u in (c['members'] as List))
        personFrom(u as Map<String, dynamic>),
    ];
    if (n.isGroup) {
      n.members
        ..clear()
        ..addAll(members.where((p) => !isMe(p)));
      n.name = c['title'] as String?;
    }
    n.unread = identical(openNode, n) ? 0 : (c['unread'] as num).toInt();
    final last = c['lastMessage'] as Map<String, dynamic>?;
    if (last != null && !n.messages.any((m) => m.serverId == last['id'])) {
      n.messages.add(messageFrom(last));
    }
  }

  Future<void> loadMessages(BubbleNode n) async {
    await _ready(n);
    final id = n.serverId;
    if (id == null) return;
    final list = await _quiet(
      () => api.get('/conversations/$id/messages?limit=50'),
    );
    if (list is! List) return;
    final msgs = list.reversed
        .map((m) => messageFrom(m as Map<String, dynamic>))
        .toList();
    final local = n.messages
        .where((m) => m.serverId == null)
        .toList(); // being sent
    n.messages
      ..clear()
      ..addAll(msgs)
      ..addAll(local);
    n.loaded = true;
    store.notifyChanged();
    markRead(n);
  }

  Future<void> refreshLocations() async {
    final list = await _quiet(() => api.get('/friends/locations'));
    if (list is! List) return;
    store.spots
      ..clear()
      ..addAll(list.map((l) => _spotFrom(l as Map<String, dynamic>)));
    store.notifyChanged();
  }

  FriendSpot _spotFrom(Map<String, dynamic> l) {
    final updated = DateTime.tryParse(l['updatedAt'] as String? ?? '');
    return FriendSpot.real(
      personFrom(l['user'] as Map<String, dynamic>),
      LatLng((l['lat'] as num).toDouble(), (l['lng'] as num).toDouble()),
      place: (l['place'] as String?) ?? 'Shared position',
      status: (l['status'] as String?) ?? 'On Challengea',
      updated: updated == null ? '' : _ago(updated),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t.toLocal());
    if (d.inMinutes < 1) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inDays < 1) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }

  Future<void> refreshMatches() async {
    final list = await _quiet(() => api.get('/matches'));
    if (list is! List) return;
    for (final m in list) {
      _applyMatch(m as Map<String, dynamic>);
    }
  }

  OnlineMatch _applyMatch(Map<String, dynamic> d) {
    final id = (d['id'] as num).toInt();
    final match = matches[id] ??= OnlineMatch(id);
    match.apply(d, this);
    return match;
  }

  // ------------------------------------------------------------- feed
  static const _pageSize = 20;
  bool _feedLoading = false;
  bool _feedEnded = false;
  final Map<Post, int> _reactSeq = {};
  final Map<Post, Future<void>> _reactQueue = {};
  final Set<Post> _commentsLoaded = {};

  FeedData get _feed => store.feed;

  String _mediaUrl(String url) =>
      url.startsWith('http') ? url : '${api.baseUrl}$url';

  /// "#112233,#445566" <-> gradient colours.
  static List<Color> _colorsFrom(String? background) => background == null
      ? const []
      : [for (final hex in background.split(',')) _color(hex)];

  static String _backgroundOf(List<Color> colors) => [
    for (final c in colors)
      '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}',
  ].join(',');

  static String? _emojiFor(String? type) =>
      reactionTypes.entries.where((e) => e.value == type).firstOrNull?.key;

  /// The post with this server id, created or brought up to date.
  Post _postFrom(Map<String, dynamic> d) {
    final id = (d['id'] as num).toInt();
    final reaction = _emojiFor(d['myReaction'] as String?);
    final likes = (d['reactions'] as num).toInt();
    final comments = (d['commentCount'] as num).toInt();
    final known = _feed.byServerId(id);
    if (known != null) {
      known
        ..reaction = reaction
        ..liked = reaction != null
        ..likes = likes
        ..commentCount = comments;
      return known;
    }
    final u = d['author'] as Map<String, dynamic>;
    final person = personFrom(u);
    final url = d['mediaUrl'] as String?;
    final background = d['background'] as String?;
    return Post(
        id: 'p$id',
        serverId: id,
        author: _feed.creators[person.id] ??= Creator(
          person,
          handle: u['handle'] as String,
          bio: (u['bio'] as String?) ?? '',
        ),
        caption: (d['body'] as String?) ?? '',
        colors: _colorsFrom(background),
        kind: PostKind.photo,
        photoUrl: url == null ? null : _mediaUrl(url),
        textCard: background != null && url == null,
        likes: likes,
        commentCount: comments,
        time: DateTime.tryParse(d['createdAt'] as String? ?? '')?.toLocal(),
      )
      ..reaction = reaction
      ..liked = reaction != null;
  }

  /// The newest posts. What they replace but no longer contain is gone
  /// (for example the friendship ended).
  Future<void> refreshFeed() async {
    final list = await _quiet(() => api.get('/posts?limit=$_pageSize'));
    if (list is! List) return;
    final page = [for (final d in list) _postFrom(d as Map<String, dynamic>)];
    final oldest = page.isEmpty ? 0 : page.last.serverId!;
    final gone = _feed.timeline.where(
      (p) => p.serverId != null && p.serverId! > oldest && !page.contains(p),
    );
    gone.toList().forEach(_feed.removePost);
    _feed.merge(page);
  }

  @override
  Future<void> loadMorePosts() async {
    if (_feedLoading || _feedEnded) return;
    final oldest = _feed.timeline.where((p) => p.serverId != null).lastOrNull;
    if (oldest == null) return;
    _feedLoading = true;
    final list = await _quiet(
      () => api.get('/posts?limit=$_pageSize&before=${oldest.serverId}'),
    );
    _feedLoading = false;
    if (list is! List) return;
    if (list.length < _pageSize) _feedEnded = true;
    _feed.merge([for (final d in list) _postFrom(d as Map<String, dynamic>)]);
  }

  static String _imageType(Uint8List b) {
    bool starts(List<int> sig) =>
        b.length > sig.length &&
        [for (var i = 0; i < sig.length; i++) b[i] == sig[i]].every((x) => x);
    if (starts(const [0x89, 0x50, 0x4E, 0x47])) return 'image/png';
    if (starts(const [0x47, 0x49, 0x46])) return 'image/gif';
    if (starts(const [0x52, 0x49, 0x46, 0x46])) return 'image/webp';
    return 'image/jpeg';
  }

  Future<String> _uploadPhoto(Uint8List bytes) async {
    final type = _imageType(bytes);
    final up = await api.upload(
      '/media',
      bytes,
      filename: 'photo.${type.split('/').last}',
      contentType: type,
      fields: {'kind': 'image'},
    );
    return (up as Map)['url'] as String;
  }

  @override
  void publishPost(Post p) => p.saving = _publishPost(p);

  Future<void> _publishPost(Post p) async {
    try {
      final url = p.photo == null ? null : await _uploadPhoto(p.photo!);
      final dto =
          await api.post('/posts', {
                if (p.caption.isNotEmpty) 'body': p.caption,
                'mediaUrl': ?url,
                if (p.textCard) 'background': _backgroundOf(p.colors),
              })
              as Map<String, dynamic>;
      final id = (dto['id'] as num).toInt();
      // A refresh may have brought this post back first: keep a single copy.
      final twin = _feed.byServerId(id);
      if (twin != null) _feed.removePost(twin);
      p
        ..serverId = id
        ..time = DateTime.tryParse(dto['createdAt'] as String)?.toLocal();
      _feed.merge(const []);
    } on ApiError catch (e) {
      _feed.removePost(p);
      onNotice?.call('Not posted: ${e.message}');
    }
  }

  /// Reactions on one post go out one at a time, so the last tap wins.
  @override
  void react(Post p) {
    final wanted = reactionTypes[p.reaction];
    final seq = _reactSeq[p] = (_reactSeq[p] ?? 0) + 1;
    _reactQueue[p] = (_reactQueue[p] ?? Future.value()).then((_) async {
      await p.saving;
      final id = p.serverId;
      if (id == null) return;
      final dto = await _act(
        () => api.put('/posts/$id/reaction', {'type': wanted}),
      );
      if (_reactSeq[p] != seq) return; // a newer tap is on its way
      if (dto is Map<String, dynamic>) {
        _postFrom(dto);
        _feed.notifyChanged();
      } else {
        await refreshFeed(); // not saved: show what the server has
      }
    });
  }

  Comment _commentFrom(Map<String, dynamic> d) => Comment(
    personFrom(d['author'] as Map<String, dynamic>),
    d['body'] as String,
    serverId: (d['id'] as num).toInt(),
    time: DateTime.tryParse(d['createdAt'] as String? ?? '')?.toLocal(),
  );

  /// Newest threads first; replies in the order they were written.
  void _placeComment(Post p, Comment c, int? parentId) {
    if (parentId == null) {
      p.comments.insert(0, c);
    } else {
      p.comments
          .where((t) => t.serverId == parentId)
          .firstOrNull
          ?.replies
          .add(c);
    }
  }

  @override
  Future<void> loadComments(Post p) async {
    final list = await _quiet(() => api.get('/posts/${p.serverId}/comments'));
    if (list is! List) return;
    final sending = p.comments.where((c) => c.serverId == null).toList();
    p.comments.clear();
    for (final d in list) {
      final m = d as Map<String, dynamic>;
      _placeComment(p, _commentFrom(m), (m['parentId'] as num?)?.toInt());
    }
    p.comments.insertAll(0, sending);
    p.commentCount = list.length + sending.length;
    _commentsLoaded.add(p);
    _feed.notifyChanged();
  }

  @override
  Future<void> comment(Post p, Comment c, Comment? thread) async {
    try {
      await p.saving;
      final dto =
          await api.post('/posts/${p.serverId}/comments', {
                'body': c.text,
                'parentId': ?thread?.serverId,
              })
              as Map<String, dynamic>;
      c
        ..serverId = (dto['id'] as num).toInt()
        ..time = DateTime.tryParse(dto['createdAt'] as String)?.toLocal();
      _feed.notifyChanged();
    } on ApiError catch (e) {
      p.comments.remove(c);
      thread?.replies.remove(c);
      p.commentCount--;
      _feed.notifyChanged();
      onNotice?.call('Comment not sent: ${e.message}');
    }
  }

  void _onReaction(Map<String, dynamic> d) {
    final p = _feed.byServerId((d['postId'] as num).toInt());
    if (p == null) return;
    p.likes = (d['reactions'] as num).toInt();
    // My tap from another phone. On this phone the answer to the tap decides.
    if (d['userId'] == myId && !_reactSeq.containsKey(p)) {
      p.reaction = _emojiFor(d['type'] as String?);
      p.liked = p.reaction != null;
    }
    _feed.notifyChanged();
  }

  void _onComment(Map<String, dynamic> d) {
    final dto = d['comment'] as Map<String, dynamic>;
    final p = _feed.byServerId((dto['postId'] as num).toInt());
    if (p == null) return;
    p.commentCount = (d['commentCount'] as num).toInt();
    final author = (dto['author'] as Map)['id'];
    if (author != myId && _commentsLoaded.contains(p)) {
      _placeComment(p, _commentFrom(dto), (dto['parentId'] as num?)?.toInt());
    }
    _feed.notifyChanged();
  }

  // ------------------------------------------------------------- stories
  Future<void> refreshStories() async {
    final list = await _quiet(() => api.get('/stories'));
    if (list is! List) return;
    final others = <Story>[];
    var mine = <StoryItem>[];
    for (final s in list) {
      final m = s as Map<String, dynamic>;
      final person = personFrom(m['user'] as Map<String, dynamic>);
      final items = [
        for (final i in m['items'] as List)
          _storyItemFrom(i as Map<String, dynamic>),
      ];
      if (isMe(person)) {
        mine = items;
      } else {
        others.add(Story(person, items)..seen = items.every((i) => i.seen));
      }
    }
    store.stories
      ..clear()
      ..addAll(others);
    store.myStory.items
      ..removeWhere((i) => i.serverId != null)
      ..insertAll(0, mine);
    store.notifyChanged();
  }

  StoryItem _storyItemFrom(Map<String, dynamic> d) {
    final colors = _colorsFrom(d['background'] as String?);
    final url = d['mediaUrl'] as String?;
    return StoryItem(
      colors: colors.length >= 2 ? colors : StoryItem().colors,
      text: d['body'] as String?,
      photoUrl: url == null ? null : _mediaUrl(url),
      serverId: (d['id'] as num).toInt(),
      seen: d['seen'] == true,
      time: DateTime.tryParse(d['createdAt'] as String? ?? '')?.toLocal(),
    );
  }

  Future<void> publishStoryItem(StoryItem item) async {
    try {
      final url = item.photo == null ? null : await _uploadPhoto(item.photo!);
      final dto =
          await api.post('/stories', {
                'body': ?item.text,
                'mediaUrl': ?url,
                'background': _backgroundOf(item.colors),
              })
              as Map<String, dynamic>;
      item.serverId = (dto['id'] as num).toInt();
    } on ApiError catch (e) {
      store.myStory.items.remove(item);
      store.notifyChanged();
      onNotice?.call('Not added to your story: ${e.message}');
    }
  }

  void viewStoryItem(StoryItem item) {
    final id = item.serverId;
    if (id != null) _quiet(() => api.post('/stories/items/$id/view'));
  }

  // ------------------------------------------------------------- actions
  Future<void> send(BubbleNode n, String text) async {
    final local = Message(text);
    n.messages.add(local);
    store.notifyChanged();
    try {
      await _ready(n);
      final dto = await api.post('/conversations/${n.serverId}/messages', {
        'type': 'text',
        'body': text,
      });
      final m = messageFrom(dto as Map<String, dynamic>);
      final i = n.messages.indexOf(local);
      // The live event may have arrived first: keep a single copy.
      if (n.messages.any((x) => x.serverId == m.serverId)) {
        n.messages.remove(local);
      } else if (i >= 0) {
        n.messages[i] = m;
      }
      store.notifyChanged();
    } on ApiError catch (e) {
      n.messages.remove(local);
      store.notifyChanged();
      onNotice?.call('Message not sent: ${e.message}');
    }
  }

  /// Photo / voice note / sticker: shows it at once, uploads, then sends.
  Future<void> sendMedia(
    BubbleNode n,
    Message local, {
    Uint8List? bytes,
    String? contentType,
  }) async {
    n.messages.add(local);
    store.notifyChanged();
    try {
      await _ready(n);
      String? url;
      if (bytes != null) {
        final kind = local.kind == MessageKind.image ? 'image' : 'voice';
        final ext = (contentType ?? '').split('/').last.split(';').first;
        final up = await api.upload(
          '/media',
          bytes,
          filename: '$kind.$ext',
          contentType: contentType ?? 'application/octet-stream',
          fields: {'kind': kind},
        );
        url = (up as Map)['url'] as String;
      }
      final dto = await api.post('/conversations/${n.serverId}/messages', {
        'type': local.kind.name,
        if (local.kind == MessageKind.sticker) 'body': local.text,
        'mediaUrl': ?url,
        'metadata': {
          if (local.duration != null)
            'durationMs': local.duration!.inMilliseconds,
          if (local.waveform != null)
            'waveform': [
              for (final v in local.waveform!)
                double.parse(v.toStringAsFixed(2)),
            ],
        },
      });
      final server = local.withServer(messageFrom(dto as Map<String, dynamic>));
      final i = n.messages.indexOf(local);
      if (n.messages.any((x) => x.serverId == server.serverId)) {
        n.messages.remove(local);
        final j = n.messages.indexWhere((x) => x.serverId == server.serverId);
        n.messages[j] =
            server; // keep the local file on the copy from the live event
      } else if (i >= 0) {
        n.messages[i] = server;
      }
      store.notifyChanged();
    } on ApiError catch (e) {
      n.messages.remove(local);
      store.notifyChanged();
      onNotice?.call('Not sent: ${e.message}');
    }
  }

  void markRead(BubbleNode n) {
    final last = n.messages.where((m) => m.serverId != null).lastOrNull;
    if (n.serverId == null || last == null) return;
    _quiet(
      () => api.post('/conversations/${n.serverId}/read', {
        'messageId': last.serverId,
      }),
    );
  }

  /// Creates (or finds) the 1-to-1 chat for a bubble that has no server id yet.
  Future<void> ensureDirect(BubbleNode n) async {
    final dto =
        await api.post('/conversations/direct/${idOf(n.members.first)}')
            as Map<String, dynamic>;
    final id = (dto['id'] as num).toInt();
    final twin = store.nodes
        .where((x) => x.serverId == id && !identical(x, n))
        .firstOrNull;
    if (twin != null) store.nodes.remove(twin);
    n.serverId = id;
    store.notifyChanged();
  }

  Future<void> createGroup(BubbleNode group) async {
    try {
      final dto =
          await api.post('/conversations/groups', {
                'memberIds': [for (final p in group.members) idOf(p)],
                if (group.name != null) 'title': group.name,
              })
              as Map<String, dynamic>;
      group.serverId = (dto['id'] as num).toInt();
      saveBubble(group);
    } on ApiError catch (e) {
      store.nodes.remove(group);
      store.notifyChanged();
      onNotice?.call(e.message);
    }
  }

  Future<void> addMembers(BubbleNode group, List<Person> people) async {
    await group.pending;
    await _act(
      () => api.post('/conversations/${group.serverId}/members', {
        'userIds': [for (final p in people) idOf(p)],
      }),
    );
  }

  Future<void> removeMember(BubbleNode group, Person p) async {
    await _act(
      () => api.delete('/conversations/${group.serverId}/members/${idOf(p)}'),
    );
  }

  Future<void> leave(BubbleNode group) async {
    await _act(
      () => api.delete('/conversations/${group.serverId}/members/$myId'),
    );
  }

  Future<void> rename(BubbleNode group, String? title) async {
    await _act(
      () => api.patch('/conversations/${group.serverId}', {'title': title}),
    );
  }

  /// Bubble positions are saved a moment after you stop moving them.
  void saveBubble(BubbleNode n) {
    _movedBubbles.add(n);
    _bubbleTimer?.cancel();
    _bubbleTimer = Timer(const Duration(milliseconds: 800), () {
      final items = [
        for (final b in _movedBubbles)
          if (b.serverId != null && store.nodes.contains(b))
            {
              'conversationId': b.serverId,
              'x': b.home.dx.clamp(0.0, 1.0),
              'y': b.home.dy.clamp(0.0, 1.0),
            },
      ];
      _movedBubbles.clear();
      if (items.isNotEmpty) _quiet(() => api.put('/bubbles', {'items': items}));
    });
  }

  /// Sends my GPS position, at most every 30 s or after moving 25 m.
  void pushLocation(LatLng p) {
    final now = DateTime.now();
    final moved = _lastPushed == null
        ? 1e9
        : distanceKm(_lastPushed!, p) * 1000;
    if (now.difference(_lastLocationPush).inSeconds < 30 && moved < 25) return;
    _lastLocationPush = now;
    _lastPushed = p;
    _quiet(() => api.put('/location', {'lat': p.latitude, 'lng': p.longitude}));
  }

  Future<void> setGhost(bool ghost) =>
      _act(() => api.put('/location/ghost', {'ghost': ghost}));

  // Friends
  Future<List<({Person person, String handle})>> search(String q) async {
    final list = await _quiet(
      () => api.get('/users/search?q=${Uri.encodeQueryComponent(q)}'),
    );
    if (list is! List) return [];
    return [
      for (final u in list)
        if ((u['id'] as num).toInt() != myId)
          (
            person: personFrom(u as Map<String, dynamic>),
            handle: '${u['handle']}',
          ),
    ];
  }

  Future<String?> requestFriend(Person p) async {
    final res = await _act(() => api.post('/friends/${idOf(p)}'));
    await refreshFriends();
    return res is Map ? res['friendship'] as String? : null;
  }

  Future<void> acceptFriend(Person p) async {
    await _act(() => api.post('/friends/${idOf(p)}/accept'));
    await refreshFriends();
  }

  // Games
  Future<OnlineMatch?> challenge(Person friend, GameInfo game) async {
    final dto = await _act(
      () =>
          api.post('/matches', {'gameId': game.id, 'opponentId': idOf(friend)}),
    );
    return dto is Map<String, dynamic> ? _applyMatch(dto) : null;
  }

  Future<void> accept(OnlineMatch m) async {
    final dto = await _act(() => api.post('/matches/${m.id}/accept'));
    if (dto is Map<String, dynamic>) _applyMatch(dto);
  }

  Future<void> decline(OnlineMatch m) async {
    final dto = await _act(() => api.post('/matches/${m.id}/decline'));
    if (dto is Map<String, dynamic>) _applyMatch(dto);
  }

  /// Returns the server's error code (e.g. "not_your_turn") or null on success.
  Future<String?> move(OnlineMatch m, Map<String, Object> move) async {
    try {
      final dto = await api.post('/matches/${m.id}/moves', move);
      _applyMatch(dto as Map<String, dynamic>);
      return null;
    } on ApiError catch (e) {
      return e.code;
    }
  }

  // ------------------------------------------------------------- calls
  /// Starts a real call in this chat: rings the others, then joins the LiveKit room.
  CallSession startCall(BubbleNode n, {bool video = false}) {
    final session = CallSession(
      people: [...n.members],
      me: store.me,
      groupName: n.isGroup ? n.displayName : null,
      video: video,
      simulate: false,
    );
    store.adoptCall(session);
    () async {
      try {
        await _ready(n);
        final join =
            await api.post('/calls', {
                  'conversationId': n.serverId,
                  'video': video,
                })
                as Map<String, dynamic>;
        await _connect(session, join);
      } on ApiError catch (e) {
        onNotice?.call(e.message);
        session.end();
      }
    }();
    return session;
  }

  /// Answers a call: joins the room.
  CallSession acceptCall(IncomingCall call) {
    final session = CallSession(
      people: [call.from],
      me: store.me,
      groupName: call.groupName,
      video: call.video,
      simulate: false,
    );
    store.adoptCall(session);
    () async {
      try {
        final join =
            await api.post('/calls/${call.id}/accept') as Map<String, dynamic>;
        await _connect(session, join);
      } on ApiError catch (e) {
        onNotice?.call(e.message);
        session.end();
      }
    }();
    return session;
  }

  Future<void> declineCall(IncomingCall call) =>
      _quiet(() => api.post('/calls/${call.id}/decline'));

  Future<void> _connect(CallSession session, Map<String, dynamic> join) async {
    if (session.ended) return; // hung up while ringing
    final call = join['call'] as Map<String, dynamic>;
    final live = LiveCall(this, (call['id'] as num).toInt(), session);
    final error = await live.connect(
      join['url'] as String,
      join['token'] as String,
    );
    if (error != null) {
      onNotice?.call(error);
      session.end();
    }
  }

  void inviteToCall(int callId, Person p) => _act(
    () => api.post('/calls/$callId/invite', {
      'userIds': [idOf(p)],
    }),
  );

  void leaveCall(int callId) => _quiet(() => api.post('/calls/$callId/leave'));

  int? _callIdOf(CallSession? s) => (s?.link as LiveCall?)?.callId;

  // ------------------------------------------------------------- live events
  @visibleForTesting
  void handleEvent(String type, dynamic data) => _onEvent(type, data);

  void _onEvent(String type, dynamic data) {
    final d = data is Map ? data.cast<String, dynamic>() : <String, dynamic>{};
    switch (type) {
      case 'message.new':
        _onMessage(d);
      case 'conversation.added' || 'conversation.updated':
        refreshConversations();
      case 'conversation.removed':
        store.nodes.removeWhere((n) => n.serverId == d['conversationId']);
        store.notifyChanged();
      case 'friend.request':
        refreshFriends();
        onNotice?.call(
          '${(d['from'] as Map)['displayName']} wants to be your friend',
        );
      case 'friend.accepted':
        refreshFriends();
        refreshConversations();
        refreshFeed();
        refreshStories();
        onNotice?.call(
          '${(d['by'] as Map)['displayName']} accepted your request',
        );
      case 'post.new':
        _feed.merge([_postFrom(d)]);
      case 'post.reaction':
        _onReaction(d);
      case 'post.comment':
        _onComment(d);
      case 'story.new':
        refreshStories();
      case 'location.updated':
        final spot = _spotFrom(d);
        store.spots
          ..removeWhere((s) => s.person.id == spot.person.id)
          ..add(spot);
        store.notifyChanged();
      case 'location.hidden':
        store.spots.removeWhere((s) => s.person.id == 'u${d['userId']}');
        store.notifyChanged();
      case 'match.invited':
        final m = _applyMatch(d);
        onInvite?.call(m);
      case 'match.updated':
        _applyMatch(d);
      case 'call.incoming':
        final from = personFrom(d['startedBy'] as Map<String, dynamic>);
        final node = store.nodes
            .where((n) => n.serverId == d['conversationId'])
            .firstOrNull;
        onIncomingCall?.call(
          IncomingCall(
            id: (d['id'] as num).toInt(),
            from: from,
            video: d['video'] == true,
            groupName: node != null && node.isGroup ? node.displayName : null,
          ),
        );
      case 'call.declined':
        final call = store.call;
        if (call != null &&
            _callIdOf(call) == d['callId'] &&
            !call.isGroup &&
            !call.connected) {
          onNotice?.call(
            '${call.participants.firstOrNull?.person.firstName ?? 'They'} declined',
          );
          call.end();
        }
      case 'call.ended':
        final id = (d['callId'] as num).toInt();
        endedCalls.add(id);
        final call = store.call;
        if (call != null && _callIdOf(call) == id) call.end();
    }
  }

  void _onMessage(Map<String, dynamic> d) {
    final convId = (d['conversationId'] as num).toInt();
    final node = store.nodes.where((n) => n.serverId == convId).firstOrNull;
    if (node == null) {
      refreshConversations(); // a chat I don't have yet
      return;
    }
    final m = messageFrom(d);
    if (node.messages.any((x) => x.serverId == m.serverId)) return;
    // My own message sent from this phone: replace the local copy.
    final local = m.isMine
        ? node.messages
              .where(
                (x) =>
                    x.serverId == null && x.kind == m.kind && x.text == m.text,
              )
              .firstOrNull
        : null;
    if (local != null) {
      node.messages[node.messages.indexOf(local)] = local.withServer(m);
    } else {
      node.messages.add(m);
      if (!m.isMine) {
        if (identical(openNode, node)) {
          markRead(node);
        } else {
          node.unread++;
        }
      }
    }
    store.notifyChanged();
  }

  // ------------------------------------------------------------- helpers
  /// Runs a call; errors are shown to the user.
  Future<dynamic> _act(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on ApiError catch (e) {
      onNotice?.call(e.message);
      return null;
    }
  }

  /// Runs a call; errors are ignored (background refresh).
  Future<dynamic> _quiet(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on ApiError {
      return null;
    }
  }
}

/// Someone is calling me.
class IncomingCall {
  IncomingCall({
    required this.id,
    required this.from,
    required this.video,
    this.groupName,
  });
  final int id;
  final Person from;
  final bool video;
  final String? groupName;
}
