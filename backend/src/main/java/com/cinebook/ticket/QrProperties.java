package com.cinebook.ticket;

import org.springframework.boot.context.properties.ConfigurationProperties;

@ConfigurationProperties(prefix = "cinebook.qr")
public record QrProperties(String hmacKey) {
}
