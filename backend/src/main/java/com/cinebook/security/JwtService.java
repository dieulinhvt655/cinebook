package com.cinebook.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.JwtException;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.io.Decoders;
import io.jsonwebtoken.security.Keys;
import java.time.Clock;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import javax.crypto.SecretKey;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

/** Issues and verifies HS256 access tokens (sub = user id, role). */
@Service
public class JwtService {

    private final SecretKey key;
    private final JwtProperties props;
    private final Clock clock;

    @Autowired
    public JwtService(JwtProperties props) {
        this(props, Clock.systemUTC());
    }

    JwtService(JwtProperties props, Clock clock) {
        if (props.secret() == null || props.secret().isBlank()) {
            throw new IllegalStateException("cinebook.jwt.secret (JWT_SECRET) must be set");
        }
        this.key = Keys.hmacShaKeyFor(Decoders.BASE64.decode(props.secret()));
        this.props = props;
        this.clock = clock;
    }

    public String issueAccessToken(long userId, Role role) {
        Instant now = clock.instant();
        return Jwts.builder()
                .subject(Long.toString(userId))
                .claim("role", role.name())
                .issuedAt(Date.from(now))
                .expiration(Date.from(now.plus(props.accessTtl())))
                .signWith(key, Jwts.SIG.HS256)
                .compact();
    }

    /** Returns the authenticated principal if the token is valid and unexpired. */
    public Optional<AuthUser> verify(String token) {
        try {
            Claims claims = Jwts.parser()
                    .verifyWith(key)
                    .clock(() -> Date.from(clock.instant()))
                    .build()
                    .parseSignedClaims(token)
                    .getPayload();
            return Optional.of(new AuthUser(Long.parseLong(claims.getSubject()),
                    Role.valueOf(claims.get("role", String.class))));
        } catch (JwtException | IllegalArgumentException | NullPointerException e) {
            return Optional.empty();
        }
    }
}
