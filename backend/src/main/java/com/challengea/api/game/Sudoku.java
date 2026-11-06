package com.challengea.api.game;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashSet;
import java.util.List;
import java.util.Random;

/** Generates a valid Sudoku and the puzzle shown to both players (0 = cell to fill). */
public final class Sudoku {
  public static final int BLANKS = 42;

  public record Puzzle(int[] solution, int[] givens) {}

  private Sudoku() {}

  public static Puzzle generate(long seed) {
    var rnd = new Random(seed);
    var digits = new ArrayList<Integer>();
    for (var i = 1; i <= 9; i++) digits.add(i);
    Collections.shuffle(digits, rnd);
    var rows = order(rnd);
    var cols = order(rnd);
    var solution = new int[81];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        // Shuffling digits, rows inside bands, bands, columns inside stacks and
        // stacks keeps a valid grid valid.
        var rr = rows.get(r);
        var cc = cols.get(c);
        solution[r * 9 + c] = digits.get((rr * 3 + rr / 3 + cc) % 9);
      }
    }
    var givens = solution.clone();
    var cells = new ArrayList<Integer>();
    for (var i = 0; i < 81; i++) cells.add(i);
    Collections.shuffle(cells, rnd);
    for (var i = 0; i < BLANKS; i++) givens[cells.get(i)] = 0;
    return new Puzzle(solution, givens);
  }

  private static List<Integer> order(Random rnd) {
    var bands = new ArrayList<>(List.of(0, 1, 2));
    Collections.shuffle(bands, rnd);
    var out = new ArrayList<Integer>();
    for (var b : bands) {
      var inside = new ArrayList<>(List.of(0, 1, 2));
      Collections.shuffle(inside, rnd);
      for (var i : inside) out.add(b * 3 + i);
    }
    return out;
  }

  public static boolean isValid(int[] g) {
    for (var i = 0; i < 9; i++) {
      var row = new HashSet<Integer>();
      var col = new HashSet<Integer>();
      var box = new HashSet<Integer>();
      for (var j = 0; j < 9; j++) {
        row.add(g[i * 9 + j]);
        col.add(g[j * 9 + i]);
        box.add(g[(i / 3 * 3 + j / 3) * 9 + i % 3 * 3 + j % 3]);
      }
      if (row.size() != 9 || col.size() != 9 || box.size() != 9 || row.contains(0)) return false;
    }
    return true;
  }
}
