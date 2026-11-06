package com.challengea.api.chat;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.math.RoundingMode;

@Entity
@Table(name = "bubble_positions")
public class BubblePosition {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "user_id", nullable = false)
  private long userId;

  @Column(name = "conversation_id", nullable = false)
  private long conversationId;

  private BigDecimal x;
  private BigDecimal y;

  protected BubblePosition() {}

  public BubblePosition(long userId, long conversationId) {
    this.userId = userId;
    this.conversationId = conversationId;
  }

  public long getConversationId() { return conversationId; }
  public double getX() { return x.doubleValue(); }
  public double getY() { return y.doubleValue(); }
  public void moveTo(double x, double y) {
    this.x = BigDecimal.valueOf(x).setScale(5, RoundingMode.HALF_UP);
    this.y = BigDecimal.valueOf(y).setScale(5, RoundingMode.HALF_UP);
  }
}
