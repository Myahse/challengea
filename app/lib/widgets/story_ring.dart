import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import 'avatar.dart';

/// Avatar inside a story ring: gradient = new story, grey = seen.
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
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: hasStory && !seen
            ? const SweepGradient(colors: AppColors.storyGradient)
            : null,
        color: hasStory && seen ? const Color(0xFFD6D6D6) : null,
      ),
      child: Container(
        padding: const EdgeInsets.all(2.5),
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
        ),
        child: PersonAvatar(person, diameter: size - 10),
      ),
    );
  }
}
