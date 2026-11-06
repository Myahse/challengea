package com.challengea.api.call;

import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.security.Keys;
import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Date;
import java.util.Map;
import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.stereotype.Service;

/** Room access tokens for LiveKit (the WebRTC media server). */
@Service
public class LiveKitTokens {
  @ConfigurationProperties("app.livekit")
  public record Props(String url, String apiKey, String apiSecret) {}

  private final Props props;

  public LiveKitTokens(Props props) {
    this.props = props;
    if (props.apiSecret().getBytes(StandardCharsets.UTF_8).length < 32) {
      throw new IllegalStateException("app.livekit.api-secret must be at least 32 characters");
    }
  }

  public String url() {
    return props.url();
  }

  /** A token that lets [identity] join [room] for the next 6 hours, with mic, camera and data (reactions). */
  public String token(String room, String identity, String name) {
    return token(room, identity, name, true);
  }

  /** Viewers of a live can't publish video or sound, only chat over data. */
  public String token(String room, String identity, String name, boolean canPublish) {
    var now = Instant.now();
    return Jwts.builder()
        .issuer(props.apiKey())
        .subject(identity)
        .claim("name", name)
        .claim("video", Map.of(
            "room", room,
            "roomJoin", true,
            "canPublish", canPublish,
            "canSubscribe", true,
            "canPublishData", true))
        .notBefore(Date.from(now.minusSeconds(10)))
        .expiration(Date.from(now.plus(Duration.ofHours(6))))
        .signWith(Keys.hmacShaKeyFor(props.apiSecret().getBytes(StandardCharsets.UTF_8)), Jwts.SIG.HS256)
        .compact();
  }
}
