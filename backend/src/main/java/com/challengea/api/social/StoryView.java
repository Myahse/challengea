package com.challengea.api.social;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "story_views")
public class StoryView {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "item_id", nullable = false)
  private long itemId;

  @Column(name = "viewer_id", nullable = false)
  private long viewerId;

  @Column(name = "viewed_at", nullable = false)
  private OffsetDateTime viewedAt = OffsetDateTime.now();

  protected StoryView() {}

  public StoryView(long itemId, long viewerId) {
    this.itemId = itemId;
    this.viewerId = viewerId;
  }

  public long getItemId() { return itemId; }
}
