package com.challengea.api.friend;

import jakarta.persistence.*;

@Entity
@Table(name = "friendships")
public class Friendship {
  @Id
  @GeneratedValue(strategy = GenerationType.IDENTITY)
  private Long id;

  @Column(name = "requester_id", nullable = false)
  private long requesterId;

  @Column(name = "addressee_id", nullable = false)
  private long addresseeId;

  @Column(nullable = false)
  private String status = "pending";

  protected Friendship() {}

  public Friendship(long requesterId, long addresseeId) {
    this.requesterId = requesterId;
    this.addresseeId = addresseeId;
  }

  public long getRequesterId() { return requesterId; }
  public long getAddresseeId() { return addresseeId; }
  public String getStatus() { return status; }
  public void accept() { status = "accepted"; }
  public long other(long me) { return requesterId == me ? addresseeId : requesterId; }
}
