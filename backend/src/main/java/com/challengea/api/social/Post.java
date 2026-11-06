package com.challengea.api.social;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "posts")
public class Post {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "author_id", nullable = false)
  private long authorId;

  private String body;

  @Column(name = "media_url")
  private String mediaUrl;

  private String background;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  protected Post() {}

  public Post(long authorId, String body, String mediaUrl, String background) {
    this.authorId = authorId;
    this.body = body;
    this.mediaUrl = mediaUrl;
    this.background = background;
  }

  public Long getId() { return id; }
  public long getAuthorId() { return authorId; }
  public String getBody() { return body; }
  public String getMediaUrl() { return mediaUrl; }
  public String getBackground() { return background; }
  public OffsetDateTime getCreatedAt() { return createdAt; }
}
