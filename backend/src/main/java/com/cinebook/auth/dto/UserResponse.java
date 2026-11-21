package com.cinebook.auth.dto;

import com.cinebook.auth.User;
import com.cinebook.security.Role;
import java.time.LocalDate;

public record UserResponse(long id, String email, String fullName, String phone, LocalDate dateOfBirth, Role role) {

    public static UserResponse of(User u) {
        return new UserResponse(u.getId(), u.getEmail(), u.getFullName(), u.getPhone(), u.getDateOfBirth(), u.getRole());
    }
}
