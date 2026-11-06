package com.challengea.api.friend;

import com.challengea.api.common.ApiException;
import com.challengea.api.realtime.Events;
import com.challengea.api.user.User;
import com.challengea.api.user.UserDto;
import com.challengea.api.user.UserRepository;
import com.challengea.api.user.UserService;
import java.util.List;
import java.util.Map;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class FriendService {
  private final FriendshipRepository friendships;
  private final UserRepository users;
  private final UserService userService;
  private final Events events;

  public FriendService(FriendshipRepository friendships, UserRepository users, UserService userService, Events events) {
    this.friendships = friendships;
    this.users = users;
    this.userService = userService;
    this.events = events;
  }

  /** "none", "friends", "requested" (I asked), "incoming" (they asked) or "blocked". */
  public String status(long me, long other) {
    if (me == other) return "me";
    return friendships.between(me, other).map(f -> switch (f.getStatus()) {
      case "accepted" -> "friends";
      case "blocked" -> "blocked";
      default -> f.getRequesterId() == me ? "requested" : "incoming";
    }).orElse("none");
  }

  public boolean areFriends(long a, long b) {
    return friendships.between(a, b).map(f -> f.getStatus().equals("accepted")).orElse(false);
  }

  public List<Long> friendIds(long me) {
    return friendships.ofUser(me, "accepted").stream().map(f -> f.other(me)).toList();
  }

  public List<User> friends(long me) {
    return users.findAllById(friendIds(me));
  }

  public List<User> incoming(long me) {
    return users.findAllById(friendships.findByAddresseeIdAndStatus(me, "pending").stream().map(Friendship::getRequesterId).toList());
  }

  /** Sends a request, or accepts theirs if they already asked me. */
  @Transactional
  public String request(long me, long other) {
    if (me == other) throw ApiException.badRequest("self", "You can't add yourself");
    var target = userService.get(other);
    var existing = friendships.between(me, other);
    if (existing.isPresent()) {
      var f = existing.get();
      if (f.getStatus().equals("pending") && f.getAddresseeId() == me) return accept(me, other);
      return status(me, other);
    }
    friendships.save(new Friendship(me, target.getId()));
    events.send(other, "friend.request", Map.of("from", UserDto.of(userService.get(me))));
    return "requested";
  }

  @Transactional
  public String accept(long me, long requester) {
    var f = friendships.between(me, requester)
        .filter(x -> x.getAddresseeId() == me && x.getStatus().equals("pending"))
        .orElseThrow(() -> ApiException.notFound("Friend request"));
    f.accept();
    events.send(requester, "friend.accepted", Map.of("by", UserDto.of(userService.get(me))));
    return "friends";
  }

  @Transactional
  public void remove(long me, long other) {
    friendships.between(me, other).ifPresent(friendships::delete);
  }
}
