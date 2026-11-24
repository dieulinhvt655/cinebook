package com.cinebook.booking;

import java.security.SecureRandom;

/** Booking codes like {@code CB7K2M9X}: "CB" + 6 characters without look-alikes (0/O, 1/I/L). */
final class BookingCodes {

    private static final String ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
    private static final SecureRandom RANDOM = new SecureRandom();

    private BookingCodes() {
    }

    static String next() {
        StringBuilder code = new StringBuilder("CB");
        for (int i = 0; i < 6; i++) {
            code.append(ALPHABET.charAt(RANDOM.nextInt(ALPHABET.length())));
        }
        return code.toString();
    }
}
