package com.challengea.api.user;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "users")
public class User {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  private String phone;
  private String email;

  @Column(name = "password_hash")
  private String passwordHash;

  @Column(name = "display_name", nullable = false)
  private String displayName;

  @Column(nullable = false)
  private String handle;

  private String bio;

  @Column(name = "avatar_url")
  private String avatarUrl;

  @Column(nullable = false)
  private String color = "#FF8A3D";

  @Column(name = "created_at", insertable = false, updatable = false)
  private OffsetDateTime createdAt;

  protected User() {}

  public User(String displayName, String handle) {
    this.displayName = displayName;
    this.handle = handle;
  }

  public Long getId() { return id; }
  public String getPhone() { return phone; }
  public void setPhone(String phone) { this.phone = phone; }
  public String getEmail() { return email; }
  public void setEmail(String email) { this.email = email; }
  public String getPasswordHash() { return passwordHash; }
  public void setPasswordHash(String passwordHash) { this.passwordHash = passwordHash; }
  public String getDisplayName() { return displayName; }
  public void setDisplayName(String displayName) { this.displayName = displayName; }
  public String getHandle() { return handle; }
  public void setHandle(String handle) { this.handle = handle; }
  public String getBio() { return bio; }
  public void setBio(String bio) { this.bio = bio; }
  public String getAvatarUrl() { return avatarUrl; }
  public String getColor() { return color; }
  public void setColor(String color) { this.color = color; }
}
