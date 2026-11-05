import 'dart:math';

import 'package:flutter/material.dart';

import 'models.dart';

/// In-memory data for the prototype. Later this becomes a repository that
/// talks to the Spring Boot / Oracle backend (conversations + members tables).
class ChatStore extends ChangeNotifier {
  ChatStore() {
    _seed();
  }

  final me = const Person('me', 'Moise', Color(0xFFFF8A3D));
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
