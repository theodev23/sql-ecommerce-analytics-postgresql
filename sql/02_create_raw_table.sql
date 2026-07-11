-- ============================================================
-- Project: Mini E-commerce Data Warehouse with PostgreSQL
-- File: 02_create_raw_table.sql
-- Purpose: Create the table used to store the source CSV data
-- ============================================================

CREATE TABLE IF NOT EXISTS raw.online_retail (
    raw_row_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    invoice_no TEXT,
    stock_code TEXT,
    description TEXT,
    quantity TEXT,
    invoice_date TEXT,
    unit_price TEXT,
    customer_id TEXT,
    country TEXT,

    source_file TEXT NOT NULL DEFAULT 'online_retail.csv',
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE raw.online_retail IS
    'Raw Online Retail source data imported from the CSV file.';

COMMENT ON COLUMN raw.online_retail.raw_row_id IS
    'Technical identifier generated during ingestion.';

COMMENT ON COLUMN raw.online_retail.source_file IS
    'Name of the source file used during ingestion.';

COMMENT ON COLUMN raw.online_retail.ingested_at IS
    'Timestamp indicating when the row was loaded into PostgreSQL.';
