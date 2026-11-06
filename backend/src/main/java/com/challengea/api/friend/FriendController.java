package com.challengea.api.friend;

import com.challengea.api.common.CurrentUser;
import com.challengea.api.user.UserDto;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/friends")
public class FriendController {
  private final FriendService friends;

  public FriendController(FriendService friends) {
    this.friends = friends;
  }

  @GetMapping
  List<UserDto> list() {
    return friends.friends(CurrentUser.id()).stream().map(UserDto::of).toList();
  }

  @GetMapping("/requests")
  List<UserDto> incoming() {
    return friends.incoming(CurrentUser.id()).stream().map(UserDto::of).toList();
  }

  @PostMapping("/{userId}")
  Map<String, String> add(@PathVariable long userId) {
    return Map.of("friendship", friends.request(CurrentUser.id(), userId));
  }

  @PostMapping("/{userId}/accept")
  Map<String, String> accept(@PathVariable long userId) {
    return Map.of("friendship", friends.accept(CurrentUser.id(), userId));
  }

  @DeleteMapping("/{userId}")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void remove(@PathVariable long userId) {
    friends.remove(CurrentUser.id(), userId);
  }
}
