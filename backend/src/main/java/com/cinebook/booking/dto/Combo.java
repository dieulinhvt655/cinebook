package com.cinebook.booking.dto;

/** A combo on sale. {@code imageUrl} may be null or relative. */
public record Combo(long id, String name, String description, int price, String imageUrl) {
}
