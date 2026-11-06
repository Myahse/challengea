# Challengea: handoff for the next agent

Challengea is a social app: a Flutter client (`app/`) and a Spring Boot API on
Oracle Database 23ai (`backend/`). It mixes Facebook (home feed), TikTok
(videos), Snapchat (stories, friends map) and WhatsApp (chats). On top of that
it has 1 vs 1 games and "bubble" group chats.

Read `app/README.md` (features, push setup) and `backend/README.md` (API
endpoints, settings, tests) before you change anything. This file covers what
those READMEs don't: the current state, the conventions and what to build next.

## Ground rules from the owner

- The Figma file "Challengea - N'TERI" also holds **NTERI**, a separate
  project. **Do not touch the NTERI part.** Use only the Challengea (MOBILE)
  sections.
- Keep every existing feature when you redesign. The owner wants the UI fluid,
  with animations almost everywhere.
- The owner writes in English and French. Reply in the language they use.

## Repository map

```
app/                         Flutter 3.47 / Dart 3.13
  lib/main.dart              entry; demo mode vs online mode (API_URL)
  lib/chat_store.dart        app state (ChangeNotifier): bubbles, chats, stories, feed
  lib/models.dart            Person, BubbleNode, Message...
  lib/feed.dart              Post, Creator, Comment, FeedData (home, forYou, following, reactions)
  lib/stories.dart           Story, StoryItem, mockStories()
  lib/theme.dart             AppColors, tx() text helper (Outfit variable font)
  lib/mock/                  demo cast (people, chats, posts), used when offline
  lib/api/                   REST client, STOMP realtime, LiveKit calls, FCM push, session
  lib/screens/
    home_shell.dart          the 4 pages + frosted bottom nav (Home, Chats, +, Videos, Map)
    home_feed.dart           Facebook-style feed: stories row, composer, games, nearby, posts, reactions
    story_viewer.dart        Snapchat-style full-screen stories
    create.dart              + menu, post composer, story creator
    chat_home.dart           WhatsApp-style list  <->  bubble field (drag a bubble onto another = group)
    chat_screen.dart         conversation: text, photos, voice notes, stickers, calls, games
    video_feed.dart          TikTok feed with Following / For you tabs, live + product cards
    map_screen.dart          Snap-Map-like friends map with profile cards
    profile_screen.dart, call_screen.dart, incoming_call_screen.dart, sign_in_screen.dart
  lib/games/                 Sudoku duel and Four in a row (local AI or online matches)
  lib/widgets/motion.dart    Pressable, FadeSlideIn, SmoothPageTransitions, CountUp; reuse them
  test/widget_test.dart      11 widget tests
backend/                     Spring Boot 4.1, Java 21, Flyway V1 to V4, JWT, STOMP /ws,
                             media as BLOBs, LiveKit tokens, Firebase Admin push, MockDataLoader
```

## What works today

| Area | Demo (no server) | Online (API_URL set) |
|---|---|---|
| Chats: text, photos, voice notes, stickers | simulated | real, saved in Oracle, realtime |
| Bubble group chats (drag to merge) | yes | yes (positions saved) |
| Friends map + profile cards | yes | real locations |
| Calls (voice/video, group) | simulated | real via LiveKit, ring screen, call log |
| Games: Sudoku duel, Four in a row | friend played by the app | real online matches |
| Push notifications | n/a | FCM (needs Firebase setup, see app README) |
| **Home feed, posts, reactions, comments** | yes | **local only, not saved** |
| **Stories (view, reply, create)** | yes | **local only; replies are sent as chat messages** |
| Videos feed | placeholder animations (`FakeVideo`) | same |
| Live / live shop | placeholder | placeholder ("soon" in the + menu) |

The latest redesign (commit "Redesign: Facebook / TikTok / Snapchat /
WhatsApp-style UI") added the home feed, stories, the + menu, the WhatsApp chat
list, the Following/For you tabs and the new bottom nav.

## What to build next (in order)

1. **Save stories, posts, reactions and comments on the server.** Today they
   live only on the device, so friends never see them.
   - Flyway `V5__social.sql`: STORY and STORY_ITEM (with an expiry at 24 h),
     STORY_VIEW, POST, POST_REACTION (one row per user per post, a type
     column), COMMENT. Media goes in the existing MEDIA table.
   - REST endpoints next to `chat/` and `media/`, plus realtime events through
     `realtime/Events.java` (new story, new post, reaction).
   - Flutter: load and save through `lib/api/online.dart`. Keep the mock path
     for demo mode. `FeedData.react`, `addPost` and `ChatStore.addToMyStory` /
     `markStorySeen` are the hooks to connect.
2. **Real videos:** record or pick a clip, upload it (raise the 12 MB multipart
   limit or use chunked upload), and play it with `video_player` in place of
   `FakeVideo`.
3. **Live and live shop**, built on the LiveKit setup that calls already use.
4. **Release:** host the API and Oracle, build the Android APK / iOS
   TestFlight, and set real `JWT_SECRET`, `CORS_ORIGINS`, LiveKit keys and an
   SMS provider. `OTP_DEV_ECHO` must be false in production.
5. **Polish:** a real notifications screen (the bell opens sample data),
   search, dark mode, hide/report.

`app/README.md` still describes the old "dots" navigation. Update it when you
touch the UI.

## Running locally

Flutter lives at `/opt/sdk/flutter/bin` in the cloud container. It is not on
PATH, so run `export PATH=/opt/sdk/flutter/bin:$PATH` first.

```bash
cd app && flutter analyze && flutter test
```

```bash
cd app && flutter build web --release --no-web-resources-cdn --base-href /
```

```bash
cd app && flutter build web --release --no-web-resources-cdn --base-href / --dart-define=API_URL=http://localhost:8080 -o build/web_online
```

Backend: `cd backend && docker compose up -d oracle && mvn spring-boot:run`.
Health check: `curl http://localhost:8080/actuator/health`. The mock data
loader seeds a Marcory cast. Sign in as `moise@challengea.dev` / `challengea`.

In a cloud container without a running Docker daemon, start it first with
`nohup dockerd > /tmp/dockerd.log 2>&1 &`. Calls need the official
`livekit/livekit-server:v1.9 --dev` Docker image. Don't run downloaded
binaries.

Tests against an already running Oracle: `mvn test -Dtests.db.external=true`.

## Conventions and gotchas

- The lints are strict (`curly_braces_in_flow_control_structures` and others).
  Run `flutter analyze` until it says "No issues found".
- The widget tests use a wide test font, so a Row with text overflows easily.
  Use `Flexible` / `Expanded` / `maxLines` + ellipsis, or `FittedBox` for
  wordmarks.
- Text style: `tx(size, weight:, color:)` from `theme.dart`. Colors:
  `AppColors` (brandGradient, storyGradient, like, page, line).
- Every tap target should use `Pressable`, and lists should use `FadeSlideIn`.
- Two maps: native builds use flutter_map + GPS. The web demo draws
  `CityMapPainter` because it can't load tiles (`--dart-define=REAL_MAP=true`
  to force tiles).
- Visual checks: Playwright + Chromium are preinstalled. Use a 430x932
  viewport with `hasTouch`, and send taps as CDP `Input.dispatchTouchEvent`
  (Flutter web ignores plain mouse clicks on many widgets).
- Commits: clear messages, no model names in commits or code.
