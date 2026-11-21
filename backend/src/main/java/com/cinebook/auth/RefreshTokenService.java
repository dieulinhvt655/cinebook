package com.cinebook.auth;

import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import com.cinebook.common.Hashing;
import com.cinebook.security.JwtProperties;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Opaque refresh tokens (256 random bits, 30 days). Each refresh revokes the presented token and
 * issues a new one in the same family; presenting an already revoked token revokes the whole
 * family, since it means the token was stolen or replayed (design doc 3.4, BR-05).
 */
@Service
public class RefreshTokenService {

    private static final Logger log = LoggerFactory.getLogger(RefreshTokenService.class);
    private static final SecureRandom RANDOM = new SecureRandom();

    private final RefreshTokenRepository tokens;
    private final JwtProperties jwtProps;
    private final Clock clock;

    public RefreshTokenService(RefreshTokenRepository tokens, JwtProperties jwtProps, Clock clock) {
        this.tokens = tokens;
        this.jwtProps = jwtProps;
        this.clock = clock;
    }

    /** Starts a new family (new login). Returns the raw token, which is never stored. */
    @Transactional
    public String issue(User user) {
        return issueInFamily(user, UUID.randomUUID());
    }

    /** Rotates a refresh token; returns the owner and the new raw token. */
    @Transactional(noRollbackFor = ApiException.class)
    public Rotation rotate(String rawToken) {
        Instant now = clock.instant();
        RefreshToken current = tokens.findForUpdate(hash(rawToken)).orElseThrow(RefreshTokenService::invalid);
        if (current.getRevokedAt() != null) {
            int revoked = tokens.revokeFamily(current.getFamilyId(), now);
            log.warn("Revoked refresh token reused; revoked {} token(s) of user {}", revoked, current.getUser().getId());
            throw invalid();
        }
        if (!current.isUsableAt(now)) {
            throw invalid();
        }
        current.revoke(now);
        return new Rotation(current.getUser(), issueInFamily(current.getUser(), current.getFamilyId()));
    }

    /** Logout: revokes every token of the presented token's family. Unknown tokens are ignored. */
    @Transactional
    public void revokeFamilyOf(String rawToken) {
        tokens.findForUpdate(hash(rawToken))
                .ifPresent(t -> tokens.revokeFamily(t.getFamilyId(), clock.instant()));
    }

    @Transactional
    public int deleteExpired() {
        return tokens.deleteExpiredBefore(clock.instant());
    }

    private String issueInFamily(User user, UUID family) {
        byte[] bytes = new byte[32];
        RANDOM.nextBytes(bytes);
        String raw = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        Instant now = clock.instant();
        tokens.save(new RefreshToken(user, hash(raw), family, now, now.plus(jwtProps.refreshTtl())));
        return raw;
    }

    static String hash(String raw) {
        return Hashing.sha256Hex(raw);
    }

    private static ApiException invalid() {
        return new ApiException(ErrorCode.REFRESH_TOKEN_INVALID, "Phiên đăng nhập đã hết hạn, vui lòng đăng nhập lại");
    }

    public record Rotation(User user, String refreshToken) {
    }
}
