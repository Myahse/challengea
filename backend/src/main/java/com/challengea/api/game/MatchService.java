package com.challengea.api.game;

import com.challengea.api.chat.ChatService;
import com.challengea.api.common.ApiException;
import com.challengea.api.friend.FriendService;
import com.challengea.api.realtime.Events;
import com.challengea.api.user.UserDto;
import com.challengea.api.user.UserService;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ThreadLocalRandom;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class MatchService {
  static final int MAX_MISTAKES = 3;

  private final GameRepository games;
  private final MatchRepository matches;
  private final MoveRepository moves;
  private final FriendService friends;
  private final UserService users;
  private final ChatService chat;
  private final Events events;
  private final ApplicationEventPublisher published;

  public MatchService(GameRepository games, MatchRepository matches, MoveRepository moves, FriendService friends,
      UserService users, ChatService chat, Events events, ApplicationEventPublisher published) {
    this.games = games;
    this.matches = matches;
    this.moves = moves;
    this.friends = friends;
    this.users = users;
    this.chat = chat;
    this.events = events;
    this.published = published;
  }

  /** Something happened in a match. */
  public record MatchChanged(long matchId) {}

  /** What a player sees. The Sudoku solution never leaves the server. */
  public record MatchDto(long id, String gameId, String status, UserDto challenger, UserDto opponent,
      Long currentTurnId, Long winnerId, Map<String, Object> state, OffsetDateTime createdAt) {}

  public List<Game> games() {
    return games.findAll();
  }

  @Transactional
  public MatchDto challenge(long me, String gameId, long opponentId) {
    var game = games.findById(gameId).orElseThrow(() -> ApiException.notFound("Game"));
    if (!game.isPlayable()) throw ApiException.badRequest("coming_soon", game.getName() + " is coming soon");
    if (me == opponentId) throw ApiException.badRequest("self", "You can't challenge yourself");
    if (!friends.areFriends(me, opponentId)) throw ApiException.forbidden("You can only challenge friends");
    var match = matches.save(new Match(gameId, me, opponentId));
    var dto = view(match, opponentId);
    var name = users.get(me).getDisplayName();
    chat.post(chat.directId(me, opponentId), me, "system", name + " challenged you to " + game.getName(),
        Map.of("kind", "challenge", "matchId", match.getId(), "gameId", gameId));
    events.send(opponentId, "match.invited", dto);
    published.publishEvent(new MatchChanged(match.getId()));
    return dto;
  }

  @Transactional
  public MatchDto accept(long me, long matchId) {
    var m = lock(me, matchId);
    if (m.getOpponentId() != me || !m.getStatus().equals("invited")) {
      throw ApiException.conflict("not_invited", "This challenge can't be accepted");
    }
    switch (m.getGameId()) {
      case "arcade" -> m.start(new HashMap<>(Map.of("cells", toList(FourInRow.empty()), "moves", 0)), m.getChallengerId());
      case "sudoku" -> {
        var puzzle = Sudoku.generate(ThreadLocalRandom.current().nextLong());
        var state = new HashMap<String, Object>();
        state.put("givens", toList(puzzle.givens()));
        state.put("solution", toList(puzzle.solution()));
        state.put("players", new HashMap<>(Map.of(
            key(m.getChallengerId()), progress(), key(m.getOpponentId()), progress())));
        m.start(state, null); // both play at the same time
      }
      default -> throw ApiException.badRequest("coming_soon", "This game is coming soon");
    }
    return broadcast(m, me);
  }

  @Transactional
  public MatchDto decline(long me, long matchId) {
    var m = lock(me, matchId);
    if (!m.getStatus().equals("invited")) throw ApiException.conflict("not_invited", "This challenge is no longer open");
    m.close(m.getChallengerId() == me ? "cancelled" : "declined");
    return broadcast(m, me);
  }

  /** Four in a row: {"col": 0..6}. Sudoku: {"cell": 0..80, "value": 1..9}. */
  @Transactional
  public MatchDto move(long me, long matchId, Map<String, Object> move) {
    var m = lock(me, matchId);
    if (!m.getStatus().equals("active")) throw ApiException.conflict("not_active", "This match is not being played");
    switch (m.getGameId()) {
      case "arcade" -> playFour(m, me, move);
      case "sudoku" -> playSudoku(m, me, move);
      default -> throw ApiException.badRequest("coming_soon", "This game is coming soon");
    }
    moves.save(new MatchMove(m.getId(), me, move));
    return broadcast(m, me);
  }

  @Transactional(readOnly = true)
  public MatchDto get(long me, long matchId) {
    var m = matches.findById(matchId).filter(x -> x.involves(me)).orElseThrow(() -> ApiException.notFound("Match"));
    return view(m, me);
  }

  @Transactional(readOnly = true)
  public List<MatchDto> open(long me) {
    return matches.open(me).stream().map(m -> view(m, me)).toList();
  }

  // ------------------------------------------------------------ Four in a row
  private void playFour(Match m, long me, Map<String, Object> move) {
    if (m.getCurrentTurnId() == null || m.getCurrentTurnId() != me) throw ApiException.conflict("not_your_turn", "Wait for your turn");
    var col = intOf(move.get("col"), "col");
    var cells = toGrid(m.getState().get("cells"));
    var player = me == m.getChallengerId() ? 1 : 2;
    if (FourInRow.drop(cells, col, player) < 0) throw ApiException.badRequest("invalid_move", "This column is full");
    var state = new HashMap<>(m.getState());
    state.put("cells", toList(cells));
    state.put("moves", intOf(state.get("moves"), "moves") + 1);
    state.put("lastCol", col);
    var line = FourInRow.winLine(cells, player);
    if (line != null) {
      state.put("winLine", line.stream().map(p -> List.of(p[0], p[1])).toList());
      m.setState(state);
      finish(m, me);
    } else if (FourInRow.full(cells)) {
      m.setState(state);
      finish(m, null);
    } else {
      m.setState(state);
      m.setCurrentTurnId(m.other(me));
    }
  }

  // ------------------------------------------------------------------ Sudoku
  @SuppressWarnings("unchecked")
  private void playSudoku(Match m, long me, Map<String, Object> move) {
    var cell = intOf(move.get("cell"), "cell");
    var value = intOf(move.get("value"), "value");
    if (cell < 0 || cell > 80 || value < 1 || value > 9) throw ApiException.badRequest("invalid_move", "Invalid cell or value");
    var state = new HashMap<>(m.getState());
    var givens = (List<Object>) state.get("givens");
    var solution = (List<Object>) state.get("solution");
    if (intOf(givens.get(cell), "givens") != 0) throw ApiException.badRequest("invalid_move", "This cell is already given");
    var players = new HashMap<>((Map<String, Object>) state.get("players"));
    var mine = new HashMap<>((Map<String, Object>) players.get(key(me)));
    var cells = new ArrayList<Object>((List<Object>) mine.get("cells"));
    if (cells.stream().anyMatch(c -> intOf(c, "cell") == cell)) throw ApiException.badRequest("invalid_move", "Already solved");
    var correct = intOf(solution.get(cell), "solution") == value;
    if (correct) {
      cells.add(cell);
    } else {
      mine.put("mistakes", intOf(mine.get("mistakes"), "mistakes") + 1);
    }
    mine.put("cells", cells);
    players.put(key(me), mine);
    state.put("players", players);
    m.setState(state);
    if (cells.size() == Sudoku.BLANKS) {
      finish(m, me);
    } else if (intOf(mine.get("mistakes"), "mistakes") >= MAX_MISTAKES) {
      finish(m, m.other(me));
    }
  }

  // ----------------------------------------------------------------- helpers
  private void finish(Match m, Long winnerId) {
    m.finish(winnerId);
    var game = games.findById(m.getGameId()).orElseThrow();
    var a = users.get(m.getChallengerId()).getDisplayName();
    var b = users.get(m.getOpponentId()).getDisplayName();
    String text;
    if (winnerId == null) {
      text = game.getName() + ": draw between " + a + " and " + b;
    } else {
      var winner = winnerId == m.getChallengerId() ? a : b;
      var loser = winnerId == m.getChallengerId() ? b : a;
      text = winner + " beat " + loser + " at " + game.getName();
    }
    var meta = new LinkedHashMap<String, Object>();
    meta.put("matchId", m.getId());
    meta.put("gameId", m.getGameId());
    if (winnerId != null) meta.put("winnerId", winnerId);
    chat.post(chat.directId(m.getChallengerId(), m.getOpponentId()), null, "game_result", text, meta);
  }

  /** Sends each player their own view and returns the caller's. */
  private MatchDto broadcast(Match m, long me) {
    events.send(m.getChallengerId(), "match.updated", view(m, m.getChallengerId()));
    events.send(m.getOpponentId(), "match.updated", view(m, m.getOpponentId()));
    published.publishEvent(new MatchChanged(m.getId()));
    return view(m, me);
  }

  @SuppressWarnings("unchecked")
  private MatchDto view(Match m, long viewer) {
    Map<String, Object> state = null;
    if (m.getState() != null) {
      state = new HashMap<>(m.getState());
      if (m.getGameId().equals("sudoku")) {
        state.remove("solution");
        // Show how far each player is, but only your own cells.
        var players = (Map<String, Object>) state.get("players");
        var summary = new HashMap<String, Object>();
        players.forEach((id, p) -> {
          var progress = (Map<String, Object>) p;
          var info = new HashMap<String, Object>();
          info.put("filled", ((List<Object>) progress.get("cells")).size());
          info.put("mistakes", progress.get("mistakes"));
          if (id.equals(key(viewer))) info.put("cells", progress.get("cells"));
          summary.put(id, info);
        });
        state.put("players", summary);
        state.put("toFill", Sudoku.BLANKS);
      }
    }
    return new MatchDto(m.getId(), m.getGameId(), m.getStatus(), UserDto.of(users.get(m.getChallengerId())),
        UserDto.of(users.get(m.getOpponentId())), m.getCurrentTurnId(), m.getWinnerId(), state, m.getCreatedAt());
  }

  private Match lock(long me, long matchId) {
    return matches.lockById(matchId).filter(x -> x.involves(me)).orElseThrow(() -> ApiException.notFound("Match"));
  }

  private static Map<String, Object> progress() {
    return new HashMap<>(Map.of("cells", List.of(), "mistakes", 0));
  }

  private static String key(long userId) {
    return Long.toString(userId);
  }

  static int intOf(Object o, String field) {
    if (o instanceof Number n) return n.intValue();
    if (o instanceof String s && s.matches("-?\\d+")) return Integer.parseInt(s);
    throw ApiException.badRequest("invalid_move", "Missing or invalid " + field);
  }

  private static List<List<Integer>> toList(int[][] grid) {
    var out = new ArrayList<List<Integer>>();
    for (var row : grid) {
      var r = new ArrayList<Integer>();
      for (var v : row) r.add(v);
      out.add(r);
    }
    return out;
  }

  private static List<Integer> toList(int[] arr) {
    var out = new ArrayList<Integer>();
    for (var v : arr) out.add(v);
    return out;
  }

  @SuppressWarnings("unchecked")
  static int[][] toGrid(Object o) {
    var rows = (List<Object>) o;
    var grid = new int[FourInRow.ROWS][FourInRow.COLS];
    for (var r = 0; r < FourInRow.ROWS; r++) {
      var row = (List<Object>) rows.get(r);
      for (var c = 0; c < FourInRow.COLS; c++) grid[r][c] = intOf(row.get(c), "cells");
    }
    return grid;
  }
}
