-- Phones that receive push notifications (Firebase Cloud Messaging tokens).
CREATE TABLE devices (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id     NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token       VARCHAR2(4000) NOT NULL,
  token_hash  VARCHAR2(64) NOT NULL UNIQUE,   -- tokens are long: unique on a hash
  platform    VARCHAR2(10) NOT NULL CONSTRAINT devices_platform_ck CHECK (platform IN ('android', 'ios', 'web')),
  updated_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE INDEX devices_user_ix ON devices (user_id);
