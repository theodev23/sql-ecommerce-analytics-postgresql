# Raw Data Quality Report

## Dataset overview

The raw Online Retail dataset contains 541,909 transactional rows covering the period from 2010-12-01 08:26:00 to 2011-12-09 12:50:00.

| Metric | Result |
|---|---:|
| Raw rows | 541,909 |
| Distinct invoices | 25,900 |
| Distinct products | 4,070 |
| Distinct identified customers | 4,372 |
| Distinct countries | 38 |

## Completeness

| Check | Result |
|---|---:|
| Missing invoice numbers | 0 |
| Missing stock codes | 0 |
| Missing descriptions | 1,454 |
| Missing quantities | 0 |
| Missing invoice dates | 0 |
| Missing unit prices | 0 |
| Missing customer identifiers | 135,080 |
| Missing countries | 0 |

## Format validation

No invalid formats were detected for:

- quantities;
- unit prices;
- customer identifiers;
- invoice timestamps.

The source values can therefore be converted safely to PostgreSQL data types in the staging layer.

## Business anomalies

| Check | Result |
|---|---:|
| Negative quantity rows | 10,624 |
| Cancelled invoice rows | 9,288 |
| Distinct cancelled invoices | 3,836 |
| Negative quantities without cancellation prefix | 1,336 |
| Zero unit-price rows | 2,515 |
| Negative unit-price rows | 2 |

All invoice numbers beginning with `C` have a negative quantity.

The negative quantities without the `C` prefix mainly contain operational descriptions such as `check`, `wet rusty` and `printing smudges/thrown away`. These rows appear to represent stock adjustments rather than customer sales.

The two negative unit-price rows are labelled `Adjust bad debt` and appear to be accounting adjustments.

## Missing customer identifiers

The dataset contains 135,080 rows without a customer identifier.

Among them, 132,220 rows represent positive, non-cancelled transactions with a positive unit price. Their combined positive revenue is 1,755,276.64.

These rows must therefore remain available for global sales analysis, but they cannot be used for customer-level analysis or RFM segmentation.

## Exact duplicates

| Metric | Result |
|---|---:|
| Duplicate groups | 4,879 |
| Rows belonging to duplicate groups | 10,147 |
| Excess duplicate rows | 5,268 |

Exact duplicates will not be deleted from the raw layer.

The staging layer will assign a duplicate rank and duplicate group size to every row. This preserves source traceability while allowing downstream models to use a documented deduplication rule when required.

## Staging transformation policy

The staging layer will:

- preserve the source row identifier;
- trim text values and convert blank strings to null;
- convert quantities to integers;
- convert unit prices to numeric values;
- convert invoice dates to timestamps;
- calculate the signed line amount;
- identify cancelled invoices;
- identify negative-quantity stock adjustments;
- identify zero and negative prices;
- identify missing customers and descriptions;
- assign a rank to exact duplicate rows;
- preserve all source rows without silent deletion.
