import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:livekit_client/livekit_client.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import '../widgets/moments.dart';
import '../widgets/motion.dart';

class _Line {
  _Line(this.name, this.text);
  final String name;
  final String text;
}

/// A live broadcast, for the host and for friends watching. Video and chat
/// both go through LiveKit.
class LiveScreen extends StatefulWidget {
  const LiveScreen({
    super.key,
    required this.store,
    required this.host,
    required this.liveId,
    required this.url,
    required this.token,
    required this.hosting,
  });
  final ChatStore store;
  final Person host;
  final int liveId;
  final String url;
  final String token;
  final bool hosting;

  /// Asks for a title, then goes live.
  static Future<void> start(BuildContext context, ChatStore store) async {
    final online = store.online;
    if (online == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Sign in to go live (this is the demo)',
            style: tx(14, color: Colors.white),
          ),
        ),
      );
      return;
    }
    final title = TextEditingController();
    final go = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          20 + MediaQuery.viewInsetsOf(ctx).bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Go live', style: tx(34, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(
              'Your friends get told right away.',
              style: tx(16, color: AppColors.muted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: title,
              maxLength: 120,
              style: tx(17),
              decoration: InputDecoration(
                hintText: 'What’s happening?',
                hintStyle: tx(17, color: AppColors.muted),
                filled: true,
                fillColor: AppColors.page,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 6),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.danger,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Go live', style: tx(17, color: Colors.white)),
            ),
          ],
        ),
      ),
    );
    if (go != true || !context.mounted) return;
    final join = await online.startLive(title.text.trim());
    if (join == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveScreen(
          store: store,
          host: store.me,
          liveId: join.id,
          url: join.url,
          token: join.token,
          hosting: true,
        ),
      ),
    );
  }

  static Future<void> watch(
    BuildContext context,
    ChatStore store,
    OnlineLive live,
  ) async {
    final join = await store.online?.watchLive(live.id);
    if (join == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LiveScreen(
          store: store,
          host: live.host,
          liveId: live.id,
          url: join.url,
          token: join.token,
          hosting: false,
        ),
      ),
    );
  }

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );
  EventsListener<RoomEvent>? _events;
  final _input = TextEditingController();
  final _heartKey = GlobalKey();
  final List<_Line> _lines = [];
  bool _connecting = true;
  bool _ended = false;
  String? _error;
  DateTime _startedAt = DateTime.now();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _connect();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _connect() async {
    try {
      _events = _room.createListener()
        ..on<ParticipantConnectedEvent>((_) => _refresh())
        ..on<ParticipantDisconnectedEvent>((e) {
          if (!widget.hosting && e.participant.identity == widget.host.id) {
            setState(() => _ended = true);
          }
          _refresh();
        })
        ..on<TrackSubscribedEvent>((_) => _refresh())
        ..on<TrackUnsubscribedEvent>((_) => _refresh())
        ..on<LocalTrackPublishedEvent>((_) => _refresh())
        ..on<DataReceivedEvent>(_onData)
        ..on<RoomDisconnectedEvent>((_) {
          if (mounted && !_ended) setState(() => _ended = true);
        });
      await _room.connect(widget.url, widget.token);
      if (widget.hosting) {
        await _room.localParticipant?.setCameraEnabled(true);
        await _room.localParticipant?.setMicrophoneEnabled(true);
      }
      if (!mounted) return;
      setState(() {
        _connecting = false;
        _startedAt = DateTime.now();
      });
    } catch (e) {
      debugPrint('Live: $e');
      if (mounted) {
        setState(() {
          _connecting = false;
          _error = 'Couldn’t connect. Is the call server running?';
        });
      }
    }
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onData(DataReceivedEvent e) {
    if (e.topic == 'live-heart') {
      final ctx = _heartKey.currentContext;
      if (ctx != null && mounted) _heart(ctx);
    } else if (e.topic == 'live-chat') {
      final text = utf8.decode(e.data);
      _add(_Line(e.participant?.name ?? 'Guest', text));
    }
  }

  void _add(_Line line) {
    if (!mounted) return;
    setState(() {
      _lines.add(line);
      if (_lines.length > 30) _lines.removeAt(0);
    });
  }

  void _heart(BuildContext ctx) => Burst.on(
    ctx,
    emoji: '❤️',
    count: 10,
    spread: 70,
    colors: const [AppColors.danger, Color(0xFFFF9DB5)],
  );

  void _send() {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    _add(_Line(widget.store.me.firstName, text));
    _room.localParticipant?.publishData(
      utf8.encode(text),
      reliable: true,
      topic: 'live-chat',
    );
  }

  void _sendHeart() {
    HapticFeedback.lightImpact();
    final ctx = _heartKey.currentContext;
    if (ctx != null) _heart(ctx);
    _room.localParticipant?.publishData(
      utf8.encode('1'),
      reliable: false,
      topic: 'live-heart',
    );
  }

  Future<void> _leave() async {
    if (!widget.hosting) {
      Navigator.pop(context);
      return;
    }
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('End your live?', style: tx(24, weight: FontWeight.w600)),
        content: Text(
          'Everyone watching will be disconnected.',
          style: tx(16, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Stay', style: tx(16, color: AppColors.link)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('End', style: tx(16, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (sure == true && mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _tick?.cancel();
    if (widget.hosting) widget.store.online?.endLive(widget.liveId);
    _events?.dispose();
    _room.disconnect();
    _room.dispose();
    _input.dispose();
    super.dispose();
  }

  VideoTrack? get _video {
    final Participant? who = widget.hosting
        ? _room.localParticipant
        : _room.remoteParticipants.values
              .where((p) => p.identity == widget.host.id)
              .firstOrNull;
    final pub = who?.videoTrackPublications
        .where((t) => !t.muted && t.track != null)
        .firstOrNull;
    return pub?.track as VideoTrack?;
  }

  String get _time {
    final d = DateTime.now().difference(_startedAt);
    return '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);
    final video = _video;
    // Not counting the host, and counting me if I'm watching.
    final watchers =
        _room.remoteParticipants.values
            .where((p) => p.identity != widget.host.id)
            .length +
        (widget.hosting ? 0 : 1);
    return PopScope(
      canPop: !widget.hosting,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) _leave();
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.night,
          resizeToAvoidBottomInset: true,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (video != null)
                VideoTrackRenderer(
                  video,
                  fit: VideoViewFit.cover,
                  mirrorMode: widget.hosting
                      ? VideoViewMirrorMode.mirror
                      : VideoViewMirrorMode.off,
                )
              else
                _waiting(),
              const IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment(0, .1),
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xB0000000)],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                top: inset.top + 8,
                child: _top(watchers),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 10 + inset.bottom,
                child: _bottom(),
              ),
              if (_ended) _endedCover(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _waiting() => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Floaty(child: PersonAvatar(widget.host, diameter: 120)),
          const SizedBox(height: 20),
          Text(
            _error ?? (_connecting ? 'Connecting' : 'Starting the camera'),
            textAlign: TextAlign.center,
            style: tx(17, color: AppColors.nightMuted),
          ),
        ],
      ),
    ),
  );

  Widget _top(int watchers) => Row(
    children: [
      Glass(
        radius: 24,
        dark: true,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PersonAvatar(widget.host, diameter: 34),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  widget.host.firstName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tx(15, weight: FontWeight.w600, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.danger,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'LIVE  $_time',
          style: tx(13, weight: FontWeight.w600, color: Colors.white),
        ),
      ),
      const SizedBox(width: 8),
      Glass(
        radius: 14,
        dark: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.visibility_outlined,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text('$watchers', style: tx(13, color: Colors.white)),
            ],
          ),
        ),
      ),
      const Spacer(),
      Glass(
        radius: 24,
        dark: true,
        child: IconButton(
          tooltip: widget.hosting ? 'End live' : 'Close',
          onPressed: _leave,
          icon: const Icon(Icons.close_rounded, color: Colors.white),
        ),
      ),
    ],
  );

  Widget _bottom() => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final l in _lines.reversed.take(6).toList().reversed)
        FadeSlideIn(
          key: ObjectKey(l),
          duration: Motion.normal,
          offset: const Offset(0, 12),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${l.name}  ',
                    style: tx(15, weight: FontWeight.w600, color: Colors.white),
                  ),
                  TextSpan(
                    text: l.text,
                    style: tx(15, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      const SizedBox(height: 4),
      Row(
        children: [
          Expanded(
            child: TextField(
              controller: _input,
              onSubmitted: (_) => _send(),
              textInputAction: TextInputAction.send,
              style: tx(16, color: Colors.white),
              cursorColor: Colors.white,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Say something',
                hintStyle: tx(16, color: Colors.white),
                filled: true,
                fillColor: Colors.black.withValues(alpha: .45),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(color: Colors.white38),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Pressable(
            onTap: _sendHeart,
            child: Container(
              key: _heartKey,
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.danger,
              ),
              child: const Icon(
                Icons.favorite_rounded,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    ],
  );

  Widget _endedCover() => ColoredBox(
    color: Colors.black.withValues(alpha: .86),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'The live has ended.',
            textAlign: TextAlign.center,
            style: tx(34, weight: FontWeight.w600, color: AppColors.nightInk),
          ),
          TextLink(
            label: 'Back',
            dark: true,
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    ),
  );
}
