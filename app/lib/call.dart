import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import 'models.dart';

enum CallState { ringing, joined }

class CallParticipant {
  CallParticipant(
    this.person, {
    this.state = CallState.ringing,
    this.muted = false,
  });
  final Person person;
  CallState state;
  bool muted;
}

class Reaction {
  Reaction(this.emoji, this.from) : id = _seq++;
  static int _seq = 0;
  final int id;
  final String emoji;
  final Person? from; // null = me
}

/// One call in progress. Prototype: people "answer" after a short delay and
/// the active speaker changes randomly. The real app will plug a WebRTC
/// service (e.g. LiveKit) in here; the screen stays the same.
class CallSession extends ChangeNotifier {
  CallSession({
    required List<Person> people,
    required this.me,
    this.groupName,
    this.video = false,
    this.simulate = true,
  }) : startedAsGroup = people.length > 1,
       participants = [for (final p in people) CallParticipant(p)] {
    if (simulate) _scheduleAnswers();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// Demo: people answer by themselves. Live: a [CallLink] (LiveKit) drives it.
  final bool simulate;
  CallLink? link;

  // ---- updates from the live call ----
  void markJoined(Person p) {
    final c = participants.where((x) => x.person.id == p.id).firstOrNull;
    if (c == null) {
      participants.add(CallParticipant(p, state: CallState.joined));
    } else {
      c.state = CallState.joined;
    }
    connectedAt ??= DateTime.now();
    notifyListeners();
  }

  /// Someone hung up. In a 1-to-1 call they stay listed (the call ends right after).
  void markLeft(Person p) {
    if (isGroup && participants.length > 1) {
      participants.removeWhere((x) => x.person.id == p.id);
    }
    notifyListeners();
  }

  void setSpeaking(Person? p) {
    speaking = p;
    notifyListeners();
  }

  void setMuted(Person p, bool muted) {
    for (final c in participants) {
      if (c.person.id == p.id) c.muted = muted;
    }
    notifyListeners();
  }

  /// For [CallLink]s (notifyListeners is protected).
  void notifyChanged() => notifyListeners();

  void receiveReaction(String emoji, Person from) {
    reactions.add(Reaction(emoji, from));
    notifyListeners();
  }

  final Person me;
  final String? groupName;
  final bool startedAsGroup;
  final List<CallParticipant> participants;
  final List<Reaction> reactions = [];
  final _rnd = Random();
  late final Timer _ticker;
  final List<Timer> _timers = [];

  DateTime? connectedAt;
  bool micOn = true;
  bool video;
  bool speakerOn = false;
  bool ended = false;
  bool screenOpen = false;
  Person? speaking; // null = nobody, me = [me]

  static const maxGuests = 8;

  bool get isGroup => startedAsGroup || participants.length > 1;
  bool get connected => connectedAt != null;
  List<CallParticipant> get joined =>
      participants.where((p) => p.state == CallState.joined).toList();

  String get title {
    if (isGroup) return groupName ?? 'Group call';
    return participants.firstOrNull?.person.name ?? 'Call';
  }

  Duration get elapsed =>
      connected ? DateTime.now().difference(connectedAt!) : Duration.zero;

  String get elapsedLabel {
    final d = elapsed;
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    return h > 0
        ? '${two(h)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}'
        : '${two(d.inMinutes)}:${two(d.inSeconds % 60)}';
  }

  void _later(Duration d, VoidCallback f) => _timers.add(
    Timer(d, () {
      if (!ended) f();
    }),
  );

  void _scheduleAnswers() {
    for (var i = 0; i < participants.length; i++) {
      final p = participants[i];
      if (p.state == CallState.joined) continue;
      _later(Duration(milliseconds: 2200 + i * 900 + _rnd.nextInt(600)), () {
        p.state = CallState.joined;
        p.muted = _rnd.nextInt(4) == 0;
        connectedAt ??= DateTime.now();
        notifyListeners();
      });
    }
  }

  void _tick() {
    if (ended) return;
    if (!simulate) {
      notifyListeners(); // the timer
      return;
    }
    // Pretend someone is talking.
    final talkers = <Person>[
      if (micOn) me,
      for (final p in joined)
        if (!p.muted) p.person,
    ];
    speaking = talkers.isEmpty || _rnd.nextInt(5) == 0
        ? null
        : talkers[_rnd.nextInt(talkers.length)];
    // Others react from time to time.
    if (joined.isNotEmpty && _rnd.nextInt(6) == 0) {
      const emojis = ['👋', '👏', '🎉', '💯', '🔥', '😂'];
      reactions.add(
        Reaction(
          emojis[_rnd.nextInt(emojis.length)],
          joined[_rnd.nextInt(joined.length)].person,
        ),
      );
    }
    notifyListeners();
  }

  /// Adding someone turns a 1-to-1 call into a group call.
  void invite(Person p) {
    if (participants.length >= maxGuests ||
        participants.any((c) => c.person == p)) {
      return;
    }
    participants.add(CallParticipant(p));
    if (simulate) {
      _scheduleAnswers();
    } else {
      link?.invite(p);
    }
    notifyListeners();
  }

  void react(String emoji) {
    link?.sendReaction(emoji);
    reactions.add(Reaction(emoji, null));
    notifyListeners();
  }

  void consumeReaction(Reaction r) => reactions.remove(r);

  void toggleMic() {
    micOn = !micOn;
    link?.setMic(micOn);
    notifyListeners();
  }

  void toggleVideo() {
    video = !video;
    link?.setCamera(video);
    notifyListeners();
  }

  void toggleSpeaker() {
    speakerOn = !speakerOn;
    link?.setSpeaker(speakerOn);
    notifyListeners();
  }

  void setScreenOpen(bool v) {
    screenOpen = v;
    notifyListeners();
  }

  void end() {
    if (ended) return;
    ended = true;
    link?.hangUp();
    _ticker.cancel();
    for (final t in _timers) {
      t.cancel();
    }
    notifyListeners();
  }

  @override
  void dispose() {
    end();
    super.dispose();
  }
}

/// What a live call (LiveKit) does for [CallSession]. Implemented in api/live_call.dart.
abstract class CallLink {
  void setMic(bool on);
  void setCamera(bool on);
  void setSpeaker(bool on);
  void sendReaction(String emoji);
  void invite(Person p);
  void hangUp();

  /// Live video of a person (or me), if their camera is on.
  Object? videoTrackOf(Person p);
}
