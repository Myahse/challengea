# Design

Challengea looks like a product launch page you can live in: huge calm headlines, generous space, big rounded tiles, frosted glass, and friends as glossy bubbles shot like a hero product. Everything lives in `app/lib/theme.dart`, `app/lib/widgets/glass.dart` and `app/lib/widgets/motion.dart`.

## Theme

The app follows the device's light or dark setting and switches live (`FollowDeviceTheme`). `AppColors.*` getters resolve for the current theme, so colors are read at build time and are not `const`. The `AppColors.night*` tokens never change: stories and videos stay dark in both themes because they are full-screen media.

| Token | Light | Dark | Use |
|---|---|---|---|
| `page` | `#F5F5F7` | `#000000` | Screen background |
| `card` | `#FFFFFF` | `#1C1C1E` | Tiles and sheets |
| `hero` | `#000000` | `#1C1C1E` | Tiles with white words |
| `ink` / `onInk` | `#1D1D1F` / white | `#F5F5F7` / `#1D1D1F` | Text, and text on an ink fill |
| `muted` | `#6E6E73` | `#A1A1A6` | Secondary text |
| `line` | `#D2D2D7` | `#38383A` | Hairlines |
| `bubble` | `#E8E8ED` | `#2C2C2E` | Quiet buttons |
| `accent` | `#0071E3` | `#0A84FF` | Active state, primary buttons, sent messages |
| `link` | `#0066CC` | `#2997FF` | Text links |

No gradient text, no colored side borders. Color comes from people's bubbles and from what they post.

## Type

Inter Tight, variable, bundled in `app/assets/fonts` (SIL OFL, licence beside the font). Use `tx(size, weight:, color:)`. Weight stops at semibold, tracking tightens automatically with size, and hierarchy comes from size: display 44 to 72, section 28 to 34, body 15 to 17.

## Shapes

- Tiles: 26 to 30 px corners, 12 px page margin, 10 px between tiles.
- Controls: fully round, at least 44 px tall.
- Text links read "Reply ›" (`TextLink`). Prefer them over boxed secondary buttons.

## Signature pieces

- **Bubbles:** `PersonAvatar` and `Orb` are lit spheres (`orbBody` + `orbShine`). A blue ring and a slow drift mean a new story.
- **Glass:** `Glass` is only for things floating over content: the menu, top bars, controls on media, the map card.
- **Hero tiles:** words on `hero` with one bubble rising from the bottom edge.

## Motion

`Motion.ease` (`Cubic(.16, 1, .3, 1)`): things arrive fast and settle slowly, with no bounce. Reuse `Pressable`, `FadeSlideIn` and `Floaty`. Respect the system's reduced-motion setting: `FadeSlideIn` and `Floaty` already do.

Key moments get more than a fade (`app/lib/widgets/moments.dart`), and they stay rare so they keep meaning something:

- **`Burst`:** small bubbles and a shock ring for "that worked": likes, sending, merges. `Burst.victory` is for winning.
- **`MorphButton`:** the label shrinks into a spinner, a check draws itself, then the button settles on its new state. Failure shakes it.
- **`showMeet`:** two bubbles collide and fuse across the whole screen, for new friends and "Game on".
- **`MessageArrival`:** a new message grows out of the list and pushes the others up.
- **`Pressable`:** every press gets a sonar ring and a springy release.
