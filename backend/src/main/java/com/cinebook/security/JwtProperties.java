package com.cinebook.security;

import java.time.Duration;
import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "cinebook.jwt")
public record JwtProperties(String secret, Duration accessTtl, Duration refreshTtl) {
}
