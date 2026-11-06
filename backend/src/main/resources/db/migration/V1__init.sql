-- Challengea schema for Oracle Database 23ai.
-- Uses 23ai features: native BOOLEAN and JSON columns, IDENTITY keys.

CREATE TABLE users (
  id             NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  phone          VARCHAR2(20)  UNIQUE,
  email          VARCHAR2(255) UNIQUE,
  password_hash  VARCHAR2(100),
  display_name   VARCHAR2(80)  NOT NULL,
  handle         VARCHAR2(30)  NOT NULL UNIQUE,
  bio            VARCHAR2(500),
  avatar_url     VARCHAR2(500),
  color          VARCHAR2(7)   DEFAULT '#FF8A3D' NOT NULL,
  created_at     TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT users_login_ck CHECK (phone IS NOT NULL OR email IS NOT NULL)
);

-- One-time codes sent by SMS for phone sign-in (only a hash is stored).
CREATE TABLE otp_codes (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  phone       VARCHAR2(20) NOT NULL,
  code_hash   VARCHAR2(100) NOT NULL,
  expires_at  TIMESTAMP WITH TIME ZONE NOT NULL,
  attempts    NUMBER(2) DEFAULT 0 NOT NULL,
  used        BOOLEAN DEFAULT FALSE NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE INDEX otp_codes_phone_ix ON otp_codes (phone, created_at);

-- One row per pair: requester asked addressee.
CREATE TABLE friendships (
  id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  requester_id  NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  addressee_id  NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  status        VARCHAR2(10) DEFAULT 'pending' NOT NULL
                CONSTRAINT friendships_status_ck CHECK (status IN ('pending', 'accepted', 'blocked')),
  created_at    TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT friendships_pair_uk UNIQUE (requester_id, addressee_id),
  CONSTRAINT friendships_self_ck CHECK (requester_id <> addressee_id)
);
CREATE INDEX friendships_addressee_ix ON friendships (addressee_id, status);

-- Chats: 'direct' (2 people) or 'group' (made by merging bubbles).
CREATE TABLE conversations (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  type        VARCHAR2(10) NOT NULL CONSTRAINT conversations_type_ck CHECK (type IN ('direct', 'group')),
  title       VARCHAR2(80),
  created_by  NUMBER REFERENCES users (id) ON DELETE SET NULL,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE TABLE conversation_members (
  id                    NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conversation_id       NUMBER NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  user_id               NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  role                  VARCHAR2(10) DEFAULT 'member' NOT NULL
                        CONSTRAINT members_role_ck CHECK (role IN ('owner', 'member')),
  last_read_message_id  NUMBER,
  joined_at             TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT members_uk UNIQUE (conversation_id, user_id)
);
CREATE INDEX members_user_ix ON conversation_members (user_id);

CREATE TABLE messages (
  id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conversation_id  NUMBER NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  sender_id        NUMBER REFERENCES users (id) ON DELETE SET NULL,
  type             VARCHAR2(12) NOT NULL CONSTRAINT messages_type_ck
                   CHECK (type IN ('text', 'voice', 'image', 'file', 'sticker', 'game_result', 'system')),
  body             VARCHAR2(4000),
  media_url        VARCHAR2(1000),
  metadata         JSON,  -- voice: {duration, waveform}; file: {name, size}; sticker: {pack, id}; game: {matchId, ...}
  created_at       TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);
-- Chat history is read newest first, page by page.
CREATE INDEX messages_conv_ix ON messages (conversation_id, id DESC);

-- Where each user placed their bubbles on the chat home (0..1 fractions).
CREATE TABLE bubble_positions (
  id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id          NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  conversation_id  NUMBER NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  x                NUMBER(6, 5) NOT NULL CONSTRAINT bubble_x_ck CHECK (x BETWEEN 0 AND 1),
  y                NUMBER(6, 5) NOT NULL CONSTRAINT bubble_y_ck CHECK (y BETWEEN 0 AND 1),
  CONSTRAINT bubble_positions_uk UNIQUE (user_id, conversation_id)
);

-- Last known position for the friends map. Ghost mode hides it.
CREATE TABLE user_locations (
  user_id     NUMBER PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  lat         NUMBER(9, 6) NOT NULL CONSTRAINT locations_lat_ck CHECK (lat BETWEEN -90 AND 90),
  lng         NUMBER(9, 6) NOT NULL CONSTRAINT locations_lng_ck CHECK (lng BETWEEN -180 AND 180),
  place       VARCHAR2(120),
  status_text VARCHAR2(120),
  ghost       BOOLEAN DEFAULT FALSE NOT NULL,
  updated_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);

CREATE TABLE games (
  id        VARCHAR2(20) PRIMARY KEY,
  name      VARCHAR2(40) NOT NULL,
  playable  BOOLEAN DEFAULT FALSE NOT NULL
);
INSERT INTO games (id, name, playable) VALUES ('sudoku', 'Sudoku duel', TRUE);
INSERT INTO games (id, name, playable) VALUES ('arcade', 'Four in a row', TRUE);
INSERT INTO games (id, name, playable) VALUES ('rumble', 'Rumble dash', FALSE);
INSERT INTO games (id, name, playable) VALUES ('purple', 'Purple raw', FALSE);

-- 1 vs 1 matches. The server holds the state and checks every move.
CREATE TABLE matches (
  id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  game_id          VARCHAR2(20) NOT NULL REFERENCES games (id),
  challenger_id    NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  opponent_id      NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  status           VARCHAR2(10) DEFAULT 'invited' NOT NULL CONSTRAINT matches_status_ck
                   CHECK (status IN ('invited', 'active', 'finished', 'declined', 'cancelled')),
  state            JSON,
  current_turn_id  NUMBER REFERENCES users (id),
  winner_id        NUMBER REFERENCES users (id),
  created_at       TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  updated_at       TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT matches_players_ck CHECK (challenger_id <> opponent_id)
);
CREATE INDEX matches_challenger_ix ON matches (challenger_id, status);
CREATE INDEX matches_opponent_ix ON matches (opponent_id, status);

CREATE TABLE match_moves (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  match_id    NUMBER NOT NULL REFERENCES matches (id) ON DELETE CASCADE,
  player_id   NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  move        JSON NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE INDEX match_moves_match_ix ON match_moves (match_id, id);
