package com.challengea.api.push;

import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.messaging.SessionConnectedEvent;
import org.springframework.web.socket.messaging.SessionDisconnectEvent;

/** Who has the app open right now (a live WebSocket). They get no push: the app shows events itself. */
@Component
public class Presence {
  private final Map<String, String> sessionUser = new ConcurrentHashMap<>();
  private final Map<String, AtomicInteger> openSessions = new ConcurrentHashMap<>();

  @EventListener
  void connected(SessionConnectedEvent e) {
    var user = e.getUser();
    var session = (String) e.getMessage().getHeaders().get("simpSessionId");
    if (user == null || session == null) return;
    sessionUser.put(session, user.getName());
    openSessions.computeIfAbsent(user.getName(), k -> new AtomicInteger()).incrementAndGet();
  }

  @EventListener
  void disconnected(SessionDisconnectEvent e) {
    var user = sessionUser.remove(e.getSessionId());
    if (user == null) return;
    var count = openSessions.get(user);
    if (count != null && count.decrementAndGet() <= 0) openSessions.remove(user);
  }

  public boolean isOnline(long userId) {
    var count = openSessions.get(Long.toString(userId));
    return count != null && count.get() > 0;
  }
}
