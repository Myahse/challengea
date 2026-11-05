import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../models.dart';
import '../theme.dart';
import 'avatar.dart';

/// A friend on the map (rounded square photo + name), used by both maps.
class FriendPin extends StatelessWidget {
  const FriendPin({
    super.key,
    required this.spot,
    required this.selected,
    required this.onTap,
  });
  final FriendSpot spot;
  final bool selected;
  final VoidCallback onTap;

  static const size = 62.0;

  @override
  Widget build(BuildContext context) {
    final p = spot.person;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedScale(
        scale: selected ? 1.2 : 1,
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.bottomCenter,
        child: Opacity(
          opacity: spot.online ? 1 : .55,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: selected
                      ? Border.all(color: AppColors.ink, width: 2)
                      : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .18),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(p.color, Colors.white, .45)!,
                          p.color,
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      p.initials,
                      style: tx(
                        26,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  spot.online
                      ? p.firstName
                      : '${p.firstName} · ${spot.updated}',
                  style: tx(11, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Me on the map: avatar with a pulsing halo, or a ghost in Ghost mode.
class MeMarker extends StatefulWidget {
  const MeMarker({super.key, required this.me, required this.ghost});
  final Person me;
  final bool ghost;

  @override
  State<MeMarker> createState() => _MeMarkerState();
}

class _MeMarkerState extends State<MeMarker>
    with SingleTickerProviderStateMixin {
  late final _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _pulse,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            if (!widget.ghost)
              Container(
                width: 50 + 40 * _pulse.value,
                height: 50 + 40 * _pulse.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(
                    0xFF3B82F6,
                  ).withValues(alpha: .35 * (1 - _pulse.value)),
                ),
              ),
            widget.ghost
                ? Container(
                    width: 50,
                    height: 50,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: const Icon(
                      Icons.visibility_off_rounded,
                      color: AppColors.muted,
                    ),
                  )
                : PersonAvatar(widget.me, diameter: 50, border: 3),
          ],
        ),
      ),
    );
  }
}
