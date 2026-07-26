#!/usr/bin/env bash

set -euo pipefail

DATABASE_NAME="${1:-ecommerce_dw}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${PROJECT_ROOT}"

echo "============================================================"
echo "E-commerce Data Warehouse Pipeline"
echo "Database: ${DATABASE_NAME}"
echo "Project root: ${PROJECT_ROOT}"
echo "============================================================"

if ! command -v psql >/dev/null 2>&1; then
    echo "Error: psql is not installed or not available in PATH."
    exit 1
fi

if ! command -v createdb >/dev/null 2>&1; then
    echo "Error: createdb is not installed or not available in PATH."
    exit 1
fi

if [[ ! -f "data/online_retail.csv" ]]; then
    echo "Error: data/online_retail.csv was not found."
    echo "Run: python scripts/convert_xlsx_to_csv.py"
    exit 1
fi

DATABASE_EXISTS="$(
    psql \
        -d postgres \
        -tAc "SELECT 1 FROM pg_database WHERE datname = '${DATABASE_NAME}';"
)"

if [[ "${DATABASE_EXISTS}" != "1" ]]; then
    echo ""
    echo "Creating PostgreSQL database: ${DATABASE_NAME}"
    createdb "${DATABASE_NAME}"
else
    echo ""
    echo "Database already exists: ${DATABASE_NAME}"
fi

run_sql_file() {
    local sql_file="$1"

    echo ""
    echo "------------------------------------------------------------"
    echo "Running ${sql_file}"
    echo "------------------------------------------------------------"

    psql \
        -v ON_ERROR_STOP=1 \
        -P pager=off \
        -d "${DATABASE_NAME}" \
        -f "${sql_file}"
}

run_sql_file "sql/01_create_schemas.sql"
run_sql_file "sql/02_create_raw_table.sql"
run_sql_file "sql/03_import_data.sql"
run_sql_file "sql/04_data_quality_checks.sql"
run_sql_file "sql/05_create_staging.sql"
run_sql_file "sql/06_create_dimensions.sql"
run_sql_file "sql/07_create_fact_sales.sql"
run_sql_file "sql/08_create_views.sql"
run_sql_file "sql/09_analysis_queries.sql"

echo ""
echo "============================================================"
echo "Pipeline completed successfully."
echo "============================================================"
