import 'package:flutter/material.dart';

/// A game from the "Tales" row.
class GameInfo {
  const GameInfo(
    this.id,
    this.name,
    this.tagline,
    this.icon,
    this.colors, {
    this.playable = false,
  });
  final String id;
  final String name;
  final String tagline;
  final IconData icon;
  final List<Color> colors;
  final bool playable;
}

const sudokuDuel = GameInfo(
  'sudoku',
  'Sudoku',
  'Same grid, who finishes first?',
  Icons.grid_view_rounded,
  [Color(0xFF3FD0FF), Color(0xFFFF4FA3)],
  playable: true,
);

const fourInRow = GameInfo(
  'arcade',
  'Arcade',
  'Four in a row: line up 4 before your friend',
  Icons.sports_esports_rounded,
  [Color(0xFFFFE066), Color(0xFF2DBE60)],
  playable: true,
);

const rumbleDash = GameInfo(
  'rumble',
  'Rumble dash',
  'Tap race: first to the finish line',
  Icons.directions_run_rounded,
  [Color(0xFF3D7BFF), Color(0xFFFFB13D)],
  playable: true,
);

const purpleRaw = GameInfo(
  'purple',
  'Purple raw',
  'Reaction duel: tap when it turns purple',
  Icons.bolt_rounded,
  [Color(0xFFB45CFF), Color(0xFF7A2BC2)],
  playable: true,
);

const allGames = [sudokuDuel, fourInRow, rumbleDash, purpleRaw];

GameInfo gameById(String id) => allGames.firstWhere((g) => g.id == id);
