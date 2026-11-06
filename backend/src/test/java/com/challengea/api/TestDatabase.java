package com.challengea.api;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.testcontainers.service.connection.ServiceConnection;
import org.springframework.context.annotation.Bean;
import org.testcontainers.oracle.OracleContainer;

/**
 * Tests run against a real Oracle 23ai Free started by Testcontainers (needs Docker).
 * To use a database that is already running instead, run with
 * -Dtests.db.external=true and DB_URL / DB_USER / DB_PASSWORD.
 */
@TestConfiguration(proxyBeanMethods = false)
class TestDatabase {
  @Bean
  @ServiceConnection
  @ConditionalOnProperty(name = "tests.db.external", havingValue = "false", matchIfMissing = true)
  OracleContainer oracle() {
    return new OracleContainer("gvenzl/oracle-free:23-slim-faststart");
  }
}
