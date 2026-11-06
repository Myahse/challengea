package com.challengea.api.game;

import jakarta.persistence.*;

@Entity
@Table(name = "games")
public class Game {
  @Id
  private String id;

  @Column(nullable = false)
  private String name;

  private boolean playable;

  protected Game() {}

  public String getId() { return id; }
  public String getName() { return name; }
  public boolean isPlayable() { return playable; }
}
