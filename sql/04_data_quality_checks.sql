-- ============================================================
-- Project: Mini E-commerce Data Warehouse with PostgreSQL
-- File: 04_data_quality_checks.sql
-- Purpose: Profile the raw dataset before cleaning
-- ============================================================

\pset pager off
\timing on

\echo ''
\echo '1. GENERAL ROW COUNT'
SELECT
    COUNT(*) AS total_raw_rows
FROM raw.online_retail;

\echo ''
\echo '2. DISTINCT BUSINESS VALUES'
SELECT
    COUNT(DISTINCT invoice_no) AS distinct_invoices,
    COUNT(DISTINCT stock_code) AS distinct_products,
    COUNT(DISTINCT customer_id) AS distinct_customers,
    COUNT(DISTINCT country) AS distinct_countries
FROM raw.online_retail;

\echo ''
\echo '3. MISSING OR BLANK VALUES'
SELECT
    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(invoice_no), '') IS NULL
    ) AS missing_invoice_no,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(stock_code), '') IS NULL
    ) AS missing_stock_code,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(description), '') IS NULL
    ) AS missing_description,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(quantity), '') IS NULL
    ) AS missing_quantity,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(invoice_date), '') IS NULL
    ) AS missing_invoice_date,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(unit_price), '') IS NULL
    ) AS missing_unit_price,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(customer_id), '') IS NULL
    ) AS missing_customer_id,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(country), '') IS NULL
    ) AS missing_country
FROM raw.online_retail;

\echo ''
\echo '4. INVALID DATA FORMATS'
SELECT
    COUNT(*) FILTER (
        WHERE quantity IS NOT NULL
          AND quantity !~ '^[+-]?[0-9]+$'
    ) AS invalid_quantity_format,

    COUNT(*) FILTER (
        WHERE unit_price IS NOT NULL
          AND unit_price !~ '^[+-]?[0-9]+(\.[0-9]+)?$'
    ) AS invalid_unit_price_format,

    COUNT(*) FILTER (
        WHERE customer_id IS NOT NULL
          AND customer_id !~ '^[0-9]+$'
    ) AS invalid_customer_id_format,

    COUNT(*) FILTER (
        WHERE invoice_date IS NOT NULL
          AND invoice_date !~
              '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$'
    ) AS invalid_invoice_date_format
FROM raw.online_retail;

\echo ''
\echo '5. BUSINESS ANOMALIES'
WITH parsed_values AS (
    SELECT
        invoice_no,
        description,
        customer_id,

        CASE
            WHEN quantity ~ '^[+-]?[0-9]+$'
            THEN quantity::INTEGER
        END AS quantity_value,

        CASE
            WHEN unit_price ~ '^[+-]?[0-9]+(\.[0-9]+)?$'
            THEN unit_price::NUMERIC
        END AS unit_price_value

    FROM raw.online_retail
)
SELECT
    COUNT(*) FILTER (
        WHERE quantity_value < 0
    ) AS negative_quantity_rows,

    COUNT(*) FILTER (
        WHERE quantity_value = 0
    ) AS zero_quantity_rows,

    COUNT(*) FILTER (
        WHERE unit_price_value < 0
    ) AS negative_unit_price_rows,

    COUNT(*) FILTER (
        WHERE unit_price_value = 0
    ) AS zero_unit_price_rows,

    COUNT(*) FILTER (
        WHERE invoice_no LIKE 'C%'
    ) AS cancelled_invoice_rows,

    COUNT(DISTINCT invoice_no) FILTER (
        WHERE invoice_no LIKE 'C%'
    ) AS distinct_cancelled_invoices,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(customer_id), '') IS NULL
    ) AS rows_without_customer,

    COUNT(*) FILTER (
        WHERE NULLIF(BTRIM(description), '') IS NULL
    ) AS rows_without_description
FROM parsed_values;

\echo ''
\echo '6. SOURCE DATE RANGE'
SELECT
    MIN(invoice_date::TIMESTAMP) AS first_transaction_date,
    MAX(invoice_date::TIMESTAMP) AS last_transaction_date
FROM raw.online_retail
WHERE invoice_date ~
    '^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}$';

\echo ''
\echo '7. EXACT SOURCE DUPLICATES'
WITH duplicate_groups AS (
    SELECT
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country,
        COUNT(*) AS occurrence_count
    FROM raw.online_retail
    GROUP BY
        invoice_no,
        stock_code,
        description,
        quantity,
        invoice_date,
        unit_price,
        customer_id,
        country
    HAVING COUNT(*) > 1
)
SELECT
    COUNT(*) AS duplicate_groups,
    COALESCE(SUM(occurrence_count), 0) AS rows_in_duplicate_groups,
    COALESCE(SUM(occurrence_count - 1), 0) AS excess_duplicate_rows
FROM duplicate_groups;

\echo ''
\echo '8. COUNTRIES WITH THE MOST ROWS'
SELECT
    country,
    COUNT(*) AS row_count
FROM raw.online_retail
GROUP BY country
ORDER BY row_count DESC
LIMIT 10;

\echo ''
\echo '9. CANCELLATION AND NEGATIVE QUANTITY CONSISTENCY'
SELECT
    COUNT(*) FILTER (
        WHERE invoice_no LIKE 'C%'
          AND quantity::INTEGER < 0
    ) AS cancelled_with_negative_quantity,

    COUNT(*) FILTER (
        WHERE invoice_no LIKE 'C%'
          AND quantity::INTEGER >= 0
    ) AS cancelled_without_negative_quantity,

    COUNT(*) FILTER (
        WHERE invoice_no NOT LIKE 'C%'
          AND quantity::INTEGER < 0
    ) AS negative_quantity_without_cancel_prefix
FROM raw.online_retail;

\echo ''
\echo '10. TOP NEGATIVE QUANTITIES WITHOUT CANCELLATION PREFIX'
SELECT
    stock_code,
    COALESCE(NULLIF(BTRIM(description), ''), '[missing]') AS description,
    COUNT(*) AS row_count,
    SUM(quantity::INTEGER) AS total_quantity
FROM raw.online_retail
WHERE quantity::INTEGER < 0
  AND invoice_no NOT LIKE 'C%'
GROUP BY
    stock_code,
    COALESCE(NULLIF(BTRIM(description), ''), '[missing]')
ORDER BY
    row_count DESC,
    total_quantity ASC
LIMIT 15;

\echo ''
\echo '11. NEGATIVE UNIT PRICE ROWS'
SELECT
    raw_row_id,
    invoice_no,
    stock_code,
    description,
    quantity,
    unit_price,
    customer_id,
    country
FROM raw.online_retail
WHERE unit_price::NUMERIC < 0
ORDER BY raw_row_id;

\echo ''
\echo '12. TOP ZERO-PRICE PRODUCTS'
SELECT
    stock_code,
    COALESCE(NULLIF(BTRIM(description), ''), '[missing]') AS description,
    COUNT(*) AS row_count,
    SUM(quantity::INTEGER) AS total_quantity
FROM raw.online_retail
WHERE unit_price::NUMERIC = 0
GROUP BY
    stock_code,
    COALESCE(NULLIF(BTRIM(description), ''), '[missing]')
ORDER BY row_count DESC
LIMIT 15;

\echo ''
\echo '13. MISSING CUSTOMER PROFILE'
SELECT
    COUNT(*) AS total_rows_without_customer,

    COUNT(DISTINCT invoice_no) AS invoices_without_customer,

    COUNT(*) FILTER (
        WHERE invoice_no NOT LIKE 'C%'
          AND quantity::INTEGER > 0
          AND unit_price::NUMERIC > 0
    ) AS positive_sales_rows_without_customer,

    ROUND(
        SUM(quantity::NUMERIC * unit_price::NUMERIC) FILTER (
            WHERE invoice_no NOT LIKE 'C%'
              AND quantity::INTEGER > 0
              AND unit_price::NUMERIC > 0
        ),
        2
    ) AS positive_revenue_without_customer,

    COUNT(*) FILTER (
        WHERE invoice_no LIKE 'C%'
    ) AS cancelled_rows_without_customer,

    COUNT(*) FILTER (
        WHERE quantity::INTEGER < 0
    ) AS negative_quantity_rows_without_customer,

    COUNT(*) FILTER (
        WHERE unit_price::NUMERIC = 0
    ) AS zero_price_rows_without_customer
FROM raw.online_retail
WHERE NULLIF(BTRIM(customer_id), '') IS NULL;

\echo ''
\echo '14. EXACT DUPLICATE EXAMPLES'
SELECT
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country,
    COUNT(*) AS occurrence_count
FROM raw.online_retail
GROUP BY
    invoice_no,
    stock_code,
    description,
    quantity,
    invoice_date,
    unit_price,
    customer_id,
    country
HAVING COUNT(*) > 1
ORDER BY
    occurrence_count DESC,
    invoice_no,
    stock_code
LIMIT 15;
