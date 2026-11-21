package com.cinebook.auth.dto;

/** Returned by register, login and refresh. {@code expiresIn} is the access token lifetime in seconds. */
public record AuthResponse(String accessToken, String refreshToken, String tokenType, long expiresIn,
        UserResponse user) {
}
