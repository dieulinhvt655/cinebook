package com.cinebook.security;

/** Principal stored in the SecurityContext; inject with {@code @AuthenticationPrincipal AuthUser me}. */
public record AuthUser(long id, Role role) {
}
