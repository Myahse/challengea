package com.challengea.api.user;

import com.challengea.api.common.ApiException;
import java.text.Normalizer;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.ThreadLocalRandom;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class UserService {
  private static final String[] COLORS = {"#FF8A3D", "#B07A4F", "#F06BA8", "#8B6CF6", "#4FB3F6", "#5CC98A", "#E5A93B", "#2F5D50"};
  private final UserRepository users;

  public UserService(UserRepository users) {
    this.users = users;
  }

  public User get(long id) {
    return users.findById(id).orElseThrow(() -> ApiException.notFound("User"));
  }

  /** Creates a user with a unique @handle derived from the name. Needs a phone or an email. */
  @Transactional
  public User create(String displayName, String phone, String email, String passwordHash) {
    var user = new User(displayName.trim(), uniqueHandle(displayName));
    user.setPhone(phone);
    user.setEmail(email);
    user.setPasswordHash(passwordHash);
    user.setColor(COLORS[ThreadLocalRandom.current().nextInt(COLORS.length)]);
    return users.save(user);
  }

  String uniqueHandle(String name) {
    var base = Normalizer.normalize(name, Normalizer.Form.NFD)
        .replaceAll("\\p{M}", "")
        .toLowerCase(Locale.ROOT)
        .replaceAll("[^a-z0-9_]", "");
    if (base.length() < 3) base = "user" + base;
    if (base.length() > 20) base = base.substring(0, 20);
    var handle = base;
    while (users.existsByHandleIgnoreCase(handle)) {
      handle = base + ThreadLocalRandom.current().nextInt(10, 10000);
    }
    return handle;
  }

  @Transactional
  public User update(long id, String displayName, String handle, String bio) {
    var u = get(id);
    if (displayName != null && !displayName.isBlank()) u.setDisplayName(displayName.trim());
    if (bio != null) u.setBio(bio.isBlank() ? null : bio.trim());
    if (handle != null && !handle.equalsIgnoreCase(u.getHandle())) {
      if (!handle.matches("[A-Za-z0-9_.]{3,30}")) {
        throw ApiException.badRequest("invalid_handle", "Use 3 to 30 letters, numbers, _ or .");
      }
      if (users.existsByHandleIgnoreCase(handle)) throw ApiException.conflict("handle_taken", "@" + handle + " is taken");
      u.setHandle(handle);
    }
    return u;
  }

  public List<User> search(String q) {
    if (q == null || q.isBlank()) return List.of();
    return users.search(q.trim(), PageRequest.of(0, 20));
  }
}
