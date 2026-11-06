-- Photos and voice notes sent in chats. Stored in Oracle as BLOBs so
-- development needs nothing else; an object store (S3 / OCI Object Storage)
-- can replace this table later without changing the API.
CREATE TABLE media (
  id            VARCHAR2(36) PRIMARY KEY,   -- random UUID, used in URLs
  owner_id      NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  kind          VARCHAR2(10) NOT NULL CONSTRAINT media_kind_ck CHECK (kind IN ('image', 'voice')),
  content_type  VARCHAR2(100) NOT NULL,
  size_bytes    NUMBER NOT NULL,
  data          BLOB NOT NULL,
  created_at    TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE INDEX media_owner_ix ON media (owner_id, created_at);
