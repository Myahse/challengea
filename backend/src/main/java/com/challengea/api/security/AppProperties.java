package com.challengea.api.security;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties("app")
public record AppProperties(Jwt jwt, Otp otp) {
  public record Jwt(String secret, Duration ttl) {}

  public record Otp(Duration ttl, boolean devEcho) {}
}
