package com.cinebook.booking;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * @param holdTtl           seats are held for this long after "Tiếp tục" (10 min)
 * @param salesCutoff       online sales close this long before the showtime starts (15 min)
 * @param maxSeats          max seats per booking (8)
 * @param expiryJobInterval how often {@link HoldExpiryJob} sweeps expired holds (30 s)
 */
@ConfigurationProperties(prefix = "cinebook.booking")
public record BookingProperties(Duration holdTtl, Duration salesCutoff, int maxSeats, Duration expiryJobInterval) {
}
