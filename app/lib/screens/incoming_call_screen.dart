import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/online.dart';
import '../chat_store.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/motion.dart';
import 'call_screen.dart';

/// Full-screen ringing: who is calling, Accept / Decline.
class IncomingCallScreen extends StatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.store,
    required this.call,
  });
  final ChatStore store;
  final IncomingCall call;

  static Future<void> show(
    BuildContext context,
    ChatStore store,
    IncomingCall call,
  ) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: true,
        transitionDuration: Motion.slow,
        pageBuilder: (_, a, _) => FadeTransition(
          opacity: a,
          child: ScaleTransition(
            scale: Tween(
              begin: 1.08,
              end: 1.0,
            ).animate(CurvedAnimation(parent: a, curve: Motion.ease)),
            child: IncomingCallScreen(store: store, call: call),
          ),
        ),
      ),
    );
  }

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();
  Timer? _buzz;
  Timer? _check;

  OnlineSync get online => widget.store.online!;

  @override
  void initState() {
    super.initState();
    HapticFeedback.heavyImpact();
    _buzz = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) => HapticFeedback.mediumImpact(),
    );
    // The caller hung up (or someone else answered): close.
    _check = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if (online.endedCalls.contains(widget.call.id) && mounted) {
        _close();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Missed call from ${widget.call.from.firstName}',
              style: tx(14, color: Colors.white),
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _buzz?.cancel();
    _check?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _close() {
    _buzz?.cancel();
    _check?.cancel();
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  void _accept() {
    final session = online.acceptCall(widget.call);
    final nav = Navigator.of(context);
    _close();
    CallScreen.open(nav.context, widget.store, session);
  }

  void _decline() {
    online.declineCall(widget.call);
    _close();
  }

  @override
  Widget build(BuildContext context) {
    final from = widget.call.from;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.lerp(from.color, Colors.white, .55)!,
              from.color,
              Color.lerp(from.color, Colors.black, .55)!,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 60),
              FadeSlideIn(
                child: Text(
                  widget.call.groupName ?? from.name,
                  textAlign: TextAlign.center,
                  style: tx(34, weight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(height: 6),
              FadeSlideIn(
                delay: const Duration(milliseconds: 120),
                child: Text(
                  widget.call.groupName != null
                      ? '${from.firstName} is calling the group'
                      : (widget.call.video ? 'Video call…' : 'Voice call…'),
                  style: tx(16, color: Colors.white70),
                ),
              ),
              const Spacer(),
              // Avatar with rings pulsing outwards.
              SizedBox(
                width: 280,
                height: 280,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, _) => Stack(
                    alignment: Alignment.center,
                    children: [
                      for (var i = 0; i < 3; i++)
                        Builder(
                          builder: (_) {
                            final t = (_pulse.value + i / 3) % 1;
                            return Container(
                              width: 140 + 140 * t,
                              height: 140 + 140 * t,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(
                                    alpha: .5 * (1 - t),
                                  ),
                                  width: 2,
                                ),
                              ),
                            );
                          },
                        ),
                      Transform.scale(
                        scale: 1 + .03 * sin(_pulse.value * 2 * pi * 2),
                        child: Container(
                          padding: const EdgeInsets.all(5),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: PersonAvatar(from, diameter: 130),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FadeSlideIn(
                delay: const Duration(milliseconds: 250),
                offset: const Offset(0, 60),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(40, 0, 40, 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _button(
                        Icons.call_end_rounded,
                        'Decline',
                        const Color(0xFFE5484D),
                        _decline,
                      ),
                      _button(
                        widget.call.video
                            ? Icons.videocam_rounded
                            : Icons.call_rounded,
                        'Accept',
                        AppColors.online,
                        _accept,
                        wiggle: true,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _button(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap, {
    bool wiggle = false,
  }) {
    return Column(
      children: [
        Pressable(
          onTap: onTap,
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (context, child) => Transform.rotate(
              angle: wiggle
                  ? .18 *
                        sin(_pulse.value * 2 * pi * 3) *
                        (_pulse.value < .35 ? 1 : 0)
                  : 0,
              child: child,
            ),
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: .5),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 34),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: tx(14, weight: FontWeight.w600, color: Colors.white),
        ),
      ],
    );
  }
}
