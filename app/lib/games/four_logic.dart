import 'dart:math';

/// Four in a row on a 7 x 6 board. 0 = empty, 1 = me, 2 = friend.
class FourBoard {
  FourBoard() : cells = List.generate(rows, (_) => List.filled(cols, 0));

  static const cols = 7, rows = 6;
  final List<List<int>> cells; // cells[row][col], row 0 = top

  bool canPlay(int col) => cells[0][col] == 0;
  bool get full => List.generate(cols, (c) => c).every((c) => !canPlay(c));

  /// Drops a disc; returns the row it lands on, or null if the column is full.
  int? drop(int col, int player) {
    for (var r = rows - 1; r >= 0; r--) {
      if (cells[r][col] == 0) {
        cells[r][col] = player;
        return r;
      }
    }
    return null;
  }

  void undo(int col) {
    for (var r = 0; r < rows; r++) {
      if (cells[r][col] != 0) {
        cells[r][col] = 0;
        return;
      }
    }
  }

  /// The 4 winning cells for [player], or null.
  List<(int, int)>? winLine(int player) {
    const dirs = [(0, 1), (1, 0), (1, 1), (1, -1)];
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        for (final (dr, dc) in dirs) {
          final line = [for (var k = 0; k < 4; k++) (r + dr * k, c + dc * k)];
          if (line.every(
            (p) =>
                p.$1 >= 0 &&
                p.$1 < rows &&
                p.$2 >= 0 &&
                p.$2 < cols &&
                cells[p.$1][p.$2] == player,
          )) {
            return line;
          }
        }
      }
    }
    return null;
  }

  /// Friend's move: win if possible, else block, else avoid giving a win,
  /// preferring the centre. Not perfect on purpose, so you can win.
  int pickMove(Random rnd) {
    final options = [
      for (var c = 0; c < cols; c++)
        if (canPlay(c)) c,
    ];
    for (final player in [2, 1]) {
      for (final c in options) {
        drop(c, player);
        final wins = winLine(player) != null;
        undo(c);
        if (wins) return c;
      }
    }
    final safe = options.where((c) {
      drop(c, 2);
      final givesWin = options.any((o) {
        if (!canPlay(o)) return false;
        drop(o, 1);
        final w = winLine(1) != null;
        undo(o);
        return w;
      });
      undo(c);
      return !givesWin;
    }).toList();
    final pool = safe.isEmpty ? options : safe;
    pool.sort((a, b) => (a - 3).abs().compareTo((b - 3).abs()));
    // Mostly central, sometimes random.
    return rnd.nextInt(4) == 0 ? pool[rnd.nextInt(pool.length)] : pool.first;
  }
}
