package com.challengea.api.chat;

import jakarta.persistence.*;

@Entity
@Table(name = "conversation_members")
public class ConversationMember {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "conversation_id", nullable = false)
  private long conversationId;

  @Column(name = "user_id", nullable = false)
  private long userId;

  @Column(nullable = false)
  private String role = "member";

  @Column(name = "last_read_message_id")
  private Long lastReadMessageId;

  protected ConversationMember() {}

  public ConversationMember(long conversationId, long userId, String role) {
    this.conversationId = conversationId;
    this.userId = userId;
    this.role = role;
  }

  public long getConversationId() { return conversationId; }
  public long getUserId() { return userId; }
  public String getRole() { return role; }
  public void setRole(String role) { this.role = role; }
  public Long getLastReadMessageId() { return lastReadMessageId; }
  public void setLastReadMessageId(Long id) { this.lastReadMessageId = id; }
}
