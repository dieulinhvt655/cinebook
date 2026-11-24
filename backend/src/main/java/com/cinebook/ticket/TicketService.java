package com.cinebook.ticket;

import org.springframework.stereotype.Service;

/**
 * Signs what a QR carries: a seat's ticket code, or the booking code shown on S13 (one QR per
 * booking). Signed with QR_HMAC_KEY, so a forged code fails the check at the door.
 */
@Service
public class TicketService {

    private final QrSigner qrSigner;

    public TicketService(QrSigner qrSigner) {
        this.qrSigner = qrSigner;
    }

    /** The QR never exposes sequential ids, only the random ticket code plus an HMAC signature. */
    public String qrPayloadFor(String ticketCode) {
        return qrSigner.sign(ticketCode);
    }

    /** S13 shows one QR per booking; the door resolves the booking code to its seat tickets. */
    public String qrPayloadForBooking(String bookingCode) {
        return qrSigner.sign(bookingCode);
    }
}
