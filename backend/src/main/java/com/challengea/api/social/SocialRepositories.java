package com.challengea.api.social;

import java.time.OffsetDateTime;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;

interface StoryRepository extends JpaRepository<Story, Long> {
  Optional<Story> findByUserId(long userId);

  /** Mine and my friends', most recent first. */
  @Query("""
      select s from Story s
      where s.lastItemAt > :since
        and (s.userId = :me or exists (
          select 1 from Friendship f
          where f.status = 'accepted'
            and ((f.requesterId = :me and f.addresseeId = s.userId)
              or (f.addresseeId = :me and f.requesterId = s.userId))))
      order by s.lastItemAt desc""")
  List<Story> visibleTo(long me, OffsetDateTime since);
}

interface StoryItemRepository extends JpaRepository<StoryItem, Long> {
  List<StoryItem> findByStoryIdInAndExpiresAtAfterOrderById(Collection<Long> storyIds, OffsetDateTime now);

  List<StoryItem> findByExpiresAtBefore(OffsetDateTime now);
}

interface StoryViewRepository extends JpaRepository<StoryView, Long> {
  boolean existsByItemIdAndViewerId(long itemId, long viewerId);

  List<StoryView> findByViewerIdAndItemIdIn(long viewerId, Collection<Long> itemIds);
}

interface PostRepository extends JpaRepository<Post, Long> {
  /** My posts and my friends' with an id below before, newest first. */
  @Query("""
      select p from Post p
      where p.id < :before
        and not exists (select 1 from PostHide h where h.postId = p.id and h.userId = :me)
        and (p.authorId = :me or exists (
          select 1 from Friendship f
          where f.status = 'accepted'
            and ((f.requesterId = :me and f.addresseeId = p.authorId)
              or (f.addresseeId = :me and f.requesterId = p.authorId))))
      order by p.id desc""")
  List<Post> feed(long me, long before, Pageable page);

  /** Posts I can see whose text contains q. */
  @Query("""
      select p from Post p
      where lower(p.body) like lower(concat('%', :q, '%'))
        and not exists (select 1 from PostHide h where h.postId = p.id and h.userId = :me)
        and (p.authorId = :me or exists (
          select 1 from Friendship f
          where f.status = 'accepted'
            and ((f.requesterId = :me and f.addresseeId = p.authorId)
              or (f.addresseeId = :me and f.requesterId = p.authorId))))
      order by p.id desc""")
  List<Post> search(long me, String q, Pageable page);
}

interface HideRepository extends JpaRepository<PostHide, Long> {
  boolean existsByPostIdAndUserId(long postId, long userId);
}

interface ReportRepository extends JpaRepository<PostReport, Long> {
  boolean existsByPostIdAndUserId(long postId, long userId);
}

interface ReactionRepository extends JpaRepository<PostReaction, Long> {
  Optional<PostReaction> findByPostIdAndUserId(long postId, long userId);

  List<PostReaction> findByUserIdAndPostIdIn(long userId, Collection<Long> postIds);

  @Query("select r.postId, count(r) from PostReaction r where r.postId in :postIds group by r.postId")
  List<Object[]> countByPosts(Collection<Long> postIds);
}

interface CommentRepository extends JpaRepository<PostComment, Long> {
  List<PostComment> findByPostIdOrderById(long postId);

  long countByPostId(long postId);

  @Query("select c.postId, count(c) from PostComment c where c.postId in :postIds group by c.postId")
  List<Object[]> countByPosts(Collection<Long> postIds);
}
