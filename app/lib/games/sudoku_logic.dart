import 'dart:math';

/// A Sudoku puzzle: [solution] is a full valid grid, [givens] has 0 for the
/// cells to fill. Both players of a duel use the same [seed].
class SudokuPuzzle {
  SudokuPuzzle._(this.solution, this.givens);

  factory SudokuPuzzle.generate({int seed = 1, int blanks = 42}) {
    final rnd = Random(seed);
    // Start from a known valid pattern, then shuffle what keeps it valid.
    int base(int r, int c) => (r * 3 + r ~/ 3 + c) % 9;
    final digits = [for (var i = 1; i <= 9; i++) i]..shuffle(rnd);
    List<int> order() {
      final bands = [0, 1, 2]..shuffle(rnd);
      return [
        for (final b in bands)
          ...([0, 1, 2]..shuffle(rnd)).map((i) => b * 3 + i),
      ];
    }

    final rows = order(), cols = order();
    final solution = [
      for (var r = 0; r < 9; r++)
        [for (var c = 0; c < 9; c++) digits[base(rows[r], cols[c])]],
    ];
    final givens = [
      for (final row in solution) [...row],
    ];
    final cells = [for (var i = 0; i < 81; i++) i]..shuffle(rnd);
    for (final i in cells.take(blanks)) {
      givens[i ~/ 9][i % 9] = 0;
    }
    return SudokuPuzzle._(solution, givens);
  }

  final List<List<int>> solution;
  final List<List<int>> givens;

  int get blanks => givens.expand((r) => r).where((v) => v == 0).length;

  /// True when every row, column and 3x3 box holds 1..9 once.
  static bool isValidSolution(List<List<int>> g) {
    bool ok(Iterable<int> xs) =>
        xs.toSet().length == 9 && xs.every((v) => v >= 1 && v <= 9);
    for (var i = 0; i < 9; i++) {
      if (!ok(g[i])) return false;
      if (!ok([for (var r = 0; r < 9; r++) g[r][i]])) return false;
      final br = i ~/ 3 * 3, bc = i % 3 * 3;
      if (!ok([
        for (var r = 0; r < 3; r++)
          for (var c = 0; c < 3; c++) g[br + r][bc + c],
      ])) {
        return false;
      }
    }
    return true;
  }
}
