package com.challengea.api.social;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

/** One person's story; its slides are {@link StoryItem}s. */
@Entity
@Table(name = "stories")
public class Story {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "user_id", nullable = false)
  private long userId;

  @Column(name = "last_item_at", nullable = false)
  private OffsetDateTime lastItemAt = OffsetDateTime.now();

  protected Story() {}

  public Story(long userId) {
    this.userId = userId;
  }

  public void touch() {
    lastItemAt = OffsetDateTime.now();
  }

  public Long getId() { return id; }
  public long getUserId() { return userId; }
}
