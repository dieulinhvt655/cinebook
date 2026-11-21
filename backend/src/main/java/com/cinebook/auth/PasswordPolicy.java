package com.cinebook.auth;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.io.UncheckedIOException;
import java.nio.charset.StandardCharsets;
import java.util.Locale;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * Password rules for register / change password (BR-02). Not applied at login, where only
 * "required" is checked (BR-02 note), so existing accounts keep working.
 * <ul>
 *   <li>15–64 characters, any characters including spaces; never trimmed or normalised (BR-02.1–02.3)</li>
 *   <li>no composition rules (BR-02.4)</li>
 *   <li>rejects common / easily guessed passwords (BR-02.5)</li>
 *   <li>at most 72 UTF-8 bytes, because BCrypt ignores everything after that</li>
 * </ul>
 */
public final class PasswordPolicy {

    public static final int MIN_LENGTH = 15;
    public static final int MAX_LENGTH = 64;
    public static final int MAX_BYTES = 72;

    private static final Set<String> COMMON = load();

    private PasswordPolicy() {
    }

    /** Returns the user-facing reason the password is rejected, or empty when it is acceptable. */
    public static Optional<String> violation(String password) {
        if (password == null || password.isEmpty()) {
            return Optional.of("Vui lòng nhập mật khẩu");
        }
        int length = password.codePointCount(0, password.length());
        if (length < MIN_LENGTH) {
            return Optional.of("Mật khẩu phải có ít nhất " + MIN_LENGTH + " ký tự");
        }
        if (length > MAX_LENGTH || password.getBytes(StandardCharsets.UTF_8).length > MAX_BYTES) {
            return Optional.of("Mật khẩu quá dài (tối đa " + MAX_LENGTH + " ký tự)");
        }
        if (isEasilyGuessed(password)) {
            return Optional.of("Mật khẩu quá phổ biến hoặc dễ đoán, vui lòng chọn mật khẩu khác");
        }
        return Optional.empty();
    }

    static boolean isEasilyGuessed(String password) {
        String key = password.replace(" ", "").toLowerCase(Locale.ROOT);
        return COMMON.contains(key) || key.chars().distinct().count() <= 2 || isSequential(key);
    }

    /** "abcdefghijklmno", "987654321098765"... : every char is the previous one +1 (or -1), digits wrap. */
    private static boolean isSequential(String s) {
        if (s.length() < 3) {
            return false;
        }
        int step = stepBetween(s.charAt(0), s.charAt(1));
        if (step == 0) {
            return false;
        }
        for (int i = 2; i < s.length(); i++) {
            if (stepBetween(s.charAt(i - 1), s.charAt(i)) != step) {
                return false;
            }
        }
        return true;
    }

    /** +1 when b comes right after a, -1 when right before (digits wrap 9→0), otherwise 0. */
    private static int stepBetween(char a, char b) {
        int d = b - a;
        if (Character.isDigit(a) && Character.isDigit(b)) {
            if (d == -9) {
                d = 1;
            } else if (d == 9) {
                d = -1;
            }
        }
        return d == 1 || d == -1 ? d : 0;
    }

    private static Set<String> load() {
        var in = PasswordPolicy.class.getResourceAsStream("/auth/common-passwords.txt");
        if (in == null) {
            throw new IllegalStateException("auth/common-passwords.txt is missing");
        }
        try (var reader = new BufferedReader(new InputStreamReader(in, StandardCharsets.UTF_8))) {
            return reader.lines()
                    .map(String::trim)
                    .filter(l -> !l.isEmpty() && !l.startsWith("#"))
                    .map(l -> l.replace(" ", "").toLowerCase(Locale.ROOT))
                    .collect(Collectors.toUnmodifiableSet());
        } catch (IOException e) {
            throw new UncheckedIOException(e);
        }
    }
}
