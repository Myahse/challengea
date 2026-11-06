package com.challengea.api.media;

import jakarta.persistence.*;
import java.time.OffsetDateTime;

@Entity
@Table(name = "media")
public class Media {
  @Id
  private String id;

  @Column(name = "owner_id", nullable = false)
  private long ownerId;

  @Column(nullable = false)
  private String kind;

  @Column(name = "content_type", nullable = false)
  private String contentType;

  @Column(name = "size_bytes", nullable = false)
  private long sizeBytes;

  @Lob
  @Column(nullable = false)
  private byte[] data;

  @Column(name = "created_at", nullable = false)
  private OffsetDateTime createdAt = OffsetDateTime.now();

  protected Media() {}

  public Media(String id, long ownerId, String kind, String contentType, byte[] data) {
    this.id = id;
    this.ownerId = ownerId;
    this.kind = kind;
    this.contentType = contentType;
    this.data = data;
    this.sizeBytes = data.length;
  }

  public String getId() { return id; }
  public long getOwnerId() { return ownerId; }
  public String getKind() { return kind; }
  public String getContentType() { return contentType; }
  public long getSizeBytes() { return sizeBytes; }
  public byte[] getData() { return data; }
}
