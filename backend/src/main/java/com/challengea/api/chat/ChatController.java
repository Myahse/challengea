package com.challengea.api.chat;

import com.challengea.api.chat.ChatDtos.BubbleDto;
import com.challengea.api.chat.ChatDtos.ConversationDto;
import com.challengea.api.chat.ChatDtos.MessageDto;
import com.challengea.api.common.CurrentUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class ChatController {
  private final ChatService chat;

  public ChatController(ChatService chat) {
    this.chat = chat;
  }

  public record NewGroup(@NotEmpty List<Long> memberIds, @Size(max = 80) String title) {}

  public record Members(@NotEmpty List<Long> userIds) {}

  public record Rename(@Size(max = 80) String title) {}

  public record NewMessage(@NotNull String type, @Size(max = 4000) String body, @Size(max = 1000) String mediaUrl,
      Map<String, Object> metadata) {}

  public record Read(long messageId) {}

  public record Bubbles(@NotNull List<BubbleDto> items) {}

  /** All my bubbles: 1-to-1 chats and groups, with last message, unread count and position. */
  @GetMapping("/conversations")
  List<ConversationDto> list() {
    return chat.list(CurrentUser.id());
  }

  @GetMapping("/conversations/{id}")
  ConversationDto get(@PathVariable long id) {
    return chat.get(CurrentUser.id(), id);
  }

  @PostMapping("/conversations/direct/{userId}")
  ConversationDto direct(@PathVariable long userId) {
    return chat.direct(CurrentUser.id(), userId);
  }

  @PostMapping("/conversations/groups")
  @ResponseStatus(HttpStatus.CREATED)
  ConversationDto createGroup(@RequestBody @Valid NewGroup body) {
    return chat.createGroup(CurrentUser.id(), body.memberIds(), body.title());
  }

  @PostMapping("/conversations/{id}/members")
  ConversationDto addMembers(@PathVariable long id, @RequestBody @Valid Members body) {
    return chat.addMembers(CurrentUser.id(), id, body.userIds());
  }

  @DeleteMapping("/conversations/{id}/members/{userId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void removeMember(@PathVariable long id, @PathVariable long userId) {
    chat.removeMember(CurrentUser.id(), id, userId);
  }

  @PatchMapping("/conversations/{id}")
  ConversationDto rename(@PathVariable long id, @RequestBody @Valid Rename body) {
    return chat.rename(CurrentUser.id(), id, body.title());
  }

  @GetMapping("/conversations/{id}/messages")
  List<MessageDto> messages(@PathVariable long id, @RequestParam(required = false) Long before,
      @RequestParam(defaultValue = "30") int limit) {
    return chat.messages(CurrentUser.id(), id, before, limit);
  }

  @PostMapping("/conversations/{id}/messages")
  @ResponseStatus(HttpStatus.CREATED)
  MessageDto send(@PathVariable long id, @RequestBody @Valid NewMessage body) {
    return chat.send(CurrentUser.id(), id, body.type(), body.body(), body.mediaUrl(), body.metadata());
  }

  @PostMapping("/conversations/{id}/read")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void read(@PathVariable long id, @RequestBody Read body) {
    chat.markRead(CurrentUser.id(), id, body.messageId());
  }

  @PutMapping("/bubbles")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void bubbles(@RequestBody @Valid Bubbles body) {
    chat.saveBubbles(CurrentUser.id(), body.items());
  }
}
