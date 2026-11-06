package com.challengea.api.media;

import com.challengea.api.common.ApiException;
import com.challengea.api.common.CurrentUser;
import java.io.IOException;
import java.time.Duration;
import org.springframework.http.CacheControl;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/media")
public class MediaController {
  private final MediaService media;

  public MediaController(MediaService media) {
    this.media = media;
  }

  /** multipart/form-data: file + kind ("image" or "voice"). Returns the URL to put in a message. */
  @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  MediaService.Uploaded upload(@RequestParam MultipartFile file, @RequestParam String kind) throws IOException {
    return media.upload(CurrentUser.id(), kind, file.getContentType(), file.getBytes());
  }

  /**
   * The file itself. The id is a random UUID that only chat members receive,
   * so the URL works in image and audio players without an auth header.
   */
  @GetMapping("/{id}")
  ResponseEntity<byte[]> get(@PathVariable String id) {
    var m = media.get(id).orElseThrow(() -> ApiException.notFound("File"));
    return ResponseEntity.ok()
        .contentType(MediaType.parseMediaType(m.getContentType()))
        .cacheControl(CacheControl.maxAge(Duration.ofDays(365)).cachePrivate().immutable())
        .body(m.getData());
  }
}
