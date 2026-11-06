package com.challengea.api.mock;

import com.challengea.api.chat.BubblePosition;
import com.challengea.api.chat.ChatMessage;
import com.challengea.api.chat.Conversation;
import com.challengea.api.chat.ConversationMember;
import com.challengea.api.friend.Friendship;
import com.challengea.api.location.UserLocation;
import com.challengea.api.social.Post;
import com.challengea.api.social.Story;
import com.challengea.api.social.StoryItem;
import com.challengea.api.user.User;
import com.challengea.api.user.UserRepository;
import jakarta.persistence.EntityManager;
import java.util.List;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

/**
 * Dev cast around Marcory, so a fresh database is not empty.
 * Sign in as {@code moise@challengea.dev} / {@code challengea}.
 * Skipped once that account already exists.
 */
@Component
@ConditionalOnProperty(name = "mock.enabled", havingValue = "true")
public class MockDataLoader implements ApplicationRunner {
  private static final String PASSWORD = "challengea";
  private final EntityManager em;
  private final UserRepository users;
  private final PasswordEncoder encoder;

  public MockDataLoader(EntityManager em, UserRepository users, PasswordEncoder encoder) {
    this.em = em;
    this.users = users;
    this.encoder = encoder;
  }

  @Override
  @Transactional
  public void run(ApplicationArguments args) {
    if (users.findByEmailIgnoreCase("moise@challengea.dev").isEmpty()) {
      seed(encoder.encode(PASSWORD));
    }
    shareWithLonelyAccounts();
    seedSocial();
  }

  /** A few posts, and stories again whenever the last ones have expired. */
  private void seedSocial() {
    if (em.createQuery("select count(p) from Post p", Long.class).getSingleResult() == 0) {
      post("melanie", "Grand March\u00e9 de Marcory ce matin, les prix ont encore mont\u00e9 !", null);
      post("marc", "Sudoku en 3:12. Qui veut me d\u00e9fier ?", "#B5E48C,#1A759F");
      post("awa", "Pause caf\u00e9 en Zone 4 \u2615", null);
      post("brendon", "Rematch ce soir, soyez pr\u00eats.", "#A0C4FF,#5E60CE");
    }
    var active = em.createQuery("select count(i) from StoryItem i where i.expiresAt > CURRENT_TIMESTAMP", Long.class)
        .getSingleResult();
    if (active == 0) {
      storySlide("melanie", "Nouvelle tenue pour dimanche", "#FFC8DD,#B5179E");
      storySlide("marc", "Lagune \u00c9bri\u00e9 ce soir", "#2B2D42,#8D99AE");
      storySlide("awa", "Coffee break", "#ADE8F4,#0077B6");
    }
  }

  private void post(String handle, String body, String background) {
    em.persist(new Post(byEmail(handle + "@mock.challengea").getId(), body, null, background));
  }

  private void storySlide(String handle, String body, String background) {
    var userId = byEmail(handle + "@mock.challengea").getId();
    var story = em.createQuery("select s from Story s where s.userId = :id", Story.class)
        .setParameter("id", userId).getResultStream().findFirst().orElse(null);
    if (story == null) {
      story = new Story(userId);
      em.persist(story);
    }
    story.touch();
    em.persist(new StoryItem(story.getId(), body, null, background));
  }

  /** Gives the Marcory cast to any real account that has no friends yet. */
  private void shareWithLonelyAccounts() {
    var cast = users.findAll().stream().filter(u -> isCast(u.getEmail())).toList();
    if (cast.isEmpty()) return;
    for (var person : users.findAll()) {
      if (isCast(person.getEmail()) || "moise@challengea.dev".equalsIgnoreCase(person.getEmail())) continue;
      if (friendCount(person.getId()) > 0) continue;
      for (var friend : cast) {
        var link = new Friendship(person.getId(), friend.getId());
        em.persist(link);
        link.accept();
      }
      var melanie = byEmail("melanie@mock.challengea");
      var marc = byEmail("marc@mock.challengea");
      var brendon = byEmail("brendon@mock.challengea");
      var awa = byEmail("awa@mock.challengea");
      var mom = byEmail("maman@mock.challengea");
      var papa = byEmail("papa@mock.challengea");
      var aicha = byEmail("aicha@mock.challengea");
      var maurice = byEmail("maurice@mock.challengea");
      var celine = byEmail("celine@mock.challengea");
      var clena = byEmail("clena@mock.challengea");
      var yao = byEmail("yao@mock.challengea");

      var withMelanie = direct(person, melanie, 0.44, 0.17);
      var last = say(withMelanie, melanie, "Tu as vu le nouveau jeu dans Tales ?");
      readUpTo(withMelanie, person, last);
      var family = group(person, "Family group", 0.78, 0.18, mom, papa, aicha);
      last = say(family, mom, "Diner dimanche chez nous");
      readUpTo(family, person, last);
      var withMarc = direct(person, marc, 0.19, 0.36);
      last = say(withMarc, marc, "On se fait un Sudoku en duel ?");
      readUpTo(withMarc, person, last);
      direct(person, awa, 0.50, 0.47);
      var withBrendon = direct(person, brendon, 0.75, 0.51);
      last = say(withBrendon, brendon, "Regarde ma story");
      readUpTo(withBrendon, person, last);
      var tales = group(person, "Tales", 0.33, 0.22, marc, brendon, awa);
      last = say(tales, brendon, "Qui est chaud pour un Four in a row ?");
      readUpTo(tales, person, last);
      direct(person, clena, 0.20, 0.62);
      var withMaurice = direct(person, maurice, 0.53, 0.76);
      say(withMaurice, maurice, "Tu passes au Grand Carrefour ?");
      var withCeline = direct(person, celine, 0.12, 0.84);
      last = say(withCeline, celine, "Je suis au stade, tu viens ?");
      readUpTo(withCeline, person, last);
      direct(person, yao, 0.86, 0.78);
    }
  }

  private void seed(String hash) {

    var moise = user("Moise", "moise", "moise@challengea.dev", "+2250700000001", "#FF8A3D",
        "Sudoku champion of Marcory. Challenge me if you dare.", hash);
    var melanie = user("M\u00e9lanie", "melanie", "melanie@mock.challengea", "+2250700000002", "#B07A4F",
        "Always at the market.", hash);
    var marc = user("Marc", "marc", "marc@mock.challengea", "+2250700000003", "#F06BA8",
        "Sudoku, then alloco.", hash);
    var brendon = user("Brendon", "brendon", "brendon@mock.challengea", "+2250700000004", "#F59FC4",
        "Stories and rematches.", hash);
    var clena = user("Clena", "clena", "clena@mock.challengea", "+2250700000005", "#8B6CF6",
        "Around Treichville.", hash);
    var maurice = user("Maurice", "maurice", "maurice@mock.challengea", "+2250700000006", "#C9A27E",
        "Grand Carrefour.", hash);
    var awa = user("Awa", "awa", "awa@mock.challengea", "+2250700000007", "#4FB3F6",
        "Coffee in Zone 4.", hash);
    var yao = user("Yao", "yao", "yao@mock.challengea", "+2250700000008", "#5CC98A",
        "The barbershop in Bietry.", hash);
    var mom = user("Maman", "maman", "maman@mock.challengea", "+2250700000009", "#E5A93B",
        "Sunday dinner is at ours.", hash);
    var papa = user("Papa", "papa", "papa@mock.challengea", "+2250700000010", "#7D8CA3",
        "I bring the wine.", hash);
    var aicha = user("A\u00efcha", "aicha", "aicha@mock.challengea", "+2250700000011", "#D96C6C",
        "I bring dessert.", hash);
    var celine = user("Celine May", "celine", "celine@mock.challengea", "+2250700000012", "#9B6B4F",
        "On my way to the match.", hash);
    em.flush();

    for (var friend : List.of(melanie, marc, brendon, clena, maurice, awa, yao, mom, papa, aicha, celine)) {
      var link = new Friendship(moise.getId(), friend.getId());
      em.persist(link);
      link.accept();
    }

    var withMelanie = direct(moise, melanie, 0.44, 0.17);
    ChatMessage last = say(withMelanie, melanie, "Tu as vu le nouveau jeu dans Tales ?");
    last = say(withMelanie, moise, "Pas encore, je teste ce soir");
    last = say(withMelanie, melanie, "Je te challenge des que tu es en ligne");
    readUpTo(withMelanie, moise, last);

    var family = group(moise, "Family group", 0.78, 0.18, mom, papa, aicha);
    say(family, mom, "Diner dimanche chez nous");
    say(family, aicha, "Je ramene le dessert");
    last = say(family, papa, "J'apporte le vin");
    readUpTo(family, moise, last);

    var withMarc = direct(moise, marc, 0.19, 0.36);
    last = say(withMarc, marc, "On se fait un Sudoku en duel ?");
    readUpTo(withMarc, moise, last);

    direct(moise, awa, 0.50, 0.47);

    var withBrendon = direct(moise, brendon, 0.75, 0.51);
    last = say(withBrendon, brendon, "Regarde ma story");
    readUpTo(withBrendon, moise, last);

    var tales = group(moise, "Tales", 0.33, 0.22, marc, brendon, awa);
    say(tales, brendon, "Qui est chaud pour un Four in a row ?");
    last = say(tales, marc, "Moi. Perdant paie les allocos.");
    readUpTo(tales, moise, last);

    direct(moise, clena, 0.20, 0.62);

    var withMaurice = direct(moise, maurice, 0.53, 0.76);
    say(withMaurice, maurice, "Tu passes au Grand Carrefour ?");
    say(withMaurice, moise, "Dans une heure");
    say(withMaurice, maurice, "Ok je t'attends devant la station");

    direct(moise, yao, 0.86, 0.78);

    var withCeline = direct(moise, celine, 0.12, 0.84);
    last = say(withCeline, celine, "Je suis au stade, tu viens ?");
    readUpTo(withCeline, moise, last);

    pin(celine, 560, 760, "Marcory, Abidjan", "On my way to the match");
    pin(melanie, 985, 640, "Remblais, Marcory", "At the market");
    pin(marc, 420, 1210, "Koumassi", "Playing Sudoku");
    pin(brendon, 905, 1250, "Avenue des M\u00e9tiers", "Story time");
    pin(maurice, 770, 1490, "Grand Carrefour, Koumassi", "Free tonight?");
    pin(awa, 1060, 985, "Marcory Zone 4", "Coffee break");
    pin(clena, 300, 870, "Treichville", "Offline");
    pin(yao, 1180, 820, "Bi\u00e9try", "At the barbershop");
  }

  private static boolean isCast(String email) {
    return email != null && email.endsWith("@mock.challengea");
  }

  private User byEmail(String email) {
    return users.findByEmailIgnoreCase(email).orElseThrow();
  }

  private long friendCount(long userId) {
    return em.createQuery(
            "select count(f) from Friendship f where f.requesterId = :id or f.addresseeId = :id", Long.class)
        .setParameter("id", userId)
        .getSingleResult();
  }

  private User user(String name, String handle, String email, String phone, String color, String bio, String hash) {
    var u = new User(name, handle);
    u.setEmail(email);
    u.setPhone(phone);
    u.setColor(color);
    u.setBio(bio);
    u.setPasswordHash(hash);
    em.persist(u);
    return u;
  }

  private long direct(User me, User other, double x, double y) {
    var c = new Conversation("direct", null, me.getId());
    em.persist(c);
    em.flush();
    em.persist(new ConversationMember(c.getId(), me.getId(), "member"));
    em.persist(new ConversationMember(c.getId(), other.getId(), "member"));
    place(me, c.getId(), x, y);
    return c.getId();
  }

  private long group(User me, String title, double x, double y, User... others) {
    var c = new Conversation("group", title, me.getId());
    em.persist(c);
    em.flush();
    em.persist(new ConversationMember(c.getId(), me.getId(), "owner"));
    for (var other : others) {
      em.persist(new ConversationMember(c.getId(), other.getId(), "member"));
    }
    place(me, c.getId(), x, y);
    return c.getId();
  }

  private void place(User me, long conversationId, double x, double y) {
    var bubble = new BubblePosition(me.getId(), conversationId);
    bubble.moveTo(x, y);
    em.persist(bubble);
  }

  private ChatMessage say(long conversationId, User sender, String body) {
    var message = new ChatMessage(conversationId, sender.getId(), "text", body, null, null);
    em.persist(message);
    return message;
  }

  private void readUpTo(long conversationId, User reader, ChatMessage last) {
    em.flush();
    em.createQuery(
            "select m from ConversationMember m where m.conversationId = :conversation and m.userId = :user",
            ConversationMember.class)
        .setParameter("conversation", conversationId)
        .setParameter("user", reader.getId())
        .getSingleResult()
        .setLastReadMessageId(last.getId());
  }

  /** Same conversion as the app's drawn map: 3 m per pixel, centered on Marcory. */
  private void pin(User user, double x, double y, String place, String status) {
    double lat = 5.3005 + -(y - 1010) * 3.0 / 111320;
    double lng = -3.9845 + (x - 700) * 3.0 / (111320 * Math.cos(Math.toRadians(5.3005)));
    var loc = new UserLocation(user.getId());
    loc.update(lat, lng, place, status);
    em.persist(loc);
  }
}
