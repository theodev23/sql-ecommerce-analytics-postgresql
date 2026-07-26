# Key Business Insights

## Executive summary

This analysis is based on the Online Retail transactional dataset covering the period from 2010-12-01 to 2011-12-09.

The PostgreSQL pipeline transforms 541,909 raw source rows into a deduplicated star schema containing 536,641 fact rows.

The principal results are:

| KPI | Result |
|---|---:|
| Positive sales lines | 524,878 |
| Positive orders | 19,960 |
| Cancelled invoices | 3,836 |
| Identified purchasing customers | 4,338 |
| Countries with positive sales | 38 |
| Gross revenue | 10,642,110.80 |
| Cancellation amount | 893,979.73 |
| Net revenue | 9,748,131.07 |
| Average order value | 533.17 |
| Cancellation invoice rate | 16.12% |

Monetary values are expressed in the source dataset currency.

---

## 1. Data quality findings

The raw dataset contains several characteristics that required explicit transformation rules:

| Data-quality observation | Result |
|---|---:|
| Missing customer identifiers | 135,080 rows |
| Missing descriptions | 1,454 rows |
| Negative quantity rows | 10,624 rows |
| Cancelled invoice rows | 9,288 rows |
| Negative quantities without cancellation prefix | 1,336 rows |
| Zero-price rows | 2,515 rows |
| Negative-price rows | 2 rows |
| Excess exact duplicate rows | 5,268 rows |

The 135,080 raw rows without a customer identifier cannot be used for customer-level analysis. However, 132,220 of these rows represent positive sales with a combined revenue of 1,755,276.64.

Removing them would therefore materially understate global sales.

The project keeps these transactions for overall revenue analysis and connects them to an explicit unknown customer dimension member.

---

## 2. Deduplication and product normalization

The staging layer preserves every source row and assigns:

- an exact duplicate rank;
- a duplicate group size;
- a first-occurrence indicator.

Only first occurrences are loaded into the fact table.

| Reconciliation metric | Result |
|---|---:|
| Raw and staging rows | 541,909 |
| Excess duplicate rows excluded from the fact table | 5,268 |
| Final fact rows | 536,641 |

Product codes were also normalized to uppercase.

| Product-code metric | Result |
|---|---:|
| Distinct source codes | 4,070 |
| Distinct normalized codes | 3,958 |
| Codes merged through case normalization | 112 |

For example, `85123A` and `85123a` are treated as the same product after normalization.

---

## 3. Monthly revenue trend

Revenue increased significantly during the final full months of the dataset.

| Month | Gross revenue | Net revenue | Gross revenue growth |
|---|---:|---:|---:|
| 2011-08 | 757,841.38 | 703,510.58 | 5.54% |
| 2011-09 | 1,056,435.19 | 1,017,596.68 | 39.40% |
| 2011-10 | 1,151,263.73 | 1,069,368.23 | 8.98% |
| 2011-11 | 1,503,866.78 | 1,456,145.80 | 30.63% |

November 2011 is the strongest month in the dataset, with gross revenue above 1.5 million.

The sharp increase beginning in September suggests a strong seasonal effect during the pre-Christmas period.

December 2011 must not be compared directly with complete months because the dataset ends on 2011-12-09. Its apparent 57.59% monthly decline is therefore not evidence of a full-month business contraction.

---

## 4. Geographic concentration

The United Kingdom dominates the retailer's activity.

| Country | Positive orders | Identified customers | Gross revenue | Net revenue |
|---|---:|---:|---:|---:|
| United Kingdom | 18,019 | 3,920 | 9,001,744.09 | 8,189,252.30 |
| Netherlands | 94 | 9 | 285,446.34 | 284,661.54 |
| EIRE | 288 | 3 | 283,140.52 | 262,993.38 |
| Germany | 457 | 94 | 228,678.40 | 221,509.47 |
| France | 392 | 87 | 209,625.37 | 197,317.11 |

The United Kingdom generates approximately 84.59% of total gross revenue.

International markets represent a smaller share of total revenue, but several show high average order values:

- Netherlands: 3,036.66;
- Australia: 2,429.01;
- Sweden: 1,065.77;
- Switzerland: 1,056.81.

This suggests that some international customers place fewer but substantially larger orders.

---

## 5. Customer recurrence

Customer revenue is highly concentrated among repeat buyers.

| Customer segment | Customers | Average orders | Segment revenue |
|---|---:|---:|---:|
| One-time customers | 1,493 | 1.00 | 613,989.56 |
| 2 to 5 orders | 1,973 | 3.02 | 2,379,225.32 |
| 6 to 10 orders | 535 | 7.42 | 1,510,028.00 |
| More than 10 orders | 337 | 21.11 | 4,383,966.01 |

The identified-customer revenue represented in this analysis is 8,887,208.89.

One-time customers account for:

- 34.42% of identified purchasing customers;
- only 6.91% of identified-customer revenue.

Highly recurrent customers account for:

- only 7.77% of identified purchasing customers;
- 49.33% of identified-customer revenue.

This indicates that customer retention is a major driver of revenue.

---

## 6. RFM segmentation

The RFM analysis scores customers according to:

- recency;
- frequency;
- monetary value.

| RFM segment | Customers | Average recency | Average frequency | Total revenue |
|---|---:|---:|---:|---:|
| Champions | 948 | 12.90 days | 11.16 | 5,739,180.25 |
| Loyal customers | 985 | 34.07 days | 3.76 | 1,351,029.66 |
| At risk | 669 | 150.86 days | 3.39 | 849,236.53 |
| Needs attention | 756 | 87.12 days | 1.16 | 352,320.98 |
| Hibernating | 667 | 277.87 days | 1.07 | 307,238.57 |
| Promising | 313 | 18.44 days | 1.25 | 288,202.90 |

Champions represent:

- 21.85% of identified purchasing customers;
- 64.58% of identified-customer revenue.

The 669 at-risk customers are strategically important because they historically purchased relatively frequently and generated 849,236.53 in revenue, but their average recency exceeds 150 days.

They represent a relevant target for reactivation campaigns.

The segmentation is based on quintile scores and documented heuristic rules. It should be treated as an analytical framework rather than a universal customer classification.

---

## 7. Best-performing merchandise by net quantity

Net quantity subtracts cancelled units from sold units.

| Rank | Product | Net quantity | Net revenue |
|---:|---|---:|---:|
| 1 | POPCORN HOLDER | 56,427 | 50,967.92 |
| 2 | WORLD WAR 2 GLIDERS ASSTD DESIGNS | 53,751 | 13,560.09 |
| 3 | JUMBO BAG RED RETROSPOT | 47,256 | 92,175.79 |
| 4 | ASSORTED COLOUR BIRD ORNAMENT | 36,282 | 58,792.42 |
| 5 | PACK OF 72 RETROSPOT CAKE CASES | 36,016 | 21,047.07 |
| 6 | WHITE HANGING HEART T-LIGHT HOLDER | 35,355 | 99,790.93 |
| 7 | RABBIT NIGHT LIGHT | 30,631 | 66,661.63 |
| 8 | MINI PAINT SET VINTAGE | 26,437 | 16,810.42 |
| 9 | PACK OF 12 LONDON TISSUES | 26,095 | 7,967.82 |
| 10 | PACK OF 60 PINK PAISLEY CAKE CASES | 24,719 | 12,170.77 |

High sales volume does not necessarily imply high revenue. Products with low unit prices can dominate quantity rankings without dominating revenue rankings.

---

## 8. Best-performing merchandise by net revenue

| Rank | Product | Gross revenue | Cancellation amount | Net revenue |
|---:|---|---:|---:|---:|
| 1 | REGENCY CAKESTAND 3 TIER | 174,156.54 | 9,697.05 | 164,459.49 |
| 2 | WHITE HANGING HEART T-LIGHT HOLDER | 106,415.23 | 6,624.30 | 99,790.93 |
| 3 | PARTY BUNTING | 99,445.23 | 1,201.35 | 98,243.88 |
| 4 | JUMBO BAG RED RETROSPOT | 94,159.81 | 1,984.02 | 92,175.79 |
| 5 | RABBIT NIGHT LIGHT | 66,870.03 | 208.40 | 66,661.63 |
| 6 | PAPER CHAIN KIT 50'S CHRISTMAS | 64,875.59 | 1,160.35 | 63,715.24 |
| 7 | ASSORTED COLOUR BIRD ORNAMENT | 58,927.62 | 135.20 | 58,792.42 |
| 8 | CHILLI LIGHTS | 54,096.36 | 349.70 | 53,746.66 |
| 9 | PICNIC BASKET WICKER SMALL | 51,408.77 | 385.25 | 51,023.52 |
| 10 | POPCORN HOLDER | 51,334.47 | 366.55 | 50,967.92 |

The revenue is relatively distributed across the catalogue.

The 20 highest-revenue merchandise references generate approximately 12.06% of merchandise net revenue. The retailer is therefore not dependent on a single dominant physical product.

---

## 9. Cancellation anomalies

Gross sales alone can produce misleading product rankings.

Two extreme examples illustrate this issue:

| Stock code | Product | Sold quantity | Cancelled quantity | Net quantity | Net revenue |
|---|---|---:|---:|---:|---:|
| `23843` | PAPER CRAFT, LITTLE BIRDIE | 80,995 | 80,995 | 0 | 0.00 |
| `23166` | MEDIUM CERAMIC TOP STORAGE JAR | 78,033 | 74,494 | 3,539 | 4,221.28 |

Without cancellation analysis, these products would appear among the strongest products by gross quantity or gross revenue.

The project therefore uses:

- net quantity for volume rankings;
- net revenue for revenue rankings;
- separate sold and cancelled quantities for transparency.

Products with especially high cancellation ratios include:

| Product | Sold quantity | Cancelled quantity | Cancelled percentage |
|---|---:|---:|---:|
| PAPER CRAFT, LITTLE BIRDIE | 80,995 | 80,995 | 100.00% |
| ROTATING SILVER ANGELS T-LIGHT HLDR | 9,461 | 9,376 | 99.10% |
| MEDIUM CERAMIC TOP STORAGE JAR | 78,033 | 74,494 | 95.46% |
| PANTRY CHOPPING BOARD | 1,154 | 946 | 81.98% |

These cases should be investigated before drawing conclusions from gross sales.

---

## 10. Non-merchandise transaction codes

The source dataset contains product-like codes that actually represent fees, vouchers or adjustments.

Examples include:

| Code | Category |
|---|---|
| `DOT` | Shipping fee |
| `POST` | Shipping fee |
| `C2` | Shipping fee |
| `AMAZONFEE` | Financial adjustment |
| `BANK CHARGES` | Financial adjustment |
| `D` | Discount or financial adjustment |
| `M` | Manual operation |
| `S` | Sample |
| `GIFT_...` | Gift voucher |

These codes remain available in the warehouse, but they are excluded from merchandise product rankings.

This prevents charges such as `DOTCOM POSTAGE` from being presented as top-selling physical products.

---

## 11. Business recommendations

### Retain high-value repeat customers

Highly recurrent customers and RFM Champions generate a disproportionate share of identified revenue.

Recommended actions include:

- loyalty benefits;
- early access to seasonal products;
- personalized recommendations;
- proactive retention campaigns.

### Reactivate at-risk customers

The at-risk segment contains 669 historically valuable customers.

A reactivation strategy could use:

- targeted email campaigns;
- personalized offers;
- reminders based on previously purchased categories;
- time-limited incentives.

### Investigate cancellation-heavy products

Products with unusually high cancellation ratios should be reviewed for:

- data-entry errors;
- bulk-order corrections;
- stock availability problems;
- fulfilment issues;
- fraudulent or accidental orders.

### Separate merchandise from operational charges

Product performance dashboards should systematically exclude:

- shipping fees;
- manual operations;
- financial adjustments;
- gift vouchers;
- sample codes.

### Account for incomplete periods

December 2011 is incomplete and should be labelled accordingly in any dashboard or monthly comparison.

---

## Conclusion

The project demonstrates that reliable e-commerce analysis requires more than aggregating positive sales.

The final results depend on:

- preserving the raw data;
- documenting missing values;
- identifying cancellations;
- deduplicating transparently;
- normalizing product identifiers;
- separating merchandise from operational codes;
- measuring both gross and net performance;
- excluding anonymous transactions only when customer identification is required.

These rules make the analytical results more accurate, interpretable and reproducible.
