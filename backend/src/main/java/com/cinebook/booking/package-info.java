/**
 * Booking module: seat holds (POST /bookings), combos, cancel, hold expiry.
 * Double booking is prevented by the database (partial unique index), not by application locks.
 */
package com.cinebook.booking;
