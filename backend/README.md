# Challengea API (Spring Boot + Oracle Database 23ai)

Backend for the Challengea Flutter app: accounts, friends, chats (1-to-1 and
groups made by merging bubbles), the friends map, and server-checked 1 vs 1
games. Real-time events go over WebSocket.

| | |
|---|---|
| Language | Java 21, Spring Boot 4.1 |
| Database | Oracle Database 23ai (native `BOOLEAN` and `JSON` columns) |
| Schema | Flyway migrations in `src/main/resources/db/migration` |
| Auth | Phone + 6-digit SMS code, or email + password → JWT |
| Real time | STOMP over WebSocket at `/ws` |

## Run it

Everything with Docker:

```bash
docker compose up -d
```

Or Oracle in Docker and the API from your IDE / terminal:

```bash
docker compose up -d oracle
mvn spring-boot:run
```

Check: `curl http://localhost:8080/actuator/health` → `{"status":"UP"}`.

### Settings (environment variables)

| Variable | Default | |
|---|---|---|
| `DB_URL` | `jdbc:oracle:thin:@localhost:1521/FREEPDB1` | Oracle connection |
| `DB_USER` / `DB_PASSWORD` | `challengea` / `challengea_dev` | |
| `JWT_SECRET` | dev value | **Set a long random secret in production** |
| `JWT_TTL` | `30d` | How long a sign-in lasts |
| `OTP_DEV_ECHO` | `true` | Returns the SMS code in the API response. **Set to `false` once an SMS provider is connected** |

## Tests

```bash
mvn test
```

The tests start their own Oracle 23ai with Testcontainers (Docker must be
running). To use an Oracle that is already running instead:

```bash
mvn test -Dtests.db.external=true
```

## API

Every request except `/api/auth/*` needs `Authorization: Bearer <token>`.
Errors look like `{"error": "not_your_turn", "message": "Wait for your turn"}`.

### Sign in

| Method | Path | Body | |
|---|---|---|---|
| POST | `/api/auth/otp/request` | `{phone}` | Sends a 6-digit code (local `07…` numbers become `+225…`). Max 3 codes per 5 min |
| POST | `/api/auth/otp/verify` | `{phone, code, displayName?}` | Signs in, or creates the account (`name_required` if new and no name). 5 tries per code |
| POST | `/api/auth/register` | `{email, password, displayName}` | Email account |
| POST | `/api/auth/login` | `{email, password}` | |

All four return `{token, user, isNew}`.

### Profile and friends

| Method | Path | |
|---|---|---|
| GET / PATCH | `/api/me` | My profile; PATCH `{displayName?, handle?, bio?}` |
| GET | `/api/users/{id}` | `{user, friendship}`: `none`, `requested`, `incoming`, `friends` |
| GET | `/api/users/search?q=` | By @handle or name |
| GET | `/api/friends` | My friends |
| GET | `/api/friends/requests` | Requests I received |
| POST | `/api/friends/{userId}` | Send a request (accepts theirs if they already asked) |
| POST | `/api/friends/{userId}/accept` | |
| DELETE | `/api/friends/{userId}` | |

### Chats and bubbles

| Method | Path | |
|---|---|---|
| GET | `/api/conversations` | My bubbles: members, last message, unread count, saved position |
| POST | `/api/conversations/direct/{userId}` | 1-to-1 chat with a friend (created the first time) |
| POST | `/api/conversations/groups` | `{memberIds, title?}`: merge bubbles into a group (me + at least 2 friends) |
| POST | `/api/conversations/{id}/members` | `{userIds}`: drop more bubbles on a group |
| DELETE | `/api/conversations/{id}/members/{userId}` | Leave, or remove someone (owner only). A group left with 1 person is deleted |
| PATCH | `/api/conversations/{id}` | `{title}` |
| GET | `/api/conversations/{id}/messages?before=&limit=` | Newest first, page with `before` = oldest id you have |
| POST | `/api/conversations/{id}/messages` | `{type, body?, mediaUrl?, metadata?}`; types `text`, `sticker` (body = the sticker), `image` and `voice` (upload first; voice metadata: `durationMs`, `waveform`) |
| POST | `/api/conversations/{id}/read` | `{messageId}` |
| POST | `/api/media` | multipart `file` + `kind` (`image` ≤ 10 MB, `voice` ≤ 5 MB) → `{id, url}` to put in a message's `mediaUrl` |
| GET | `/api/media/{id}` | The file (no token: the random id is the secret) |
| PUT | `/api/bubbles` | `{items: [{conversationId, x, y}]}` (0..1) |

### Map

| Method | Path | |
|---|---|---|
| PUT | `/api/location` | `{lat, lng, place?, status?}` |
| PUT | `/api/location/ghost` | `{ghost: true/false}` |
| GET | `/api/friends/locations` | Friends sharing their position (not in Ghost mode) |

### Games

| Method | Path | |
|---|---|---|
| GET | `/api/games` | `sudoku`, `arcade` (Four in a row), `rumble`, `purple` |
| POST | `/api/matches` | `{gameId, opponentId}`: challenge a friend |
| GET | `/api/matches` | My invites and matches in progress |
| GET | `/api/matches/{id}` | |
| POST | `/api/matches/{id}/accept` / `decline` | |
| POST | `/api/matches/{id}/moves` | Four in a row `{col}`; Sudoku `{cell, value}` |

The server keeps the state and checks every move (turns, full columns,
Sudoku answers). The Sudoku solution never leaves the server. When a match
ends, the result is posted in the players' chat (`game_result` message).

### Real-time events

Connect with STOMP to `ws://host:8080/ws`, send `Authorization: Bearer <token>`
in the CONNECT frame, subscribe to `/user/queue/events`. Each event is
`{"type": "...", "data": {...}}`:

`message.new`, `message.read`, `conversation.added`, `conversation.updated`,
`conversation.removed`, `friend.request`, `friend.accepted`,
`location.updated`, `location.hidden`, `match.invited`, `match.updated`.

## Not done yet

- **SMS sending**: plug a provider (Orange / MTN SMS API, Twilio…) in
  `AuthService.requestCode`, then set `OTP_DEV_ECHO=false`.
- **Media storage at scale**: photos and voice notes are stored in Oracle
  (BLOB) for now; move them to object storage (OCI Object Storage / S3) when
  usage grows. Videos are not supported yet.
- **Calls**: a LiveKit (WebRTC) server; the API will issue room tokens.
- **Videos, comments, shop and payments** (CinetPay / Wave / mobile money).
- **Push notifications** (FCM) when the app is closed.
