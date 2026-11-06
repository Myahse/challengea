package com.challengea.api.location;

import jakarta.persistence.*;
import java.math.BigDecimal;
import java.time.OffsetDateTime;

@Entity
@Table(name = "user_locations")
public class UserLocation {
  @Id
  @Column(name = "user_id")
  private Long userId;

  private BigDecimal lat;
  private BigDecimal lng;
  private String place;

  @Column(name = "status_text")
  private String statusText;

  private boolean ghost;

  @Column(name = "updated_at", nullable = false)
  private OffsetDateTime updatedAt = OffsetDateTime.now();

  protected UserLocation() {}

  public UserLocation(long userId) {
    this.userId = userId;
  }

  public Long getUserId() { return userId; }
  public double getLat() { return lat.doubleValue(); }
  public double getLng() { return lng.doubleValue(); }
  public String getPlace() { return place; }
  public String getStatusText() { return statusText; }
  public boolean isGhost() { return ghost; }
  public void setGhost(boolean ghost) { this.ghost = ghost; }
  public OffsetDateTime getUpdatedAt() { return updatedAt; }
  public boolean hasPosition() { return lat != null; }

  public void update(double lat, double lng, String place, String statusText) {
    // ~0.1 m precision is plenty and keeps NUMBER(9,6).
    this.lat = BigDecimal.valueOf(lat).setScale(6, java.math.RoundingMode.HALF_UP);
    this.lng = BigDecimal.valueOf(lng).setScale(6, java.math.RoundingMode.HALF_UP);
    if (place != null) this.place = place;
    if (statusText != null) this.statusText = statusText;
    this.updatedAt = OffsetDateTime.now();
  }
}
