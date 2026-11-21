package com.cinebook.auth;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;

class PasswordPolicyTest {

    @Test
    void acceptsLongPassphraseWithSpacesAndNoCompositionRules() {
        assertThat(PasswordPolicy.violation("ngựa vằn ăn cỏ ven sông")).isEmpty();
        assertThat(PasswordPolicy.violation("onlylowercaseletters")).isEmpty();
    }

    @Test
    void rejectsShorterThan15Characters() {
        assertThat(PasswordPolicy.violation("Demo@1234")).contains("Mật khẩu phải có ít nhất 15 ký tự");
        assertThat(PasswordPolicy.violation("abcdefghijklmn")).isPresent();
    }

    @Test
    void countsCharactersNotBytes() {
        // 14 characters (20 UTF-8 bytes): still too short
        assertThat(PasswordPolicy.violation("ăn cơm chưa bạ")).contains("Mật khẩu phải có ít nhất 15 ký tự");
        assertThat(PasswordPolicy.violation("mưa rơi trên phố")).isEmpty(); // 16 chars, 22 bytes
    }

    @Test
    void rejectsTooLongInCharactersOrBytes() {
        assertThat(PasswordPolicy.violation("a1b2c3d4e5".repeat(7))).contains("Mật khẩu quá dài (tối đa 64 ký tự)");
        // 30 chars but 90 UTF-8 bytes: BCrypt would silently ignore the tail
        assertThat(PasswordPolicy.violation("ằẳẵặẫậầẩấềểễệếởỡợờớừửữựứỳỷỹỵý")).isPresent();
    }

    @ParameterizedTest
    @ValueSource(strings = {"passwordpassword", "Password Password", "123456789012345", "aaaaaaaaaaaaaaaa",
            "abababababababab", "abcdefghijklmnop", "987654321098765", "QWERTYUIOPASDFG"})
    void rejectsCommonOrEasilyGuessed(String password) {
        assertThat(PasswordPolicy.violation(password))
                .contains("Mật khẩu quá phổ biến hoặc dễ đoán, vui lòng chọn mật khẩu khác");
    }

    @Test
    void neverTrimsOrNormalises() {
        assertThat(PasswordPolicy.violation("   ")).isPresent();
        assertThat(PasswordPolicy.violation("")).contains("Vui lòng nhập mật khẩu");
        assertThat(PasswordPolicy.violation(null)).contains("Vui lòng nhập mật khẩu");
    }
}
