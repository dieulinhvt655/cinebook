package com.cinebook.booking;

import java.security.SecureRandom;

/**
 * Ticket codes like {@code TK7K2M9XQ4PA}: "TK" + 10 characters without look-alikes. The QR that
 * carries a code is signed by {@link com.cinebook.ticket.TicketService}.
 */
final class TicketCodes {

    private static final String ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    private TicketCodes() {
    }

    static String next() {
        StringBuilder code = new StringBuilder("TK");
        for (int i = 0; i < 10; i++) {
            code.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
        }
        return code.toString();
    }
}
