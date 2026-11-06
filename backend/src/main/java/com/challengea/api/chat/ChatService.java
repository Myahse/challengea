package com.challengea.api.chat;

import com.challengea.api.chat.ChatDtos.BubbleDto;
import com.challengea.api.chat.ChatDtos.ConversationDto;
import com.challengea.api.chat.ChatDtos.MessageDto;
import com.challengea.api.common.ApiException;
import com.challengea.api.friend.FriendService;
import com.challengea.api.realtime.Events;
import com.challengea.api.user.UserDto;
import com.challengea.api.user.UserRepository;
import java.util.Collection;
import java.util.Comparator;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ChatService {
  private static final Set<String> USER_TYPES = Set.of("text", "voice", "image", "file", "sticker");
  private static final int MAX_GROUP = 50;

  private final ConversationRepository conversations;
  private final MemberRepository members;
  private final MessageRepository messages;
  private final BubbleRepository bubbles;
  private final UserRepository users;
  private final FriendService friends;
  private final Events events;
  private final com.challengea.api.media.MediaService media;

  public ChatService(ConversationRepository conversations, MemberRepository members, MessageRepository messages,
      BubbleRepository bubbles, UserRepository users, FriendService friends, Events events,
      com.challengea.api.media.MediaService media) {
    this.media = media;
    this.conversations = conversations;
    this.members = members;
    this.messages = messages;
    this.bubbles = bubbles;
    this.users = users;
    this.friends = friends;
    this.events = events;
  }

  // ------------------------------------------------------------------ reads
  @Transactional(readOnly = true)
  public List<ConversationDto> list(long me) {
    var bubbleMap = bubbles.findByUserId(me).stream()
        .collect(Collectors.toMap(BubblePosition::getConversationId, b -> b));
    return members.findByUserId(me).stream()
        .map(m -> view(conversations.findById(m.getConversationId()).orElseThrow(), m, bubbleMap.get(m.getConversationId())))
        .sorted(Comparator.comparing((ConversationDto c) -> c.lastMessage() == null ? 0L : c.lastMessage().id()).reversed())
        .toList();
  }

  @Transactional(readOnly = true)
  public ConversationDto get(long me, long conversationId) {
    var membership = requireMember(me, conversationId);
    var bubble = bubbles.findByUserIdAndConversationId(me, conversationId).orElse(null);
    return view(conversations.findById(conversationId).orElseThrow(), membership, bubble);
  }

  /** Newest first; pass the oldest id you have as [before] to load older messages. */
  @Transactional(readOnly = true)
  public List<MessageDto> messages(long me, long conversationId, Long before, int limit) {
    requireMember(me, conversationId);
    var page = PageRequest.of(0, Math.clamp(limit, 1, 100));
    var list = before == null
        ? messages.findByConversationIdOrderByIdDesc(conversationId, page)
        : messages.findByConversationIdAndIdLessThanOrderByIdDesc(conversationId, before, page);
    return list.stream().map(MessageDto::of).toList();
  }

  // --------------------------------------------------------------- creation
  /** The 1-to-1 chat with a friend (created the first time). */
  @Transactional
  public ConversationDto direct(long me, long other) {
    if (!friends.areFriends(me, other)) throw ApiException.forbidden("You can only chat with friends");
    var conversation = conversations.findDirect(me, other).orElseGet(() -> {
      var c = conversations.save(new Conversation("direct", null, me));
      members.save(new ConversationMember(c.getId(), me, "member"));
      members.save(new ConversationMember(c.getId(), other, "member"));
      return c;
    });
    return get(me, conversation.getId());
  }

  /** A group made by merging bubbles: me + at least 2 friends. */
  @Transactional
  public ConversationDto createGroup(long me, Collection<Long> memberIds, String title) {
    var others = new LinkedHashSet<>(memberIds);
    others.remove(me);
    if (others.size() < 2) throw ApiException.badRequest("too_few_members", "A group needs at least 2 friends");
    if (others.size() + 1 > MAX_GROUP) throw ApiException.badRequest("too_many_members", "Groups are limited to " + MAX_GROUP);
    requireFriends(me, others);
    var c = conversations.save(new Conversation("group", blankToNull(title), me));
    members.save(new ConversationMember(c.getId(), me, "owner"));
    others.forEach(id -> members.save(new ConversationMember(c.getId(), id, "member")));
    var dto = get(me, c.getId());
    events.send(others, "conversation.added", Map.of("conversationId", c.getId()));
    return dto;
  }

  /** Dropping a bubble on a group adds those people. */
  @Transactional
  public ConversationDto addMembers(long me, long conversationId, Collection<Long> userIds) {
    var c = requireGroup(me, conversationId);
    var current = memberIds(conversationId);
    var added = userIds.stream().filter(id -> !current.contains(id)).distinct().toList();
    if (current.size() + added.size() > MAX_GROUP) throw ApiException.badRequest("too_many_members", "Group is full");
    requireFriends(me, added);
    added.forEach(id -> members.save(new ConversationMember(c.getId(), id, "member")));
    events.send(added, "conversation.added", Map.of("conversationId", c.getId()));
    events.send(current, "conversation.updated", Map.of("conversationId", c.getId()));
    return get(me, conversationId);
  }

  /** Leave a group (yourself) or remove someone (owner only). */
  @Transactional
  public void removeMember(long me, long conversationId, long userId) {
    var c = requireGroup(me, conversationId);
    var mine = requireMember(me, conversationId);
    if (userId != me && !"owner".equals(mine.getRole())) throw ApiException.forbidden("Only the group owner can remove people");
    members.findByConversationIdAndUserId(conversationId, userId).ifPresent(members::delete);
    var left = memberIds(conversationId);
    if (left.size() < 2) {
      conversations.delete(c); // a group of one is not a group: delete it (cascades)
    } else if (userId == me && "owner".equals(mine.getRole())) {
      // Hand ownership to the longest-standing member.
      members.findByConversationId(conversationId).getFirst().setRole("owner");
    }
    events.send(left, "conversation.updated", Map.of("conversationId", conversationId));
    events.send(userId, "conversation.removed", Map.of("conversationId", conversationId));
  }

  @Transactional
  public ConversationDto rename(long me, long conversationId, String title) {
    var c = requireGroup(me, conversationId);
    c.setTitle(blankToNull(title));
    events.send(memberIds(conversationId), "conversation.updated", Map.of("conversationId", conversationId));
    return get(me, conversationId);
  }

  // --------------------------------------------------------------- messages
  @Transactional
  public MessageDto send(long me, long conversationId, String type, String body, String mediaUrl,
      Map<String, Object> metadata) {
    requireMember(me, conversationId);
    if (!USER_TYPES.contains(type)) throw ApiException.badRequest("invalid_type", "Unknown message type " + type);
    if (type.equals("text") && (body == null || body.isBlank())) throw ApiException.badRequest("empty", "Message is empty");
    if (type.equals("sticker") && (body == null || body.isBlank())) throw ApiException.badRequest("empty", "Pick a sticker");
    if (type.equals("image") || type.equals("voice")) {
      media.requireOwned(me, mediaUrl, type); // only files you uploaded
    } else if (type.equals("file")) {
      throw ApiException.badRequest("invalid_type", "Files are not supported yet");
    } else if (mediaUrl != null) {
      throw ApiException.badRequest("invalid_media", "This message type has no file");
    }
    var m = messages.save(new ChatMessage(conversationId, me, type, body, mediaUrl, metadata));
    var dto = MessageDto.of(m);
    events.send(memberIds(conversationId), "message.new", dto);
    return dto;
  }

  /** Server-made messages (game results...). */
  @Transactional
  public MessageDto post(long conversationId, Long senderId, String type, String body, Map<String, Object> metadata) {
    var m = messages.save(new ChatMessage(conversationId, senderId, type, body, null, metadata));
    var dto = MessageDto.of(m);
    events.send(memberIds(conversationId), "message.new", dto);
    return dto;
  }

  /** The 1-to-1 conversation id between two users, created if needed (no friendship check). */
  @Transactional
  public long directId(long a, long b) {
    return conversations.findDirect(a, b).orElseGet(() -> {
      var c = conversations.save(new Conversation("direct", null, a));
      members.save(new ConversationMember(c.getId(), a, "member"));
      members.save(new ConversationMember(c.getId(), b, "member"));
      return c;
    }).getId();
  }

  @Transactional
  public void markRead(long me, long conversationId, long messageId) {
    var m = requireMember(me, conversationId);
    if (m.getLastReadMessageId() == null || messageId > m.getLastReadMessageId()) {
      m.setLastReadMessageId(messageId);
      events.send(memberIds(conversationId), "message.read",
          Map.of("conversationId", conversationId, "userId", me, "messageId", messageId));
    }
  }

  // ----------------------------------------------------------------- bubbles
  @Transactional
  public void saveBubbles(long me, List<BubbleDto> items) {
    for (var item : items) {
      requireMember(me, item.conversationId());
      var b = bubbles.findByUserIdAndConversationId(me, item.conversationId())
          .orElseGet(() -> new BubblePosition(me, item.conversationId()));
      b.moveTo(Math.clamp(item.x(), 0, 1), Math.clamp(item.y(), 0, 1));
      bubbles.save(b);
    }
  }

  // ----------------------------------------------------------------- helpers
  private ConversationDto view(Conversation c, ConversationMember membership, BubblePosition bubble) {
    var ids = memberIds(c.getId());
    var people = users.findAllById(ids).stream().map(UserDto::of).toList();
    var last = messages.findFirstByConversationIdOrderByIdDesc(c.getId()).map(MessageDto::of).orElse(null);
    var after = membership.getLastReadMessageId() == null ? 0L : membership.getLastReadMessageId();
    var unread = messages.countUnread(c.getId(), after, membership.getUserId());
    var b = bubble == null ? null : new BubbleDto(c.getId(), bubble.getX(), bubble.getY());
    return new ConversationDto(c.getId(), c.getType(), c.getTitle(), people, last, unread, b);
  }

  private List<Long> memberIds(long conversationId) {
    return members.findByConversationId(conversationId).stream().map(ConversationMember::getUserId).toList();
  }

  private ConversationMember requireMember(long me, long conversationId) {
    return members.findByConversationIdAndUserId(conversationId, me)
        .orElseThrow(() -> ApiException.notFound("Conversation"));
  }

  private Conversation requireGroup(long me, long conversationId) {
    requireMember(me, conversationId);
    var c = conversations.findById(conversationId).orElseThrow(() -> ApiException.notFound("Conversation"));
    if (!c.isGroup()) throw ApiException.badRequest("not_a_group", "This is a 1-to-1 chat");
    return c;
  }

  private void requireFriends(long me, Collection<Long> ids) {
    var mine = Set.copyOf(friends.friendIds(me));
    for (var id : ids) {
      if (!mine.contains(id)) throw ApiException.forbidden("You can only add friends to a group");
    }
  }

  private static String blankToNull(String s) {
    return s == null || s.isBlank() ? null : s.trim();
  }
}
