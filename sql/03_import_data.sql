-- ============================================================
-- Project: Mini E-commerce Data Warehouse with PostgreSQL
-- File: 03_import_data.sql
-- Purpose: Load the Online Retail CSV into the raw layer
-- ============================================================

BEGIN;

-- Make the script safely rerunnable by removing any previous load.
TRUNCATE TABLE raw.online_retail RESTART IDENTITY;

-- \copy reads the local CSV file through the psql client.
\copy raw.online_retail (invoice_no, stock_code, description, quantity, invoice_date, unit_price, customer_id, country) FROM 'data/online_retail.csv' WITH (FORMAT CSV, HEADER TRUE, ENCODING 'UTF8');

COMMIT;
