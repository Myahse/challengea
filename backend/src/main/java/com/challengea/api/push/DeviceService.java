package com.challengea.api.push;

import com.challengea.api.common.ApiException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.util.HexFormat;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

interface DeviceRepository extends JpaRepository<Device, Long> {
  Optional<Device> findByTokenHash(String tokenHash);

  List<Device> findByUserId(long userId);
}

@Service
public class DeviceService {
  private static final Set<String> PLATFORMS = Set.of("android", "ios", "web");
  private final DeviceRepository devices;

  public DeviceService(DeviceRepository devices) {
    this.devices = devices;
  }

  /** Registers this phone for me (a token moves to the last account that signed in on it). */
  @Transactional
  public void register(long me, String token, String platform) {
    if (token == null || token.isBlank() || token.length() > 4000) throw ApiException.badRequest("invalid_token", "Invalid token");
    if (!PLATFORMS.contains(platform)) throw ApiException.badRequest("invalid_platform", "android, ios or web");
    var hash = hash(token);
    devices.findByTokenHash(hash).ifPresentOrElse(
        d -> d.reassign(me, platform),
        () -> devices.save(new Device(me, token, hash, platform)));
  }

  @Transactional
  public void unregister(long me, String token) {
    devices.findByTokenHash(hash(token)).filter(d -> d.getUserId() == me).ifPresent(devices::delete);
  }

  @Transactional(readOnly = true)
  public List<String> tokens(long userId) {
    return devices.findByUserId(userId).stream().map(Device::getToken).toList();
  }

  /** Firebase said the token is no longer valid (app uninstalled...). */
  @Transactional
  public void forget(String token) {
    devices.findByTokenHash(hash(token)).ifPresent(devices::delete);
  }

  static String hash(String token) {
    try {
      return HexFormat.of().formatHex(MessageDigest.getInstance("SHA-256").digest(token.getBytes(StandardCharsets.UTF_8)));
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }
}
