package com.challengea.api.realtime;

import java.util.Collection;
import java.util.Map;
import com.challengea.api.push.PushNotifier;
import org.springframework.context.annotation.Lazy;
import org.springframework.messaging.simp.SimpMessagingTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/** Pushes events to users' phones. Sent after the transaction commits. */
@Service
public class Events {
  private final SimpMessagingTemplate broker;
  private final PushNotifier notifier;

  public Events(SimpMessagingTemplate broker, @Lazy PushNotifier notifier) {
    this.broker = broker;
    this.notifier = notifier;
  }

  /** Live event over WebSocket; also a push notification if the person doesn't have the app open. */
  public void send(long userId, String type, Object data) {
    Runnable push = () -> {
      broker.convertAndSendToUser(Long.toString(userId), "/queue/events", Map.of("type", type, "data", data));
      notifier.onEvent(userId, type, data);
    };
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
      TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
        @Override
        public void afterCommit() {
          push.run();
        }
      });
    } else {
      push.run();
    }
  }

  public void send(Collection<Long> userIds, String type, Object data) {
    for (var id : userIds) send(id, type, data);
  }
}
