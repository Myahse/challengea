package com.challengea.api.call;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "calls")
public class Call {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "conversation_id", nullable = false)
  private long conversationId;

  @Column(name = "started_by", nullable = false)
  private long startedBy;

  private boolean video;

  @Column(nullable = false)
  private String status = "ringing";

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  @Column(name = "answered_at")
  private OffsetDateTime answeredAt;

  @Column(name = "ended_at")
  private OffsetDateTime endedAt;

  protected Call() {}

  public Call(long conversationId, long startedBy, boolean video) {
    this.conversationId = conversationId;
    this.startedBy = startedBy;
    this.video = video;
  }

  public Long getId() { return id; }
  public long getConversationId() { return conversationId; }
  public long getStartedBy() { return startedBy; }
  public boolean isVideo() { return video; }
  public String getStatus() { return status; }
  public OffsetDateTime getAnsweredAt() { return answeredAt; }
  public OffsetDateTime getEndedAt() { return endedAt; }
  public String room() { return "call-" + id; }
  public boolean isOver() { return status.equals("ended") || status.equals("missed"); }

  public void answer() {
    if (status.equals("ringing")) {
      status = "active";
      answeredAt = OffsetDateTime.now();
    }
  }

  public void end() {
    status = answeredAt == null ? "missed" : "ended";
    endedAt = OffsetDateTime.now();
  }
}
