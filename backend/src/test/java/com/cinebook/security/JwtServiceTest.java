package com.cinebook.security;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.ZoneOffset;
import org.junit.jupiter.api.Test;

class JwtServiceTest {

    private static final String SECRET = "dGVzdC1vbmx5LWp3dC1zZWNyZXQta2V5LWZvci1jaW5lYm9vay10ZXN0cy0xMjM0NTY=";
    private static final JwtProperties PROPS = new JwtProperties(SECRET, Duration.ofMinutes(15), Duration.ofDays(30));
    private static final Instant T0 = Instant.parse("2026-11-20T10:00:00Z");

    @Test
    void roundTripsUserIdAndRole() {
        JwtService jwt = new JwtService(PROPS, Clock.fixed(T0, ZoneOffset.UTC));
        String token = jwt.issueAccessToken(42L, Role.ADMIN);
        assertThat(jwt.verify(token)).contains(new AuthUser(42L, Role.ADMIN));
    }

    @Test
    void rejectsExpiredToken() {
        String token = new JwtService(PROPS, Clock.fixed(T0, ZoneOffset.UTC)).issueAccessToken(1L, Role.CUSTOMER);
        JwtService later = new JwtService(PROPS, Clock.fixed(T0.plus(Duration.ofMinutes(16)), ZoneOffset.UTC));
        assertThat(later.verify(token)).isEmpty();
    }

    @Test
    void rejectsGarbage() {
        assertThat(new JwtService(PROPS).verify("not.a.jwt")).isEmpty();
    }
}
