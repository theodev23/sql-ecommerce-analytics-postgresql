-- ============================================================
-- Project: Mini E-commerce Data Warehouse with PostgreSQL
-- File: 05_create_staging.sql
-- Purpose: Create and populate the cleaned staging layer
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS staging.transactions (
    raw_row_id BIGINT PRIMARY KEY,

    invoice_no TEXT,
    stock_code TEXT,
    description TEXT,
    quantity INTEGER,
    invoice_date TIMESTAMP,
    unit_price NUMERIC(18, 4),
    customer_id INTEGER,
    country TEXT,

    line_amount NUMERIC(20, 4),

    is_cancelled BOOLEAN NOT NULL,
    is_stock_adjustment BOOLEAN NOT NULL,
    is_accounting_adjustment BOOLEAN NOT NULL,
    is_zero_price BOOLEAN NOT NULL,
    is_missing_customer BOOLEAN NOT NULL,
    is_missing_description BOOLEAN NOT NULL,
    is_positive_sale BOOLEAN NOT NULL,

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

    duplicate_rank BIGINT NOT NULL CHECK (duplicate_rank >= 1),
    duplicate_group_size BIGINT NOT NULL CHECK (duplicate_group_size >= 1),
    is_exact_duplicate BOOLEAN NOT NULL,
    is_first_occurrence BOOLEAN NOT NULL,

    source_file TEXT NOT NULL,
    raw_ingested_at TIMESTAMPTZ NOT NULL,
    staged_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE staging.transactions IS
    'Typed and classified transactional data derived from raw.online_retail.';

COMMENT ON COLUMN staging.transactions.raw_row_id IS
    'Logical lineage identifier referencing the corresponding raw source row.';

COMMENT ON COLUMN staging.transactions.line_amount IS
    'Signed line amount calculated as quantity multiplied by unit price.';

COMMENT ON COLUMN staging.transactions.record_type IS
    'Business classification assigned to the source transaction row.';

COMMENT ON COLUMN staging.transactions.duplicate_rank IS
    'Position of the row inside its exact source duplicate group.';

COMMENT ON COLUMN staging.transactions.duplicate_group_size IS
    'Number of rows sharing the same exact source business values.';

TRUNCATE TABLE staging.transactions;

WITH typed_rows AS (
    SELECT
        raw_row_id,

        NULLIF(BTRIM(invoice_no), '') AS invoice_no,
        NULLIF(BTRIM(stock_code), '') AS stock_code,
        NULLIF(BTRIM(description), '') AS description,

        NULLIF(BTRIM(quantity), '')::INTEGER AS quantity,
        NULLIF(BTRIM(invoice_date), '')::TIMESTAMP AS invoice_date,
        NULLIF(BTRIM(unit_price), '')::NUMERIC(18, 4) AS unit_price,
        NULLIF(BTRIM(customer_id), '')::INTEGER AS customer_id,

        NULLIF(BTRIM(country), '') AS country,

        source_file,
        ingested_at AS raw_ingested_at,

        ROW_NUMBER() OVER (
            PARTITION BY
                invoice_no,
                stock_code,
                description,
                quantity,
                invoice_date,
                unit_price,
                customer_id,
                country
            ORDER BY raw_row_id
        ) AS duplicate_rank,

        COUNT(*) OVER (
            PARTITION BY
                invoice_no,
                stock_code,
                description,
                quantity,
                invoice_date,
                unit_price,
                customer_id,
                country
        ) AS duplicate_group_size

    FROM raw.online_retail
),

classified_rows AS (
    SELECT
        raw_row_id,
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country,

        quantity::NUMERIC * unit_price AS line_amount,

        COALESCE(invoice_no LIKE 'C%', FALSE) AS is_cancelled,

        COALESCE(
            quantity < 0
            AND invoice_no NOT LIKE 'C%',
            FALSE
        ) AS is_stock_adjustment,

        COALESCE(unit_price < 0, FALSE) AS is_accounting_adjustment,
        COALESCE(unit_price = 0, FALSE) AS is_zero_price,
        customer_id IS NULL AS is_missing_customer,
        description IS NULL AS is_missing_description,

        COALESCE(
            invoice_no NOT LIKE 'C%'
            AND quantity > 0
            AND unit_price > 0,
            FALSE
        ) AS is_positive_sale,

        CASE
            WHEN invoice_no LIKE 'C%'
                THEN 'CANCELLATION'

            WHEN unit_price < 0
                THEN 'ACCOUNTING_ADJUSTMENT'

            WHEN quantity < 0
                THEN 'STOCK_ADJUSTMENT'

            WHEN unit_price = 0
                THEN 'ZERO_PRICE'

            WHEN quantity > 0 AND unit_price > 0
                THEN 'SALE'

            ELSE 'OTHER'
        END AS record_type,

        duplicate_rank,
        duplicate_group_size,
        duplicate_group_size > 1 AS is_exact_duplicate,
        duplicate_rank = 1 AS is_first_occurrence,

        source_file,
        raw_ingested_at

    FROM typed_rows
)

INSERT INTO staging.transactions (
    raw_row_id,
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    line_amount,
    is_cancelled,
    is_stock_adjustment,
    is_accounting_adjustment,
    is_zero_price,
    is_missing_customer,
    is_missing_description,
    is_positive_sale,
    record_type,
    duplicate_rank,
    duplicate_group_size,
    is_exact_duplicate,
    is_first_occurrence,
    source_file,
    raw_ingested_at
)
SELECT
    raw_row_id,
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    line_amount,
    is_cancelled,
    is_stock_adjustment,
    is_accounting_adjustment,
    is_zero_price,
    is_missing_customer,
    is_missing_description,
    is_positive_sale,
    record_type,
    duplicate_rank,
    duplicate_group_size,
    is_exact_duplicate,
    is_first_occurrence,
    source_file,
    raw_ingested_at
FROM classified_rows
ORDER BY raw_row_id;

COMMIT;
