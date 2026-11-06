package com.challengea.api.social;

import com.challengea.api.user.UserDto;
import java.time.OffsetDateTime;
import java.util.List;

public final class SocialDtos {
  private SocialDtos() {}

  public record StoryItemDto(long id, String body, String mediaUrl, String background, OffsetDateTime createdAt,
      OffsetDateTime expiresAt, boolean seen) {
    static StoryItemDto of(StoryItem i, boolean seen) {
      return new StoryItemDto(i.getId(), i.getBody(), i.getMediaUrl(), i.getBackground(), i.getCreatedAt(),
          i.getExpiresAt(), seen);
    }
  }

  public record StoryDto(UserDto user, List<StoryItemDto> items) {}

  /** myReaction is null if I didn't react. */
  public record PostDto(long id, UserDto author, String body, String mediaUrl, String background, long reactions,
      String myReaction, long commentCount, OffsetDateTime createdAt) {}

  public record CommentDto(long id, long postId, Long parentId, UserDto author, String body, OffsetDateTime createdAt) {}

  /** Live event: someone reacted. type is null if the reaction was removed. */
  public record ReactionEvent(long postId, long userId, String type, long reactions) {}

  public record CommentEvent(CommentDto comment, long commentCount) {}

  public record StoryEvent(long userId) {}
}
