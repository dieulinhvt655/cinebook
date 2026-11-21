package com.cinebook.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.cinebook.support.IntegrationTest;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;

/** End-to-end auth flows on real PostgreSQL. Every test uses its own e-mail, so tests stay independent. */
@IntegrationTest
@AutoConfigureMockMvc
class AuthFlowIT {

    private static final String PASSWORD = "ngựa vằn ăn cỏ ven sông";

    @Autowired
    MockMvc mvc;

    @Autowired
    ObjectMapper json;

    @Test
    void registerLoginMeRefreshLogout() throws Exception {
        String email = uniqueEmail();
        register(email, PASSWORD).andExpect(status().isCreated())
                .andExpect(jsonPath("$.tokenType").value("Bearer"))
                .andExpect(jsonPath("$.expiresIn").value(900))
                .andExpect(jsonPath("$.user.role").value("CUSTOMER"));

        JsonNode login = body(login(email.toUpperCase(), PASSWORD).andExpect(status().isOk()));
        mvc.perform(get("/me").header("Authorization", "Bearer " + login.get("accessToken").asText()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.email").value(email))
                .andExpect(jsonPath("$.fullName").value("Người Dùng Thử"));

        JsonNode refreshed = body(refresh(login.get("refreshToken").asText()).andExpect(status().isOk()));
        assertThat(refreshed.get("refreshToken").asText()).isNotEqualTo(login.get("refreshToken").asText());

        mvc.perform(post("/auth/logout").contentType(MediaType.APPLICATION_JSON)
                        .content(json(Map.of("refreshToken", refreshed.get("refreshToken").asText()))))
                .andExpect(status().isNoContent());
        refresh(refreshed.get("refreshToken").asText()).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("REFRESH_TOKEN_INVALID"));
    }

    @Test
    void reusingARotatedRefreshTokenRevokesTheWholeFamily() throws Exception {
        String email = uniqueEmail();
        String first = body(register(email, PASSWORD)).get("refreshToken").asText();
        String second = body(refresh(first).andExpect(status().isOk())).get("refreshToken").asText();

        refresh(first).andExpect(status().isUnauthorized()); // replay of a revoked token
        refresh(second).andExpect(status().isUnauthorized()); // ...kills the newer one too
    }

    @Test
    void duplicateEmailIsRejectedCaseInsensitively() throws Exception {
        String email = uniqueEmail();
        register(email, PASSWORD).andExpect(status().isCreated());
        register(email.toUpperCase(), PASSWORD).andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("EMAIL_TAKEN"))
                .andExpect(jsonPath("$.detail").value("Email đã được sử dụng"));
    }

    @Test
    void registerValidatesFieldsAndPasswordPolicy() throws Exception {
        register("not-an-email", "Demo@1234").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"))
                .andExpect(jsonPath("$.fields.email").value("Email không đúng định dạng"))
                .andExpect(jsonPath("$.fields.password").value("Mật khẩu phải có ít nhất 15 ký tự"));
        register(uniqueEmail(), "passwordpassword").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fields.password")
                        .value("Mật khẩu quá phổ biến hoặc dễ đoán, vui lòng chọn mật khẩu khác"));
    }

    @Test
    void loginRequiresBothFieldsAndKeepsSeededAccountsWorking() throws Exception {
        login("", "").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.fields.email").value("Vui lòng nhập email"))
                .andExpect(jsonPath("$.fields.password").value("Vui lòng nhập mật khẩu"));
        // the password policy is not applied at login: the 9-char demo password still works
        login("demo2@cinebook.dev", "Demo@1234").andExpect(status().isOk());
    }

    @Test
    void fiveFailuresLockTheEmailEvenWithTheRightPasswordAfterwards() throws Exception {
        String email = uniqueEmail();
        register(email, PASSWORD).andExpect(status().isCreated());

        for (int i = 1; i <= 4; i++) {
            login(email, "wrong password " + i).andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.detail").value("Email hoặc mật khẩu không chính xác"));
        }
        login(email, "wrong password 5").andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("TOO_MANY_LOGIN_ATTEMPTS"))
                .andExpect(header().string("Retry-After", "900"));
        login(email, PASSWORD).andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.retryAfterSeconds").isNumber());
    }

    @Test
    void unknownEmailsAreThrottledTheSameWayAsRealOnes() throws Exception {
        String nobody = uniqueEmail(); // never registered (BR-03.7)
        for (int i = 1; i <= 4; i++) {
            login(nobody, PASSWORD).andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.code").value("INVALID_CREDENTIALS"));
        }
        login(nobody, PASSWORD).andExpect(status().isTooManyRequests());
    }

    @Test
    void successfulLoginResetsTheFailureCounter() throws Exception {
        String email = uniqueEmail();
        register(email, PASSWORD).andExpect(status().isCreated());
        for (int i = 0; i < 4; i++) {
            login(email, "wrong").andExpect(status().isUnauthorized());
        }
        login(email, PASSWORD).andExpect(status().isOk());
        for (int i = 0; i < 4; i++) {
            login(email, "wrong").andExpect(status().isUnauthorized()); // counting starts again
        }
    }

    @Test
    void meRequiresAToken() throws Exception {
        mvc.perform(get("/me")).andExpect(status().isUnauthorized())
                .andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    private ResultActions register(String email, String password) throws Exception {
        return mvc.perform(post("/auth/register").contentType(MediaType.APPLICATION_JSON).content(json(Map.of(
                "email", email, "password", password, "fullName", "Người Dùng Thử",
                "phone", "0912345678", "dateOfBirth", "2000-01-01"))));
    }

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("email", email, "password", password))));
    }

    private ResultActions refresh(String token) throws Exception {
        return mvc.perform(post("/auth/refresh").contentType(MediaType.APPLICATION_JSON)
                .content(json(Map.of("refreshToken", token))));
    }

    private JsonNode body(ResultActions result) throws Exception {
        return json.readTree(result.andReturn().getResponse().getContentAsString());
    }

    private String json(Object value) throws Exception {
        return json.writeValueAsString(value);
    }

    private static String uniqueEmail() {
        return "it-" + UUID.randomUUID().toString().substring(0, 8) + "@cinebook.dev";
    }
}
