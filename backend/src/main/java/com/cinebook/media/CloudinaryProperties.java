package com.cinebook.media;

import org.springframework.boot.context.properties.ConfigurationProperties;

/** @param url cloudinary://api_key:api_secret@cloud_name */
@ConfigurationProperties(prefix = "cinebook.cloudinary")
public record CloudinaryProperties(String url) {
}
