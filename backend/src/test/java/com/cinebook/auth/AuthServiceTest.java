package com.cinebook.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.cinebook.auth.dto.LoginRequest;
import com.cinebook.common.ApiException;
import com.cinebook.common.ErrorCode;
import com.cinebook.security.JwtProperties;
import com.cinebook.security.JwtService;
import java.time.Duration;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;

class AuthServiceTest {

    private static final String SECRET = "dGVzdC1vbmx5LWp3dC1zZWNyZXQta2V5LWZvci1jaW5lYm9vay10ZXN0cy0xMjM0NTY=";

    private final PasswordEncoder encoder = new BCryptPasswordEncoder(4);
    private final UserRepository users = mock(UserRepository.class);
    private final RefreshTokenService refreshTokens = mock(RefreshTokenService.class);
    private final LoginAttemptService attempts = mock(LoginAttemptService.class);
    private AuthService auth;
    private User demo;

    @BeforeEach
    void setUp() {
        JwtProperties jwt = new JwtProperties(SECRET, Duration.ofMinutes(15), Duration.ofDays(30));
        auth = new AuthService(users, encoder, new JwtService(jwt), jwt, refreshTokens, attempts);
        demo = new User("demo@cinebook.dev", encoder.encode("Demo@1234"), "Khách Demo", null, null);
        org.springframework.test.util.ReflectionTestUtils.setField(demo, "id", 1L);
        when(users.findByEmail("demo@cinebook.dev")).thenReturn(Optional.of(demo));
        when(refreshTokens.issue(any())).thenReturn("refresh-1");
        when(attempts.recordFailure(anyString())).thenReturn(Optional.empty());
    }

    @Test
    void loginIsCaseInsensitiveAndResetsTheFailureCounter() {
        var res = auth.login(new LoginRequest("  Demo@CineBook.dev ", "Demo@1234"));

        assertThat(res.refreshToken()).isEqualTo("refresh-1");
        assertThat(res.expiresIn()).isEqualTo(900);
        assertThat(res.user().email()).isEqualTo("demo@cinebook.dev");
        verify(attempts).reset("demo@cinebook.dev");
    }

    @Test
    void wrongPasswordAndUnknownEmailGiveTheSameError() {
        assertThatThrownBy(() -> auth.login(new LoginRequest("demo@cinebook.dev", "wrong")))
                .isInstanceOf(ApiException.class)
                .hasMessage("Email hoặc mật khẩu không chính xác")
                .extracting("code").isEqualTo(ErrorCode.INVALID_CREDENTIALS);
        assertThatThrownBy(() -> auth.login(new LoginRequest("nobody@cinebook.dev", "Demo@1234")))
                .isInstanceOf(ApiException.class)
                .hasMessage("Email hoặc mật khẩu không chính xác");

        verify(attempts).recordFailure("demo@cinebook.dev");
        verify(attempts).recordFailure("nobody@cinebook.dev");
        verify(refreshTokens, never()).issue(any());
    }

    @Test
    void theFailureThatReachesTheThresholdReturnsTooManyAttempts() {
        when(attempts.recordFailure("demo@cinebook.dev")).thenReturn(Optional.of(Duration.ofMinutes(15)));

        assertThatThrownBy(() -> auth.login(new LoginRequest("demo@cinebook.dev", "wrong")))
                .isInstanceOf(LoginLockedException.class)
                .hasMessageContaining("15 phút");
    }

    @Test
    void lockedAccountIsRefusedEvenWithTheRightPassword() {
        org.mockito.Mockito.doThrow(new LoginLockedException(Duration.ofMinutes(10)))
                .when(attempts).checkNotLocked("demo@cinebook.dev");

        assertThatThrownBy(() -> auth.login(new LoginRequest("demo@cinebook.dev", "Demo@1234")))
                .isInstanceOf(LoginLockedException.class);
        verify(refreshTokens, never()).issue(any());
    }

    @Test
    void passwordLongerThanBcryptLimitIsJustAWrongPassword() {
        assertThatThrownBy(() -> auth.login(new LoginRequest("demo@cinebook.dev", "x".repeat(100))))
                .isInstanceOf(ApiException.class)
                .extracting("code").isEqualTo(ErrorCode.INVALID_CREDENTIALS);
    }
}
