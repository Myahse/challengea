-- Stories, posts, reactions and comments.
-- Photos live in the media table; these rows keep their /api/media/... URL.
-- "background" is the gradient of a text card: comma-separated #RRGGBB colours.

-- One row per person; last_item_at finds who has something to show.
CREATE TABLE stories (
  id            NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id       NUMBER NOT NULL UNIQUE REFERENCES users (id) ON DELETE CASCADE,
  last_item_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE INDEX stories_recent_ix ON stories (last_item_at);

-- Each slide disappears on its own, 24 h after it was posted.
CREATE TABLE story_items (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  story_id    NUMBER NOT NULL REFERENCES stories (id) ON DELETE CASCADE,
  body        VARCHAR2(500),
  media_url   VARCHAR2(1000),
  background  VARCHAR2(64),
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  expires_at  TIMESTAMP WITH TIME ZONE NOT NULL,
  CONSTRAINT story_items_content_ck CHECK (body IS NOT NULL OR media_url IS NOT NULL)
);
CREATE INDEX story_items_story_ix ON story_items (story_id, expires_at);
CREATE INDEX story_items_expiry_ix ON story_items (expires_at);

CREATE TABLE story_views (
  id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  item_id    NUMBER NOT NULL REFERENCES story_items (id) ON DELETE CASCADE,
  viewer_id  NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  viewed_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT story_views_uk UNIQUE (item_id, viewer_id)
);
CREATE INDEX story_views_viewer_ix ON story_views (viewer_id);

CREATE TABLE posts (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  author_id   NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  body        VARCHAR2(4000),
  media_url   VARCHAR2(1000),
  background  VARCHAR2(64),
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT posts_content_ck CHECK (body IS NOT NULL OR media_url IS NOT NULL)
);
CREATE INDEX posts_author_ix ON posts (author_id, id);

-- One reaction per person per post.
CREATE TABLE post_reactions (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id     NUMBER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
  user_id     NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  type        VARCHAR2(10) NOT NULL
              CONSTRAINT post_reactions_type_ck CHECK (type IN ('like', 'love', 'haha', 'wow', 'sad', 'angry')),
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL,
  CONSTRAINT post_reactions_uk UNIQUE (post_id, user_id)
);
CREATE INDEX post_reactions_user_ix ON post_reactions (user_id);

-- COMMENT is a reserved word in Oracle. parent_id: replies are one level deep.
CREATE TABLE post_comments (
  id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  post_id     NUMBER NOT NULL REFERENCES posts (id) ON DELETE CASCADE,
  author_id   NUMBER NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  parent_id   NUMBER REFERENCES post_comments (id) ON DELETE CASCADE,
  body        VARCHAR2(2000) NOT NULL,
  created_at  TIMESTAMP WITH TIME ZONE DEFAULT SYSTIMESTAMP NOT NULL
);
CREATE INDEX post_comments_post_ix ON post_comments (post_id, id);
CREATE INDEX post_comments_author_ix ON post_comments (author_id);
CREATE INDEX post_comments_parent_ix ON post_comments (parent_id);
