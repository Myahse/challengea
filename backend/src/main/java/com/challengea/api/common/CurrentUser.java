package com.challengea.api.common;

import org.springframework.http.HttpStatus;
import org.springframework.security.core.context.SecurityContextHolder;

/** The signed-in user's id, set by the JWT filter. */
public final class CurrentUser {
  private CurrentUser() {}

  public static long id() {
    var auth = SecurityContextHolder.getContext().getAuthentication();
    if (auth == null || !(auth.getPrincipal() instanceof Long id)) {
      throw new ApiException(HttpStatus.UNAUTHORIZED, "unauthorized", "Sign in first");
    }
    return id;
  }
}
