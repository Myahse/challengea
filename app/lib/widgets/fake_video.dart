import 'dart:math';

import 'package:flutter/material.dart';

import '../feed.dart';
import '../theme.dart';

/// Placeholder for a video or photo: a slowly moving gradient with the
/// author's initial. The real app plays the uploaded file here
/// (video_player / cached images) once the backend stores media.
class FakeVideo extends StatelessWidget {
  const FakeVideo({super.key, required this.post, required this.t});
  final Post post;

  /// Animation time in [0, 1).
  final double t;

  @override
  Widget build(BuildContext context) {
    final c = post.colors;
    final a = 2 * pi * t;
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(sin(a) * .6, -1),
              end: Alignment(-sin(a) * .6, 1),
              colors: c,
            ),
          ),
        ),
        // Two soft blobs drifting around, so it feels like motion.
        for (var i = 0; i < 2; i++)
          Align(
            alignment: Alignment(
              sin(a + i * 2.4) * .7,
              cos(a * .8 + i * 1.7) * .6,
            ),
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: .22),
                    Colors.white.withValues(alpha: 0),
                  ],
                ),
              ),
            ),
          ),
        Center(
          child: Text(
            post.author.person.initials,
            style: tx(
              220,
              weight: FontWeight.w800,
              color: Colors.white.withValues(alpha: .14),
            ),
          ),
        ),
      ],
    );
  }
}

/// Small rounded thumbnail used in profile grids.
class PostThumb extends StatelessWidget {
  const PostThumb({super.key, required this.post});
  final Post post;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: post.colors,
              ),
            ),
          ),
          Center(
            child: Text(
              post.author.person.initials,
              style: tx(
                40,
                weight: FontWeight.w800,
                color: Colors.white.withValues(alpha: .25),
              ),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 6,
            child: Row(
              children: [
                Icon(
                  post.kind == PostKind.video
                      ? Icons.play_arrow_rounded
                      : (post.kind == PostKind.story
                            ? Icons.auto_awesome
                            : Icons.favorite_rounded),
                  color: Colors.white,
                  size: 16,
                ),
                const SizedBox(width: 2),
                Text(
                  compact(post.likes),
                  style: tx(11, weight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          if (post.live)
            Positioned(
              right: 6,
              top: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5484D),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'LIVE',
                  style: tx(9, weight: FontWeight.w800, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
