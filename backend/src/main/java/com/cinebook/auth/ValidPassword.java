package com.cinebook.auth;

import jakarta.validation.Constraint;
import jakarta.validation.ConstraintValidator;
import jakarta.validation.ConstraintValidatorContext;
import jakarta.validation.Payload;
import java.lang.annotation.ElementType;
import java.lang.annotation.Retention;
import java.lang.annotation.RetentionPolicy;
import java.lang.annotation.Target;

/** Bean Validation hook for {@link PasswordPolicy}; the message is the specific reason. */
@Target(ElementType.FIELD)
@Retention(RetentionPolicy.RUNTIME)
@Constraint(validatedBy = ValidPassword.Validator.class)
public @interface ValidPassword {

    String message() default "Mật khẩu không hợp lệ";

    Class<?>[] groups() default {};

    Class<? extends Payload>[] payload() default {};

    class Validator implements ConstraintValidator<ValidPassword, String> {

        @Override
        public boolean isValid(String value, ConstraintValidatorContext ctx) {
            return PasswordPolicy.violation(value).map(reason -> {
                ctx.disableDefaultConstraintViolation();
                ctx.buildConstraintViolationWithTemplate(reason.replace("{", "\\{")).addConstraintViolation();
                return false;
            }).orElse(true);
        }
    }
}
