package com.challengea.api.user;

/** Public view of a user (never includes phone, email or password). */
public record UserDto(long id, String displayName, String handle, String bio, String avatarUrl, String color) {
  public static UserDto of(User u) {
    return new UserDto(u.getId(), u.getDisplayName(), u.getHandle(), u.getBio(), u.getAvatarUrl(), u.getColor());
  }
}
