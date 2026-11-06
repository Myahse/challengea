package com.challengea.api.realtime;

import com.challengea.api.security.JwtService;
import java.security.Principal;
import org.springframework.context.annotation.Configuration;
import org.springframework.messaging.Message;
import org.springframework.messaging.MessageChannel;
import org.springframework.messaging.simp.config.ChannelRegistration;
import org.springframework.messaging.simp.config.MessageBrokerRegistry;
import org.springframework.messaging.simp.stomp.StompCommand;
import org.springframework.messaging.simp.stomp.StompHeaderAccessor;
import org.springframework.messaging.support.ChannelInterceptor;
import org.springframework.messaging.support.MessageHeaderAccessor;
import org.springframework.web.socket.config.annotation.EnableWebSocketMessageBroker;
import org.springframework.web.socket.config.annotation.StompEndpointRegistry;
import org.springframework.web.socket.config.annotation.WebSocketMessageBrokerConfigurer;

/**
 * Real-time channel. The app connects to ws://host/ws with STOMP, sends
 * "Authorization: Bearer <token>" in the CONNECT frame and subscribes to
 * "/user/queue/events". Every event is {"type": "...", "data": {...}}.
 */
@Configuration
@EnableWebSocketMessageBroker
public class WebSocketConfig implements WebSocketMessageBrokerConfigurer {
  private final JwtService jwt;

  public WebSocketConfig(JwtService jwt) {
    this.jwt = jwt;
  }

  @Override
  public void registerStompEndpoints(StompEndpointRegistry registry) {
    registry.addEndpoint("/ws").setAllowedOriginPatterns("*");
  }

  @Override
  public void configureMessageBroker(MessageBrokerRegistry registry) {
    registry.enableSimpleBroker("/queue");
    registry.setUserDestinationPrefix("/user");
  }

  @Override
  public void configureClientInboundChannel(ChannelRegistration registration) {
    registration.interceptors(new ChannelInterceptor() {
      @Override
      public Message<?> preSend(Message<?> message, MessageChannel channel) {
        var accessor = MessageHeaderAccessor.getAccessor(message, StompHeaderAccessor.class);
        if (accessor != null && StompCommand.CONNECT.equals(accessor.getCommand())) {
          var header = accessor.getFirstNativeHeader("Authorization");
          var userId = header != null && header.startsWith("Bearer ") ? jwt.verify(header.substring(7)) : java.util.Optional.<Long>empty();
          if (userId.isEmpty()) throw new IllegalArgumentException("Invalid or missing token");
          var name = Long.toString(userId.get());
          accessor.setUser((Principal) () -> name);
        }
        return message;
      }
    });
  }
}
