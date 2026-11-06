import 'dart:math';
import 'dart:typed_data';

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

enum MessageKind { text, image, voice, sticker }

class Message {
  Message(
    this.text, {
    this.sender,
    DateTime? time,
    this.game,
    this.serverId,
    this.isChallenge = false,
    this.isEvent = false,
    this.kind = MessageKind.text,
    this.mediaUrl,
    this.localPath,
    this.localBytes,
    this.duration,
    this.waveform,
  }) : time = time ?? DateTime.now();

  final MessageKind kind;

  /// Photo / voice note on the server (absolute URL).
  final String? mediaUrl;

  /// Just recorded or picked on this phone (shown before / without upload).
  final String? localPath;
  final Uint8List? localBytes;

  /// Voice notes: length and loudness bars (0..1).
  final Duration? duration;
  final List<double>? waveform;

  /// Same message with the server's id and URL, keeping the local file so
  /// the photo doesn't flicker when the upload finishes.
  Message withServer(Message server) => Message(
    server.text,
    sender: server.sender,
    time: server.time,
    game: server.game,
    serverId: server.serverId,
    isChallenge: server.isChallenge,
    isEvent: server.isEvent,
    kind: server.kind,
    mediaUrl: server.mediaUrl,
    localPath: localPath,
    localBytes: localBytes,
    duration: server.duration ?? duration,
    waveform: server.waveform ?? waveform,
  );

  /// A challenge invite (not a result): the card shows no Rematch button.
  final bool isChallenge;

  /// A call log line ("📞 Voice call · 3:12"): shown centered, not as a bubble.
  final bool isEvent;
  final String text;

  /// Id in the backend (null in demo mode or while sending).
  final int? serverId;

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

  /// Conversation id in the backend (null in demo mode or until created).
  int? serverId;

  /// Completes when the server has created this conversation.
  Future<void>? pending;

  /// Messages were fetched from the server.
  bool loaded = false;
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
