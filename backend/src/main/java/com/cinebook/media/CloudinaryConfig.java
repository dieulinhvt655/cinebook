package com.cinebook.media;

import com.cloudinary.Cloudinary;
import org.springframework.boot.autoconfigure.condition.ConditionalOnExpression;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Posters, banners and combo images live on Cloudinary; the DB stores only public_id + url
 * (media_assets). The app loads images straight from Cloudinary's CDN. Admin uploads go through
 * POST /admin/media. Disabled when CLOUDINARY_URL is not set.
 */
@Configuration
@ConditionalOnExpression("!'${cinebook.cloudinary.url:}'.isBlank()")
public class CloudinaryConfig {

    @Bean
    Cloudinary cloudinary(CloudinaryProperties props) {
        Cloudinary cloudinary = new Cloudinary(props.url());
        cloudinary.config.secure = true;
        return cloudinary;
    }
}
