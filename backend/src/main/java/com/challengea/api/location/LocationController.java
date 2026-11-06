package com.challengea.api.location;

import com.challengea.api.common.CurrentUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class LocationController {
  private final LocationService locations;

  public LocationController(LocationService locations) {
    this.locations = locations;
  }

  public record Position(double lat, double lng, @Size(max = 120) String place, @Size(max = 120) String status) {}

  public record Ghost(boolean ghost) {}

  @PutMapping("/location")
  LocationService.MyLocation update(@RequestBody @Valid Position body) {
    return locations.update(CurrentUser.id(), body.lat(), body.lng(), body.place(), body.status());
  }

  @PutMapping("/location/ghost")
  LocationService.MyLocation ghost(@RequestBody Ghost body) {
    return locations.ghost(CurrentUser.id(), body.ghost());
  }

  @GetMapping("/friends/locations")
  List<LocationService.FriendLocation> friends() {
    return locations.friendsLocations(CurrentUser.id());
  }
}
