package com.challengea.api.push;

import com.challengea.api.user.UserRepository;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import org.springframework.stereotype.Service;

/**
 * Turns live events into push notifications for people who don't have the
 * app open (no WebSocket). Sent in the background so requests stay fast.
 */
@Service
public class PushNotifier {
  private static final Set<String> PUSHED = Set.of("message.new", "match.invited", "call.incoming", "friend.request", "friend.accepted");

  private final Presence presence;
  private final DeviceService devices;
  private final PushSender sender;
  private final UserRepository users;
  private final Executor executor = Executors.newVirtualThreadPerTaskExecutor();

  public PushNotifier(Presence presence, DeviceService devices, PushSender sender, UserRepository users) {
    this.presence = presence;
    this.devices = devices;
    this.sender = sender;
    this.users = users;
  }

  /** Called for every live event; only a few kinds become notifications. */
  public void onEvent(long userId, String type, Object data) {
    if (!PUSHED.contains(type) || presence.isOnline(userId)) return;
    executor.execute(() -> deliver(userId, type, data));
  }

  void deliver(long userId, String type, Object data) {
    var n = format(userId, type, data);
    if (n == null) return;
    for (var token : devices.tokens(userId)) {
      if (!sender.send(token, n.title(), n.body(), n.data(), n.urgent())) devices.forget(token);
    }
  }

  record Note(String title, String body, Map<String, String> data, boolean urgent) {}

  @SuppressWarnings("unchecked")
  Note format(long userId, String type, Object data) {
    var json = data instanceof Map<?, ?> m ? (Map<String, Object>) m : toMap(data);
    var extra = new HashMap<String, String>();
    extra.put("type", type);
    switch (type) {
      case "message.new" -> {
        var senderId = json.get("senderId");
        if (senderId == null || senderId.equals(userId)) return null; // my own / system messages
        var name = name(senderId);
        extra.put("conversationId", String.valueOf(json.get("conversationId")));
        var body = switch (String.valueOf(json.get("type"))) {
          case "image" -> "📷 Photo";
          case "voice" -> "🎤 Voice note";
          case "sticker" -> String.valueOf(json.get("body"));
          default -> String.valueOf(json.get("body"));
        };
        return new Note(name, body, extra, false);
      }
      case "match.invited" -> {
        var from = (Map<String, Object>) json.get("challenger");
        extra.put("matchId", String.valueOf(json.get("id")));
        var game = "sudoku".equals(json.get("gameId")) ? "a Sudoku duel" : "Four in a row";
        return new Note("⚡ " + from.get("displayName") + " challenges you", "Play " + game + " now", extra, true);
      }
      case "call.incoming" -> {
        var from = (Map<String, Object>) json.get("startedBy");
        extra.put("callId", String.valueOf(json.get("id")));
        var video = Boolean.TRUE.equals(json.get("video"));
        return new Note((video ? "📹 " : "📞 ") + from.get("displayName") + " is calling", "Tap to answer", extra, true);
      }
      case "friend.request" -> {
        var from = (Map<String, Object>) json.get("from");
        return new Note("New friend request", from.get("displayName") + " wants to be your friend", extra, false);
      }
      case "friend.accepted" -> {
        var by = (Map<String, Object>) json.get("by");
        return new Note(by.get("displayName") + " accepted your request", "You can chat and play together now", extra, false);
      }
      default -> {
        return null;
      }
    }
  }

  private String name(Object userId) {
    var id = ((Number) userId).longValue();
    return users.findById(id).map(u -> u.getDisplayName()).orElse("Challengea");
  }

  /** Records (DTOs) to maps, via their accessors. */
  private static Map<String, Object> toMap(Object o) {
    var out = new HashMap<String, Object>();
    if (o == null || !o.getClass().isRecord()) return out;
    for (var c : o.getClass().getRecordComponents()) {
      try {
        var v = c.getAccessor().invoke(o);
        out.put(c.getName(), v != null && v.getClass().isRecord() ? toMap(v) : v);
      } catch (Exception ignored) {
        // skip unreadable fields
      }
    }
    return out;
  }
}
