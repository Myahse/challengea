import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../call.dart';
import '../models.dart';
import 'online.dart';

/// Connects a [CallSession] to a LiveKit room: real audio/video, who joined,
/// who is speaking, mute states, and emoji reactions over the data channel.
class LiveCall implements CallLink {
  LiveCall(this.sync, this.callId, this.session) {
    session.link = this;
  }

  final OnlineSync sync;
  final int callId;
  final CallSession session;
  Room? _room;
  EventsListener<RoomEvent>? _events;
  Timer? _noAnswer;
  bool _left = false;

  /// Returns an error message, or null once connected.
  Future<String?> connect(String url, String token) async {
    try {
      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _room = room;
      _events = room.createListener()
        ..on<ParticipantConnectedEvent>(
          (e) => session.markJoined(_person(e.participant)),
        )
        ..on<ParticipantDisconnectedEvent>(
          (e) => _onLeft(_person(e.participant)),
        )
        ..on<ActiveSpeakersChangedEvent>((e) {
          final s = e.speakers.firstOrNull;
          session.setSpeaking(
            s == null
                ? null
                : (s is LocalParticipant ? session.me : _person(s)),
          );
        })
        ..on<TrackMutedEvent>((e) => _muteChanged(e.participant))
        ..on<TrackUnmutedEvent>((e) => _muteChanged(e.participant))
        ..on<TrackSubscribedEvent>((_) => session.notifyChanged())
        ..on<LocalTrackPublishedEvent>((_) => session.notifyChanged())
        ..on<DataReceivedEvent>((e) {
          if (e.topic != 'reaction' || e.participant == null) return;
          final emoji = utf8.decode(e.data);
          session.receiveReaction(emoji, _person(e.participant!));
        })
        ..on<RoomDisconnectedEvent>((_) {
          if (!session.ended) session.end();
        });
      await room.connect(url, token);
      await room.localParticipant?.setMicrophoneEnabled(true);
      if (session.video) await room.localParticipant?.setCameraEnabled(true);
      for (final p in room.remoteParticipants.values) {
        session.markJoined(_person(p));
      }
      // Nobody answers within 45 s: hang up (the server records a missed call).
      _noAnswer = Timer(const Duration(seconds: 45), () {
        if (!session.connected && !session.ended) {
          sync.onNotice?.call('No answer');
          session.end();
        }
      });
      return null;
    } catch (e) {
      debugPrint('LiveKit: $e');
      return 'Couldn’t connect the call. Is the call server running?';
    }
  }

  Person _person(Participant p) =>
      sync.personById(p.identity) ??
      Person(
        p.identity,
        p.name.isEmpty ? 'Guest' : p.name,
        const Color(0xFF8B6CF6),
      );

  void _muteChanged(Participant p) {
    if (p is LocalParticipant) return;
    session.setMuted(_person(p), !p.isMicrophoneEnabled());
  }

  void _onLeft(Person p) {
    session.markLeft(p);
    // 1-to-1: when the other person hangs up, the call is over.
    if (!session.isGroup || session.joined.isEmpty) session.end();
  }

  @override
  void setMic(bool on) => _room?.localParticipant?.setMicrophoneEnabled(on);

  @override
  void setCamera(bool on) => _room?.localParticipant
      ?.setCameraEnabled(on)
      .then((_) => session.notifyChanged());

  @override
  void setSpeaker(bool on) {
    if (kIsWeb) return; // browsers pick the output themselves
    AudioManager.instance.setSpeakerOutputPreferred(on).catchError((_) {});
  }

  @override
  void sendReaction(String emoji) => _room?.localParticipant?.publishData(
    utf8.encode(emoji),
    reliable: true,
    topic: 'reaction',
  );

  @override
  void invite(Person p) => sync.inviteToCall(callId, p);

  @override
  void hangUp() {
    if (_left) return;
    _left = true;
    _noAnswer?.cancel();
    _events?.dispose();
    _room?.disconnect();
    _room?.dispose();
    sync.leaveCall(callId);
  }

  @override
  VideoTrack? videoTrackOf(Person p) {
    final room = _room;
    if (room == null) return null;
    final Participant? who = p.id == session.me.id
        ? room.localParticipant
        : room.remoteParticipants.values
              .where((x) => x.identity == p.id)
              .firstOrNull;
    final pub = who?.videoTrackPublications
        .where((t) => !t.muted && t.track != null)
        .firstOrNull;
    return pub?.track as VideoTrack?;
  }
}
