import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../theme.dart';
import 'avatar.dart';
import 'city_map.dart';
import 'glass.dart';
import 'motion.dart';

/// A friend's card over the map.
class FriendProfileSheet extends StatelessWidget {
  const FriendProfileSheet({
    super.key,
    required this.spot,
    required this.distanceKm,
    required this.mutuals,
    required this.scroll,
    required this.onMessage,
    required this.onCall,
    required this.onChallenge,
    required this.onRoute,
    this.miniMap,
    this.onOpenProfile,
  });

  final FriendSpot spot;
  final double distanceKm;
  final List<FriendSpot> mutuals;
  final ScrollController scroll;
  final VoidCallback onMessage;
  final VoidCallback onCall;
  final VoidCallback onChallenge;
  final VoidCallback onRoute;

  /// Map shown in the address card; defaults to the drawn map.
  final Widget? miniMap;

  /// Opens the full profile (tap on the photo or the name).
  final VoidCallback? onOpenProfile;

  @override
  Widget build(BuildContext context) {
    final p = spot.person;
    return Glass(
      radius: 30,
      shadow: true,
      tint: AppColors.card.withValues(alpha: .86),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          20,
          10,
          20,
          30 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.line,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Pressable(
                onTap: onOpenProfile,
                child: PersonAvatar(p, diameter: 68),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: GestureDetector(
                  onTap: onOpenProfile,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tx(30, weight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: spot.online
                                  ? AppColors.online
                                  : AppColors.muted,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${spot.online ? 'Online' : 'Seen ${spot.updated}'} · ${spot.place}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tx(15, color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _button('Message', onMessage)),
              const SizedBox(width: 8),
              Expanded(child: _button('Call', onCall)),
              const SizedBox(width: 8),
              Expanded(child: _button('Challenge', onChallenge, primary: true)),
            ],
          ),
          const SizedBox(height: 10),
          if (spot.common > 0)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 14.0 * mutuals.length + 10,
                    height: 24,
                    child: Stack(
                      children: [
                        for (var i = 0; i < mutuals.length; i++)
                          Positioned(
                            left: i * 14.0,
                            child: PersonAvatar(
                              mutuals[i].person,
                              diameter: 24,
                              border: 1.5,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${spot.common} friends in common',
                    style: tx(15, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(spot.status, style: tx(20, weight: FontWeight.w600)),
                Text(
                  'Updated ${spot.updated}',
                  style: tx(14, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Mini map with the address.
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: SizedBox(
              height: 170,
              child: Stack(
                children: [
                  Positioned.fill(
                    child:
                        miniMap ??
                        CustomPaint(
                          painter: CityMapPainter(
                            focus: spot.position,
                            zoom: .75,
                          ),
                        ),
                  ),
                  Center(child: PersonAvatar(p, diameter: 40)),
                  Positioned(
                    left: 10,
                    right: 10,
                    bottom: 10,
                    child: Glass(
                      radius: 18,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 14, right: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${spot.place} · ${distanceKm.toStringAsFixed(1)} km',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: tx(15),
                              ),
                            ),
                            TextLink(label: 'Route', size: 15, onTap: onRoute),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _button(String label, VoidCallback onTap, {bool primary = false}) {
    return Pressable(
      onTap: onTap,
      child: Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? AppColors.accent : AppColors.bubble,
          borderRadius: BorderRadius.circular(23),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              label,
              style: tx(
                15,
                weight: FontWeight.w500,
                color: primary ? Colors.white : AppColors.ink,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
