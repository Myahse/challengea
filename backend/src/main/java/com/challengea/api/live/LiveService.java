package com.challengea.api.live;

import com.challengea.api.call.LiveKitTokens;
import com.challengea.api.common.ApiException;
import com.challengea.api.friend.FriendService;
import com.challengea.api.realtime.Events;
import com.challengea.api.user.UserDto;
import com.challengea.api.user.UserService;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

interface LiveRepository extends JpaRepository<Live, Long> {
  List<Live> findByEndedAtIsNullAndStartedAtAfterOrderByStartedAtDesc(OffsetDateTime since);

  List<Live> findByHostIdAndEndedAtIsNull(long hostId);
}

/** Friends can watch each other's lives. The video goes through LiveKit. */
@Service
public class LiveService {
  private static final int MAX_HOURS = 4;

  private final LiveRepository lives;
  private final FriendService friends;
  private final UserService users;
  private final LiveKitTokens livekit;
  private final Events events;

  public LiveService(LiveRepository lives, FriendService friends, UserService users, LiveKitTokens livekit,
      Events events) {
    this.lives = lives;
    this.friends = friends;
    this.users = users;
    this.livekit = livekit;
    this.events = events;
  }

  public record LiveDto(long id, UserDto host, String title, OffsetDateTime startedAt) {}

  public record Join(LiveDto live, String url, String token) {}

  /** Friends' lives happening now, and mine. */
  @Transactional(readOnly = true)
  public List<LiveDto> active(long me) {
    var mine = friends.friendIds(me);
    return lives.findByEndedAtIsNullAndStartedAtAfterOrderByStartedAtDesc(OffsetDateTime.now().minusHours(MAX_HOURS))
        .stream().filter(l -> l.getHostId() == me || mine.contains(l.getHostId())).map(this::view).toList();
  }

  /** Goes live, closing any broadcast I left open. */
  @Transactional
  public Join start(long me, String title) {
    lives.findByHostIdAndEndedAtIsNull(me).forEach(this::close);
    var clean = title == null || title.isBlank() ? null : title.strip();
    var live = lives.save(new Live(me, clean));
    var dto = view(live);
    events.send(friends.friendIds(me), "live.started", dto);
    return join(me, live, true);
  }

  @Transactional(readOnly = true)
  public Join watch(long me, long liveId) {
    var live = lives.findById(liveId).filter(l -> !l.isOver())
        .filter(l -> l.getHostId() == me || friends.areFriends(me, l.getHostId()))
        .orElseThrow(() -> ApiException.notFound("Live"));
    return join(me, live, live.getHostId() == me);
  }

  @Transactional
  public void end(long me, long liveId) {
    var live = lives.findById(liveId).orElseThrow(() -> ApiException.notFound("Live"));
    if (live.getHostId() != me) throw ApiException.forbidden("Only the host can end a live");
    close(live);
  }

  private void close(Live live) {
    if (live.isOver()) return;
    live.end();
    var everyone = new ArrayList<>(friends.friendIds(live.getHostId()));
    everyone.add(live.getHostId());
    events.send(everyone, "live.ended", Map.of("liveId", live.getId()));
  }

  private Join join(long me, Live live, boolean host) {
    var token = livekit.token(live.room(), "u" + me, users.get(me).getDisplayName(), host);
    return new Join(view(live), livekit.url(), token);
  }

  private LiveDto view(Live l) {
    return new LiveDto(l.getId(), UserDto.of(users.get(l.getHostId())), l.getTitle(), l.getStartedAt());
  }
}
