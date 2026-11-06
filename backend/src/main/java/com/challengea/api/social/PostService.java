package com.challengea.api.social;

import com.challengea.api.common.ApiException;
import com.challengea.api.friend.FriendService;
import com.challengea.api.media.MediaService;
import com.challengea.api.realtime.Events;
import com.challengea.api.social.SocialDtos.CommentDto;
import com.challengea.api.social.SocialDtos.CommentEvent;
import com.challengea.api.social.SocialDtos.PostDto;
import com.challengea.api.social.SocialDtos.ReactionEvent;
import com.challengea.api.user.User;
import com.challengea.api.user.UserDto;
import com.challengea.api.user.UserRepository;
import com.challengea.api.user.UserService;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Everyone can see their own posts and their friends' posts, nothing else. */
@Service
public class PostService {
  private static final Set<String> REACTIONS = Set.of("like", "love", "haha", "wow", "sad", "angry");
  private static final Set<String> REPORT_REASONS = Set.of("spam", "harassment", "violence", "nudity", "other");

  private final PostRepository posts;
  private final ReactionRepository reactions;
  private final CommentRepository comments;
  private final UserRepository users;
  private final UserService userService;
  private final FriendService friends;
  private final MediaService media;
  private final Events events;
  private final HideRepository hides;
  private final ReportRepository reports;

  public PostService(PostRepository posts, ReactionRepository reactions, CommentRepository comments,
      UserRepository users, UserService userService, FriendService friends, MediaService media, Events events,
      HideRepository hides, ReportRepository reports) {
    this.posts = posts;
    this.reactions = reactions;
    this.comments = comments;
    this.users = users;
    this.userService = userService;
    this.friends = friends;
    this.media = media;
    this.events = events;
    this.hides = hides;
    this.reports = reports;
  }

  @Transactional(readOnly = true)
  public PostDto get(long me, long postId) {
    return views(me, List.of(requireVisible(me, postId))).getFirst();
  }

  @Transactional(readOnly = true)
  public List<PostDto> search(long me, String q, int limit) {
    var text = SocialText.clean(q);
    if (text == null) return List.of();
    return views(me, posts.search(me, text, PageRequest.of(0, Math.clamp(limit, 1, 50))));
  }

  /** Changes the text of my post. */
  @Transactional
  public PostDto edit(long me, long postId, String body) {
    var post = requireMine(me, postId);
    var text = SocialText.clean(body);
    if (text == null && post.getMediaUrl() == null) {
      throw ApiException.badRequest("empty_post", "Write something or add a photo");
    }
    post.setBody(text);
    var dto = views(me, List.of(post)).getFirst();
    events.send(audience(post), "post.updated", Map.of("postId", postId, "body", text == null ? "" : text));
    return dto;
  }

  @Transactional
  public void delete(long me, long postId) {
    var post = requireMine(me, postId);
    var everyone = audience(post);
    posts.delete(post);
    if (post.getMediaUrl() != null) media.delete(post.getMediaUrl());
    events.send(everyone, "post.deleted", Map.of("postId", postId));
  }

  /** I no longer see this post. */
  @Transactional
  public void hide(long me, long postId) {
    requireVisible(me, postId);
    if (!hides.existsByPostIdAndUserId(postId, me)) hides.save(new PostHide(postId, me));
  }

  /** Reporting also hides the post from me. */
  @Transactional
  public void report(long me, long postId, String reason) {
    var post = requireVisible(me, postId);
    if (post.getAuthorId() == me) throw ApiException.badRequest("own_post", "You can't report your own post");
    if (!REPORT_REASONS.contains(reason)) throw ApiException.badRequest("invalid_reason", "Unknown reason");
    if (!reports.existsByPostIdAndUserId(postId, me)) reports.save(new PostReport(postId, me, reason));
    if (!hides.existsByPostIdAndUserId(postId, me)) hides.save(new PostHide(postId, me));
  }

  /** Newest first; pass the oldest id you have as [before] to load older posts. */
  @Transactional(readOnly = true)
  public List<PostDto> feed(long me, Long before, int limit) {
    var page = PageRequest.of(0, Math.clamp(limit, 1, 50));
    return views(me, posts.feed(me, before == null ? Long.MAX_VALUE : before, page));
  }

  @Transactional
  public PostDto create(long me, String body, String mediaUrl, String background) {
    var text = SocialText.clean(body);
    var url = SocialText.clean(mediaUrl);
    if (text == null && url == null) throw ApiException.badRequest("empty_post", "Write something or add a photo");
    if (url != null) media.requireOwned(me, url, "image");
    var post = posts.save(new Post(me, text, url, SocialText.background(background)));
    var dto = views(me, List.of(post)).getFirst();
    events.send(friends.friendIds(me), "post.new", dto);
    return dto;
  }

  /** Sets my reaction on a post; null removes it. */
  @Transactional
  public PostDto react(long me, long postId, String type) {
    var post = requireVisible(me, postId);
    if (type != null && !REACTIONS.contains(type)) throw ApiException.badRequest("invalid_reaction", "Unknown reaction");
    var mine = reactions.findByPostIdAndUserId(postId, me);
    if (type == null) {
      mine.ifPresent(reactions::delete);
    } else if (mine.isPresent()) {
      mine.get().setType(type);
    } else {
      reactions.save(new PostReaction(postId, me, type));
    }
    var dto = views(me, List.of(post)).getFirst();
    events.send(audience(post), "post.reaction", new ReactionEvent(postId, me, type, dto.reactions()));
    return dto;
  }

  /** Oldest first. A reply has the id of its comment in parentId. */
  @Transactional(readOnly = true)
  public List<CommentDto> comments(long me, long postId) {
    requireVisible(me, postId);
    var list = comments.findByPostIdOrderById(postId);
    var people = peopleById(list.stream().map(PostComment::getAuthorId).toList());
    return list.stream().map(c -> view(c, people.get(c.getAuthorId()))).toList();
  }

  /** Replies stay one level deep: answering a reply joins its thread. */
  @Transactional
  public CommentDto comment(long me, long postId, String body, Long parentId) {
    var post = requireVisible(me, postId);
    var text = SocialText.clean(body);
    if (text == null) throw ApiException.badRequest("empty_comment", "Write something first");
    Long thread = null;
    if (parentId != null) {
      var parent = comments.findById(parentId).filter(c -> c.getPostId() == postId)
          .orElseThrow(() -> ApiException.notFound("Comment"));
      thread = parent.getParentId() != null ? parent.getParentId() : parent.getId();
    }
    var saved = comments.save(new PostComment(postId, me, thread, text));
    var dto = view(saved, userService.get(me));
    events.send(audience(post), "post.comment", new CommentEvent(dto, comments.countByPostId(postId)));
    return dto;
  }

  private Post requireVisible(long me, long postId) {
    // Same answer as a post that doesn't exist: nothing leaks to strangers.
    return posts.findById(postId)
        .filter(p -> p.getAuthorId() == me || friends.areFriends(me, p.getAuthorId()))
        .orElseThrow(() -> ApiException.notFound("Post"));
  }

  private Post requireMine(long me, long postId) {
    var post = requireVisible(me, postId);
    if (post.getAuthorId() != me) throw ApiException.forbidden("This post is not yours");
    return post;
  }

  /** Everyone who can see this post. */
  private List<Long> audience(Post post) {
    var ids = new ArrayList<>(friends.friendIds(post.getAuthorId()));
    ids.add(post.getAuthorId());
    return ids;
  }

  private List<PostDto> views(long me, List<Post> page) {
    if (page.isEmpty()) return List.of();
    var ids = page.stream().map(Post::getId).toList();
    var reactionCounts = counts(reactions.countByPosts(ids));
    var commentCounts = counts(comments.countByPosts(ids));
    var mine = reactions.findByUserIdAndPostIdIn(me, ids).stream()
        .collect(Collectors.toMap(PostReaction::getPostId, PostReaction::getType));
    var people = peopleById(page.stream().map(Post::getAuthorId).toList());
    return page.stream()
        .map(p -> new PostDto(p.getId(), UserDto.of(people.get(p.getAuthorId())), p.getBody(), p.getMediaUrl(),
            p.getBackground(), reactionCounts.getOrDefault(p.getId(), 0L), mine.get(p.getId()),
            commentCounts.getOrDefault(p.getId(), 0L), p.getCreatedAt()))
        .toList();
  }

  private static CommentDto view(PostComment c, User author) {
    return new CommentDto(c.getId(), c.getPostId(), c.getParentId(), UserDto.of(author), c.getBody(), c.getCreatedAt());
  }

  private static Map<Long, Long> counts(List<Object[]> rows) {
    return rows.stream().collect(Collectors.toMap(r -> (Long) r[0], r -> (Long) r[1]));
  }

  private Map<Long, User> peopleById(Collection<Long> ids) {
    return users.findAllById(new HashSet<>(ids)).stream()
        .collect(Collectors.toMap(User::getId, Function.identity()));
  }
}
