-- ============================================================
-- Project: Mini E-commerce Data Warehouse with PostgreSQL
-- File: 09_analysis_queries.sql
-- Purpose: Answer key business questions using advanced SQL
-- ============================================================

\pset pager off
\timing on

\echo ''
\echo '1. OVERALL BUSINESS KPIS'
SELECT *
FROM analytics.v_kpi_overview;

\echo ''
\echo '2. MONTHLY REVENUE AND MONTH-OVER-MONTH GROWTH'
WITH monthly_revenue AS (
    SELECT
        year_month,
        month_start,
        gross_revenue,
        net_revenue
    FROM analytics.v_monthly_kpis
),
revenue_with_previous_month AS (
    SELECT
        year_month,
        month_start,
        gross_revenue,
        net_revenue,
        LAG(gross_revenue) OVER (
            ORDER BY month_start
        ) AS previous_month_gross_revenue
    FROM monthly_revenue
)
SELECT
    year_month,
    gross_revenue,
    net_revenue,
    previous_month_gross_revenue,
    ROUND(
        100.0
        * (gross_revenue - previous_month_gross_revenue)
        / NULLIF(previous_month_gross_revenue, 0),
        2
    ) AS gross_revenue_growth_pct
FROM revenue_with_previous_month
ORDER BY month_start;

\echo ''
\echo '3. TOP 10 COUNTRIES BY GROSS REVENUE'
SELECT
    country_name,
    positive_order_count,
    identified_customer_count,
    sold_quantity,
    gross_revenue,
    net_revenue,
    average_order_value,
    DENSE_RANK() OVER (
        ORDER BY gross_revenue DESC
    ) AS revenue_rank
FROM analytics.v_country_kpis
ORDER BY revenue_rank
LIMIT 10;

\echo ''
\echo '4. TOP 10 MERCHANDISE PRODUCTS BY NET QUANTITY'
SELECT
    stock_code,
    product_description,
    positive_order_count,
    sold_quantity,
    cancelled_quantity,
    net_quantity,
    net_revenue,

    DENSE_RANK() OVER (
        ORDER BY net_quantity DESC
    ) AS quantity_rank

FROM analytics.v_product_kpis

WHERE is_merchandise = TRUE
  AND net_quantity > 0

ORDER BY quantity_rank, stock_code
LIMIT 10;

\echo '5. TOP 10 MERCHANDISE PRODUCTS BY NET REVENUE'
SELECT
    stock_code,
    product_description,
    positive_order_count,
    sold_quantity,
    cancelled_quantity,
    gross_revenue,
    cancellation_amount,
    net_revenue,

    DENSE_RANK() OVER (
        ORDER BY net_revenue DESC
    ) AS revenue_rank

FROM analytics.v_product_kpis

WHERE is_merchandise = TRUE
  AND net_revenue > 0

ORDER BY revenue_rank, stock_code
LIMIT 10;

\echo '6. TOP 10 CUSTOMERS BY GROSS REVENUE'
SELECT
    customer_id,
    order_count,
    purchased_quantity,
    gross_revenue,
    average_order_value,
    first_order_timestamp,
    last_order_timestamp,
    DENSE_RANK() OVER (
        ORDER BY gross_revenue DESC
    ) AS customer_revenue_rank
FROM analytics.v_customer_kpis
ORDER BY customer_revenue_rank, customer_id
LIMIT 10;

\echo ''
\echo '7. ONE-TIME AND REPEAT CUSTOMER DISTRIBUTION'
SELECT
    CASE
        WHEN order_count = 1 THEN 'ONE_TIME'
        WHEN order_count BETWEEN 2 AND 5 THEN 'REPEAT_2_TO_5'
        WHEN order_count BETWEEN 6 AND 10 THEN 'REPEAT_6_TO_10'
        ELSE 'HIGHLY_RECURRENT'
    END AS customer_frequency_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(order_count), 2) AS average_order_count,
    ROUND(SUM(gross_revenue), 2) AS segment_revenue
FROM analytics.v_customer_kpis
GROUP BY
    CASE
        WHEN order_count = 1 THEN 'ONE_TIME'
        WHEN order_count BETWEEN 2 AND 5 THEN 'REPEAT_2_TO_5'
        WHEN order_count BETWEEN 6 AND 10 THEN 'REPEAT_6_TO_10'
        ELSE 'HIGHLY_RECURRENT'
    END
ORDER BY
    MIN(order_count);

\echo ''
\echo '8. TOP MERCHANDISE PRODUCT BY NET REVENUE FOR EACH MONTH'
WITH monthly_product_revenue AS (
    SELECT
        year_month,
        product_key,
        stock_code,
        product_description,

        ROUND(
            SUM(line_amount) FILTER (
                WHERE record_type IN ('SALE', 'CANCELLATION')
            ),
            2
        ) AS net_revenue

    FROM analytics.v_sales_enriched

    WHERE is_merchandise = TRUE

    GROUP BY
        year_month,
        product_key,
        stock_code,
        product_description
),
ranked_products AS (
    SELECT
        year_month,
        stock_code,
        product_description,
        net_revenue,

        ROW_NUMBER() OVER (
            PARTITION BY year_month
            ORDER BY net_revenue DESC, stock_code
        ) AS product_rank

    FROM monthly_product_revenue
    WHERE net_revenue > 0
)
SELECT
    year_month,
    stock_code,
    product_description,
    net_revenue
FROM ranked_products
WHERE product_rank = 1
ORDER BY year_month;

\echo ''
\echo '9. MERCHANDISE NET REVENUE CONTRIBUTION AND CUMULATIVE SHARE'
WITH product_revenue AS (
    SELECT
        product_key,
        stock_code,
        product_description,
        net_revenue
    FROM analytics.v_product_kpis
    WHERE is_merchandise = TRUE
      AND net_revenue > 0
),
revenue_contribution AS (
    SELECT
        product_key,
        stock_code,
        product_description,
        net_revenue,

        SUM(net_revenue) OVER () AS total_revenue,

        SUM(net_revenue) OVER (
            ORDER BY net_revenue DESC, stock_code
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_revenue

    FROM product_revenue
)
SELECT
    stock_code,
    product_description,
    net_revenue,

    ROUND(
        100.0 * net_revenue / NULLIF(total_revenue, 0),
        2
    ) AS revenue_share_pct,

    ROUND(
        100.0 * cumulative_revenue / NULLIF(total_revenue, 0),
        2
    ) AS cumulative_revenue_share_pct

FROM revenue_contribution
ORDER BY net_revenue DESC, stock_code
LIMIT 20;

\echo ''
\echo '10. MOST CANCELLED MERCHANDISE PRODUCTS'
SELECT
    stock_code,
    product_description,
    positive_order_count,
    cancellation_invoice_count,
    sold_quantity,
    cancelled_quantity,
    cancelled_units_pct_of_sold,
    cancellation_amount
FROM analytics.v_product_kpis
WHERE is_merchandise = TRUE
  AND cancelled_quantity > 0
ORDER BY cancelled_quantity DESC, stock_code
LIMIT 20;

\echo ''
\echo '11. CUSTOMER RFM SEGMENTATION'
WITH analysis_date AS (
    SELECT
        MAX(full_date) + 1 AS reference_date
    FROM warehouse.dim_date
    WHERE is_unknown = FALSE
),
customer_rfm AS (
    SELECT
        customer.customer_id,

        analysis.reference_date
            - MAX(orders.order_timestamp::DATE) AS recency_days,

        COUNT(*) AS frequency,

        ROUND(
            SUM(orders.order_revenue),
            2
        ) AS monetary_value

    FROM analytics.v_order_summary AS orders

    INNER JOIN warehouse.dim_customer AS customer
        ON customer.customer_key = orders.customer_key

    CROSS JOIN analysis_date AS analysis

    WHERE orders.customer_key <> 0

    GROUP BY
        customer.customer_id,
        analysis.reference_date
),
rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary_value,

        6 - NTILE(5) OVER (
            ORDER BY recency_days ASC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency ASC
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary_value ASC
        ) AS monetary_score

    FROM customer_rfm
),
rfm_segments AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary_value,
        recency_score,
        frequency_score,
        monetary_score,

        CONCAT(
            recency_score,
            frequency_score,
            monetary_score
        ) AS rfm_score,

        CASE
            WHEN recency_score >= 4
             AND frequency_score >= 4
             AND monetary_score >= 4
                THEN 'CHAMPIONS'

            WHEN recency_score >= 3
             AND frequency_score >= 3
                THEN 'LOYAL_CUSTOMERS'

            WHEN recency_score >= 4
             AND frequency_score <= 2
                THEN 'PROMISING'

            WHEN recency_score <= 2
             AND frequency_score >= 3
                THEN 'AT_RISK'

            WHEN recency_score = 1
             AND frequency_score <= 2
                THEN 'HIBERNATING'

            ELSE 'NEEDS_ATTENTION'
        END AS rfm_segment

    FROM rfm_scores
)
SELECT
    rfm_segment,
    COUNT(*) AS customer_count,
    ROUND(AVG(recency_days), 2) AS average_recency_days,
    ROUND(AVG(frequency), 2) AS average_frequency,
    ROUND(AVG(monetary_value), 2) AS average_monetary_value,
    ROUND(SUM(monetary_value), 2) AS total_segment_revenue
FROM rfm_segments
GROUP BY rfm_segment
ORDER BY total_segment_revenue DESC;
