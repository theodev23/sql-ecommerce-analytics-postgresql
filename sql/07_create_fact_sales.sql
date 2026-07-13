-- ============================================================
-- Project: Mini E-commerce Data Warehouse with PostgreSQL
-- File: 07_create_fact_sales.sql
-- Purpose: Create and populate the central transaction fact table
-- Grain: One deduplicated source transaction line
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS warehouse.fact_sales (
    sales_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    raw_row_id BIGINT NOT NULL UNIQUE,

    date_key INTEGER NOT NULL,
    customer_key BIGINT NOT NULL,
    product_key BIGINT NOT NULL,
    country_key BIGINT NOT NULL,

    invoice_no TEXT NOT NULL,
    invoice_timestamp TIMESTAMP NOT NULL,

    quantity INTEGER NOT NULL,
    unit_price NUMERIC(18, 4) NOT NULL,
    line_amount NUMERIC(20, 4) NOT NULL,

    record_type TEXT NOT NULL CHECK (
        record_type IN (
            'SALE',
            'CANCELLATION',
            'STOCK_ADJUSTMENT',
            'ACCOUNTING_ADJUSTMENT',
            'ZERO_PRICE',
            'OTHER'
        )
    ),

    is_cancelled BOOLEAN NOT NULL,
    is_stock_adjustment BOOLEAN NOT NULL,
    is_accounting_adjustment BOOLEAN NOT NULL,
    is_zero_price BOOLEAN NOT NULL,
    is_missing_customer BOOLEAN NOT NULL,
    is_missing_description BOOLEAN NOT NULL,
    is_positive_sale BOOLEAN NOT NULL,

    source_duplicate_group_size BIGINT NOT NULL
        CHECK (source_duplicate_group_size >= 1),

    source_file TEXT NOT NULL,
    raw_ingested_at TIMESTAMPTZ NOT NULL,
    warehouse_loaded_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT fact_sales_date_fk
        FOREIGN KEY (date_key)
        REFERENCES warehouse.dim_date (date_key),

    CONSTRAINT fact_sales_customer_fk
        FOREIGN KEY (customer_key)
        REFERENCES warehouse.dim_customer (customer_key),

    CONSTRAINT fact_sales_product_fk
        FOREIGN KEY (product_key)
        REFERENCES warehouse.dim_product (product_key),

    CONSTRAINT fact_sales_country_fk
        FOREIGN KEY (country_key)
        REFERENCES warehouse.dim_country (country_key)
);

COMMENT ON TABLE warehouse.fact_sales IS
    'Central fact table containing one row per deduplicated transaction line.';

COMMENT ON COLUMN warehouse.fact_sales.sales_key IS
    'Warehouse surrogate key identifying the fact row.';

COMMENT ON COLUMN warehouse.fact_sales.raw_row_id IS
    'Identifier of the retained staging and raw source row.';

COMMENT ON COLUMN warehouse.fact_sales.invoice_no IS
    'Degenerate dimension containing the source invoice identifier.';

COMMENT ON COLUMN warehouse.fact_sales.line_amount IS
    'Signed amount calculated as quantity multiplied by unit price.';

COMMENT ON COLUMN warehouse.fact_sales.source_duplicate_group_size IS
    'Number of exact source occurrences represented by the retained row.';

TRUNCATE TABLE warehouse.fact_sales RESTART IDENTITY;

INSERT INTO warehouse.fact_sales (
    raw_row_id,
    date_key,
    customer_key,
    product_key,
    country_key,
    invoice_no,
    invoice_timestamp,
    quantity,
    unit_price,
    line_amount,
    record_type,
    is_cancelled,
    is_stock_adjustment,
    is_accounting_adjustment,
    is_zero_price,
    is_missing_customer,
    is_missing_description,
    is_positive_sale,
    source_duplicate_group_size,
    source_file,
    raw_ingested_at
)
SELECT
    staging.raw_row_id,

    COALESCE(date_dimension.date_key, 0) AS date_key,
    COALESCE(customer_dimension.customer_key, 0) AS customer_key,
    COALESCE(product_dimension.product_key, 0) AS product_key,
    COALESCE(country_dimension.country_key, 0) AS country_key,

    staging.invoice_no,
    staging.invoice_date AS invoice_timestamp,
    staging.quantity,
    staging.unit_price,
    staging.line_amount,
    staging.record_type,
    staging.is_cancelled,
    staging.is_stock_adjustment,
    staging.is_accounting_adjustment,
    staging.is_zero_price,
    staging.is_missing_customer,
    staging.is_missing_description,
    staging.is_positive_sale,
    staging.duplicate_group_size AS source_duplicate_group_size,
    staging.source_file,
    staging.raw_ingested_at

FROM staging.transactions AS staging

LEFT JOIN warehouse.dim_date AS date_dimension
    ON date_dimension.full_date = staging.invoice_date::DATE
   AND date_dimension.is_unknown = FALSE

LEFT JOIN warehouse.dim_customer AS customer_dimension
    ON customer_dimension.customer_id = staging.customer_id
   AND customer_dimension.is_unknown = FALSE

LEFT JOIN warehouse.dim_product AS product_dimension
    ON product_dimension.stock_code = staging.stock_code
   AND product_dimension.is_unknown = FALSE

LEFT JOIN warehouse.dim_country AS country_dimension
    ON country_dimension.country_name = staging.country
   AND country_dimension.is_unknown = FALSE

WHERE staging.is_first_occurrence = TRUE

ORDER BY staging.raw_row_id;

-- Indexes supporting the most common analytical joins and filters.

CREATE INDEX IF NOT EXISTS fact_sales_date_key_idx
    ON warehouse.fact_sales (date_key);

CREATE INDEX IF NOT EXISTS fact_sales_customer_key_idx
    ON warehouse.fact_sales (customer_key);

CREATE INDEX IF NOT EXISTS fact_sales_product_key_idx
    ON warehouse.fact_sales (product_key);

CREATE INDEX IF NOT EXISTS fact_sales_country_key_idx
    ON warehouse.fact_sales (country_key);

CREATE INDEX IF NOT EXISTS fact_sales_invoice_no_idx
    ON warehouse.fact_sales (invoice_no);

CREATE INDEX IF NOT EXISTS fact_sales_record_type_idx
    ON warehouse.fact_sales (record_type);

COMMIT;
