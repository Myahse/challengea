package com.challengea.api.call;

import com.challengea.api.chat.ChatService;
import com.challengea.api.common.ApiException;
import com.challengea.api.friend.FriendService;
import com.challengea.api.realtime.Events;
import com.challengea.api.user.UserDto;
import com.challengea.api.user.UserService;
import java.time.Duration;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

interface CallRepository extends JpaRepository<Call, Long> {}

/**
 * Rings people, hands out LiveKit tokens and keeps the call's state.
 * Who is in a call right now is kept in memory (one API instance); move it to
 * LiveKit webhooks when running several instances.
 */
@Service
public class CallService {
  private final CallRepository calls;
  private final ChatService chat;
  private final FriendService friends;
  private final UserService users;
  private final LiveKitTokens livekit;
  private final Events events;
  private final ApplicationEventPublisher published;
  private final Map<Long, Set<Long>> inCall = new ConcurrentHashMap<>();
  private final Map<Long, Set<Long>> invited = new ConcurrentHashMap<>();

  public CallService(CallRepository calls, ChatService chat, FriendService friends, UserService users,
      LiveKitTokens livekit, Events events, ApplicationEventPublisher published) {
    this.calls = calls;
    this.chat = chat;
    this.friends = friends;
    this.users = users;
    this.livekit = livekit;
    this.events = events;
    this.published = published;
  }

  /** Something changed in a call. */
  public record CallChanged(long callId) {}

  /** Who is ringing and who is in the call right now. */
  public record Snapshot(boolean over, Set<Long> invited, Set<Long> present) {}

  public Snapshot snapshot(long callId) {
    var over = calls.findById(callId).map(Call::isOver).orElse(true);
    return new Snapshot(over, Set.copyOf(invited.getOrDefault(callId, Set.of())),
        Set.copyOf(inCall.getOrDefault(callId, Set.of())));
  }

  /** What a phone needs to join: the call, the LiveKit URL and its own token. */
  public record Join(CallDto call, String url, String token) {}

  public record CallDto(long id, long conversationId, UserDto startedBy, boolean video, String status,
      Collection<Long> inCall) {}

  /** Starts a call in a conversation and rings its other members. */
  @Transactional
  public Join start(long me, long conversationId, boolean video) {
    var conversation = chat.get(me, conversationId); // checks I'm a member
    var call = calls.save(new Call(conversationId, me, video));
    var others = new LinkedHashSet<Long>();
    conversation.members().forEach(u -> { if (u.id() != me) others.add(u.id()); });
    invited.put(call.getId(), ConcurrentHashMap.newKeySet());
    invited.get(call.getId()).addAll(others);
    inCall.put(call.getId(), ConcurrentHashMap.newKeySet());
    inCall.get(call.getId()).add(me);
    var dto = view(call);
    events.send(others, "call.incoming", dto);
    published.publishEvent(new CallChanged(call.getId()));
    return join(me, call, dto);
  }

  /** Answer (or rejoin) a call I was invited to. */
  @Transactional
  public Join accept(long me, long callId) {
    var call = require(me, callId);
    if (call.isOver()) throw ApiException.conflict("call_over", "This call has ended");
    call.answer();
    inCall.computeIfAbsent(callId, k -> ConcurrentHashMap.newKeySet()).add(me);
    var dto = view(call);
    events.send(participants(call), "call.updated", dto);
    published.publishEvent(new CallChanged(callId));
    return join(me, call, dto);
  }

  @Transactional
  public void decline(long me, long callId) {
    var call = require(me, callId);
    invited.getOrDefault(callId, Set.of()).remove(me);
    events.send(call.getStartedBy(), "call.declined", Map.of("callId", callId, "userId", me));
    // Nobody left to answer and nobody talking: the call is over.
    if (invited.getOrDefault(callId, Set.of()).isEmpty() && call.getAnsweredAt() == null) end(call);
  }

  /** Leave the call; the last one out ends it. */
  @Transactional
  public void leave(long me, long callId) {
    var call = require(me, callId);
    var present = inCall.getOrDefault(callId, ConcurrentHashMap.newKeySet());
    present.remove(me);
    if (present.isEmpty() || call.getAnsweredAt() == null) {
      end(call);
    } else {
      events.send(participants(call), "call.updated", view(call));
      published.publishEvent(new CallChanged(callId));
    }
  }

  /** Bring more friends into the call (a 1-to-1 call becomes a group call). */
  @Transactional
  public CallDto invite(long me, long callId, Collection<Long> userIds) {
    var call = require(me, callId);
    var mine = Set.copyOf(friends.friendIds(me));
    for (var id : userIds) {
      if (!mine.contains(id)) throw ApiException.forbidden("You can only add friends to a call");
    }
    invited.computeIfAbsent(callId, k -> ConcurrentHashMap.newKeySet()).addAll(userIds);
    var dto = view(call);
    events.send(userIds, "call.incoming", dto);
    published.publishEvent(new CallChanged(callId));
    return dto;
  }

  private void end(Call call) {
    if (call.isOver()) return;
    call.end();
    var everyone = participants(call);
    inCall.remove(call.getId());
    invited.remove(call.getId());
    var kind = call.isVideo() ? "Video call" : "Voice call";
    var meta = new HashMap<String, Object>();
    meta.put("kind", "call");
    meta.put("callId", call.getId());
    meta.put("video", call.isVideo());
    String text;
    if (call.getAnsweredAt() == null) {
      text = "📵 Missed " + kind.toLowerCase();
    } else {
      var d = Duration.between(call.getAnsweredAt(), call.getEndedAt());
      meta.put("durationSec", d.toSeconds());
      text = "📞 " + kind + " · " + d.toMinutes() + ":" + String.format("%02d", d.toSecondsPart());
    }
    chat.post(call.getConversationId(), call.getStartedBy(), "system", text, meta);
    events.send(everyone, "call.ended", Map.of("callId", call.getId()));
  }

  private Join join(long me, Call call, CallDto dto) {
    var user = users.get(me);
    return new Join(dto, livekit.url(), livekit.token(call.room(), "u" + me, user.getDisplayName()));
  }

  /** Members of the conversation plus anyone invited later. */
  private Set<Long> participants(Call call) {
    var all = new LinkedHashSet<Long>();
    chat.get(call.getStartedBy(), call.getConversationId()).members().forEach(u -> all.add(u.id()));
    all.addAll(invited.getOrDefault(call.getId(), Set.of()));
    all.addAll(inCall.getOrDefault(call.getId(), Set.of()));
    return all;
  }

  private Call require(long me, long callId) {
    var call = calls.findById(callId).orElseThrow(() -> ApiException.notFound("Call"));
    var allowed = call.getStartedBy() == me
        || invited.getOrDefault(callId, Set.of()).contains(me)
        || inCall.getOrDefault(callId, Set.of()).contains(me)
        || isMember(me, call);
    if (!allowed) throw ApiException.notFound("Call");
    return call;
  }

  private boolean isMember(long me, Call call) {
    try {
      chat.get(me, call.getConversationId());
      return true;
    } catch (ApiException e) {
      return false;
    }
  }

  private CallDto view(Call call) {
    return new CallDto(call.getId(), call.getConversationId(), UserDto.of(users.get(call.getStartedBy())), call.isVideo(),
        call.getStatus(), Set.copyOf(inCall.getOrDefault(call.getId(), Set.of())));
  }
}
