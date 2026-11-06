package com.challengea.api.push;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;
import com.google.firebase.messaging.AndroidConfig;
import com.google.firebase.messaging.ApnsConfig;
import com.google.firebase.messaging.Aps;
import com.google.firebase.messaging.FirebaseMessaging;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;
import com.google.firebase.messaging.Notification;
import java.io.FileInputStream;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/** Sends one notification to one phone. Returns false if the token is dead. */
public interface PushSender {
  boolean send(String token, String title, String body, Map<String, String> data, boolean urgent);
}

@Configuration
class PushSenderConfig {
  private static final Logger log = LoggerFactory.getLogger(PushSenderConfig.class);

  /** Firebase when credentials are configured; otherwise notifications are only logged (dev). */
  @Bean
  PushSender pushSender(@Value("${app.push.firebase-credentials:}") String credentials) throws Exception {
    if (credentials == null || credentials.isBlank()) {
      log.info("Push notifications: no FIREBASE_CREDENTIALS, logging them instead");
      return (token, title, body, data, urgent) -> {
        log.info("[push] {} | {} | {}", title, body, data);
        return true;
      };
    }
    try (var in = new FileInputStream(credentials)) {
      var app = FirebaseApp.initializeApp(FirebaseOptions.builder().setCredentials(GoogleCredentials.fromStream(in)).build());
      var messaging = FirebaseMessaging.getInstance(app);
      log.info("Push notifications: Firebase ready");
      return (token, title, body, data, urgent) -> {
        var message = Message.builder()
            .setToken(token)
            .setNotification(Notification.builder().setTitle(title).setBody(body).build())
            .putAllData(data)
            .setAndroidConfig(AndroidConfig.builder()
                .setPriority(urgent ? AndroidConfig.Priority.HIGH : AndroidConfig.Priority.NORMAL).build())
            .setApnsConfig(ApnsConfig.builder().setAps(Aps.builder().setSound("default").build())
                .putHeader("apns-priority", urgent ? "10" : "5").build())
            .build();
        try {
          messaging.send(message);
          return true;
        } catch (FirebaseMessagingException e) {
          var code = e.getMessagingErrorCode();
          if (code == MessagingErrorCode.UNREGISTERED || code == MessagingErrorCode.INVALID_ARGUMENT) return false;
          log.warn("Push failed: {}", e.getMessage());
          return true;
        }
      };
    }
  }
}
