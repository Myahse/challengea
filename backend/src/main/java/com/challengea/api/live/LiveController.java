package com.challengea.api.live;

import com.challengea.api.common.CurrentUser;
import com.challengea.api.live.LiveService.Join;
import com.challengea.api.live.LiveService.LiveDto;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/lives")
public class LiveController {
  private final LiveService lives;

  public LiveController(LiveService lives) {
    this.lives = lives;
  }

  public record NewLive(@Size(max = 120) String title) {}

  @GetMapping
  List<LiveDto> active() {
    return lives.active(CurrentUser.id());
  }

  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  Join start(@RequestBody @Valid NewLive body) {
    return lives.start(CurrentUser.id(), body.title());
  }

  @PostMapping("/{id}/watch")
  Join watch(@PathVariable long id) {
    return lives.watch(CurrentUser.id(), id);
  }

  @PostMapping("/{id}/end")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void end(@PathVariable long id) {
    lives.end(CurrentUser.id(), id);
  }
}
