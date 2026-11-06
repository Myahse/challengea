package com.challengea.api.game;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.Map;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "matches")
public class Match {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "game_id", nullable = false)
  private String gameId;

  @Column(name = "challenger_id", nullable = false)
  private long challengerId;

  @Column(name = "opponent_id", nullable = false)
  private long opponentId;

  @Column(nullable = false)
  private String status = "invited";

  /** Game state in an Oracle 23ai JSON column (board, puzzle, progress...). */
  @JdbcTypeCode(SqlTypes.JSON)
  private Map<String, Object> state;

  @Column(name = "current_turn_id")
  private Long currentTurnId;

  @Column(name = "winner_id")
  private Long winnerId;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  @Column(name = "updated_at", nullable = false)
  private OffsetDateTime updatedAt = OffsetDateTime.now();

  protected Match() {}

  public Match(String gameId, long challengerId, long opponentId) {
    this.gameId = gameId;
    this.challengerId = challengerId;
    this.opponentId = opponentId;
  }

  public Long getId() { return id; }
  public String getGameId() { return gameId; }
  public long getChallengerId() { return challengerId; }
  public long getOpponentId() { return opponentId; }
  public String getStatus() { return status; }
  public Map<String, Object> getState() { return state; }
  public Long getCurrentTurnId() { return currentTurnId; }
  public Long getWinnerId() { return winnerId; }
  public OffsetDateTime getCreatedAt() { return createdAt; }

  public boolean involves(long userId) { return userId == challengerId || userId == opponentId; }
  public long other(long userId) { return userId == challengerId ? opponentId : challengerId; }

  public void start(Map<String, Object> state, Long firstTurn) {
    this.status = "active";
    this.state = state;
    this.currentTurnId = firstTurn;
    touch();
  }

  public void setState(Map<String, Object> state) {
    this.state = state;
    touch();
  }

  public void setCurrentTurnId(Long id) { this.currentTurnId = id; }

  public void finish(Long winnerId) {
    this.status = "finished";
    this.winnerId = winnerId;
    this.currentTurnId = null;
    touch();
  }

  public void close(String status) {
    this.status = status;
    touch();
  }

  private void touch() { this.updatedAt = OffsetDateTime.now(); }
}
