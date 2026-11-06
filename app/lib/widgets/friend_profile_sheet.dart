import 'package:flutter/material.dart';

import '../chat_store.dart';
import '../theme.dart';
import 'avatar.dart';
import 'city_map.dart';

/// Figma: profile card over the map (node 15:124, "Celine May").
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .15), blurRadius: 24),
        ],
      ),
      child: ListView(
        controller: scroll,
        padding: EdgeInsets.fromLTRB(
          22,
          10,
          22,
          30 + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.bubble,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),
          // Avatar with the dark red ring from Figma.
          Center(
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(
                  colors: [
                    Color(0xFF9E1C1C),
                    Color(0xFF3B0B0B),
                    Color(0xFF9E1C1C),
                  ],
                ),
              ),
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.bubble,
                ),
                child: GestureDetector(
                  onTap: onOpenProfile,
                  child: PersonAvatar(p, diameter: 96),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: spot.online ? AppColors.online : AppColors.muted,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                spot.online ? 'Online' : 'Seen ${spot.updated}',
                style: tx(12, weight: FontWeight.w600),
              ),
            ],
          ),
          GestureDetector(
            onTap: onOpenProfile,
            child: Text(
              p.name,
              textAlign: TextAlign.center,
              style: tx(40, weight: FontWeight.w800).copyWith(height: 1.05),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(spot.place, style: tx(14, weight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          if (spot.common > 0)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14.0 * mutuals.length + 8,
                  height: 20,
                  child: Stack(
                    children: [
                      for (var i = 0; i < mutuals.length; i++)
                        Positioned(
                          left: i * 14.0,
                          child: PersonAvatar(
                            mutuals[i].person,
                            diameter: 20,
                            border: 1.5,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${spot.common} friends in common',
                  style: tx(12, color: AppColors.muted),
                ),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Call',
                onPressed: onCall,
                icon: const Icon(Icons.call_outlined, size: 32),
              ),
              const SizedBox(width: 48),
              IconButton(
                tooltip: 'Message',
                onPressed: onMessage,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 32),
              ),
            ],
          ),
          const Divider(height: 28, indent: 10, endIndent: 10),
          // Status card ("I am on my way" in Figma).
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE6E6E6)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      colors: [p.color.withValues(alpha: .5), p.color],
                    ),
                  ),
                  child: const Icon(
                    Icons.music_note_rounded,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(spot.status, style: tx(17, weight: FontWeight.w600)),
                      Text(
                        'Updated ${spot.updated}',
                        style: tx(12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Mini map with the address.
          ClipRRect(
            borderRadius: BorderRadius.circular(26),
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
                  Center(child: PersonAvatar(p, diameter: 34, border: 2.5)),
                  Positioned(
                    left: 36,
                    right: 36,
                    bottom: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${spot.place} · ${distanceKm.toStringAsFixed(1)} km away',
                        textAlign: TextAlign.center,
                        style: tx(13, weight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _square(Icons.sports_esports_rounded, 'Challenge', onChallenge),
              const SizedBox(width: 70),
              _square(Icons.directions_rounded, 'Route', onRoute),
            ],
          ),
        ],
      ),
    );
  }

  Widget _square(IconData icon, String label, VoidCallback onTap) {
    return Column(
      children: [
        Material(
          color: AppColors.bubble,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onTap,
            child: SizedBox(width: 50, height: 50, child: Icon(icon)),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: tx(12, weight: FontWeight.w500)),
      ],
    );
  }
}
