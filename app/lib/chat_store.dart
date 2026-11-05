import 'dart:math';

import 'package:flutter/material.dart';

import 'package:latlong2/latlong.dart';

import 'call.dart';
import 'feed.dart';
import 'geo.dart';
import 'models.dart';

class FriendSpot {
  FriendSpot(
    this.person,
    this.position, {
    required this.place,
    required this.status,
    required this.updated,
    required this.common,
  });
  final Person person;
  final Offset position;
  final String place;
  final String status;
  final String updated;
  final int common;
  bool get online => person.online;
  LatLng get latLng => drawnToLatLng(position);
}

/// In-memory data for the prototype. Later this becomes a repository that
/// talks to the Spring Boot / Oracle backend (conversations + members tables).
class ChatStore extends ChangeNotifier {
  ChatStore() {
    _seed();
  }

  Person me = const Person('me', 'Moise', Color(0xFFFF8A3D));

  void setMyName(String name) {
    if (name.trim().isEmpty) return;
    me = Person('me', name.trim(), me.color);
    notifyListeners();
  }

  final List<BubbleNode> nodes = [];
  int _groupSeq = 0;

  static const _melanie = Person('melanie', 'Mélanie', Color(0xFFB07A4F));
  static const _marc = Person('marc', 'Marc', Color(0xFFF06BA8));
  static const _brendon = Person('brendon', 'Brendon', Color(0xFFF59FC4));
  static const _clena = Person(
    'clena',
    'Clena',
    Color(0xFF8B6CF6),
    online: false,
  );
  static const _maurice = Person('maurice', 'Maurice', Color(0xFFC9A27E));
  static const _awa = Person('awa', 'Awa', Color(0xFF4FB3F6));
  static const _yao = Person('yao', 'Yao', Color(0xFF5CC98A), online: false);
  static const _mom = Person('maman', 'Maman', Color(0xFFE5A93B));
  static const _papa = Person('papa', 'Papa', Color(0xFF7D8CA3));
  static const _sis = Person('aicha', 'Aïcha', Color(0xFFD96C6C));
  static const _celine = Person('celine', 'Celine May', Color(0xFF9B6B4F));

  /// Friends who share their location (map page). Positions are in map pixels.
  late final List<FriendSpot> spots = [
    FriendSpot(
      _celine,
      const Offset(560, 760),
      place: 'Marcory, Abidjan',
      status: 'On my way to the match',
      updated: '2 min ago',
      common: 20,
    ),
    FriendSpot(
      _melanie,
      const Offset(985, 640),
      place: 'Remblais, Marcory',
      status: 'At the market',
      updated: '5 min ago',
      common: 12,
    ),
    FriendSpot(
      _marc,
      const Offset(420, 1210),
      place: 'Koumassi',
      status: 'Playing Sudoku',
      updated: 'just now',
      common: 8,
    ),
    FriendSpot(
      _brendon,
      const Offset(905, 1250),
      place: 'Avenue des Métiers',
      status: 'Story time',
      updated: '10 min ago',
      common: 15,
    ),
    FriendSpot(
      _maurice,
      const Offset(770, 1490),
      place: 'Grand Carrefour, Koumassi',
      status: 'Free tonight?',
      updated: '1 h ago',
      common: 5,
    ),
    FriendSpot(
      _awa,
      const Offset(1060, 985),
      place: 'Marcory Zone 4',
      status: 'Coffee break',
      updated: '20 min ago',
      common: 9,
    ),
    FriendSpot(
      _clena,
      const Offset(300, 870),
      place: 'Treichville',
      status: 'Offline',
      updated: '3 h ago',
      common: 3,
    ),
  ];

  /// My position on the map.
  final myPosition = const Offset(700, 1010);

  /// Profiles, videos, comments.
  late final FeedData feed = FeedData(
    me: me,
    friends: [_melanie, _marc, _brendon, _clena, _maurice, _awa, _yao, _celine],
  );

  /// The call in progress, if any (only one at a time).
  CallSession? call;

  CallSession startCall(
    List<Person> people, {
    String? groupName,
    bool video = false,
  }) {
    call?.end();
    final c = CallSession(
      people: people,
      me: me,
      groupName: groupName,
      video: video,
    );
    c.addListener(() {
      if (c.ended && identical(call, c)) {
        call = null;
        notifyListeners();
      }
    });
    call = c;
    notifyListeners();
    return c;
  }

  /// Real GPS position (installed app). Null until the phone shares it.
  LatLng? myLocation;
  bool ghostMode = false;

  void setMyLocation(LatLng? v) {
    myLocation = v;
    notifyListeners();
  }

  bool showOffline = true;

  void setGhostMode(bool v) {
    ghostMode = v;
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
    notifyListeners();
    return node;
  }

  /// Friends that have their own bubble (used by "Create group").
  List<Person> get friends => [
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
    notifyListeners();
    return group;
  }

  void _seed() {
    final t = DateTime.now();
    nodes.addAll([
      BubbleNode.person(
        _melanie,
        home: const Offset(.44, .17),
        size: 53,
        tag: Icons.bookmark,
        messages: [
          Message(
            'Tu as vu le nouveau jeu dans Tales ?',
            sender: _melanie,
            time: t.subtract(const Duration(minutes: 40)),
          ),
          Message(
            'Pas encore, je teste ce soir',
            time: t.subtract(const Duration(minutes: 38)),
          ),
        ],
      ),
      BubbleNode.group(
        id: 'g_family',
        members: [_mom, _papa, _sis],
        home: const Offset(.78, .18),
        name: 'Family group',
        messages: [
          Message(
            'Dîner dimanche chez nous',
            sender: _mom,
            time: t.subtract(const Duration(hours: 3)),
          ),
          Message(
            'Je ramène le dessert',
            sender: _sis,
            time: t.subtract(const Duration(hours: 2)),
          ),
        ],
      ),
      BubbleNode.person(
        _marc,
        home: const Offset(.19, .36),
        size: 52,
        tag: Icons.favorite,
        messages: [
          Message(
            'On se fait un Sudoku en duel ?',
            sender: _marc,
            time: t.subtract(const Duration(minutes: 12)),
          ),
        ],
      ),
      BubbleNode.person(_awa, home: const Offset(.50, .47), size: 30),
      BubbleNode.person(
        _brendon,
        home: const Offset(.75, .51),
        size: 54,
        storyRing: true,
        messages: [
          Message(
            'Regarde ma story',
            sender: _brendon,
            time: t.subtract(const Duration(minutes: 5)),
          ),
        ],
      ),
      BubbleNode.person(_clena, home: const Offset(.20, .62), size: 26),
      BubbleNode.person(
        _maurice,
        home: const Offset(.53, .76),
        size: 52,
        unread: 6,
        messages: [
          Message(
            'Message here',
            sender: _maurice,
            time: t.subtract(const Duration(minutes: 30)),
          ),
          Message(
            'Message here',
            time: t.subtract(const Duration(minutes: 29)),
          ),
          Message(
            'Message here',
            sender: _maurice,
            time: t.subtract(const Duration(minutes: 3)),
          ),
        ],
      ),
      BubbleNode.person(_yao, home: const Offset(.86, .78), size: 24),
    ]);
  }

  /// Drops [dragged] onto [target]. Returns the resulting group and whether it is new.
  ({BubbleNode group, bool created}) merge(
    BubbleNode dragged,
    BubbleNode target,
  ) {
    if (target.isGroup) {
      _addMembers(target, dragged.members);
      if (dragged.isGroup) {
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
    group.members.remove(p);
    if (group.members.length < 2) nodes.remove(group);
    notifyListeners();
  }

  void dissolve(BubbleNode group) {
    nodes.remove(group);
    notifyListeners();
  }

  void rename(BubbleNode group, String name) {
    group.name = name.trim().isEmpty ? null : name.trim();
    notifyListeners();
  }

  void send(BubbleNode node, String text) {
    node.messages.add(Message(text));
    notifyListeners();
    // Fake a reply so the conversation feels alive in the prototype.
    final replier = node.members[Random().nextInt(node.members.length)];
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (!nodes.contains(node)) return;
      const replies = [
        'Ok !',
        'Grave',
        'On se fait une partie ?',
        'Haha',
        'Je suis là',
      ];
      node.messages.add(
        Message(replies[Random().nextInt(replies.length)], sender: replier),
      );
      notifyListeners();
    });
  }

  /// Adds a message to a chat (game results, replies).
  void post(BubbleNode node, Message m) {
    node.messages.add(m);
    notifyListeners();
  }

  void markRead(BubbleNode node) {
    if (node.unread == 0) return;
    node.unread = 0;
    notifyListeners();
  }

  static const _newFriends = [
    Person('koffi', 'Koffi', Color(0xFF6FA8DC)),
    Person('fatou', 'Fatou', Color(0xFFE38BD1)),
    Person('ibrahim', 'Ibrahim', Color(0xFFA3C95C)),
    Person('nadia', 'Nadia', Color(0xFFF0A35E)),
    Person('serge', 'Serge', Color(0xFF8E9AF0)),
  ];

  /// Demo helper for the "+" button: adds the next friend bubble.
  BubbleNode? addFriend() {
    final existing = nodes.expand((n) => n.members).toSet();
    final next = _newFriends.where((p) => !existing.contains(p)).firstOrNull;
    if (next == null) return null;
    final node = BubbleNode.person(next, home: const Offset(.5, .5), size: 34)
      ..spawn = 0;
    nodes.add(node);
    notifyListeners();
    return node;
  }
}
