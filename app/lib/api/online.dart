import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../chat_store.dart';
import '../games/games.dart';
import '../geo.dart';
import '../models.dart';
import 'api_client.dart';
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
class OnlineSync {
  OnlineSync(this.store, this.api, this.myId);

  final ChatStore store;
  final ApiClient api;
  final int myId;
  Realtime? _realtime;

  final Map<int, Person> _people = {};
  final List<Person> friends = [];
  final List<Person> incoming = [];
  final Map<int, OnlineMatch> matches = {};

  /// Set by the UI: a friend challenged me / something to tell the user.
  void Function(OnlineMatch match)? onInvite;
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
    store.feed.me.bio = (meDto['bio'] as String?) ?? '';
    await sync.refreshAll();
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
      body =
          'You sent a ${gameById(gameId).name} challenge'; // the server text is written for the friend
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

  // ------------------------------------------------------------- live events
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
        onNotice?.call(
          '${(d['by'] as Map)['displayName']} accepted your request',
        );
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
