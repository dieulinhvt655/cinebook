package com.cinebook.common;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;

/** Business dates ("today", a showtime's day) are Vietnam dates; timestamps stay UTC. */
public final class VietnamTime {

    public static final ZoneId ZONE = ZoneId.of("Asia/Ho_Chi_Minh");

    private VietnamTime() {
    }

    public static LocalDate today(Clock clock) {
        return LocalDate.now(clock.withZone(ZONE));
    }
}
