package com.challengea.api.game;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.Map;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "match_moves")
public class MatchMove {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "match_id", nullable = false)
  private long matchId;

  @Column(name = "player_id", nullable = false)
  private long playerId;

  @JdbcTypeCode(SqlTypes.JSON)
  @Column(nullable = false)
  private Map<String, Object> move;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  protected MatchMove() {}

  public MatchMove(long matchId, long playerId, Map<String, Object> move) {
    this.matchId = matchId;
    this.playerId = playerId;
    this.move = move;
  }
}
