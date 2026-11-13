-- V001__extensions_and_schemas.sql
-- Baseline derived from docs/database/schema.sql: extensions and the single application schema.
-- Phase 0 intentionally creates no business tables.
-- btree_gist is required by later exclusion constraints (e.g. non-overlapping effective ranges).

CREATE EXTENSION IF NOT EXISTS btree_gist;

CREATE SCHEMA IF NOT EXISTS voltreckon;
