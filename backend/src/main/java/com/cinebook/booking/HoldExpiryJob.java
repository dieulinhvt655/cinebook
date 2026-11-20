package com.cinebook.booking;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

@Component
public class HoldExpiryJob {

    private static final Logger log = LoggerFactory.getLogger(HoldExpiryJob.class);

    private final HoldExpiryService holdExpiryService;

    public HoldExpiryJob(HoldExpiryService holdExpiryService) {
        this.holdExpiryService = holdExpiryService;
    }

    @Scheduled(fixedDelayString = "${cinebook.booking.expiry-job-interval}")
    public void run() {
        int expired = holdExpiryService.expireOverdueHolds();
        if (expired > 0) {
            log.info("Expired {} seat hold(s)", expired);
        }
    }
}
