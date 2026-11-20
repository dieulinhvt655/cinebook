package com.cinebook.ticket;

import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.MessageDigest;
import java.util.Base64;
import java.util.Optional;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * Signs ticket payloads for QR codes: {@code base64url(payload) + "." + base64url(HMAC-SHA256(payload))}.
 */
@Component
public class QrSigner {

    private static final String ALG = "HmacSHA256";
    private static final Base64.Encoder ENC = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder DEC = Base64.getUrlDecoder();

    private final SecretKeySpec key;

    public QrSigner(QrProperties props) {
        if (props.hmacKey() == null || props.hmacKey().isBlank()) {
            throw new IllegalStateException("cinebook.qr.hmac-key (QR_HMAC_KEY) must be set");
        }
        this.key = new SecretKeySpec(Base64.getDecoder().decode(props.hmacKey()), ALG);
    }

    public String sign(String payload) {
        byte[] data = payload.getBytes(StandardCharsets.UTF_8);
        return ENC.encodeToString(data) + "." + ENC.encodeToString(mac(data));
    }

    /** Returns the original payload if the signature is valid. */
    public Optional<String> verify(String token) {
        int dot = token.indexOf('.');
        if (dot <= 0 || dot == token.length() - 1) {
            return Optional.empty();
        }
        try {
            byte[] data = DEC.decode(token.substring(0, dot));
            byte[] sig = DEC.decode(token.substring(dot + 1));
            return MessageDigest.isEqual(mac(data), sig)
                    ? Optional.of(new String(data, StandardCharsets.UTF_8))
                    : Optional.empty();
        } catch (IllegalArgumentException e) {
            return Optional.empty();
        }
    }

    private byte[] mac(byte[] data) {
        try {
            Mac mac = Mac.getInstance(ALG);
            mac.init(key);
            return mac.doFinal(data);
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
}
