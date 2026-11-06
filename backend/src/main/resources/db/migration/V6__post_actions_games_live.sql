-- Posts someone chose not to see.
CREATE TABLE post_hides (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id     NUMBER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
  user_id     NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT post_hides_uk UNIQUE (post_id, user_id)
);
CREATE INDEX post_hides_user_ix ON post_hides (user_id);

-- Reports wait here for someone to review them.
CREATE TABLE post_reports (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id     NUMBER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
  user_id     NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  reason      VARCHAR2(20) NOT NULL
              CONSTRAINT post_reports_reason_ck CHECK (reason IN ('spam', 'harassment', 'violence', 'nudity', 'other')),
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT post_reports_uk UNIQUE (post_id, user_id)
);
CREATE INDEX post_reports_user_ix ON post_reports (user_id);

UPDATE games SET playable = TRUE WHERE id IN ('rumble', 'purple');

-- Live broadcasts. The video itself goes through LiveKit.
CREATE TABLE lives (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  host_id     NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  title       VARCHAR2(120),
  started_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  ended_at    TIMESTAMP WITH TIME ZONE
);
CREATE INDEX lives_host_ix ON lives (host_id, ended_at);
