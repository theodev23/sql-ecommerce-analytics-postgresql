# Mini E-commerce Data Warehouse with PostgreSQL

## Project overview

This project consists of building a small analytical data warehouse from a real-world e-commerce transactional dataset.

The objective is to transform raw retail data into a clean and structured dimensional model that can be used to calculate business KPIs and answer analytical questions with PostgreSQL.

## Data pipeline

```text
Online Retail dataset
        |
        v
raw.online_retail
        |
        v
staging.transactions
        |
        v
warehouse.dim_customer
warehouse.dim_product
warehouse.dim_country
warehouse.dim_date
warehouse.fact_sales
        |
        v
analytics views and business KPIs
```

## Main objectives

- Import raw transactional data into PostgreSQL
- Perform data profiling and quality checks
- Clean and standardize the source data
- Build a dimensional star schema
- Create reusable analytical views
- Calculate e-commerce business indicators
- Perform customer segmentation using RFM analysis
- Document the data model and transformation rules

## Technologies

- PostgreSQL 16
- SQL
- Git
- GitHub

## Repository structure

```text
.
├── data/
├── docs/
├── images/
├── results/
├── sql/
├── .gitignore
└── README.md
```

## Planned analyses

The project will include analyses such as:

- Total and monthly revenue
- Revenue by country
- Best-selling products
- Top customers
- Average order value
- Monthly order evolution
- Cancellation rate
- Negative quantity detection
- Frequently cancelled products
- Repeat customer analysis
- Customer segmentation
- RFM analysis

## Project status

Work in progress — initial project structure created.
