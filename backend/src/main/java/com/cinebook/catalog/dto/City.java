package com.cinebook.catalog.dto;

/** A city with at least one active cinema (Home city picker). */
public record City(String name, int cinemaCount) {
}
