package com.cinebook.common;

import java.net.URI;
import org.springframework.http.ProblemDetail;

public final class Problems {

    private Problems() {
    }

    public static ProblemDetail of(ErrorCode code, String detail) {
        ProblemDetail pd = ProblemDetail.forStatusAndDetail(code.status(), detail);
        pd.setType(URI.create("https://cinebook.dev/errors/" + code.name().toLowerCase().replace('_', '-')));
        pd.setTitle(code.name());
        pd.setProperty("code", code.name());
        return pd;
    }
}
