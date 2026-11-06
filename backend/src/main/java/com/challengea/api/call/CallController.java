package com.challengea.api.call;

import com.challengea.api.common.CurrentUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotEmpty;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/calls")
public class CallController {
  private final CallService calls;

  public CallController(CallService calls) {
    this.calls = calls;
  }

  public record NewCall(long conversationId, boolean video) {}

  public record Invite(@NotEmpty List<Long> userIds) {}

  /** Rings the conversation's members ("call.incoming") and returns my LiveKit token. */
  @PostMapping
  @ResponseStatus(HttpStatus.CREATED)
  CallService.Join start(@RequestBody NewCall body) {
    return calls.start(CurrentUser.id(), body.conversationId(), body.video());
  }

  @PostMapping("/{id}/accept")
  CallService.Join accept(@PathVariable long id) {
    return calls.accept(CurrentUser.id(), id);
  }

  @PostMapping("/{id}/decline")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void decline(@PathVariable long id) {
    calls.decline(CurrentUser.id(), id);
  }

  @PostMapping("/{id}/leave")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void leave(@PathVariable long id) {
    calls.leave(CurrentUser.id(), id);
  }

  @PostMapping("/{id}/invite")
  CallService.CallDto invite(@PathVariable long id, @RequestBody @Valid Invite body) {
    return calls.invite(CurrentUser.id(), id, body.userIds());
  }
}
