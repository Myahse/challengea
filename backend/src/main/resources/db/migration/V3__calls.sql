-- Voice / video calls. Audio and video go through LiveKit (WebRTC);
-- this table keeps who called whom, for the "missed call" messages and history.
CREATE TABLE calls (
  id               NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  conversation_id  NUMBER NOT NULL REFERENCES conversations (id) ON DELETE CASCADE,
  started_by       NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  video            BOOLEAN DEFAULT FALSE NOT NULL,
  status           VARCHAR2(10) DEFAULT 'ringing' NOT NULL
                   CONSTRAINT calls_status_ck CHECK (status IN ('ringing', 'active', 'ended', 'missed')),
  created_at       TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  answered_at      TIMESTAMP WITH TIME ZONE,
  ended_at         TIMESTAMP WITH TIME ZONE
);
CREATE INDEX calls_conversation_ix ON calls (conversation_id, created_at);
