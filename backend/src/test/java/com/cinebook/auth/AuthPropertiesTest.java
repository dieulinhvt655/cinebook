package com.cinebook.auth;

import static org.assertj.core.api.Assertions.assertThat;

import java.time.Duration;
import java.util.List;
import org.junit.jupiter.api.Test;

class AuthPropertiesTest {

    private final AuthProperties props = new AuthProperties(5,
            List.of(Duration.ofMinutes(15), Duration.ofMinutes(30), Duration.ofHours(1)), Duration.ofDays(1), "-");

    @Test
    void lockGrowsThenStaysAtTheLastValue() {
        assertThat(props.lockDurationFor(1)).isEqualTo(Duration.ofMinutes(15));
        assertThat(props.lockDurationFor(2)).isEqualTo(Duration.ofMinutes(30));
        assertThat(props.lockDurationFor(3)).isEqualTo(Duration.ofHours(1));
        assertThat(props.lockDurationFor(9)).isEqualTo(Duration.ofHours(1));
    }
}
