package com.challengea.api.auth;

import java.time.OffsetDateTime;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;

public interface OtpRepository extends JpaRepository<OtpCode, Long> {
  Optional<OtpCode> findFirstByPhoneOrderByIdDesc(String phone);

  long countByPhoneAndExpiresAtAfter(String phone, OffsetDateTime after);
}
