package com.cinebook.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** S02. Only "required" and basic format are checked here; the password policy is not (BR-02 note). */
public record LoginRequest(
        @NotBlank(message = "Vui lòng nhập email")
        @Email(message = "Email không đúng định dạng")
        @Size(max = 254, message = "Email tối đa 254 ký tự")
        String email,

        @NotBlank(message = "Vui lòng nhập mật khẩu")
        @Size(max = 1024, message = "Mật khẩu quá dài")
        String password) {
}
