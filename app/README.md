# nteri — Flutter app (prototype)

Prototype of the screens from the Figma file "Challengea - N'TERI":

1. **Splash** — logo + "Powered by Djogana group"
2. **Onboarding** — 4 slides with the tilted card carousel, `?` opens *Contact support*
3. **Sign up / log in** — phone number (+225, code by SMS — demo accepts any 6 digits) or email
4. **Chat home** — the bubble chats described below
5. **Conversation** — 1-to-1 and group chat

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
- `lib/screens/splash.dart`, `onboarding.dart`, `auth.dart` — start of the app
- `lib/theme.dart` — colors and text styles from Figma (one place to update)
