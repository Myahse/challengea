package com.challengea.api.social;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "post_comments")
public class PostComment {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "post_id", nullable = false)
  private long postId;

  @Column(name = "author_id", nullable = false)
  private long authorId;

  @Column(name = "parent_id")
  private Long parentId;

  @Column(nullable = false)
  private String body;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  protected PostComment() {}

  public PostComment(long postId, long authorId, Long parentId, String body) {
    this.postId = postId;
    this.authorId = authorId;
    this.parentId = parentId;
    this.body = body;
  }

  public Long getId() { return id; }
  public long getPostId() { return postId; }
  public long getAuthorId() { return authorId; }
  public Long getParentId() { return parentId; }
  public String getBody() { return body; }
  public OffsetDateTime getCreatedAt() { return createdAt; }
}
