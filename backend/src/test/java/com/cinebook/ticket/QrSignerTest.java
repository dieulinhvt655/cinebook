package com.cinebook.ticket;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Base64;
import org.junit.jupiter.api.Test;

class QrSignerTest {

    private final QrSigner signer = new QrSigner(new QrProperties(
            Base64.getEncoder().encodeToString("unit-test-key-0123456789abcdef!!".getBytes())));

    @Test
    void verifiesItsOwnSignature() {
        String token = signer.sign("t=ABC123;b=42");
        assertThat(signer.verify(token)).contains("t=ABC123;b=42");
    }

    @Test
    void rejectsTamperedPayload() {
        String token = signer.sign("t=ABC123;b=42");
        String forged = Base64.getUrlEncoder().withoutPadding().encodeToString("t=ABC123;b=43".getBytes())
                + token.substring(token.indexOf('.'));
        assertThat(signer.verify(forged)).isEmpty();
    }

    @Test
    void rejectsMalformedToken() {
        assertThat(signer.verify("not-a-token")).isEmpty();
        assertThat(signer.verify("abc.")).isEmpty();
        assertThat(signer.verify("***.***")).isEmpty();
    }
}
