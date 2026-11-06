package com.challengea.api.social;

import com.challengea.api.common.ApiException;
import com.challengea.api.friend.FriendService;
import com.challengea.api.media.MediaService;
import com.challengea.api.realtime.Events;
import com.challengea.api.social.SocialDtos.StoryDto;
import com.challengea.api.social.SocialDtos.StoryEvent;
import com.challengea.api.social.SocialDtos.StoryItemDto;
import com.challengea.api.user.User;
import com.challengea.api.user.UserDto;
import com.challengea.api.user.UserRepository;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Objects;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class StoryService {
  private static final Logger log = LoggerFactory.getLogger(StoryService.class);

  private final StoryRepository stories;
  private final StoryItemRepository items;
  private final StoryViewRepository views;
  private final UserRepository users;
  private final FriendService friends;
  private final MediaService media;
  private final Events events;

  public StoryService(StoryRepository stories, StoryItemRepository items, StoryViewRepository views,
      UserRepository users, FriendService friends, MediaService media, Events events) {
    this.stories = stories;
    this.items = items;
    this.views = views;
    this.users = users;
    this.friends = friends;
    this.media = media;
    this.events = events;
  }

  /** Slides from the last 24 h: mine and my friends', grouped by person. */
  @Transactional(readOnly = true)
  public List<StoryDto> visible(long me) {
    var now = OffsetDateTime.now();
    var list = stories.visibleTo(me, now.minus(StoryItem.LIFETIME));
    if (list.isEmpty()) return List.of();
    var slides = items.findByStoryIdInAndExpiresAtAfterOrderById(list.stream().map(Story::getId).toList(), now);
    if (slides.isEmpty()) return List.of();
    var seen = views.findByViewerIdAndItemIdIn(me, slides.stream().map(StoryItem::getId).toList()).stream()
        .map(StoryView::getItemId).collect(Collectors.toSet());
    var people = users.findAllById(list.stream().map(Story::getUserId).toList()).stream()
        .collect(Collectors.toMap(User::getId, Function.identity()));
    var byStory = slides.stream().collect(Collectors.groupingBy(StoryItem::getStoryId));
    var out = new ArrayList<StoryDto>();
    for (var story : list) {
      var own = byStory.get(story.getId());
      if (own == null) continue;
      var dtos = own.stream().map(i -> StoryItemDto.of(i, seen.contains(i.getId()))).toList();
      out.add(new StoryDto(UserDto.of(people.get(story.getUserId())), dtos));
    }
    return out;
  }

  /** Adds a slide to my story. */
  @Transactional
  public StoryItemDto add(long me, String body, String mediaUrl, String background) {
    var text = SocialText.clean(body);
    var url = SocialText.clean(mediaUrl);
    if (text == null && url == null) throw ApiException.badRequest("empty_story", "Add a photo or some text");
    if (url != null) media.requireOwned(me, url, "image");
    var story = stories.findByUserId(me).orElseGet(() -> stories.save(new Story(me)));
    story.touch();
    var item = items.save(new StoryItem(story.getId(), text, url, SocialText.background(background)));
    events.send(friends.friendIds(me), "story.new", new StoryEvent(me));
    return StoryItemDto.of(item, false);
  }

  /** Remembers that I saw this slide. My own slides, or ones I saw already, change nothing. */
  @Transactional
  public void view(long me, long itemId) {
    var item = items.findById(itemId).filter(i -> i.getExpiresAt().isAfter(OffsetDateTime.now()))
        .orElseThrow(() -> ApiException.notFound("Story"));
    var owner = stories.findById(item.getStoryId()).orElseThrow().getUserId();
    if (owner == me) return;
    if (!friends.areFriends(me, owner)) throw ApiException.notFound("Story");
    if (!views.existsByItemIdAndViewerId(itemId, me)) views.save(new StoryView(itemId, me));
  }

  /** Expired slides leave the feed at once; this removes the rows and their photos. */
  @Scheduled(fixedDelay = 3_600_000, initialDelay = 60_000)
  @Transactional
  public void removeExpired() {
    var expired = items.findByExpiresAtBefore(OffsetDateTime.now());
    if (expired.isEmpty()) return;
    items.deleteAll(expired); // their views go with them (ON DELETE CASCADE)
    expired.stream().map(StoryItem::getMediaUrl).filter(Objects::nonNull).forEach(media::delete);
    log.info("Removed {} expired story items", expired.size());
  }
}
