package com.challengea.api.game;

import jakarta.persistence.LockModeType;
import java.util.List;
import java.util.Optional;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Query;

interface GameRepository extends JpaRepository<Game, String> {}

interface MatchRepository extends JpaRepository<Match, Long> {
  /** SELECT ... FOR UPDATE: two moves on the same match are applied one after the other. */
  @Lock(LockModeType.PESSIMISTIC_WRITE)
  @Query("select m from Match m where m.id = :id")
  Optional<Match> lockById(long id);

  @Query("""
      select m from Match m
      where (m.challengerId = :me or m.opponentId = :me) and m.status in ('invited', 'active')
      order by m.id desc""")
  List<Match> open(long me);
}

interface MoveRepository extends JpaRepository<MatchMove, Long> {}
