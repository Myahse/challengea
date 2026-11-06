package com.challengea.api.social;

import com.challengea.api.common.ApiException;
import java.util.regex.Pattern;

/** Input checks shared by posts and stories. */
final class SocialText {
  private static final Pattern BACKGROUND = Pattern.compile("^#[0-9A-Fa-f]{6}(,#[0-9A-Fa-f]{6}){1,7}$");

  private SocialText() {}

  static String clean(String s) {
    return s == null || s.isBlank() ? null : s.strip();
  }

  /** A gradient: at least 2 colours, each #RRGGBB, separated by commas. */
  static String background(String s) {
    if (s == null || s.isBlank()) return null;
    if (!BACKGROUND.matcher(s).matches()) throw ApiException.badRequest("invalid_background", "Invalid background");
    return s;
  }
}
