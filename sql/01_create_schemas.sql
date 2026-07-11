-- ============================================================
-- Project: Mini E-commerce Data Warehouse with PostgreSQL
-- File: 01_create_schemas.sql
-- Purpose: Create the logical layers of the data warehouse
-- ============================================================

-- Raw layer:
-- Stores source data as close as possible to its original format.
CREATE SCHEMA IF NOT EXISTS raw;

-- Staging layer:
-- Stores cleaned, standardized and enriched transactional data.
CREATE SCHEMA IF NOT EXISTS staging;

-- Warehouse layer:
-- Stores dimensions and fact tables used for analytical queries.
CREATE SCHEMA IF NOT EXISTS warehouse;

-- Analytics layer:
-- Stores reusable business views and KPI calculations.
CREATE SCHEMA IF NOT EXISTS analytics;

COMMENT ON SCHEMA raw IS
    'Raw source data imported without business transformations.';

COMMENT ON SCHEMA staging IS
    'Cleaned and standardized intermediary data.';

COMMENT ON SCHEMA warehouse IS
    'Dimensional model containing dimensions and fact tables.';

COMMENT ON SCHEMA analytics IS
    'Business views and analytical indicators.';
