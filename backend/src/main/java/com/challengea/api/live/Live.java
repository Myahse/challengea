package com.challengea.api.live;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

/** A live broadcast. */
@Entity
@Table(name = "lives")
public class Live {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "host_id", nullable = false)
  private long hostId;

  private String title;

  @Column(name = "started_at", nullable = false)
  private OffsetDateTime startedAt = OffsetDateTime.now();

  @Column(name = "ended_at")
  private OffsetDateTime endedAt;

  protected Live() {}

  public Live(long hostId, String title) {
    this.hostId = hostId;
    this.title = title;
  }

  public void end() {
    endedAt = OffsetDateTime.now();
  }

  public boolean isOver() {
    return endedAt != null;
  }

  public String room() {
    return "live-" + id;
  }

  public Long getId() { return id; }
  public long getHostId() { return hostId; }
  public String getTitle() { return title; }
  public OffsetDateTime getStartedAt() { return startedAt; }
}
