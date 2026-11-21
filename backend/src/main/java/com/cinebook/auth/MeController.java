package com.cinebook.auth;

import com.cinebook.auth.dto.UserResponse;
import com.cinebook.security.AuthUser;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@Tag(name = "Auth")
public class MeController {

    private final AuthService auth;

    public MeController(AuthService auth) {
        this.auth = auth;
    }

    @GetMapping("/me")
    @Operation(summary = "Hồ sơ người dùng đang đăng nhập (màn Tài khoản, Splash kiểm tra phiên)")
    public UserResponse me(@AuthenticationPrincipal AuthUser me) {
        return auth.me(me.id());
    }
}
