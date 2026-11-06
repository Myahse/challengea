package com.challengea.api.friend;

import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface FriendshipRepository extends JpaRepository<Friendship, Long> {
  @Query("""
      select f from Friendship f
      where (f.requesterId = :a and f.addresseeId = :b) or (f.requesterId = :b and f.addresseeId = :a)""")
  Optional<Friendship> between(long a, long b);

  @Query("select f from Friendship f where (f.requesterId = :me or f.addresseeId = :me) and f.status = :status")
  List<Friendship> ofUser(long me, String status);

  List<Friendship> findByAddresseeIdAndStatus(long addresseeId, String status);
}
