-- Two database roles (design doc 3.5). Local passwords only; production uses secrets.
CREATE ROLE cinebook_migrator LOGIN PASSWORD 'cinebook_migrator';
CREATE ROLE cinebook_app LOGIN PASSWORD 'cinebook_app';

-- Extensions need superuser on vanilla Postgres; create them up front for the migrator.
\connect cinebook
CREATE EXTENSION IF NOT EXISTS unaccent;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gist;

ALTER SCHEMA public OWNER TO cinebook_migrator;
GRANT USAGE ON SCHEMA public TO cinebook_app;
