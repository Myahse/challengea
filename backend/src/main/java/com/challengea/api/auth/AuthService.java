package com.challengea.api.auth;

import com.challengea.api.common.ApiException;
import com.challengea.api.security.AppProperties;
import com.challengea.api.security.JwtService;
import com.challengea.api.user.User;
import com.challengea.api.user.UserDto;
import com.challengea.api.user.UserRepository;
import com.challengea.api.user.UserService;
import java.security.SecureRandom;
import java.time.OffsetDateTime;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
  private static final int MAX_ATTEMPTS = 5;
  private static final int MAX_CODES_PER_WINDOW = 3;
  private final SecureRandom random = new SecureRandom();
  private final OtpRepository otps;
  private final UserRepository users;
  private final UserService userService;
  private final PasswordEncoder encoder;
  private final JwtService jwt;
  private final AppProperties props;

  public AuthService(OtpRepository otps, UserRepository users, UserService userService, PasswordEncoder encoder,
      JwtService jwt, AppProperties props) {
    this.otps = otps;
    this.users = users;
    this.userService = userService;
    this.encoder = encoder;
    this.jwt = jwt;
    this.props = props;
  }

  public record Session(String token, UserDto user, boolean isNew) {}

  /** Côte d'Ivoire numbers: +225 followed by 10 digits. Other countries: E.164. */
  static String normalizePhone(String raw) {
    var digits = raw.replaceAll("[^0-9+]", "");
    if (digits.matches("0\\d{9}")) digits = "+225" + digits; // local format 07 00 00 00 00
    if (digits.matches("225\\d{10}")) digits = "+" + digits;
    if (!digits.matches("\\+\\d{8,15}")) throw ApiException.badRequest("invalid_phone", "Enter a valid phone number");
    return digits;
  }

  /** Creates a 6-digit code. Returns it only when dev-echo is on (no SMS provider yet). */
  @Transactional
  public String requestCode(String rawPhone) {
    var phone = normalizePhone(rawPhone);
    if (otps.countByPhoneAndExpiresAtAfter(phone, OffsetDateTime.now()) >= MAX_CODES_PER_WINDOW) {
      throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "too_many_codes", "Wait a few minutes before asking again");
    }
    var code = String.format("%06d", random.nextInt(1_000_000));
    otps.save(new OtpCode(phone, encoder.encode(code), OffsetDateTime.now().plus(props.otp().ttl())));
    // TODO: send the SMS (Orange / MTN / Twilio...) here.
    return props.otp().devEcho() ? code : null;
  }

  /** Wrong codes are counted even though an error is returned (no rollback), so guessing is limited. */
  @Transactional(noRollbackFor = ApiException.class)
  public Session verifyCode(String rawPhone, String code, String displayName) {
    var phone = normalizePhone(rawPhone);
    var otp = otps.findFirstByPhoneOrderByIdDesc(phone)
        .orElseThrow(() -> ApiException.badRequest("no_code", "Ask for a code first"));
    if (otp.isUsed()) throw ApiException.badRequest("code_used", "This code was already used, ask for a new one");
    if (otp.getExpiresAt().isBefore(OffsetDateTime.now())) {
      throw ApiException.badRequest("code_expired", "This code expired, ask for a new one");
    }
    if (otp.getAttempts() >= MAX_ATTEMPTS) {
      throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "too_many_attempts", "Too many tries, ask for a new code");
    }
    otp.addAttempt();
    if (!encoder.matches(code, otp.getCodeHash())) throw ApiException.badRequest("wrong_code", "Wrong code");

    var existing = users.findByPhone(phone);
    if (existing.isEmpty() && (displayName == null || displayName.isBlank())) {
      // The code stays valid: the app asks for the name and sends the same code again.
      throw ApiException.badRequest("name_required", "Enter your name to create your account");
    }
    otp.markUsed();
    return existing.map(u -> session(u, false))
        .orElseGet(() -> session(userService.create(displayName, phone, null, null), true));
  }

  @Transactional
  public Session register(String email, String password, String displayName) {
    if (users.findByEmailIgnoreCase(email).isPresent()) {
      throw ApiException.conflict("email_taken", "An account already uses this email");
    }
    var user = userService.create(displayName, null, email.trim().toLowerCase(), encoder.encode(password));
    return session(user, true);
  }

  public Session login(String email, String password) {
    var user = users.findByEmailIgnoreCase(email.trim())
        .filter(u -> u.getPasswordHash() != null && encoder.matches(password, u.getPasswordHash()))
        .orElseThrow(() -> new ApiException(HttpStatus.UNAUTHORIZED, "bad_credentials", "Wrong email or password"));
    return session(user, false);
  }

  private Session session(User user, boolean isNew) {
    return new Session(jwt.issue(user.getId()), UserDto.of(user), isNew);
  }
}
