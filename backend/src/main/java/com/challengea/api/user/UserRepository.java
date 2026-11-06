package com.challengea.api.user;

import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

public interface UserRepository extends JpaRepository<User, Long> {
  Optional<User> findByPhone(String phone);

  Optional<User> findByEmailIgnoreCase(String email);

  boolean existsByHandleIgnoreCase(String handle);

  @Query("""
      select u from User u
      where lower(u.handle) like lower(concat(:q, '%')) or lower(u.displayName) like lower(concat('%', :q, '%'))
      order by u.displayName""")
  List<User> search(String q, Pageable page);
}
