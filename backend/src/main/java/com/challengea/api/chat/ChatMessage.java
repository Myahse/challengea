package com.challengea.api.chat;

import jakarta.persistence.*;
import java.time.OffsetDateTime;
import java.util.Map;
import org.hibernate.annotations.JdbcTypeCode;
import org.hibernate.type.SqlTypes;

@Entity
@Table(name = "messages")
public class ChatMessage {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "conversation_id", nullable = false)
  private long conversationId;

  @Column(name = "sender_id")
  private Long senderId; // null for system messages

  @Column(nullable = false)
  private String type;

  private String body;

  @Column(name = "media_url")
  private String mediaUrl;

  /** Stored in an Oracle 23ai JSON column. */
  @JdbcTypeCode(SqlTypes.JSON)
  private Map<String, Object> metadata;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  protected ChatMessage() {}

  public ChatMessage(long conversationId, Long senderId, String type, String body, String mediaUrl,
      Map<String, Object> metadata) {
    this.conversationId = conversationId;
    this.senderId = senderId;
    this.type = type;
    this.body = body;
    this.mediaUrl = mediaUrl;
    this.metadata = metadata;
  }

  public Long getId() { return id; }
  public long getConversationId() { return conversationId; }
  public Long getSenderId() { return senderId; }
  public String getType() { return type; }
  public String getBody() { return body; }
  public String getMediaUrl() { return mediaUrl; }
  public Map<String, Object> getMetadata() { return metadata; }
  public OffsetDateTime getCreatedAt() { return createdAt; }
}
