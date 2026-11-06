package com.challengea.api.call;

import com.challengea.api.common.ApiException;
import com.challengea.api.user.UserService;
import jakarta.annotation.PreDestroy;
import java.time.Duration;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * The demo cast picks up, so a call can be tested with one phone. They never
 * join the media room, so there is no sound from them: the ringing, answering,
 * hanging up and the call log are real, the voice is not.
 */
@Component
@ConditionalOnProperty(name = "app.bot.enabled", havingValue = "true")
public class CallBot {
  private static final Logger log = LoggerFactory.getLogger(CallBot.class);
  private static final String BOT_EMAIL_SUFFIX = "@mock.challengea";

  private final CallService calls;
  private final UserService users;
  private final Duration ring;
  private final Set<String> answering = ConcurrentHashMap.newKeySet();
  private final ScheduledExecutorService clock = Executors.newSingleThreadScheduledExecutor();

  public CallBot(CallService calls, UserService users, @Value("${app.bot.ring:3s}") Duration ring) {
    this.calls = calls;
    this.users = users;
    this.ring = ring;
  }

  @PreDestroy
  void stop() {
    clock.shutdownNow();
  }

  @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT, fallbackExecution = true)
  void onCallChanged(CallService.CallChanged event) {
    var callId = event.callId();
    var call = calls.snapshot(callId);
    if (call.over()) return;
    for (var id : call.invited()) {
      if (isBot(id) && !call.present().contains(id) && answering.add(callId + ":" + id)) {
        clock.schedule(() -> run(() -> calls.accept(id, callId)), ring.toMillis(), TimeUnit.MILLISECONDS);
      }
    }
    // Everyone real has gone: hang up too, so the call ends and gets logged.
    if (!call.present().isEmpty() && call.present().stream().allMatch(this::isBot)) {
      clock.execute(() -> run(() -> call.present().forEach(id -> calls.leave(id, callId))));
    }
  }

  private boolean isBot(long userId) {
    var email = users.get(userId).getEmail();
    return email != null && email.endsWith(BOT_EMAIL_SUFFIX);
  }

  private void run(Runnable action) {
    try {
      action.run();
    } catch (ApiException e) {
      log.debug("Call: {}", e.getMessage()); // it ended meanwhile
    } catch (RuntimeException e) {
      log.warn("The call bot failed", e);
    }
  }
}
