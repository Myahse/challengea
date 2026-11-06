package com.challengea.api.social;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

/** Someone chose not to see this post. */
@Entity
@Table(name = "post_hides")
public class PostHide {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "post_id", nullable = false)
  private long postId;

  @Column(name = "user_id", nullable = false)
  private long userId;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  protected PostHide() {}

  public PostHide(long postId, long userId) {
    this.postId = postId;
    this.userId = userId;
  }
}
