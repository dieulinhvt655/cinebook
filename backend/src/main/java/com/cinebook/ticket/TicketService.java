package com.cinebook.ticket;

import org.springframework.stereotype.Service;

/** Issues one ticket per booked seat once a booking is PAID; QR payload = signed ticket code. */
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
}
