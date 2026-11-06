package com.challengea.api.user;

import com.challengea.api.common.CurrentUser;
import com.challengea.api.friend.FriendService;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class UserController {
  private final UserService users;
  private final FriendService friends;

  public UserController(UserService users, FriendService friends) {
    this.users = users;
    this.friends = friends;
  }

  public record UpdateMe(@Size(max = 80) String displayName, @Size(max = 30) String handle, @Size(max = 500) String bio) {}

  /** A profile as seen by the signed-in user. */
  public record ProfileDto(UserDto user, String friendship) {}

  @GetMapping("/me")
  UserDto me() {
    return UserDto.of(users.get(CurrentUser.id()));
  }

  @PatchMapping("/me")
  UserDto updateMe(@RequestBody @jakarta.validation.Valid UpdateMe body) {
    return UserDto.of(users.update(CurrentUser.id(), body.displayName(), body.handle(), body.bio()));
  }

  @GetMapping("/users/{id}")
  ProfileDto profile(@PathVariable long id) {
    return new ProfileDto(UserDto.of(users.get(id)), friends.status(CurrentUser.id(), id));
  }

  @GetMapping("/users/search")
  List<UserDto> search(@RequestParam String q) {
    return users.search(q).stream().map(UserDto::of).toList();
  }
}
