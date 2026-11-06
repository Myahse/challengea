package com.challengea.api.social;

import com.challengea.api.common.CurrentUser;
import com.challengea.api.social.SocialDtos.CommentDto;
import com.challengea.api.social.SocialDtos.PostDto;
import com.challengea.api.social.SocialDtos.StoryDto;
import com.challengea.api.social.SocialDtos.StoryItemDto;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Size;
import java.util.List;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api")
public class SocialController {
  private final StoryService stories;
  private final PostService posts;

  public SocialController(StoryService stories, PostService posts) {
    this.stories = stories;
    this.posts = posts;
  }

  public record NewStoryItem(@Size(max = 500) String body, @Size(max = 1000) String mediaUrl,
      @Size(max = 64) String background) {}

  public record NewPost(@Size(max = 4000) String body, @Size(max = 1000) String mediaUrl,
      @Size(max = 64) String background) {}

  public record Reaction(String type) {}

  public record NewComment(@Size(max = 2000) String body, Long parentId) {}

  @GetMapping("/stories")
  List<StoryDto> stories() {
    return stories.visible(CurrentUser.id());
  }

  @PostMapping("/stories")
  @ResponseStatus(HttpStatus.CREATED)
  StoryItemDto addStory(@RequestBody @Valid NewStoryItem body) {
    return stories.add(CurrentUser.id(), body.body(), body.mediaUrl(), body.background());
  }

  @PostMapping("/stories/items/{id}/view")
  @ResponseStatus(HttpStatus.NO_CONTENT)
  void viewStory(@PathVariable long id) {
    try {
      stories.view(CurrentUser.id(), id);
    } catch (DataIntegrityViolationException sameMoment) {
      // Two phones at once: the row exists, which is all we need.
    }
  }

  @GetMapping("/posts")
  List<PostDto> feed(@RequestParam(required = false) Long before, @RequestParam(defaultValue = "20") int limit) {
    return posts.feed(CurrentUser.id(), before, limit);
  }

  @PostMapping("/posts")
  @ResponseStatus(HttpStatus.CREATED)
  PostDto createPost(@RequestBody @Valid NewPost body) {
    return posts.create(CurrentUser.id(), body.body(), body.mediaUrl(), body.background());
  }

  @PutMapping("/posts/{id}/reaction")
  PostDto react(@PathVariable long id, @RequestBody Reaction body) {
    try {
      return posts.react(CurrentUser.id(), id, body.type());
    } catch (DataIntegrityViolationException sameMoment) {
      return posts.react(CurrentUser.id(), id, body.type()); // the row exists now: this updates it
    }
  }

  @GetMapping("/posts/{id}/comments")
  List<CommentDto> comments(@PathVariable long id) {
    return posts.comments(CurrentUser.id(), id);
  }

  @PostMapping("/posts/{id}/comments")
  @ResponseStatus(HttpStatus.CREATED)
  CommentDto comment(@PathVariable long id, @RequestBody @Valid NewComment body) {
    return posts.comment(CurrentUser.id(), id, body.body(), body.parentId());
  }
}
