package com.challengea.api.push;

import com.challengea.api.common.CurrentUser;
import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/devices")
public class DeviceController {
  private final DeviceService devices;

  public DeviceController(DeviceService devices) {
    this.devices = devices;
  }

  public record Register(@NotBlank String token, @NotBlank String platform) {}

  /** The app sends its Firebase token after sign-in (and when it changes). */
  @PutMapping
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void register(@RequestBody @Valid Register body) {
    devices.register(CurrentUser.id(), body.token(), body.platform());
  }

  /** On sign-out, so this phone stops receiving the account's notifications. */
  @PostMapping("/unregister")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void unregister(@RequestBody @Valid Register body) {
    devices.unregister(CurrentUser.id(), body.token());
  }
}
