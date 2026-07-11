# Dataset

## Source

This project uses the **Online Retail** dataset from the UCI Machine Learning Repository.

The dataset contains transactional data from a UK-based online retailer between December 2010 and December 2011.

Source page: https://archive.ics.uci.edu/dataset/352/online+retail

License: CC BY 4.0

## Source columns

| Column | Description |
|---|---|
| `InvoiceNo` | Invoice identifier |
| `StockCode` | Product identifier |
| `Description` | Product description |
| `Quantity` | Quantity purchased or returned |
| `InvoiceDate` | Transaction date and time |
| `UnitPrice` | Product unit price |
| `CustomerID` | Customer identifier |
| `Country` | Customer country |

## Local files

The following full data files are intentionally excluded from Git:

    data/online_retail.xlsx
    data/online_retail.csv

The original Excel file can be downloaded from the UCI repository.

## Source file integrity

The Excel file used for this project has the following SHA-256 checksum:

    43465a06f2ccf7c8b5bd2892bc7defb52f97487934fe93b16ae4c3936424676d

## CSV conversion

The Excel source file is converted to UTF-8 CSV using:

    python scripts/convert_xlsx_to_csv.py

Expected result:

    Rows written including header: 541910
    Data rows: 541909

No business cleaning or filtering is performed during this conversion. The objective is only to create a PostgreSQL-compatible source file while preserving the raw values.
