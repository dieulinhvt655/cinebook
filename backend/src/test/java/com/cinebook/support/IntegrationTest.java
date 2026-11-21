package com.cinebook.support;

import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.context.annotation.Import;
import org.springframework.test.context.ActiveProfiles;
import org.testcontainers.junit.jupiter.Testcontainers;

/**
 * Full Spring context on Testcontainers PostgreSQL.
 * Skipped locally when Docker is not available; on CI (CI=true) a missing Docker fails the build instead.
 */
@Target(ElementType.TYPE)
@Retention(RetentionPolicy.RUNTIME)
@SpringBootTest
@ActiveProfiles("test")
@Import(PostgresContainerConfig.class)
@ExtendWith(DockerAvailableCondition.class)
@Testcontainers
public @interface IntegrationTest {
}
