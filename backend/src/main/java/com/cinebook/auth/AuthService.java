package com.cinebook.auth;

import com.cinebook.auth.dto.AuthResponse;
import com.cinebook.auth.dto.LoginRequest;
import com.cinebook.auth.dto.RegisterRequest;
import com.cinebook.auth.dto.UserResponse;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import com.cinebook.security.JwtProperties;
import com.cinebook.security.JwtService;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private static final String BAD_CREDENTIALS = "Email hoặc mật khẩu không chính xác";

    private final UserRepository users;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final JwtProperties jwtProps;
    private final RefreshTokenService refreshTokens;
    private final LoginAttemptService attempts;
    /** Compared against when the e-mail is unknown, so both cases take the same BCrypt time (BR-03.7). */
    private final String dummyHash;

    public AuthService(UserRepository users, PasswordEncoder passwordEncoder, JwtService jwtService,
            JwtProperties jwtProps, RefreshTokenService refreshTokens, LoginAttemptService attempts) {
        this.users = users;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.jwtProps = jwtProps;
        this.refreshTokens = refreshTokens;
        this.attempts = attempts;
        this.dummyHash = passwordEncoder.encode("cinebook-timing-equaliser");
    }

    @Transactional
    public AuthResponse register(RegisterRequest req) {
        String email = normaliseEmail(req.email());
        if (users.existsByEmail(email)) {
            throw emailTaken();
        }
        User user = new User(email, passwordEncoder.encode(req.password()), req.fullName().trim(),
                blankToNull(req.phone()), req.dateOfBirth());
        try {
            users.saveAndFlush(user);
        } catch (DataIntegrityViolationException e) {
            throw emailTaken(); // two registrations with the same e-mail at the same time
        }
        return tokensFor(user, refreshTokens.issue(user));
    }

    /**
     * BR-03/BR-04: locked e-mails are refused before the password is checked; a wrong e-mail and a
     * wrong password give the same error; a success resets the failure counter.
     */
    public AuthResponse login(LoginRequest req) {
        String email = normaliseEmail(req.email());
        attempts.checkNotLocked(email);

        User user = users.findByEmail(email).orElse(null);
        boolean ok = matches(req.password(), user == null ? dummyHash : user.getPasswordHash()) && user != null;
        if (!ok) {
            attempts.recordFailure(email).ifPresent(lock -> {
                throw new LoginLockedException(lock);
            });
            throw new ApiException(ErrorCode.INVALID_CREDENTIALS, BAD_CREDENTIALS);
        }
        attempts.reset(email);
        return tokensFor(user, refreshTokens.issue(user));
    }

    public AuthResponse refresh(String refreshToken) {
        RefreshTokenService.Rotation rotation = refreshTokens.rotate(refreshToken);
        return tokensFor(rotation.user(), rotation.refreshToken());
    }

    public void logout(String refreshToken) {
        refreshTokens.revokeFamilyOf(refreshToken);
    }

    @Transactional(readOnly = true)
    public UserResponse me(long userId) {
        return users.findById(userId).map(UserResponse::of)
                .orElseThrow(() -> new ApiException(ErrorCode.UNAUTHORIZED, "Tài khoản không còn tồn tại"));
    }

    /** BR-01.5: e-mails are case-insensitive everywhere (stored lower-case, DB CHECK). */
    static String normaliseEmail(String email) {
        return email.trim().toLowerCase(Locale.ROOT);
    }

    /** BCrypt only reads 72 bytes; longer input can never match a stored hash, so it is just a wrong password. */
    private boolean matches(String raw, String hash) {
        if (raw.getBytes(StandardCharsets.UTF_8).length > PasswordPolicy.MAX_BYTES) {
            passwordEncoder.matches("x", hash);
            return false;
        }
        return passwordEncoder.matches(raw, hash);
    }

    private AuthResponse tokensFor(User user, String refreshToken) {
        return new AuthResponse(jwtService.issueAccessToken(user.getId(), user.getRole()), refreshToken, "Bearer",
                jwtProps.accessTtl().toSeconds(), UserResponse.of(user));
    }

    private static ApiException emailTaken() {
        return new ApiException(ErrorCode.EMAIL_TAKEN, "Email đã được sử dụng");
    }

    private static String blankToNull(String s) {
        return s == null || s.isBlank() ? null : s.trim();
    }
}
