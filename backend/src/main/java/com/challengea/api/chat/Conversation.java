package com.challengea.api.chat;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "conversations")
public class Conversation {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false)
  private String type; // direct | group

  private String title;

  @Column(name = "created_by")
  private Long createdBy;

  @Column(name = "created_at", insertable = false, updatable = false)
  private OffsetDateTime createdAt;

  protected Conversation() {}

  public Conversation(String type, String title, long createdBy) {
    this.type = type;
    this.title = title;
    this.createdBy = createdBy;
  }

  public Long getId() { return id; }
  public String getType() { return type; }
  public boolean isGroup() { return "group".equals(type); }
  public String getTitle() { return title; }
  public void setTitle(String title) { this.title = title; }
}
