package com.challengea.api.social;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "post_reports")
public class PostReport {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "post_id", nullable = false)
  private long postId;

  @Column(name = "user_id", nullable = false)
  private long userId;

  @Column(nullable = false)
  private String reason;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  protected PostReport() {}

  public PostReport(long postId, long userId, String reason) {
    this.postId = postId;
    this.userId = userId;
    this.reason = reason;
  }
}
