# Challengea — Flutter app (prototype)

Prototype of the **Challengea** screens (MOBILE section of the Figma file
"Challengea - N'TERI"; the NTERI part of that file is a separate project).

1. **Chat home** — the bubble chats described below; `+` opens Map / New group / Add friend
2. **Conversation** — 1-to-1 and group chat (tap the name for the profile): text, **photos** (gallery or camera, tap to zoom), **voice notes** (hold the mic, slide left to cancel) and **stickers**
3. **Friends map** (swipe left from Chats, or the dots) — works like Snap Map:
   tap a friend to fly to them and open their card (call, message, status,
   mini map, Challenge, Route). The filter button has **Ghost mode** and
   "show offline friends". Swipe from the left edge or tap the dots to go back.

4. **Calls** (phone / camera icons in a chat, or the call button on a friend's
   map card): "Calling…" with pulsing dots, then you in the middle and
   people around you; `+` spots invite more people (a 1-to-1 call becomes a
   group call), emoji reactions float up, Camera / Mute / Speaker / guests,
   and `⌄` minimizes the call behind a green "Tap to return to call" bar.
   Signed in, calls are real: the friend's phone rings full screen (Accept /
   Decline), audio and video go through LiveKit (`lib/api/live_call.dart`),
   reactions are shared with everyone in the call, and the chat logs
   "📞 Voice call · 3:12" or "📵 Missed call". In the demo they're simulated.

5. **Videos** (3rd dot): full-screen vertical feed. Swipe up for the next
   video, double-tap to like, tap to pause, tap the caption to expand it.
   Like / comments / share / save / repost on the side, Follow, music disc.
   **Comments** sheet (likes, replies, "See translation", image comments).
   **Live** videos show product cards; tap one for the **product sheet**
   (sizes + Buy).
6. **Profile** (4th dot = mine; tap an avatar in a video, on the map card or
   in a chat header for someone else's): cover, Follow / Edit profile,
   followers / following / likes, Message, bio, sticky tabs
   posts / Videos / Stories / tags and the grid (tap to watch).

7. **Games ("Tales")**: challenge a friend 1 vs 1 from the Tales tiles,
   Explore, the **Challenge** button on a friend's map card, the ⋮ menu of a
   chat, or during a 1-to-1 call. The friend accepts, you play, and the result
   is posted in your chat with a **Rematch** button.
   - **Sudoku duel**: same grid for both, live progress bars, 3 mistakes
     and you lose, 3 hints.
   - **Arcade = Four in a row**: turn by turn, falling discs, the friend
     blocks your lines.
   - Rumble dash and Purple raw: "soon".
   The friend's moves are simulated for now; online matches need the backend
   (invites by push notification, moves over WebSocket).

Videos and photos are animated colour placeholders until the backend stores
real media (then `video_player` / cached images replace `FakeVideo`).

**Two maps, same screen:**
- Installed app (Android / iOS): real **OpenStreetMap** map (`flutter_map`)
  and your real **GPS position** (`geolocator`, asks permission; if refused, a
  demo position in Marcory is used). Demo friends are placed around Marcory.
- Web prototype link: the map is drawn in code, because that page cannot load
  map tiles. Build the web version with `--dart-define=REAL_MAP=true` to get
  the real map in a browser.

OpenStreetMap's public tile servers are fine for development; a public
release needs its own tile provider (e.g. MapTiler, Stadia, Thunderforest)
or Google Maps.

## Bubble chats: what you can try

| Gesture | Result |
|---|---|
| Drag a bubble and drop it on empty space | Rearranges your bubbles |
| Drag a friend onto another friend | Creates a **group** bubble |
| Drag a friend (or a group) onto a group | **Adds** them to the group (groups merge) |
| Tap a bubble | Opens the chat (1-to-1 or group) |
| Long-press a group | Members, remove a member, rename, split the group |
| `+` button | Adds a demo friend |

Two modes:

- **Connected** (phones / emulators): sign in with your phone number (SMS code)
  or email; chats, friends, groups, bubble positions, the map and online games
  go through the Challengea API (`../backend`), with live updates over WebSocket.
- **Demo** (the shared web link, or "Try the demo"): sample data in memory.

## Run it

Start the backend first (`cd ../backend && docker compose up -d`), then:

```bash
cd app
flutter pub get
flutter run
```

- Android emulator: reaches your computer at `http://10.0.2.2:8080` automatically.
- iOS simulator: `http://localhost:8080` automatically.
- **Real phone** (same Wi-Fi as your computer): pass your computer's address,
  e.g. `flutter run --dart-define=API_URL=http://192.168.1.20:8080`.
- Browser: `flutter run -d chrome --dart-define=API_URL=http://localhost:8080`
  (without `API_URL` the web build runs the demo).

While no SMS provider is connected, the server shows the code on the sign-in
screen ("Test server: your code is …").

## Code map

- `lib/widgets/bubble_field.dart` — floating physics, drag, hover highlight, merge
- `lib/chat_store.dart` — friends, groups, messages (to be replaced by the Oracle-backed API)
- `lib/screens/chat_home.dart` — header, Tales (games) row, bubble area, group sheet
- `lib/screens/chat_screen.dart` — conversation screen
- `lib/screens/home_shell.dart` — swipeable pages (Chats, Map) and the dots
- `lib/screens/map_screen.dart` — map screen (top bar, friend card, settings)
- `lib/widgets/map_views.dart` — real map (OpenStreetMap + GPS) and drawn map
- `lib/widgets/map_markers.dart`, `friend_profile_sheet.dart`, `city_map.dart` — pins, friend card, drawn map
- `lib/call.dart`, `lib/screens/call_screen.dart`, `lib/widgets/call_banner.dart` — calls
- `lib/feed.dart`, `lib/screens/video_feed.dart`, `lib/screens/profile_screen.dart`, `lib/widgets/comments_sheet.dart`, `product_sheet.dart`, `fake_video.dart` — videos, profiles, shop
- `lib/games/` — games list, challenge flow, Sudoku duel, Four in a row (logic is in `*_logic.dart`, tested)
- `lib/api/` — API client, saved session, live events (STOMP), `online.dart` keeps the app in sync with the server
- `lib/screens/sign_in_screen.dart` — phone / email sign-in
- `lib/theme.dart` — colors and text styles from Figma (one place to update)
