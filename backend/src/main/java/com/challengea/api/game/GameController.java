package com.challengea.api.game;

import com.challengea.api.common.CurrentUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import java.util.List;
import java.util.Map;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class GameController {
  private final MatchService matches;

  public GameController(MatchService matches) {
    this.matches = matches;
  }

  public record GameDto(String id, String name, boolean playable) {}

  public record NewChallenge(@NotBlank String gameId, long opponentId) {}

  @GetMapping("/games")
  List<GameDto> games() {
    return matches.games().stream().map(g -> new GameDto(g.getId(), g.getName(), g.isPlayable())).toList();
  }

  /** Challenges a friend; they get a "match.invited" event and a message in your chat. */
  @PostMapping("/matches")
  @ResponseStatus(HttpStatus.CREATED)
  MatchService.MatchDto challenge(@RequestBody @Valid NewChallenge body) {
    return matches.challenge(CurrentUser.id(), body.gameId(), body.opponentId());
  }

  @GetMapping("/matches")
  List<MatchService.MatchDto> open() {
    return matches.open(CurrentUser.id());
  }

  @GetMapping("/matches/{id}")
  MatchService.MatchDto get(@PathVariable long id) {
    return matches.get(CurrentUser.id(), id);
  }

  @PostMapping("/matches/{id}/accept")
  MatchService.MatchDto accept(@PathVariable long id) {
    return matches.accept(CurrentUser.id(), id);
  }

  @PostMapping("/matches/{id}/decline")
  MatchService.MatchDto decline(@PathVariable long id) {
    return matches.decline(CurrentUser.id(), id);
  }

  @PostMapping("/matches/{id}/moves")
  MatchService.MatchDto move(@PathVariable long id, @RequestBody Map<String, Object> move) {
    return matches.move(CurrentUser.id(), id, move);
  }
}
