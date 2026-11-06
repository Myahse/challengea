package com.challengea.api;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.context.properties.ConfigurationPropertiesScan;

@SpringBootApplication
@ConfigurationPropertiesScan
public class ChallengeaApiApplication {
  public static void main(String[] args) {
    SpringApplication.run(ChallengeaApiApplication.class, args);
  }
}
