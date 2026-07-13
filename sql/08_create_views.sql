-- ============================================================
-- Project: Mini E-commerce Data Warehouse with PostgreSQL
-- File: 08_create_views.sql
-- Purpose: Create reusable analytical views and business KPIs
-- ============================================================

BEGIN;

-- Drop dependent views first to keep the script rerunnable.
DROP VIEW IF EXISTS analytics.v_customer_kpis;
DROP VIEW IF EXISTS analytics.v_product_kpis;
DROP VIEW IF EXISTS analytics.v_country_kpis;
DROP VIEW IF EXISTS analytics.v_monthly_kpis;
DROP VIEW IF EXISTS analytics.v_kpi_overview;
DROP VIEW IF EXISTS analytics.v_order_summary;
DROP VIEW IF EXISTS analytics.v_sales_enriched;

-- ------------------------------------------------------------
-- Enriched sales detail
-- ------------------------------------------------------------

CREATE VIEW analytics.v_sales_enriched AS
SELECT
    fact.sales_key,
    fact.raw_row_id,

    fact.date_key,
    date_dimension.full_date,
    date_dimension.calendar_year,
    date_dimension.calendar_quarter,
    date_dimension.month_number,
    date_dimension.month_name,
    date_dimension.year_month,
    date_dimension.week_of_year,
    date_dimension.day_of_week,
    date_dimension.day_name,
    date_dimension.is_weekend,

    fact.customer_key,
    customer_dimension.customer_id,

    fact.product_key,
    product_dimension.stock_code,
    product_dimension.product_description,

    fact.country_key,
    country_dimension.country_name,

    fact.invoice_no,
    fact.invoice_timestamp,
    fact.quantity,
    fact.unit_price,
    fact.line_amount,

    fact.record_type,
    fact.is_cancelled,
    fact.is_stock_adjustment,
    fact.is_accounting_adjustment,
    fact.is_zero_price,
    fact.is_missing_customer,
    fact.is_missing_description,
    fact.is_positive_sale,

    fact.source_duplicate_group_size,
    fact.source_file,
    fact.raw_ingested_at,
    fact.warehouse_loaded_at

FROM warehouse.fact_sales AS fact

INNER JOIN warehouse.dim_date AS date_dimension
    ON date_dimension.date_key = fact.date_key

INNER JOIN warehouse.dim_customer AS customer_dimension
    ON customer_dimension.customer_key = fact.customer_key

INNER JOIN warehouse.dim_product AS product_dimension
    ON product_dimension.product_key = fact.product_key

INNER JOIN warehouse.dim_country AS country_dimension
    ON country_dimension.country_key = fact.country_key;

COMMENT ON VIEW analytics.v_sales_enriched IS
    'Fact sales enriched with customer, product, country and calendar attributes.';

-- ------------------------------------------------------------
-- One row per positive customer order
-- ------------------------------------------------------------

CREATE VIEW analytics.v_order_summary AS
SELECT
    invoice_no,

    customer_key,
    customer_id,

    country_key,
    country_name,

    MIN(date_key) AS date_key,
    MIN(invoice_timestamp) AS order_timestamp,

    COUNT(*) AS line_count,
    COUNT(DISTINCT product_key) AS distinct_product_count,

    SUM(quantity) AS order_quantity,
    ROUND(SUM(line_amount), 4) AS order_revenue

FROM analytics.v_sales_enriched

WHERE is_positive_sale = TRUE

GROUP BY
    invoice_no,
    customer_key,
    customer_id,
    country_key,
    country_name;

COMMENT ON VIEW analytics.v_order_summary IS
    'One row per positive sales invoice, used for order-level KPIs.';

-- ------------------------------------------------------------
-- Overall business KPI summary
-- ------------------------------------------------------------

CREATE VIEW analytics.v_kpi_overview AS
SELECT
    COUNT(*) FILTER (
        WHERE is_positive_sale
    ) AS positive_sale_lines,

    COUNT(DISTINCT invoice_no) FILTER (
        WHERE is_positive_sale
    ) AS positive_order_count,

    COUNT(DISTINCT invoice_no) FILTER (
        WHERE is_cancelled
    ) AS cancelled_invoice_count,

    COUNT(DISTINCT customer_key) FILTER (
        WHERE is_positive_sale
          AND customer_key <> 0
    ) AS identified_customer_count,

    COUNT(DISTINCT country_key) FILTER (
        WHERE is_positive_sale
          AND country_key <> 0
    ) AS sales_country_count,

    COALESCE(
        SUM(quantity) FILTER (
            WHERE is_positive_sale
        ),
        0
    ) AS sold_quantity,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE is_positive_sale
            ),
            0
        ),
        2
    ) AS gross_revenue,

    ROUND(
        ABS(
            COALESCE(
                SUM(line_amount) FILTER (
                    WHERE is_cancelled
                ),
                0
            )
        ),
        2
    ) AS cancellation_amount,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE record_type IN ('SALE', 'CANCELLATION')
            ),
            0
        ),
        2
    ) AS net_revenue,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE is_positive_sale
            ),
            0
        )
        /
        NULLIF(
            COUNT(DISTINCT invoice_no) FILTER (
                WHERE is_positive_sale
            ),
            0
        ),
        2
    ) AS average_order_value,

    ROUND(
        100.0
        *
        COUNT(DISTINCT invoice_no) FILTER (
            WHERE is_cancelled
        )
        /
        NULLIF(
            COUNT(DISTINCT invoice_no) FILTER (
                WHERE is_positive_sale
            )
            +
            COUNT(DISTINCT invoice_no) FILTER (
                WHERE is_cancelled
            ),
            0
        ),
        2
    ) AS cancellation_invoice_rate_pct

FROM analytics.v_sales_enriched;

COMMENT ON VIEW analytics.v_kpi_overview IS
    'Single-row overview containing the main e-commerce business KPIs.';

-- ------------------------------------------------------------
-- Monthly KPIs
-- ------------------------------------------------------------

CREATE VIEW analytics.v_monthly_kpis AS
SELECT
    year_month,
    calendar_year,
    month_number,
    month_name,
    MIN(full_date) AS month_start,

    COUNT(DISTINCT invoice_no) FILTER (
        WHERE is_positive_sale
    ) AS positive_order_count,

    COUNT(DISTINCT invoice_no) FILTER (
        WHERE is_cancelled
    ) AS cancelled_invoice_count,

    COALESCE(
        SUM(quantity) FILTER (
            WHERE is_positive_sale
        ),
        0
    ) AS sold_quantity,

    ABS(
        COALESCE(
            SUM(quantity) FILTER (
                WHERE is_cancelled
            ),
            0
        )
    ) AS cancelled_quantity,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE is_positive_sale
            ),
            0
        ),
        2
    ) AS gross_revenue,

    ROUND(
        ABS(
            COALESCE(
                SUM(line_amount) FILTER (
                    WHERE is_cancelled
                ),
                0
            )
        ),
        2
    ) AS cancellation_amount,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE record_type IN ('SALE', 'CANCELLATION')
            ),
            0
        ),
        2
    ) AS net_revenue,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE is_positive_sale
            ),
            0
        )
        /
        NULLIF(
            COUNT(DISTINCT invoice_no) FILTER (
                WHERE is_positive_sale
            ),
            0
        ),
        2
    ) AS average_order_value,

    ROUND(
        100.0
        *
        COUNT(DISTINCT invoice_no) FILTER (
            WHERE is_cancelled
        )
        /
        NULLIF(
            COUNT(DISTINCT invoice_no) FILTER (
                WHERE is_positive_sale
            )
            +
            COUNT(DISTINCT invoice_no) FILTER (
                WHERE is_cancelled
            ),
            0
        ),
        2
    ) AS cancellation_invoice_rate_pct

FROM analytics.v_sales_enriched

GROUP BY
    year_month,
    calendar_year,
    month_number,
    month_name

ORDER BY year_month;

COMMENT ON VIEW analytics.v_monthly_kpis IS
    'Monthly sales, cancellation, order and average basket indicators.';

-- ------------------------------------------------------------
-- Country KPIs
-- ------------------------------------------------------------

CREATE VIEW analytics.v_country_kpis AS
SELECT
    country_key,
    country_name,

    COUNT(DISTINCT invoice_no) FILTER (
        WHERE is_positive_sale
    ) AS positive_order_count,

    COUNT(DISTINCT customer_key) FILTER (
        WHERE is_positive_sale
          AND customer_key <> 0
    ) AS identified_customer_count,

    COALESCE(
        SUM(quantity) FILTER (
            WHERE is_positive_sale
        ),
        0
    ) AS sold_quantity,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE is_positive_sale
            ),
            0
        ),
        2
    ) AS gross_revenue,

    ROUND(
        ABS(
            COALESCE(
                SUM(line_amount) FILTER (
                    WHERE is_cancelled
                ),
                0
            )
        ),
        2
    ) AS cancellation_amount,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE record_type IN ('SALE', 'CANCELLATION')
            ),
            0
        ),
        2
    ) AS net_revenue,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE is_positive_sale
            ),
            0
        )
        /
        NULLIF(
            COUNT(DISTINCT invoice_no) FILTER (
                WHERE is_positive_sale
            ),
            0
        ),
        2
    ) AS average_order_value

FROM analytics.v_sales_enriched

GROUP BY
    country_key,
    country_name;

COMMENT ON VIEW analytics.v_country_kpis IS
    'Sales and cancellation indicators grouped by country.';

-- ------------------------------------------------------------
-- Product KPIs
-- ------------------------------------------------------------

CREATE VIEW analytics.v_product_kpis AS
SELECT
    product_key,
    stock_code,
    product_description,

    COUNT(DISTINCT invoice_no) FILTER (
        WHERE is_positive_sale
    ) AS positive_order_count,

    COUNT(DISTINCT invoice_no) FILTER (
        WHERE is_cancelled
    ) AS cancellation_invoice_count,

    COALESCE(
        SUM(quantity) FILTER (
            WHERE is_positive_sale
        ),
        0
    ) AS sold_quantity,

    ABS(
        COALESCE(
            SUM(quantity) FILTER (
                WHERE is_cancelled
            ),
            0
        )
    ) AS cancelled_quantity,

    ABS(
        COALESCE(
            SUM(quantity) FILTER (
                WHERE is_stock_adjustment
            ),
            0
        )
    ) AS stock_adjustment_quantity,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE is_positive_sale
            ),
            0
        ),
        2
    ) AS gross_revenue,

    ROUND(
        ABS(
            COALESCE(
                SUM(line_amount) FILTER (
                    WHERE is_cancelled
                ),
                0
            )
        ),
        2
    ) AS cancellation_amount,

    ROUND(
        COALESCE(
            SUM(line_amount) FILTER (
                WHERE record_type IN ('SALE', 'CANCELLATION')
            ),
            0
        ),
        2
    ) AS net_revenue,

    ROUND(
        100.0
        *
        ABS(
            COALESCE(
                SUM(quantity) FILTER (
                    WHERE is_cancelled
                ),
                0
            )
        )
        /
        NULLIF(
            SUM(quantity) FILTER (
                WHERE is_positive_sale
            ),
            0
        ),
        2
    ) AS cancelled_units_pct_of_sold

FROM analytics.v_sales_enriched

WHERE product_key <> 0

GROUP BY
    product_key,
    stock_code,
    product_description;

COMMENT ON VIEW analytics.v_product_kpis IS
    'Sales, returns and stock-adjustment indicators grouped by product.';

-- ------------------------------------------------------------
-- Customer KPIs
-- ------------------------------------------------------------

CREATE VIEW analytics.v_customer_kpis AS
SELECT
    customer_key,
    customer_id,

    MIN(order_timestamp) AS first_order_timestamp,
    MAX(order_timestamp) AS last_order_timestamp,

    COUNT(*) AS order_count,
    COUNT(DISTINCT order_timestamp::DATE) AS active_purchase_days,
    COUNT(DISTINCT country_key) AS country_count,

    SUM(order_quantity) AS purchased_quantity,

    ROUND(
        SUM(order_revenue),
        2
    ) AS gross_revenue,

    ROUND(
        AVG(order_revenue),
        2
    ) AS average_order_value,

    MAX(order_timestamp::DATE)
        - MIN(order_timestamp::DATE) AS customer_lifespan_days

FROM analytics.v_order_summary

WHERE customer_key <> 0

GROUP BY
    customer_key,
    customer_id;

COMMENT ON VIEW analytics.v_customer_kpis IS
    'Positive purchase indicators grouped by identified customer.';

COMMIT;
