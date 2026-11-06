package com.challengea.api.location;

import com.challengea.api.common.ApiException;
import com.challengea.api.friend.FriendService;
import com.challengea.api.realtime.Events;
import com.challengea.api.user.UserDto;
import com.challengea.api.user.UserRepository;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

interface LocationRepository extends JpaRepository<UserLocation, Long> {}

@Service
public class LocationService {
  private final LocationRepository locations;
  private final FriendService friends;
  private final UserRepository users;
  private final Events events;

  public LocationService(LocationRepository locations, FriendService friends, UserRepository users, Events events) {
    this.locations = locations;
    this.friends = friends;
    this.users = users;
    this.events = events;
  }

  public record FriendLocation(UserDto user, double lat, double lng, String place, String status, OffsetDateTime updatedAt) {}

  public record MyLocation(Double lat, Double lng, String place, String status, boolean ghost) {}

  @Transactional
  public MyLocation update(long me, double lat, double lng, String place, String status) {
    if (lat < -90 || lat > 90 || lng < -180 || lng > 180) throw ApiException.badRequest("invalid_position", "Invalid position");
    var loc = locations.findById(me).orElseGet(() -> new UserLocation(me));
    loc.update(lat, lng, place, status);
    locations.save(loc);
    if (!loc.isGhost()) {
      var view = view(loc);
      events.send(friends.friendIds(me), "location.updated", view);
    }
    return mine(loc);
  }

  /** Ghost mode: friends stop seeing me on the map. */
  @Transactional
  public MyLocation ghost(long me, boolean ghost) {
    var loc = locations.findById(me).orElseGet(() -> new UserLocation(me));
    if (!loc.hasPosition()) loc.update(0, 0, null, null); // placeholder until the first GPS update
    loc.setGhost(ghost);
    locations.save(loc);
    events.send(friends.friendIds(me), ghost ? "location.hidden" : "location.updated",
        ghost ? Map.of("userId", me) : view(loc));
    return mine(loc);
  }

  /** Friends who share their position (not in Ghost mode). */
  @Transactional(readOnly = true)
  public List<FriendLocation> friendsLocations(long me) {
    return locations.findAllById(friends.friendIds(me)).stream()
        .filter(l -> !l.isGhost())
        .map(this::view)
        .toList();
  }

  private FriendLocation view(UserLocation l) {
    var user = UserDto.of(users.findById(l.getUserId()).orElseThrow());
    return new FriendLocation(user, l.getLat(), l.getLng(), l.getPlace(), l.getStatusText(), l.getUpdatedAt());
  }

  private static MyLocation mine(UserLocation l) {
    return new MyLocation(l.getLat(), l.getLng(), l.getPlace(), l.getStatusText(), l.isGhost());
  }
}
