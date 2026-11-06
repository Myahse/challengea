import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'mock/people.dart';
import 'models.dart';

/// One slide of a story: a photo, or a coloured card with text / emoji.
class StoryItem {
  StoryItem({
    this.colors = const [Color(0xFF3D7BFF), Color(0xFF8B6CF6)],
    this.text,
    this.emoji,
    this.photo,
    DateTime? time,
  }) : time = time ?? DateTime.now();
  final List<Color> colors;
  final String? text;
  final String? emoji;
  final Uint8List? photo;
  final DateTime time;

  String get ago {
    final d = DateTime.now().difference(time);
    if (d.inMinutes < 1) return 'now';
    if (d.inHours < 1) return '${d.inMinutes}m';
    return '${d.inHours}h';
  }
}

/// Everything one person posted in the last 24 h.
class Story {
  Story(this.person, this.items);
  final Person person;
  final List<StoryItem> items;
  bool seen = false;
}

/// Demo stories for the Marcory cast (24 h, like Snapchat / WhatsApp status).
List<Story> mockStories() {
  final now = DateTime.now();
  DateTime ago(int minutes) => now.subtract(Duration(minutes: minutes));
  return [
    Story(MockPeople.melanie, [
      StoryItem(
        colors: const [Color(0xFFFFD6A5), Color(0xFFE76F51)],
        emoji: '🛍️',
        text: 'Grand Marché de Marcory with the girls',
        time: ago(42),
      ),
      StoryItem(
        colors: const [Color(0xFFFFC8DD), Color(0xFFB5179E)],
        emoji: '💅',
        text: 'New nails, who dis',
        time: ago(30),
      ),
    ]),
    Story(MockPeople.brendon, [
      StoryItem(
        colors: const [Color(0xFFA0C4FF), Color(0xFF5E60CE)],
        emoji: '🎮',
        text: 'Rumble dash rematch tonight. @marc you ready?',
        time: ago(95),
      ),
    ]),
    Story(MockPeople.marc, [
      StoryItem(
        colors: const [Color(0xFFB5E48C), Color(0xFF1A759F)],
        emoji: '🧩',
        text: 'Sudoku in 3:12. Beat that 😤',
        time: ago(12),
      ),
      StoryItem(
        colors: const [Color(0xFF2B2D42), Color(0xFF8D99AE)],
        emoji: '🌙',
        text: 'Lagune Ébrié tonight',
        time: ago(5),
      ),
    ]),
    Story(MockPeople.awa, [
      StoryItem(
        colors: const [Color(0xFFADE8F4), Color(0xFF0077B6)],
        emoji: '☕',
        text: 'Coffee break in Zone 4',
        time: ago(200),
      ),
    ]),
    Story(MockPeople.celine, [
      StoryItem(
        colors: const [Color(0xFFD8E2DC), Color(0xFF52796F)],
        emoji: '⚽',
        text: 'On my way to the match',
        time: ago(18),
      ),
    ]),
    Story(MockPeople.maurice, [
      StoryItem(
        colors: const [Color(0xFFFFE5B4), Color(0xFFD4A373)],
        emoji: '🍖',
        text: 'Garba time',
        time: ago(320),
      ),
    ]),
  ];
}
