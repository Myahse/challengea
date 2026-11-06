import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'avatar.dart';
import 'glass.dart';

/// A friend's bubble: a thin blue ring and a slow drift mean a new story.
/// Once seen, the bubble rests and the ring goes.
class StoryRing extends StatelessWidget {
  const StoryRing({
    super.key,
    required this.person,
    this.seen = false,
    this.size = 64,
    this.hasStory = true,
  });
  final Person person;
  final bool seen;
  final bool hasStory;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fresh = hasStory && !seen;
    final bubble = Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(3.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: fresh ? Border.all(color: AppColors.accent, width: 2) : null,
      ),
      child: PersonAvatar(person, diameter: size - 11),
    );
    return fresh
        ? Floaty(
            distance: 3,
            phase: person.id.hashCode % 100 / 100,
            child: bubble,
          )
        : bubble;
  }
}
