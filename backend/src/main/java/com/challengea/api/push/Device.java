package com.challengea.api.push;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "devices")
public class Device {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "user_id", nullable = false)
  private long userId;

  @Column(nullable = false, length = 4000)
  private String token;

  @Column(name = "token_hash", nullable = false)
  private String tokenHash;

  @Column(nullable = false)
  private String platform;

  @Column(name = "updated_at", nullable = false)
  private OffsetDateTime updatedAt = OffsetDateTime.now();

  protected Device() {}

  public Device(long userId, String token, String tokenHash, String platform) {
    this.userId = userId;
    this.token = token;
    this.tokenHash = tokenHash;
    this.platform = platform;
  }

  public long getUserId() { return userId; }
  public String getToken() { return token; }

  public void reassign(long userId, String platform) {
    this.userId = userId;
    this.platform = platform;
    this.updatedAt = OffsetDateTime.now();
  }
}
