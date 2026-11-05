# Challengea — Flutter app (prototype)

Prototype of the **Challengea** screens (MOBILE section of the Figma file
"Challengea - N'TERI"; the NTERI part of that file is a separate project).

1. **Chat home** — the bubble chats described below
2. **Conversation** — 1-to-1 and group chat

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
- `lib/theme.dart` — colors and text styles from Figma (one place to update)
