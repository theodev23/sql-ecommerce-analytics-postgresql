-- ============================================================
-- Project: Mini E-commerce Data Warehouse with PostgreSQL
-- File: 10_validate_pipeline.sql
-- Purpose: Validate pipeline row counts and data integrity
-- ============================================================

\pset pager off
\timing on

\echo ''
\echo 'PIPELINE VALIDATION'

DO $$
DECLARE
    raw_count BIGINT;
    staging_count BIGINT;
    expected_fact_count BIGINT;
    actual_fact_count BIGINT;
    normalized_product_count BIGINT;
    orphan_count BIGINT;
BEGIN
    SELECT COUNT(*)
    INTO raw_count
    FROM raw.online_retail;

    SELECT COUNT(*)
    INTO staging_count
    FROM staging.transactions;

    SELECT COUNT(*)
    INTO expected_fact_count
    FROM staging.transactions
    WHERE is_first_occurrence = TRUE;

    SELECT COUNT(*)
    INTO actual_fact_count
    FROM warehouse.fact_sales;

    SELECT COUNT(DISTINCT stock_code)
    INTO normalized_product_count
    FROM staging.transactions
    WHERE stock_code IS NOT NULL;

    IF raw_count <> 541909 THEN
        RAISE EXCEPTION
            'Unexpected raw row count: %, expected 541909',
            raw_count;
    END IF;

    IF staging_count <> raw_count THEN
        RAISE EXCEPTION
            'Raw/staging reconciliation failed: raw=%, staging=%',
            raw_count,
            staging_count;
    END IF;

    IF actual_fact_count <> expected_fact_count THEN
        RAISE EXCEPTION
            'Staging/fact reconciliation failed: expected=%, actual=%',
            expected_fact_count,
            actual_fact_count;
    END IF;

    IF normalized_product_count <> 3958 THEN
        RAISE EXCEPTION
            'Unexpected normalized product count: %, expected 3958',
            normalized_product_count;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM staging.transactions
        WHERE stock_code <> UPPER(stock_code)
    ) THEN
        RAISE EXCEPTION
            'Some staging product codes are not normalized to uppercase.';
    END IF;

    IF EXISTS (
        SELECT raw_row_id
        FROM warehouse.fact_sales
        GROUP BY raw_row_id
        HAVING COUNT(*) > 1
    ) THEN
        RAISE EXCEPTION
            'Duplicate raw_row_id values detected in fact_sales.';
    END IF;

    SELECT COUNT(*)
    INTO orphan_count
    FROM warehouse.fact_sales AS fact
    LEFT JOIN warehouse.dim_date AS dim_date
        ON dim_date.date_key = fact.date_key
    LEFT JOIN warehouse.dim_customer AS dim_customer
        ON dim_customer.customer_key = fact.customer_key
    LEFT JOIN warehouse.dim_product AS dim_product
        ON dim_product.product_key = fact.product_key
    LEFT JOIN warehouse.dim_country AS dim_country
        ON dim_country.country_key = fact.country_key
    WHERE dim_date.date_key IS NULL
       OR dim_customer.customer_key IS NULL
       OR dim_product.product_key IS NULL
       OR dim_country.country_key IS NULL;

    IF orphan_count <> 0 THEN
        RAISE EXCEPTION
            'Fact table contains % orphan dimension references.',
            orphan_count;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM warehouse.dim_customer
        WHERE customer_key = 0
          AND is_unknown = TRUE
    ) THEN
        RAISE EXCEPTION
            'Unknown customer dimension member is missing.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM warehouse.dim_product
        WHERE product_key = 0
          AND is_unknown = TRUE
    ) THEN
        RAISE EXCEPTION
            'Unknown product dimension member is missing.';
    END IF;

    RAISE NOTICE
        'Validation successful: raw=%, staging=%, fact=%, normalized products=%',
        raw_count,
        staging_count,
        actual_fact_count,
        normalized_product_count;
END
$$;

\echo ''
\echo 'ROW COUNT SUMMARY'

SELECT
    (SELECT COUNT(*) FROM raw.online_retail) AS raw_rows,
    (SELECT COUNT(*) FROM staging.transactions) AS staging_rows,
    (SELECT COUNT(*) FROM warehouse.fact_sales) AS fact_rows,
    (SELECT COUNT(*) FROM warehouse.dim_customer) AS customer_dimension_rows,
    (SELECT COUNT(*) FROM warehouse.dim_product) AS product_dimension_rows,
    (SELECT COUNT(*) FROM warehouse.dim_country) AS country_dimension_rows,
    (SELECT COUNT(*) FROM warehouse.dim_date) AS date_dimension_rows;

\echo ''
\echo 'VALIDATION COMPLETED SUCCESSFULLY'
