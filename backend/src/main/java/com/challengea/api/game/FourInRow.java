package com.challengea.api.game;

import java.util.ArrayList;
import java.util.List;

/** Four in a row on a 7 x 6 board. 0 = empty, 1 = challenger, 2 = opponent. Row 0 is the top. */
public final class FourInRow {
  public static final int COLS = 7, ROWS = 6;

  private FourInRow() {}

  public static int[][] empty() {
    return new int[ROWS][COLS];
  }

  /** Drops a disc and returns its row, or -1 if the column is full or invalid. */
  public static int drop(int[][] cells, int col, int player) {
    if (col < 0 || col >= COLS) return -1;
    for (var r = ROWS - 1; r >= 0; r--) {
      if (cells[r][col] == 0) {
        cells[r][col] = player;
        return r;
      }
    }
    return -1;
  }

  public static boolean full(int[][] cells) {
    for (var c = 0; c < COLS; c++) if (cells[0][c] == 0) return false;
    return true;
  }

  /** The 4 winning cells [row, col] for [player], or null. */
  public static List<int[]> winLine(int[][] cells, int player) {
    int[][] dirs = {{0, 1}, {1, 0}, {1, 1}, {1, -1}};
    for (var r = 0; r < ROWS; r++) {
      for (var c = 0; c < COLS; c++) {
        for (var d : dirs) {
          var line = new ArrayList<int[]>();
          for (var k = 0; k < 4; k++) {
            int rr = r + d[0] * k, cc = c + d[1] * k;
            if (rr < 0 || rr >= ROWS || cc < 0 || cc >= COLS || cells[rr][cc] != player) break;
            line.add(new int[] {rr, cc});
          }
          if (line.size() == 4) return line;
        }
      }
    }
    return null;
  }
}
