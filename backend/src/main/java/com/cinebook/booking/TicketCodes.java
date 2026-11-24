package com.cinebook.booking;

import com.cinebook.security.JwtProperties;
import java.nio.charset.StandardCharsets;
import java.security.GeneralSecurityException;
import java.security.SecureRandom;
import java.util.Base64;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Component;

/**
 * Ticket codes ({@code TK} + 10 characters) and the signed QR payload {@code CINEBOOK:<code>.<sig>}.
 * The QR carries no sequential id, and a forged code fails the signature check at the door.
 * Signed with the server secret (JWT_SECRET) under its own "ticket:" prefix.
 */
@Component
class TicketCodes {

    private static final String ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    private final byte[] key;

    TicketCodes(JwtProperties jwt) {
        this.key = Base64.getDecoder().decode(jwt.secret());
    }

    String next() {
        StringBuilder code = new StringBuilder("TK");
        for (int i = 0; i < 10; i++) {
            code.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
        }
        return code.toString();
    }

    String qrPayload(String ticketCode) {
        return "CINEBOOK:" + ticketCode + "." + sign(ticketCode);
    }

    /** True if the payload was issued by this server. */
    boolean verify(String payload) {
        if (payload == null || !payload.startsWith("CINEBOOK:")) {
            return false;
        }
        String body = payload.substring("CINEBOOK:".length());
        int dot = body.indexOf('.');
        return dot > 0 && java.security.MessageDigest.isEqual(
                sign(body.substring(0, dot)).getBytes(StandardCharsets.US_ASCII),
                body.substring(dot + 1).getBytes(StandardCharsets.US_ASCII));
    }

    private String sign(String ticketCode) {
        try {
            Mac mac = Mac.getInstance("HmacSHA256");
            mac.init(new SecretKeySpec(key, "HmacSHA256"));
            byte[] sig = mac.doFinal(("ticket:" + ticketCode).getBytes(StandardCharsets.UTF_8));
            // 128 bits is plenty for a door check and keeps the QR small.
            return Base64.getUrlEncoder().withoutPadding().encodeToString(java.util.Arrays.copyOf(sig, 16));
        } catch (GeneralSecurityException e) {
            throw new IllegalStateException(e);
        }
    }
}
