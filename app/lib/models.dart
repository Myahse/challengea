import 'dart:math';

import 'package:flutter/material.dart';

import 'games/games.dart';

class Person {
  const Person(this.id, this.name, this.color, {this.online = true});
  final String id;
  final String name;
  final Color color;
  final bool online;

  String get initials =>
      name.isEmpty ? '?' : name.characters.first.toUpperCase();
  String get firstName => name.split(' ').first;
}

class Message {
  Message(this.text, {this.sender, DateTime? time, this.game})
    : time = time ?? DateTime.now();
  final String text;

  /// Set for game results posted in the chat (shows a Rematch button).
  final GameInfo? game;
  final Person? sender; // null = me
  final DateTime time;
  bool get isMine => sender == null;
}

/// One bubble on the chat home: a single friend, or a group made by merging bubbles.
class BubbleNode {
  BubbleNode.person(
    Person p, {
    required this.home,
    this.size = 52,
    this.unread = 0,
    this.tag,
    this.storyRing = false,
    List<Message>? messages,
  }) : id = 'p_${p.id}',
       isGroup = false,
       members = [p],
       messages = messages ?? [];

  BubbleNode.group({
    required this.id,
    required this.members,
    required this.home,
    this.name,
    List<Message>? messages,
  }) : isGroup = true,
       size = 0,
       unread = 0,
       tag = null,
       storyRing = false,
       messages = messages ?? [];

  final String id;
  final bool isGroup;
  final List<Person> members;
  String? name;
  final List<Message> messages;
  int unread;
  final IconData? tag;
  final bool storyRing;

  /// Radius in Figma pixels (scaled to the screen width at render time).
  final double size;
  double get radius => isGroup ? 34 + 4.0 * members.length.clamp(2, 6) : size;

  String get displayName => isGroup
      ? (name?.isNotEmpty == true
            ? name!
            : members.map((m) => m.firstName).join(', '))
      : members.first.name;

  // ---- layout / physics state (owned by BubbleField) ----
  /// Resting position as a fraction (0..1) of the bubble area.
  Offset home;
  Offset? pos; // pixels
  Offset vel = Offset.zero;
  double spawn = 1; // 0 -> 1 pop-in animation progress
  final double phase =
      _rng.nextDouble() * 2 * pi; // so bubbles float out of sync
  static final _rng = Random();
}
