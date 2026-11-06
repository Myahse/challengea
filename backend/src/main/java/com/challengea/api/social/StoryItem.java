package com.challengea.api.social;

import jakarta.persistence.*;
import java.time.Duration;
import java.time.OffsetDateTime;

@Entity
@Table(name = "story_items")
public class StoryItem {
  public static final Duration LIFETIME = Duration.ofHours(24);

  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "story_id", nullable = false)
  private long storyId;

  private String body;

  @Column(name = "media_url")
  private String mediaUrl;

  private String background;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  @Column(name = "expires_at", nullable = false)
  private OffsetDateTime expiresAt = createdAt.plus(LIFETIME);

  protected StoryItem() {}

  public StoryItem(long storyId, String body, String mediaUrl, String background) {
    this.storyId = storyId;
    this.body = body;
    this.mediaUrl = mediaUrl;
    this.background = background;
  }

  public Long getId() { return id; }
  public long getStoryId() { return storyId; }
  public String getBody() { return body; }
  public String getMediaUrl() { return mediaUrl; }
  public String getBackground() { return background; }
  public OffsetDateTime getCreatedAt() { return createdAt; }
  public OffsetDateTime getExpiresAt() { return expiresAt; }
}
