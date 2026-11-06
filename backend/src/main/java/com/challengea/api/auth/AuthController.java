package com.challengea.api.auth;

import jakarta.validation.Valid;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Pattern;
import jakarta.validation.constraints.Size;
import java.util.HashMap;
import java.util.Map;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/auth")
public class AuthController {
  private final AuthService auth;

  public AuthController(AuthService auth) {
    this.auth = auth;
  }

  public record CodeRequest(@NotBlank String phone) {}

  public record CodeVerify(@NotBlank String phone, @Pattern(regexp = "\\d{6}") String code, @Size(max = 80) String displayName) {}

  public record Register(@Email @NotBlank String email, @Size(min = 6, max = 100) String password,
      @NotBlank @Size(max = 80) String displayName) {}

  public record Login(@NotBlank String email, @NotBlank String password) {}

  /** Step 1 of phone sign-in: sends a 6-digit code by SMS. */
  @PostMapping("/otp/request")
  Map<String, Object> requestCode(@RequestBody @Valid CodeRequest body) {
    var devCode = auth.requestCode(body.phone());
    var res = new HashMap<String, Object>();
    res.put("sent", true);
    if (devCode != null) res.put("devCode", devCode);
    return res;
  }

  /** Step 2: checks the code, signs in, or creates the account (needs displayName). */
  @PostMapping("/otp/verify")
  AuthService.Session verify(@RequestBody @Valid CodeVerify body) {
    return auth.verifyCode(body.phone(), body.code(), body.displayName());
  }

  @PostMapping("/register")
  AuthService.Session register(@RequestBody @Valid Register body) {
    return auth.register(body.email(), body.password(), body.displayName());
  }

  @PostMapping("/login")
  AuthService.Session login(@RequestBody @Valid Login body) {
    return auth.login(body.email(), body.password());
  }
}
