package com.challengea.api;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import java.lang.reflect.Type;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.BlockingQueue;
import java.util.concurrent.LinkedBlockingQueue;
import java.util.concurrent.TimeUnit;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.web.server.LocalServerPort;
import org.springframework.context.annotation.Import;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.messaging.converter.JacksonJsonMessageConverter;
import org.springframework.messaging.simp.stomp.StompFrameHandler;
import org.springframework.messaging.simp.stomp.StompHeaders;
import org.springframework.messaging.simp.stomp.StompSessionHandlerAdapter;
import org.springframework.web.client.HttpClientErrorException;
import org.springframework.web.client.RestClient;
import org.springframework.web.socket.WebSocketHttpHeaders;
import org.springframework.web.socket.client.standard.StandardWebSocketClient;
import org.springframework.web.socket.messaging.WebSocketStompClient;

/** End-to-end: HTTP + WebSocket against a real Oracle 23ai. */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Import(TestDatabase.class)
@SuppressWarnings("unchecked")
class ApiIntegrationTest {
  @LocalServerPort
  int port;

  RestClient http;

  @BeforeEach
  void setUp() {
    http = RestClient.builder().baseUrl("http://localhost:" + port + "/api").build();
  }

  record Account(long id, String token) {}

  Map<String, Object> post(String path, Object body, String token) {
    var req = http.post().uri(path);
    if (token != null) req = req.header("Authorization", "Bearer " + token);
    if (body != null) req = req.body(body);
    return req.retrieve().body(new ParameterizedTypeReference<Map<String, Object>>() {});
  }

  <T> T get(String path, String token, ParameterizedTypeReference<T> type) {
    return http.get().uri(path).header("Authorization", "Bearer " + token).retrieve().body(type);
  }

  /** Signs up by email with a unique address. */
  Account signUp(String name) {
    var res = post("/auth/register", Map.of("email", UUID.randomUUID() + "@test.ci", "password", "secret123",
        "displayName", name), null);
    var user = (Map<String, Object>) res.get("user");
    return new Account(((Number) user.get("id")).longValue(), (String) res.get("token"));
  }

  void befriend(Account a, Account b) {
    post("/friends/" + b.id(), null, a.token());
    post("/friends/" + a.id() + "/accept", null, b.token());
  }

  @Test
  void phoneSignInWithSmsCode() {
    var phone = "07" + String.format("%08d", (int) (Math.random() * 1e8));
    var code = (String) post("/auth/otp/request", Map.of("phone", phone), null).get("devCode");
    var wrong = code.equals("000000") ? "111111" : "000000";
    assertThatThrownBy(() -> post("/auth/otp/verify", Map.of("phone", phone, "code", wrong), null))
        .isInstanceOf(HttpClientErrorException.BadRequest.class);
    // New number without a name: asks for it, and the code still works afterwards.
    assertThatThrownBy(() -> post("/auth/otp/verify", Map.of("phone", phone, "code", code), null))
        .hasMessageContaining("name_required");
    var session = post("/auth/otp/verify", Map.of("phone", phone, "code", code, "displayName", "Awa Traoré"), null);
    assertThat(session.get("isNew")).isEqualTo(true);
    assertThat(((Map<String, Object>) session.get("user")).get("handle").toString()).startsWith("awatraore");

    // Signing in again with the same number finds the same account.
    // Same number in international format (Ivorian numbers keep their leading 0).
    var again = (String) post("/auth/otp/request", Map.of("phone", "+225" + phone), null).get("devCode");
    var second = post("/auth/otp/verify", Map.of("phone", phone, "code", again), null);
    assertThat(second.get("isNew")).isEqualTo(false);
  }

  @Test
  void guessingCodesIsLimitedTo5Tries() {
    var phone = "05" + String.format("%08d", (int) (Math.random() * 1e8));
    var code = (String) post("/auth/otp/request", Map.of("phone", phone), null).get("devCode");
    var wrong = code.equals("000000") ? "111111" : "000000";
    for (var i = 0; i < 5; i++) {
      assertThatThrownBy(() -> post("/auth/otp/verify", Map.of("phone", phone, "code", wrong), null)).hasMessageContaining("wrong_code");
    }
    // Even the right code is refused after 5 wrong tries.
    assertThatThrownBy(() -> post("/auth/otp/verify", Map.of("phone", phone, "code", code, "displayName", "X"), null))
        .hasMessageContaining("too_many_attempts");
  }

  @Test
  void friendGetsMessagesInRealTime() throws Exception {
    var moise = signUp("Moise");
    var marc = signUp("Marc");
    befriend(moise, marc);

    // Marc connects to the WebSocket with his token and listens to his events.
    var events = new LinkedBlockingQueue<Map<String, Object>>();
    var stomp = new WebSocketStompClient(new StandardWebSocketClient());
    stomp.setMessageConverter(new JacksonJsonMessageConverter());
    var connect = new StompHeaders();
    connect.add("Authorization", "Bearer " + marc.token());
    var session = stomp.connectAsync("ws://localhost:" + port + "/ws", new WebSocketHttpHeaders(), connect,
        new StompSessionHandlerAdapter() {}).get(10, TimeUnit.SECONDS);
    session.subscribe("/user/queue/events", new StompFrameHandler() {
      @Override
      public Type getPayloadType(StompHeaders headers) { return Map.class; }

      @Override
      public void handleFrame(StompHeaders headers, Object payload) { events.add((Map<String, Object>) payload); }
    });
    Thread.sleep(300); // let the subscription register

    var chat = post("/conversations/direct/" + marc.id(), null, moise.token());
    post("/conversations/" + chat.get("id") + "/messages", Map.of("type", "text", "body", "Salut Marc !"), moise.token());

    var event = next(events, "message.new");
    assertThat(((Map<String, Object>) event.get("data")).get("body")).isEqualTo("Salut Marc !");
    session.disconnect();
  }

  @Test
  void groupsAreMadeOfFriendsAndOnlyTheOwnerRemovesPeople() {
    var owner = signUp("Owner");
    var a = signUp("A");
    var b = signUp("B");
    var stranger = signUp("Stranger");
    befriend(owner, a);
    befriend(owner, b);

    assertThatThrownBy(() -> post("/conversations/groups", Map.of("memberIds", List.of(a.id(), stranger.id())), owner.token()))
        .isInstanceOf(HttpClientErrorException.Forbidden.class);
    var group = post("/conversations/groups", Map.of("memberIds", List.of(a.id(), b.id())), owner.token());
    assertThat((List<?>) group.get("members")).hasSize(3);

    var id = group.get("id");
    assertThatThrownBy(() -> http.delete().uri("/conversations/" + id + "/members/" + b.id())
        .header("Authorization", "Bearer " + a.token()).retrieve().toBodilessEntity())
        .isInstanceOf(HttpClientErrorException.Forbidden.class);
  }

  @Test
  void fourInARowIsCheckedByTheServerAndTheResultIsPostedInTheChat() {
    var me = signUp("Me");
    var friend = signUp("Friend");
    befriend(me, friend);
    var match = post("/matches", Map.of("gameId", "arcade", "opponentId", friend.id()), me.token());
    var id = match.get("id");
    post("/matches/" + id + "/accept", null, friend.token());

    assertThatThrownBy(() -> post("/matches/" + id + "/moves", Map.of("col", 0), friend.token()))
        .isInstanceOf(HttpClientErrorException.Conflict.class); // not their turn
    Map<String, Object> state = null;
    for (var i = 0; i < 4; i++) {
      state = post("/matches/" + id + "/moves", Map.of("col", i), me.token());
      if (i < 3) post("/matches/" + id + "/moves", Map.of("col", i), friend.token());
    }
    assertThat(state.get("status")).isEqualTo("finished");
    assertThat(((Number) state.get("winnerId")).longValue()).isEqualTo(me.id());

    var chat = post("/conversations/direct/" + friend.id(), null, me.token());
    var last = get("/conversations/" + chat.get("id") + "/messages?limit=1", me.token(),
        new ParameterizedTypeReference<List<Map<String, Object>>>() {}).getFirst();
    assertThat(last.get("type")).isEqualTo("game_result");
    assertThat(last.get("body").toString()).isEqualTo("Me beat Friend at Four in a row");
  }

  @Test
  void photosAndVoiceNotesAreUploadedThenSentAndOnlyTheOwnerCanUseThem() {
    var me = signUp("Me");
    var friend = signUp("Friend");
    befriend(me, friend);
    var chat = post("/conversations/direct/" + friend.id(), null, me.token());

    var png = new byte[] {(byte) 0x89, 'P', 'N', 'G', 13, 10, 26, 10, 0, 0, 0, 0};
    var headers = new org.springframework.http.HttpHeaders();
    headers.setContentType(org.springframework.http.MediaType.IMAGE_PNG);
    var parts = new org.springframework.util.LinkedMultiValueMap<String, Object>();
    parts.add("kind", "image");
    parts.add("file", new org.springframework.http.HttpEntity<>(new org.springframework.core.io.ByteArrayResource(png) {
      @Override
      public String getFilename() { return "photo.png"; }
    }, headers));
    var uploaded = http.post().uri("/media").header("Authorization", "Bearer " + me.token())
        .contentType(org.springframework.http.MediaType.MULTIPART_FORM_DATA).body(parts)
        .retrieve().body(new ParameterizedTypeReference<Map<String, Object>>() {});
    var url = (String) uploaded.get("url");
    assertThat(url).startsWith("/api/media/");

    // The file is served (no token needed: the URL itself is the secret).
    var bytes = RestClient.create("http://localhost:" + port).get().uri(url).retrieve().body(byte[].class);
    assertThat(bytes).isEqualTo(png);

    var msg = post("/conversations/" + chat.get("id") + "/messages", Map.of("type", "image", "mediaUrl", url), me.token());
    assertThat(msg.get("mediaUrl")).isEqualTo(url);

    // Someone else can't send my file, and a voice note must point to a voice file.
    assertThatThrownBy(() -> post("/conversations/" + chat.get("id") + "/messages", Map.of("type", "image", "mediaUrl", url), friend.token()))
        .isInstanceOf(HttpClientErrorException.Forbidden.class);
    assertThatThrownBy(() -> post("/conversations/" + chat.get("id") + "/messages", Map.of("type", "voice", "mediaUrl", url), me.token()))
        .hasMessageContaining("invalid_media");
    // Stickers need no file.
    var sticker = post("/conversations/" + chat.get("id") + "/messages", Map.of("type", "sticker", "body", "🔥"), me.token());
    assertThat(sticker.get("body")).isEqualTo("🔥");
  }

  @Test
  void callsRingAnswerAndLeaveAMessage() throws Exception {
    var me = signUp("Caller");
    var friend = signUp("Callee");
    befriend(me, friend);
    var chat = post("/conversations/direct/" + friend.id(), null, me.token());
    var events = listen(friend);

    var started = post("/calls", Map.of("conversationId", chat.get("id"), "video", false), me.token());
    var call = (Map<String, Object>) started.get("call");
    assertThat(started.get("url").toString()).startsWith("ws");
    // The LiveKit token names the room and me.
    var claims = decodeJwt((String) started.get("token"));
    assertThat(claims.get("sub")).isEqualTo("u" + me.id());
    assertThat(((Map<String, Object>) claims.get("video")).get("room")).isEqualTo("call-" + call.get("id"));

    var ring = next(events, "call.incoming");
    assertThat(((Map<String, Object>) ring.get("data")).get("id")).isEqualTo(call.get("id"));

    var joined = post("/calls/" + call.get("id") + "/accept", null, friend.token());
    assertThat(((Map<String, Object>) joined.get("call")).get("status")).isEqualTo("active");
    post("/calls/" + call.get("id") + "/leave", null, friend.token());
    post("/calls/" + call.get("id") + "/leave", null, me.token());
    var last = get("/conversations/" + chat.get("id") + "/messages?limit=1", me.token(),
        new ParameterizedTypeReference<List<Map<String, Object>>>() {}).getFirst();
    assertThat(last.get("body").toString()).startsWith("📞 Voice call · 0:");

    // A declined call becomes a missed call.
    var second = (Map<String, Object>) post("/calls", Map.of("conversationId", chat.get("id"), "video", true), me.token()).get("call");
    post("/calls/" + second.get("id") + "/decline", null, friend.token());
    var missed = get("/conversations/" + chat.get("id") + "/messages?limit=1", me.token(),
        new ParameterizedTypeReference<List<Map<String, Object>>>() {}).getFirst();
    assertThat(missed.get("body")).isEqualTo("📵 Missed video call");

    var stranger = signUp("Stranger");
    assertThatThrownBy(() -> post("/calls/" + second.get("id") + "/accept", null, stranger.token()))
        .isInstanceOf(HttpClientErrorException.NotFound.class);
  }

  private static Map<String, Object> decodeJwt(String token) throws Exception {
    var payload = java.util.Base64.getUrlDecoder().decode(token.split("\\.")[1]);
    return new com.fasterxml.jackson.databind.ObjectMapper().readValue(payload, Map.class);
  }

  /** Connects [who] to the WebSocket and collects their events. */
  private BlockingQueue<Map<String, Object>> listen(Account who) throws Exception {
    var events = new LinkedBlockingQueue<Map<String, Object>>();
    var stomp = new WebSocketStompClient(new StandardWebSocketClient());
    stomp.setMessageConverter(new JacksonJsonMessageConverter());
    var connect = new StompHeaders();
    connect.add("Authorization", "Bearer " + who.token());
    var session = stomp.connectAsync("ws://localhost:" + port + "/ws", new WebSocketHttpHeaders(), connect,
        new StompSessionHandlerAdapter() {}).get(10, TimeUnit.SECONDS);
    session.subscribe("/user/queue/events", new StompFrameHandler() {
      @Override
      public Type getPayloadType(StompHeaders headers) { return Map.class; }

      @Override
      public void handleFrame(StompHeaders headers, Object payload) { events.add((Map<String, Object>) payload); }
    });
    Thread.sleep(300);
    return events;
  }

  @Test
  void ghostModeHidesMeFromTheMap() {
    var me = signUp("Me");
    var friend = signUp("Friend");
    befriend(me, friend);
    http.put().uri("/location").header("Authorization", "Bearer " + friend.token())
        .body(Map.of("lat", 5.3005, "lng", -3.9845, "place", "Marcory")).retrieve().toBodilessEntity();
    var type = new ParameterizedTypeReference<List<Map<String, Object>>>() {};
    assertThat(get("/friends/locations", me.token(), type)).hasSize(1);

    http.put().uri("/location/ghost").header("Authorization", "Bearer " + friend.token())
        .body(Map.of("ghost", true)).retrieve().toBodilessEntity();
    assertThat(get("/friends/locations", me.token(), type)).isEmpty();
  }

  private static Map<String, Object> next(BlockingQueue<Map<String, Object>> events, String type) throws InterruptedException {
    while (true) {
      var e = events.poll(10, TimeUnit.SECONDS);
      assertThat(e).as("event " + type).isNotNull();
      if (type.equals(e.get("type"))) return e;
    }
  }
}
