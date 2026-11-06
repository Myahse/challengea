package com.challengea.api.game;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;

class GameRulesTest {
  @Test
  void sudokuGridsAreValidAndHave42CellsToFill() {
    for (long seed = 0; seed < 200; seed++) {
      var p = Sudoku.generate(seed);
      assertThat(Sudoku.isValid(p.solution())).isTrue();
      var blanks = 0;
      for (var i = 0; i < 81; i++) {
        if (p.givens()[i] == 0) blanks++;
        else assertThat(p.givens()[i]).isEqualTo(p.solution()[i]);
      }
      assertThat(blanks).isEqualTo(Sudoku.BLANKS);
    }
  }

  @Test
  void fourInARowFindsLinesInEveryDirection() {
    var cells = FourInRow.empty();
    for (var c = 0; c < 4; c++) FourInRow.drop(cells, c, 1);
    assertThat(FourInRow.winLine(cells, 1)).hasSize(4);
    assertThat(FourInRow.winLine(cells, 2)).isNull();

    var diagonal = FourInRow.empty();
    // Builds a rising diagonal for player 2 on columns 0..3.
    for (var c = 0; c < 4; c++) {
      for (var k = 0; k < c; k++) FourInRow.drop(diagonal, c, 1);
      FourInRow.drop(diagonal, c, 2);
    }
    assertThat(FourInRow.winLine(diagonal, 2)).hasSize(4);
  }

  @Test
  void fullColumnsRejectMoves() {
    var cells = FourInRow.empty();
    for (var i = 0; i < FourInRow.ROWS; i++) assertThat(FourInRow.drop(cells, 0, 1 + i % 2)).isGreaterThanOrEqualTo(0);
    assertThat(FourInRow.drop(cells, 0, 1)).isEqualTo(-1);
    assertThat(FourInRow.drop(cells, 9, 1)).isEqualTo(-1);
  }
}
