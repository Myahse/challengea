# Challengea — Flutter app (prototype)

Prototype of the **Challengea** screens (MOBILE section of the Figma file
"Challengea - N'TERI"; the NTERI part of that file is a separate project).

1. **Chat home** — the bubble chats described below; `+` opens Map / New group / Add friend
2. **Conversation** — 1-to-1 and group chat
3. **Friends map** (swipe left from Chats, or the dots) — works like Snap Map:
   tap a friend to fly to them and open their card (call, message, status,
   mini map, Challenge, Route). The filter button has **Ghost mode** and
   "show offline friends". Swipe from the left edge or tap the dots to go back.

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

Data is fake and in memory (`lib/chat_store.dart`); no backend yet.

## Run it

```bash
cd app
flutter pub get
flutter run            # phone / emulator
flutter run -d chrome  # browser
```

## Code map

- `lib/widgets/bubble_field.dart` — floating physics, drag, hover highlight, merge
- `lib/chat_store.dart` — friends, groups, messages (to be replaced by the Oracle-backed API)
- `lib/screens/chat_home.dart` — header, Tales (games) row, bubble area, group sheet
- `lib/screens/chat_screen.dart` — conversation screen
- `lib/screens/home_shell.dart` — swipeable pages (Chats, Map) and the dots
- `lib/screens/map_screen.dart` — map screen (top bar, friend card, settings)
- `lib/widgets/map_views.dart` — real map (OpenStreetMap + GPS) and drawn map
- `lib/widgets/map_markers.dart`, `friend_profile_sheet.dart`, `city_map.dart` — pins, friend card, drawn map
- `lib/theme.dart` — colors and text styles from Figma (one place to update)
