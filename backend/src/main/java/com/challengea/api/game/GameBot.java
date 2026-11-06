package com.challengea.api.game;

import com.challengea.api.common.ApiException;
import com.challengea.api.user.UserService;
import jakarta.annotation.PreDestroy;
import java.time.Duration;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * The demo cast plays back, so a game can be tested with one phone: challenge
 * one of them and they accept and play through the normal match rules. Only
 * accounts on the demo address play; real people are never touched.
 */
@Component
@ConditionalOnProperty(name = "app.bot.enabled", havingValue = "true")
public class GameBot {
  private static final Logger log = LoggerFactory.getLogger(GameBot.class);
  static final String BOT_EMAIL_SUFFIX = "@mock.challengea";
  private static final int BOT_PLAYER = 2; // bots only answer challenges
  private static final int HUMAN_PLAYER = 1;

  private final MatchRepository matches;
  private final MatchService service;
  private final UserService users;
  private final Duration delay;
  private final Set<Long> waiting = ConcurrentHashMap.newKeySet();
  private final java.util.concurrent.ScheduledExecutorService clock = Executors.newSingleThreadScheduledExecutor();

  public GameBot(MatchRepository matches, MatchService service, UserService users,
      @Value("${app.bot.delay:1500ms}") Duration delay) {
    this.matches = matches;
    this.service = service;
    this.users = users;
    this.delay = delay;
  }

  @PreDestroy
  void stop() {
    clock.shutdownNow();
  }

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
  void onMatchChanged(MatchService.MatchChanged event) {
    var m = matches.findById(event.matchId()).orElse(null);
    if (m == null || !isBot(m.getOpponentId())) return;
    var bot = m.getOpponentId();
    var botTurn = bot == (m.getCurrentTurnId() == null ? 0L : m.getCurrentTurnId());
    switch (m.getStatus()) {
      case "invited" -> later(m, delay, () -> service.accept(bot, m.getId()));
      case "active" -> {
        var rnd = ThreadLocalRandom.current();
        switch (m.getGameId()) {
          // A person's pace: long enough that you can win the race.
          case "sudoku" -> later(m, delay.multipliedBy(4).plusMillis(rnd.nextLong(delay.toMillis() * 4 + 1)),
              () -> playSudoku(m.getId(), bot));
          case "rumble" -> {
            // Off the line with everyone else, not before.
            var startsAt = ((Number) m.getState().get("startsAt")).longValue();
            var wait = Math.max(delay.toMillis() / 4, startsAt - System.currentTimeMillis());
            later(m, Duration.ofMillis(wait), () -> service.move(bot, m.getId(), Map.of("taps", rnd.nextInt(2, 4))));
          }
          case "purple" -> later(m, delay.multipliedBy(2).plusMillis(rnd.nextLong(delay.toMillis() * 2 + 1)),
              () -> playPurple(m.getId(), bot));
          default -> {
            if (botTurn) later(m, delay, () -> playFour(m.getId(), bot));
          }
        }
      }
      default -> { }
    }
  }

  private boolean isBot(long userId) {
    var email = users.get(userId).getEmail();
    return email != null && email.endsWith(BOT_EMAIL_SUFFIX);
  }

  /** At most one waiting action per match, whatever the other player does. */
  private void later(Match m, Duration pause, Runnable action) {
    if (!waiting.add(m.getId())) return;
    clock.schedule(() -> {
      waiting.remove(m.getId());
      try {
        action.run();
      } catch (ApiException e) {
        log.debug("Match {}: {}", m.getId(), e.getMessage()); // finished or cancelled meanwhile
      } catch (RuntimeException e) {
        log.warn("Match {}: the bot could not play", m.getId(), e);
      }
    }, pause.toMillis(), TimeUnit.MILLISECONDS);
  }

  private void playFour(long matchId, long bot) {
    var m = matches.findById(matchId).orElseThrow();
    var col = pickColumn(MatchService.toGrid(m.getState().get("cells")), new Random());
    service.move(bot, matchId, Map.of("col", col));
  }

  @SuppressWarnings("unchecked")
  private void playSudoku(long matchId, long bot) {
    var state = matches.findById(matchId).orElseThrow().getState();
    var players = (Map<String, Object>) state.get("players");
    var solved = (List<Object>) ((Map<String, Object>) players.get(Long.toString(bot))).get("cells");
    var givens = (List<Object>) state.get("givens");
    var solution = (List<Object>) state.get("solution");
    var open = new ArrayList<Integer>();
    for (var c = 0; c < givens.size(); c++) {
      var cell = c;
      var done = solved.stream().anyMatch(x -> MatchService.intOf(x, "cell") == cell);
      if (MatchService.intOf(givens.get(c), "givens") == 0 && !done) open.add(c);
    }
    if (open.isEmpty()) return;
    var cell = open.get(ThreadLocalRandom.current().nextInt(open.size()));
    service.move(bot, matchId, Map.of("cell", cell, "value", MatchService.intOf(solution.get(cell), "solution")));
  }

  /** A good person's reflexes: beatable, but not by much. */
  @SuppressWarnings("unchecked")
  private void playPurple(long matchId, long bot) {
    var players = (Map<String, Object>) matches.findById(matchId).orElseThrow().getState().get("players");
    var done = ((List<Object>) ((Map<String, Object>) players.get(Long.toString(bot))).get("times")).size();
    if (done >= MatchService.PURPLE_ROUNDS) return;
    service.move(bot, matchId, Map.of("round", done, "ms", ThreadLocalRandom.current().nextInt(235, 420)));
  }

  /** Win if it can, else block, else avoid giving a win. Not perfect on purpose, so you can beat it. */
  static int pickColumn(int[][] cells, Random rnd) {
    var options = new ArrayList<Integer>();
    for (var c = 0; c < FourInRow.COLS; c++) if (cells[0][c] == 0) options.add(c);
    for (var player : new int[] {BOT_PLAYER, HUMAN_PLAYER}) {
      for (var c : options) if (wins(cells, c, player)) return c;
    }
    var safe = new ArrayList<Integer>();
    for (var c : options) {
      var next = copy(cells);
      FourInRow.drop(next, c, BOT_PLAYER);
      var givesWin = false;
      for (var o = 0; o < FourInRow.COLS; o++) givesWin |= next[0][o] == 0 && wins(next, o, HUMAN_PLAYER);
      if (!givesWin) safe.add(c);
    }
    var pool = safe.isEmpty() ? options : safe;
    pool.sort(Comparator.comparingInt(c -> Math.abs(c - FourInRow.COLS / 2)));
    return rnd.nextInt(4) == 0 ? pool.get(rnd.nextInt(pool.size())) : pool.getFirst();
  }

  private static boolean wins(int[][] cells, int col, int player) {
    var next = copy(cells);
    FourInRow.drop(next, col, player);
    return FourInRow.winLine(next, player) != null;
  }

  private static int[][] copy(int[][] cells) {
    var out = new int[cells.length][];
    for (var r = 0; r < cells.length; r++) out[r] = cells[r].clone();
    return out;
  }
}
