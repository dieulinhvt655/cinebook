-- Images bundled with the backend (src/main/resources/static/media, served at /media/**), used by
-- the demo catalogue so it works without a Cloudinary account. Their url is relative to the API
-- base (e.g. /media/posters/x.jpg); Cloudinary urls stay absolute. Existing rows are unchanged.
ALTER TABLE media_assets
    DROP CONSTRAINT media_assets_provider_check,
    ADD CONSTRAINT media_assets_provider_check CHECK (provider IN ('CLOUDINARY', 'STATIC'));
