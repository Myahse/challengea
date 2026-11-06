import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';

import 'api/online.dart';
import 'call.dart';
import 'feed.dart';
import 'geo.dart';
import 'mock/chats.dart';
import 'mock/people.dart';
import 'models.dart';
import 'stories.dart';

class FriendSpot {
  FriendSpot(
    this.person,
    Offset position, {
    required this.place,
    required this.status,
    required this.updated,
    required this.common,
  }) : _position = position,
       _real = null;

  /// A friend at a real GPS position (from the backend).
  FriendSpot.real(
    this.person,
    LatLng real, {
    required this.place,
    required this.status,
    required this.updated,
    this.common = 0,
  }) : _position = null,
       _real = real;

  final Person person;
  final Offset? _position;
  final LatLng? _real;
  final String place;
  final String status;
  final String updated;
  final int common;
  bool get online => person.online;

  /// Position on the drawn map (demo) and real coordinates (real map).
  Offset get position => _position ?? latLngToDrawn(_real!);
  LatLng get latLng => _real ?? drawnToLatLng(_position!);
}

/// The app's data. Demo mode: in-memory sample data. Online mode
/// ([goOnline]): the same objects, filled and kept in sync by [OnlineSync].
class ChatStore extends ChangeNotifier {
  ChatStore() {
    _seed();
  }

  /// Set when signed in to the backend.
  OnlineSync? online;

  /// Signs out and goes back to the sign-in screen (set by the app root).
  Future<void> Function()? onSignOut;
  bool get isOnline => online != null;

  /// Switches from the demo data to the signed-in account.
  void goOnline(OnlineSync sync, Person me) {
    online = sync;
    this.me = me;
    nodes.clear();
    spots.clear();
    notifyListeners();
  }

  void replaceNodes(List<BubbleNode> fresh) {
    nodes
      ..clear()
      ..addAll(fresh);
    notifyListeners();
  }

  /// For [OnlineSync] (notifyListeners is protected).
  void notifyChanged() => notifyListeners();

  /// A bubble was dropped somewhere new.
  void bubbleMoved(BubbleNode n) => online?.saveBubble(n);

  /// A chat is shown on screen / closed.
  void openChat(BubbleNode n) {
    final o = online;
    if (o == null) return;
    o.openNode = n;
    if (!n.loaded) o.loadMessages(n);
  }

  void closeChat(BubbleNode n) {
    if (identical(online?.openNode, n)) online?.openNode = null;
  }

  Person me = MockPeople.me;

  void setMyName(String name) {
    if (name.trim().isEmpty) return;
    me = Person(me.id, name.trim(), me.color);
    notifyListeners();
  }

  final List<BubbleNode> nodes = [];
  int _groupSeq = 0;

  /// Friends who share their location (map page). Positions are in map pixels.
  final List<FriendSpot> spots = [];

  /// Stories from the last 24 h (demo content for now), and mine.
  final List<Story> stories = mockStories();
  late final Story myStory = Story(me, []);

  void markStorySeen(Story s) {
    if (s.seen) return;
    s.seen = true;
    notifyListeners();
  }

  void addToMyStory(StoryItem item) {
    myStory.items.add(item);
    notifyListeners();
  }

  /// My position on the drawn map.
  Offset get myPosition => online != null
      ? latLngToDrawn(myLocation ?? marcory)
      : const Offset(700, 1010);

  /// Profiles, videos, comments.
  late final FeedData feed = FeedData(me: me, friends: MockPeople.feedFriends);

  /// The call in progress, if any (only one at a time).
  CallSession? call;

  CallSession startCall(
    List<Person> people, {
    String? groupName,
    bool video = false,
  }) {
    final c = CallSession(
      people: people,
      me: me,
      groupName: groupName,
      video: video,
    );
    adoptCall(c);
    return c;
  }

  /// Makes [c] the current call (ends any other one).
  void adoptCall(CallSession c) {
    if (!identical(call, c)) call?.end();
    c.addListener(() {
      if (c.ended && identical(call, c)) {
        call = null;
        notifyListeners();
      }
    });
    call = c;
    notifyListeners();
  }

  /// Real GPS position (installed app). Null until the phone shares it.
  LatLng? myLocation;
  bool ghostMode = false;

  void setMyLocation(LatLng? v) {
    myLocation = v;
    if (v != null) online?.pushLocation(v);
    notifyListeners();
  }

  bool showOffline = true;

  void setGhostMode(bool v) {
    ghostMode = v;
    online?.setGhost(v);
    notifyListeners();
  }

  void setShowOffline(bool v) {
    showOffline = v;
    notifyListeners();
  }

  /// The 1-to-1 chat bubble for [p]; created (and shown on the chat home) if missing.
  BubbleNode nodeFor(Person p) {
    final existing = nodes
        .where((n) => !n.isGroup && n.members.first == p)
        .firstOrNull;
    if (existing != null) return existing;
    final node = BubbleNode.person(p, home: const Offset(.5, .5), size: 34)
      ..spawn = 0;
    nodes.add(node);
    if (online != null) node.pending = online!.ensureDirect(node);
    notifyListeners();
    return node;
  }

  /// Friends that have their own bubble (used by "Create group").
  List<Person> get friends =>
      online?.friends ??
      [
        for (final n in nodes)
          if (!n.isGroup) n.members.first,
      ];

  BubbleNode createGroup(List<Person> members, {String? name}) {
    final group = BubbleNode.group(
      id: 'g_${_groupSeq++}',
      members: [...members],
      home: const Offset(.5, .45),
      name: name,
    )..spawn = 0;
    nodes.add(group);
    if (online != null) group.pending = online!.createGroup(group);
    notifyListeners();
    return group;
  }

  void _seed() {
    for (final s in mockSpots()) {
      spots.add(
        FriendSpot(
          s.person,
          s.position,
          place: s.place,
          status: s.status,
          updated: s.updated,
          common: s.common,
        ),
      );
    }
    nodes.addAll(mockBubbles());
  }

  /// Drops [dragged] onto [target]. Returns the resulting group and whether it is new.
  ({BubbleNode group, bool created}) merge(
    BubbleNode dragged,
    BubbleNode target,
  ) {
    if (target.isGroup) {
      final added = dragged.members
          .where((m) => !target.members.contains(m))
          .toList();
      _addMembers(target, dragged.members);
      online?.addMembers(target, added);
      // Online, the other group stays on the server (it may belong to someone else).
      if (dragged.isGroup && online == null) {
        target.messages.addAll(dragged.messages);
        target.messages.sort((a, b) => a.time.compareTo(b.time));
        nodes.remove(dragged);
      }
      target.spawn = 0.55; // little "gulp" bounce
      notifyListeners();
      return (group: target, created: false);
    }
    if (dragged.isGroup) {
      _addMembers(dragged, target.members);
      online?.addMembers(dragged, target.members);
      dragged.spawn = 0.55;
      notifyListeners();
      return (group: dragged, created: false);
    }
    final group =
        BubbleNode.group(
            id: 'g_${_groupSeq++}',
            members: [target.members.first, dragged.members.first],
            home: target.home,
          )
          ..pos = target.pos
          ..spawn = 0;
    nodes.add(group);
    if (online != null) group.pending = online!.createGroup(group);
    notifyListeners();
    return (group: group, created: true);
  }

  bool canMerge(BubbleNode dragged, BubbleNode target) {
    if (identical(dragged, target)) return false;
    final into = target.isGroup ? target : (dragged.isGroup ? dragged : null);
    if (into == null) return true;
    final other = identical(into, target) ? dragged : target;
    return other.members.any((m) => !into.members.contains(m)) || other.isGroup;
  }

  void _addMembers(BubbleNode group, List<Person> people) {
    for (final p in people) {
      if (!group.members.contains(p)) group.members.add(p);
    }
  }

  void removeMember(BubbleNode group, Person p) {
    online?.removeMember(group, p);
    group.members.remove(p);
    if (group.members.length < 2) nodes.remove(group);
    notifyListeners();
  }

  /// "Split group": online, you leave it (others keep it).
  void dissolve(BubbleNode group) {
    online?.leave(group);
    nodes.remove(group);
    notifyListeners();
  }

  void rename(BubbleNode group, String name) {
    group.name = name.trim().isEmpty ? null : name.trim();
    online?.rename(group, group.name);
    notifyListeners();
  }

  void send(BubbleNode node, String text) {
    if (online != null) {
      online!.send(node, text);
      return;
    }
    node.messages.add(Message(text));
    notifyListeners();
    // Fake a reply so the conversation feels alive in the prototype.
    final replier = node.members[Random().nextInt(node.members.length)];
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!nodes.contains(node)) return;
      node.messages.add(
        Message(
          mockReplies[Random().nextInt(mockReplies.length)],
          sender: replier,
        ),
      );
      notifyListeners();
    });
  }

  /// Photo, voice note or sticker. Demo: stays on the phone. Online: uploaded.
  void sendMedia(
    BubbleNode node,
    Message local, {
    Uint8List? bytes,
    String? contentType,
  }) {
    if (online != null) {
      online!.sendMedia(node, local, bytes: bytes, contentType: contentType);
      return;
    }
    node.messages.add(local);
    notifyListeners();
  }

  /// Adds a message to a chat (game results, replies).
  void post(BubbleNode node, Message m) {
    node.messages.add(m);
    notifyListeners();
  }

  void markRead(BubbleNode node) {
    online?.markRead(node);
    if (node.unread == 0) return;
    node.unread = 0;
    notifyListeners();
  }

  /// Demo helper for the "+" button: adds the next friend bubble.
  BubbleNode? addFriend() {
    if (online != null) return null; // online: the UI opens the friend search
    final existing = nodes.expand((n) => n.members).toSet();
    final next = MockPeople.extras
        .where((p) => !existing.contains(p))
        .firstOrNull;
    if (next == null) return null;
    final node = BubbleNode.person(next, home: const Offset(.5, .5), size: 34)
      ..spawn = 0;
    nodes.add(node);
    notifyListeners();
    return node;
  }
}
