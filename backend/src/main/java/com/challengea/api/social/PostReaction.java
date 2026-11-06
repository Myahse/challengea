package com.challengea.api.social;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "post_reactions")
public class PostReaction {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "post_id", nullable = false)
  private long postId;

  @Column(name = "user_id", nullable = false)
  private long userId;

  @Column(nullable = false)
  private String type;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  protected PostReaction() {}

  public PostReaction(long postId, long userId, String type) {
    this.postId = postId;
    this.userId = userId;
    this.type = type;
  }

  public void setType(String type) {
    this.type = type;
  }

  public long getPostId() { return postId; }
  public String getType() { return type; }
}
