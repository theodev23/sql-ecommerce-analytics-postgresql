# Data Dictionary

## Architecture overview

The project follows a layered data warehouse architecture:

    Source file
        |
        v
    raw.online_retail
        |
        v
    staging.transactions
        |
        v
    warehouse dimensions and fact table
        |
        v
    analytics views and business KPIs

The layers have distinct responsibilities:

| Layer | Purpose |
|---|---|
| `raw` | Preserve the imported source data with minimal transformation |
| `staging` | Clean, type, normalize and classify the source rows |
| `warehouse` | Store the dimensional star schema |
| `analytics` | Expose reusable business views and KPIs |

---

# Raw layer

## `raw.online_retail`

### Grain

One row represents one row imported from the source CSV file.

The source values are stored as text so that ingestion does not fail because of an unexpected value or format.

| Column | Type | Description |
|---|---|---|
| `raw_row_id` | `BIGINT` | Technical identifier generated during ingestion |
| `invoice_no` | `TEXT` | Source invoice identifier |
| `stock_code` | `TEXT` | Original product or operation code |
| `description` | `TEXT` | Original product description |
| `quantity` | `TEXT` | Original quantity value |
| `invoice_date` | `TEXT` | Original transaction timestamp |
| `unit_price` | `TEXT` | Original unit price |
| `customer_id` | `TEXT` | Original customer identifier |
| `country` | `TEXT` | Original country value |
| `source_file` | `TEXT` | Name of the imported source file |
| `ingested_at` | `TIMESTAMPTZ` | Timestamp of the raw ingestion |

---

# Staging layer

## `staging.transactions`

### Grain

One row represents one source transaction row.

All 541,909 raw rows are preserved in this layer. Exact duplicates are identified but not physically deleted.

| Column | Type | Description |
|---|---|---|
| `raw_row_id` | `BIGINT` | Logical lineage identifier referencing the raw source row |
| `invoice_no` | `TEXT` | Trimmed invoice identifier |
| `source_stock_code` | `TEXT` | Original trimmed product code preserving the source letter case |
| `stock_code` | `TEXT` | Product code normalized to uppercase |
| `description` | `TEXT` | Trimmed product description; blank values become null |
| `quantity` | `INTEGER` | Typed transaction quantity |
| `invoice_date` | `TIMESTAMP` | Typed transaction timestamp |
| `unit_price` | `NUMERIC(18,4)` | Typed unit price |
| `customer_id` | `INTEGER` | Typed customer identifier; null when unavailable |
| `country` | `TEXT` | Trimmed country value |
| `line_amount` | `NUMERIC(20,4)` | Signed amount calculated as quantity multiplied by unit price |
| `is_cancelled` | `BOOLEAN` | True when the invoice number begins with `C` |
| `is_stock_adjustment` | `BOOLEAN` | True for a negative quantity without an invoice cancellation prefix |
| `is_accounting_adjustment` | `BOOLEAN` | True when the unit price is negative |
| `is_zero_price` | `BOOLEAN` | True when the unit price is zero |
| `is_missing_customer` | `BOOLEAN` | True when the customer identifier is absent |
| `is_missing_description` | `BOOLEAN` | True when the product description is absent |
| `is_positive_sale` | `BOOLEAN` | True for a positive quantity, positive price and non-cancelled invoice |
| `record_type` | `TEXT` | Main business classification of the row |
| `duplicate_rank` | `BIGINT` | Position of the row inside its exact duplicate group |
| `duplicate_group_size` | `BIGINT` | Number of rows sharing the same exact source values |
| `is_exact_duplicate` | `BOOLEAN` | True when the row belongs to a duplicate group |
| `is_first_occurrence` | `BOOLEAN` | True for the retained row used by the warehouse layer |
| `source_file` | `TEXT` | Name of the source file |
| `raw_ingested_at` | `TIMESTAMPTZ` | Original raw ingestion timestamp |
| `staged_at` | `TIMESTAMPTZ` | Timestamp of the staging transformation |

## Record types

| Record type | Definition |
|---|---|
| `SALE` | Positive quantity, positive price and non-cancelled invoice |
| `CANCELLATION` | Invoice identifier beginning with `C` |
| `STOCK_ADJUSTMENT` | Negative quantity without cancellation prefix |
| `ACCOUNTING_ADJUSTMENT` | Negative unit price |
| `ZERO_PRICE` | Zero unit price not already classified by a higher-priority rule |
| `OTHER` | Row not covered by another classification |

The classification uses one primary record type per row. Boolean indicators preserve overlapping characteristics.

---

# Warehouse layer

## `warehouse.dim_customer`

### Grain

One row represents one identified customer.

An additional unknown member uses `customer_key = 0` for transactions without a customer identifier.

| Column | Type | Description |
|---|---|---|
| `customer_key` | `BIGINT` | Warehouse surrogate key |
| `customer_id` | `INTEGER` | Source customer identifier |
| `first_seen_at` | `TIMESTAMP` | First transaction timestamp associated with the customer |
| `last_seen_at` | `TIMESTAMP` | Last transaction timestamp associated with the customer |
| `is_unknown` | `BOOLEAN` | Identifies the unknown dimension member |
| `created_at` | `TIMESTAMPTZ` | Dimension loading timestamp |

## `warehouse.dim_product`

### Grain

One row represents one normalized product or operation code.

Product codes are converted to uppercase before dimension loading.

| Column | Type | Description |
|---|---|---|
| `product_key` | `BIGINT` | Warehouse surrogate key |
| `stock_code` | `TEXT` | Normalized uppercase product or operation code |
| `product_description` | `TEXT` | Canonical description selected from the source data |
| `product_category` | `TEXT` | Business category assigned to the code |
| `is_merchandise` | `BOOLEAN` | True only for products included in merchandise rankings |
| `first_seen_at` | `TIMESTAMP` | First transaction timestamp for the code |
| `last_seen_at` | `TIMESTAMP` | Last transaction timestamp for the code |
| `is_unknown` | `BOOLEAN` | Identifies the unknown dimension member |
| `created_at` | `TIMESTAMPTZ` | Dimension loading timestamp |

### Product categories

| Category | Definition |
|---|---|
| `MERCHANDISE` | Physical merchandise used in product performance analyses |
| `SHIPPING_FEE` | Delivery, carriage or postage charges |
| `FINANCIAL_ADJUSTMENT` | Fees, discounts, commissions and accounting adjustments |
| `MANUAL` | Manual transaction operations |
| `SAMPLE` | Sample-related transaction codes |
| `GIFT_VOUCHER` | Gift voucher codes |
| `UNKNOWN` | Unknown product member |

### Canonical product description

When several descriptions exist for one normalized stock code, the dimension selects:

1. the most frequent non-null description;
2. the most recently used description in case of a frequency tie;
3. the alphabetically first description in case of another tie.

## `warehouse.dim_country`

### Grain

One row represents one country value.

| Column | Type | Description |
|---|---|---|
| `country_key` | `BIGINT` | Warehouse surrogate key |
| `country_name` | `TEXT` | Source country name |
| `is_unknown` | `BOOLEAN` | Identifies the unknown dimension member |
| `created_at` | `TIMESTAMPTZ` | Dimension loading timestamp |

## `warehouse.dim_date`

### Grain

One row represents one calendar date between the first and last source transaction dates.

| Column | Type | Description |
|---|---|---|
| `date_key` | `INTEGER` | Date key in `YYYYMMDD` format |
| `full_date` | `DATE` | Calendar date |
| `calendar_year` | `SMALLINT` | Calendar year |
| `calendar_quarter` | `SMALLINT` | Calendar quarter from 1 to 4 |
| `month_number` | `SMALLINT` | Month number from 1 to 12 |
| `month_name` | `TEXT` | English month name |
| `year_month` | `CHAR(7)` | Month identifier in `YYYY-MM` format |
| `week_of_year` | `SMALLINT` | Week number |
| `day_of_month` | `SMALLINT` | Day number in the month |
| `day_of_week` | `SMALLINT` | ISO weekday number from 1 for Monday to 7 for Sunday |
| `day_name` | `TEXT` | English weekday name |
| `is_weekend` | `BOOLEAN` | True for Saturday and Sunday |
| `is_unknown` | `BOOLEAN` | Identifies the unknown date member |

## `warehouse.fact_sales`

### Grain

One row represents one deduplicated transaction line.

Only rows where `staging.transactions.is_first_occurrence = TRUE` are loaded.

| Column | Type | Description |
|---|---|---|
| `sales_key` | `BIGINT` | Warehouse surrogate key identifying the fact row |
| `raw_row_id` | `BIGINT` | Identifier of the retained raw and staging row |
| `date_key` | `INTEGER` | Foreign key to `dim_date` |
| `customer_key` | `BIGINT` | Foreign key to `dim_customer` |
| `product_key` | `BIGINT` | Foreign key to `dim_product` |
| `country_key` | `BIGINT` | Foreign key to `dim_country` |
| `invoice_no` | `TEXT` | Degenerate invoice dimension |
| `invoice_timestamp` | `TIMESTAMP` | Source invoice timestamp |
| `quantity` | `INTEGER` | Signed transaction quantity |
| `unit_price` | `NUMERIC(18,4)` | Unit price |
| `line_amount` | `NUMERIC(20,4)` | Signed quantity multiplied by unit price |
| `record_type` | `TEXT` | Main business classification |
| `is_cancelled` | `BOOLEAN` | Cancellation indicator |
| `is_stock_adjustment` | `BOOLEAN` | Stock adjustment indicator |
| `is_accounting_adjustment` | `BOOLEAN` | Accounting adjustment indicator |
| `is_zero_price` | `BOOLEAN` | Zero-price indicator |
| `is_missing_customer` | `BOOLEAN` | Missing customer indicator |
| `is_missing_description` | `BOOLEAN` | Missing description indicator |
| `is_positive_sale` | `BOOLEAN` | Positive commercial sale indicator |
| `source_duplicate_group_size` | `BIGINT` | Number of exact source occurrences represented by the retained row |
| `source_file` | `TEXT` | Source filename |
| `raw_ingested_at` | `TIMESTAMPTZ` | Original raw ingestion timestamp |
| `warehouse_loaded_at` | `TIMESTAMPTZ` | Fact table loading timestamp |

---

# Analytics layer

## `analytics.v_sales_enriched`

Detailed fact rows enriched with customer, product, country and date attributes.

## `analytics.v_order_summary`

One row per positive invoice.

Used to calculate:

- order count;
- average order value;
- purchase frequency;
- customer activity.

## `analytics.v_kpi_overview`

Single-row view containing the principal e-commerce KPIs.

## `analytics.v_monthly_kpis`

Monthly sales, cancellation and order indicators.

## `analytics.v_country_kpis`

Sales indicators grouped by country.

## `analytics.v_product_kpis`

Product-level indicators including:

- sold quantity;
- cancelled quantity;
- net quantity;
- gross revenue;
- cancellation amount;
- net revenue;
- stock adjustment quantity.

## `analytics.v_customer_kpis`

Customer-level positive purchase indicators.

Used for recurrence analysis and RFM segmentation.

---

# Business metric definitions

| Metric | Definition |
|---|---|
| Gross revenue | Sum of positive sale amounts |
| Cancellation amount | Absolute value of cancelled transaction amounts |
| Net revenue | Positive sales plus signed cancellation amounts |
| Sold quantity | Sum of quantities from positive sales |
| Cancelled quantity | Absolute value of quantities from cancelled invoices |
| Net quantity | Signed sum of sale and cancellation quantities |
| Positive order count | Number of distinct invoices containing positive sales |
| Average order value | Gross revenue divided by positive order count |
| Cancellation invoice rate | Cancelled invoices divided by positive and cancelled invoices |
| Customer frequency | Number of positive orders made by an identified customer |
| Customer recency | Days between the analysis reference date and the latest customer order |
| Customer monetary value | Total positive revenue generated by an identified customer |

---

# Important analytical rules

- Full raw source files are never modified by SQL transformations.
- Blank strings are converted to null in the staging layer.
- Product codes are normalized to uppercase.
- Exact duplicates remain available in staging for traceability.
- Only the first exact occurrence is loaded into the fact table.
- Transactions without a customer remain available for global revenue analysis.
- Transactions without a customer are excluded from customer-level and RFM analysis.
- Non-merchandise codes are excluded from product performance rankings.
- Product rankings use net quantity or net revenue when cancellations could distort gross values.
- December 2011 is an incomplete month because the source dataset ends on 2011-12-09.
