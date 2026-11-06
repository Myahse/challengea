package com.challengea.api.chat;

import com.challengea.api.user.UserDto;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

public final class ChatDtos {
  private ChatDtos() {}

  public record MessageDto(long id, long conversationId, Long senderId, String type, String body, String mediaUrl,
      Map<String, Object> metadata, OffsetDateTime createdAt) {
    static MessageDto of(ChatMessage m) {
      return new MessageDto(m.getId(), m.getConversationId(), m.getSenderId(), m.getType(), m.getBody(),
          m.getMediaUrl(), m.getMetadata(), m.getCreatedAt());
    }
  }

  /** One bubble on the chat home. */
  public record ConversationDto(long id, String type, String title, List<UserDto> members, MessageDto lastMessage,
      long unread, BubbleDto bubble) {}

  public record BubbleDto(long conversationId, double x, double y) {}
}
