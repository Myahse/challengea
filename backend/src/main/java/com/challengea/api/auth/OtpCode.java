package com.challengea.api.auth;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "otp_codes")
public class OtpCode {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(nullable = false)
  private String phone;

  @Column(name = "code_hash", nullable = false)
  private String codeHash;

  @Column(name = "expires_at", nullable = false)
  private OffsetDateTime expiresAt;

  private int attempts;
  private boolean used;

  protected OtpCode() {}

  public OtpCode(String phone, String codeHash, OffsetDateTime expiresAt) {
    this.phone = phone;
    this.codeHash = codeHash;
    this.expiresAt = expiresAt;
  }

  public String getCodeHash() { return codeHash; }
  public OffsetDateTime getExpiresAt() { return expiresAt; }
  public int getAttempts() { return attempts; }
  public void addAttempt() { attempts++; }
  public boolean isUsed() { return used; }
  public void markUsed() { used = true; }
}
