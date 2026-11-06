package com.challengea.api.security;

import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import javax.crypto.SecretKey;
import org.springframework.stereotype.Service;

/** Issues and checks the access tokens the app sends as "Authorization: Bearer ...". */
@Service
public class JwtService {
  private final SecretKey key;
  private final AppProperties props;

  public JwtService(AppProperties props) {
    this.props = props;
    var bytes = props.jwt().secret().getBytes(StandardCharsets.UTF_8);
    if (bytes.length < 32) throw new IllegalStateException("app.jwt.secret must be at least 32 characters");
    this.key = Keys.hmacShaKeyFor(bytes);
  }

  public String issue(long userId) {
    var now = Instant.now();
    return Jwts.builder()
        .subject(Long.toString(userId))
        .issuedAt(Date.from(now))
        .expiration(Date.from(now.plus(props.jwt().ttl())))
        .signWith(key)
        .compact();
  }

  /** The user id inside a valid token, or empty. */
  public Optional<Long> verify(String token) {
    try {
      var subject = Jwts.parser().verifyWith(key).build().parseSignedClaims(token).getPayload().getSubject();
      return Optional.of(Long.parseLong(subject));
    } catch (JwtException | IllegalArgumentException e) {
      return Optional.empty();
    }
  }
}
