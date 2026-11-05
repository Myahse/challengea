import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../call.dart';
import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import '../games/challenge.dart';
import '../widgets/avatar.dart';

/// Figma: "group call page" frames 28:97 (group) and 32:252 (calling Maurice).
///
/// * You in the middle (red ring), people around you, "+" spots to invite.
/// * While calling one person: their avatar in the middle, the spots pulse,
///   and only the hang-up button shows.
/// * Reaction bar: tap an emoji and it floats up for everyone.
class CallScreen extends StatefulWidget {
  const CallScreen({super.key, required this.store, required this.call});
  final ChatStore store;
  final CallSession call;

  static Future<void> open(
    BuildContext context,
    ChatStore store,
    CallSession call,
  ) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (_, a, _) => SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
          child: CallScreen(store: store, call: call),
        ),
      ),
    );
  }

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> with TickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();
  final List<_Floating> _floating = [];

  CallSession get call => widget.call;

  static const _emojis = ['👋', '👏', '🎉', '💯', '🔥', '😢', '😂'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => call.setScreenOpen(true),
    );
    call.addListener(_onCall);
  }

  @override
  void dispose() {
    call.removeListener(_onCall);
    _pulse.dispose();
    for (final f in _floating) {
      f.controller.dispose();
    }
    super.dispose();
  }

  void _onCall() {
    if (!mounted) return;
    if (call.ended) return;
    // Turn new reactions into floating emojis.
    for (final r in [...call.reactions]) {
      call.consumeReaction(r);
      final c = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 2200),
      );
      final f = _Floating(r, c, Random().nextDouble());
      c.forward().whenComplete(() {
        if (!mounted) return;
        setState(() => _floating.remove(f));
        c.dispose();
      });
      _floating.add(f);
    }
    setState(() {});
  }

  void _hangUp() {
    HapticFeedback.mediumImpact();
    final label = call.connected
        ? 'Call ended · ${call.elapsedLabel}'
        : 'Call cancelled';
    call.end();
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(label, style: tx(14, color: Colors.white)),
        ),
      );
  }

  void _invite() {
    final inCall = call.participants.map((p) => p.person).toSet();
    final candidates = widget.store.friends
        .where((p) => !inCall.contains(p))
        .toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Add to call', style: tx(18, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (candidates.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Everyone is already here',
                  style: tx(14, color: AppColors.muted),
                ),
              ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final p in candidates)
                    ListTile(
                      leading: PersonAvatar(p, diameter: 36),
                      title: Text(
                        p.name,
                        style: tx(15, weight: FontWeight.w500),
                      ),
                      trailing: const Icon(Icons.add_call),
                      onTap: () {
                        Navigator.pop(ctx);
                        call.invite(p);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _options() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.person_add_alt_1_outlined),
              title: Text('Add people', style: tx(15, weight: FontWeight.w500)),
              onTap: () {
                Navigator.pop(ctx);
                _invite();
              },
            ),
            ListTile(
              leading: Icon(
                call.video ? Icons.call_outlined : Icons.videocam_outlined,
              ),
              title: Text(
                call.video ? 'Switch to voice' : 'Switch to video',
                style: tx(15, weight: FontWeight.w500),
              ),
              onTap: () {
                Navigator.pop(ctx);
                call.toggleVideo();
              },
            ),
            ListTile(
              leading: const Icon(Icons.sports_esports_outlined),
              title: Text(
                'Play a game together',
                style: tx(15, weight: FontWeight.w500),
              ),
              subtitle: Text(
                call.isGroup
                    ? 'For 1-to-1 calls'
                    : 'The call keeps going in the background',
                style: tx(12, color: AppColors.muted),
              ),
              enabled: !call.isGroup,
              onTap: () {
                Navigator.pop(ctx); // close the menu
                final friend = call.participants.first.person;
                final nav = Navigator.of(context);
                nav.pop(); // minimize the call (green bar)
                call.setScreenOpen(false);
                challengeFriend(nav.context, widget.store, friend);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calling = !call.connected; // nobody answered yet
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        // Minimized: the call goes on and the green bar shows.
        if (didPop && !call.ended) {
          call.setScreenOpen(false);
        }
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              _header(calling),
              Expanded(
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => LayoutBuilder(
                    builder: (context, c) {
                      final center = Offset(c.maxWidth / 2, c.maxHeight * .5);
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ..._ring(center, calling),
                          for (final f in _floating)
                            _floatingEmoji(f, center, c.biggest),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (!calling) _reactionBar(),
              const SizedBox(height: 18),
              _controls(calling),
              const SizedBox(height: 26),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(bool calling) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
      child: Row(
        children: [
          // Minimize: the call keeps going, a green bar brings you back.
          Material(
            color: AppColors.bubble,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 32,
                height: 32,
                child: Icon(Icons.keyboard_arrow_down_rounded),
              ),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  call.title,
                  style: tx(15, weight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  calling
                      ? (call.video ? 'Video calling…' : 'Calling…')
                      : call.elapsedLabel,
                  style: tx(14, weight: FontWeight.w700).copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          IconButton(onPressed: _options, icon: const Icon(Icons.more_vert)),
        ],
      ),
    );
  }

  /// Spot positions around the middle, starting top-right and going clockwise
  /// (people fill the right side first, like in Figma).
  List<Offset> _spots(Offset center, double radius) => [
    for (final deg in [-45, 0, 45, 90, 135, 180, 225, 270])
      center + Offset.fromDirection(deg * pi / 180, radius),
  ];

  List<Widget> _ring(Offset center, bool calling) {
    const radius = 118.0;
    final spots = _spots(center, radius);
    final widgets = <Widget>[];

    if (calling && !call.isGroup) {
      // Calling one person: dots light up one after another around them.
      for (var i = 0; i < spots.length; i++) {
        final phase = (_pulse.value * spots.length - i) % spots.length;
        final glow = phase < 1 ? 1 - phase : 0.0;
        widgets.add(
          _at(
            spots[i],
            50,
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Color.lerp(
                  AppColors.bubble,
                  AppColors.accent.withValues(alpha: .55),
                  glow,
                ),
              ),
            ),
          ),
        );
      }
      widgets.add(
        _at(
          center,
          86,
          _personDisc(call.participants.first.person, 86, ring: true),
        ),
      );
      return widgets;
    }

    // Me in the middle.
    widgets.add(
      _at(
        center,
        86,
        _withLabel(
          _personDisc(
            call.me,
            86,
            ring: true,
            speaking: identical(call.speaking, call.me),
            muted: !call.micOn,
            video: call.video,
          ),
          'You',
        ),
        extraHeight: 18,
      ),
    );
    for (var i = 0; i < spots.length; i++) {
      if (i < call.participants.length) {
        final p = call.participants[i];
        widgets.add(
          _at(
            spots[i],
            52,
            _withLabel(
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: p.state == CallState.joined
                    ? 1
                    : .45 + .35 * sin(_pulse.value * 2 * pi).abs(),
                child: _personDisc(
                  p.person,
                  52,
                  speaking: call.speaking == p.person,
                  muted: p.state == CallState.joined && p.muted,
                ),
              ),
              p.state == CallState.joined
                  ? '@${p.person.firstName.toLowerCase()}'
                  : 'Ringing…',
            ),
            extraHeight: 16,
          ),
        );
      } else {
        widgets.add(
          _at(
            spots[i],
            50,
            Tooltip(
              message: 'Invite',
              child: Material(
                color: AppColors.bubble,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _invite,
                  child: const SizedBox(
                    width: 50,
                    height: 50,
                    child: Icon(Icons.add, size: 22, color: Color(0xFF555555)),
                  ),
                ),
              ),
            ),
          ),
        );
      }
    }
    return widgets;
  }

  Widget _at(Offset c, double size, Widget child, {double extraHeight = 0}) =>
      Positioned(
        left: c.dx - 50,
        top: c.dy - size / 2,
        width: 100,
        height: size + extraHeight,
        child: Align(alignment: Alignment.topCenter, child: child),
      );

  Widget _withLabel(Widget disc, String label) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      disc,
      const SizedBox(height: 2),
      Text(
        label,
        style: tx(11, weight: FontWeight.w700),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ],
  );

  Widget _personDisc(
    Person p,
    double size, {
    bool ring = false,
    bool speaking = false,
    bool muted = false,
    bool video = false,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            padding: EdgeInsets.all(ring ? 3 : 2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: speaking
                    ? AppColors.online
                    : (ring ? AppColors.storyRing : Colors.transparent),
                width: speaking ? 3 : 2,
              ),
              boxShadow: [
                if (speaking)
                  BoxShadow(
                    color: AppColors.online.withValues(alpha: .35),
                    blurRadius: 14,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: video
                ? Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFF2B2B2B), Color(0xFF555555)],
                      ),
                    ),
                    child: Icon(
                      Icons.videocam_rounded,
                      color: Colors.white,
                      size: size * .36,
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bubble,
                    ),
                    alignment: Alignment.center,
                    child: PersonAvatar(p, diameter: size * .82),
                  ),
          ),
          Positioned(
            right: size * .02,
            bottom: size * .02,
            child: Container(
              width: size * .26 + 4,
              height: size * .26 + 4,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: muted ? const Color(0xFFE5484D) : AppColors.bubble,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: size * .15,
                color: muted ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingEmoji(_Floating f, Offset center, Size area) {
    return AnimatedBuilder(
      animation: f.controller,
      builder: (context, _) {
        final t = f.controller.value;
        final x =
            center.dx + (f.drift - .5) * 160 + sin(t * 6 + f.drift * 6) * 14;
        final y = area.height + 10 - t * (area.height * .95);
        return Positioned(
          left: x - 30,
          top: y,
          child: IgnorePointer(
            child: Opacity(
              opacity: (1 - t).clamp(0.0, 1.0),
              child: Column(
                children: [
                  Text(f.reaction.emoji, style: const TextStyle(fontSize: 38)),
                  if (f.reaction.from != null)
                    Text(
                      f.reaction.from!.firstName,
                      style: tx(
                        10,
                        weight: FontWeight.w600,
                        color: AppColors.muted,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _reactionBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 46),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E6E6),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final e in _emojis)
            InkResponse(
              radius: 22,
              onTap: () {
                HapticFeedback.selectionClick();
                call.react(e);
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _controls(bool calling) {
    final hangUp = Semantics(
      button: true,
      label: calling ? 'Cancel call' : 'Hang up',
      child: GestureDetector(
        onTap: _hangUp,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.ink, width: 2),
            color: Colors.white,
          ),
          child: const Icon(
            Icons.call_end_rounded,
            color: Color(0xFFE5484D),
            size: 34,
          ),
        ),
      ),
    );
    // Figma 32:252: only the big button while calling.
    if (calling) {
      return hangUp;
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _small(
          call.video ? Icons.videocam_rounded : Icons.videocam_off_outlined,
          'Camera',
          call.toggleVideo,
          active: call.video,
        ),
        _small(
          call.micOn ? Icons.mic_rounded : Icons.mic_off_rounded,
          call.micOn ? 'Mute' : 'Unmute',
          call.toggleMic,
          active: !call.micOn,
        ),
        hangUp,
        _small(
          call.speakerOn ? Icons.volume_up_rounded : Icons.hearing_rounded,
          'Speaker',
          call.toggleSpeaker,
          active: call.speakerOn,
        ),
        _small(
          Icons.group_outlined,
          call.joined.length == 1 ? '1 guest' : '${call.joined.length} guests',
          _invite,
        ),
      ],
    );
  }

  Widget _small(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool active = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: active ? AppColors.ink : AppColors.bubble,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 50,
              height: 50,
              child: Icon(icon, color: active ? Colors.white : AppColors.ink),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: tx(11, weight: FontWeight.w500)),
      ],
    );
  }
}

class _Floating {
  _Floating(this.reaction, this.controller, this.drift);
  final Reaction reaction;
  final AnimationController controller;
  final double drift;
}
