package com.challengea.api.media;

import com.challengea.api.common.ApiException;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

interface MediaRepository extends JpaRepository<Media, String> {}

@Service
public class MediaService {
  public static final String URL_PREFIX = "/api/media/";
  private static final Pattern URL = Pattern.compile("^/api/media/([0-9a-f-]{36})$");
  private static final Map<String, Long> MAX_BYTES = Map.of("image", 10L * 1024 * 1024, "voice", 5L * 1024 * 1024);
  private static final Set<String> IMAGE_TYPES = Set.of("image/jpeg", "image/png", "image/webp", "image/gif", "image/heic");

  private final MediaRepository media;

  public MediaService(MediaRepository media) {
    this.media = media;
  }

  public record Uploaded(String id, String url, String kind, String contentType, long size) {}

  @Transactional
  public Uploaded upload(long me, String kind, String contentType, byte[] data) {
    var max = MAX_BYTES.get(kind);
    if (max == null) throw ApiException.badRequest("invalid_kind", "Upload an image or a voice note");
    if (data.length == 0) throw ApiException.badRequest("empty_file", "The file is empty");
    if (data.length > max) throw ApiException.badRequest("file_too_big", "Max " + max / (1024 * 1024) + " MB");
    var type = contentType == null ? "" : contentType.split(";")[0].trim().toLowerCase();
    var ok = kind.equals("image") ? IMAGE_TYPES.contains(type) : type.startsWith("audio/") || type.equals("video/webm");
    if (!ok) throw ApiException.badRequest("invalid_type", "This file type is not supported: " + type);
    if (type.equals("video/webm")) type = "audio/webm"; // some browsers label recorded audio as video/webm
    var m = media.save(new Media(UUID.randomUUID().toString(), me, kind, type, data));
    return new Uploaded(m.getId(), URL_PREFIX + m.getId(), kind, type, m.getSizeBytes());
  }

  @Transactional(readOnly = true)
  public Optional<Media> get(String id) {
    return media.findById(id);
  }

  /** Removes a file by its URL (the photo of an expired story). */
  @Transactional
  public void delete(String url) {
    var m = URL.matcher(url);
    if (m.matches()) media.deleteById(m.group(1));
  }

  /** A message, post or story may only point to a file its sender uploaded. */
  @Transactional(readOnly = true)
  public void requireOwned(long me, String url, String expectedKind) {
    var m = URL.matcher(url == null ? "" : url);
    if (!m.matches()) throw ApiException.badRequest("invalid_media", "Upload the file first");
    var file = media.findById(m.group(1)).orElseThrow(() -> ApiException.badRequest("invalid_media", "File not found"));
    if (file.getOwnerId() != me) throw ApiException.forbidden("This file is not yours");
    if (expectedKind != null && !file.getKind().equals(expectedKind)) {
      throw ApiException.badRequest("invalid_media", "Expected a " + expectedKind + " file");
    }
  }
}
