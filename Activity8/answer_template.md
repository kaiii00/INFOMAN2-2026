# Activity 8 Answer Template

## Part 1: Star Schema Design

### 1. Fact Table Grain

- One row per sales transaction item per transaction date.

### 2. Fact Measures

- qty (number of products sold)
- unit_price (price of each product)
- total_amount (quantity * unit_price)

### 3. Dimension Tables and Attributes

- `dim_date`: 
-- date_key (surrogate key)
-- full_date
-- year
-- month
-- day
-- quarter

- `dim_customer`:
-- customer_key (surrogate key)
-- source_id (customer_id)
-- full_name
-- region_code

- `dim_product`:
-- product_key (surrogate key)
-- source_id (product_id)
-- product_name
-- category
-- unit_price

- `dim_branch`:
-- branch_key (surrogate)
-- source_id (branch_id)
-- branch_name
-- city
-- region

- `fact_sales`:
-- sales_key
-- date_key
-- customer_key
-- product_key
-- branch_key
-- source_txn_id
-- qty
-- unit_price
-- total_amount

### 4. Relationship Summary

- fact_sales.date_key > dim_date.date_key
- fact_sales.customer_key > dim_customer.customer_key
- fact_sales.product_key > dim_product.product_key
- fact_sales.branch_key > dm_branch.branch_key

## Part 2: Warehouse DDL

```sql
CREATE SCHEMA IF NOT EXISTS dw;

CREATE TABLE dw.dim_date (
    date_key SERIAL PRIMARY KEY,
    full_date DATE UNIQUE,
    year INT,
    month INT,
    day INT,
    quarter INT
);

CREATE TABLE dw.dim_customer (
    customer_key SERIAL PRIMARY KEY,
    source_id INT UNIQUE,
    full_name TEXT,
    region_code TEXT
);

CREATE TABLE dw.dim_product (
    product_key SERIAL PRIMARY KEY,
    source_id INT UNIQUE,
    product_name TEXT,
    category TEXT,
    unit_price NUMERIC
);

CREATE TABLE dw.dim_branch (
    branch_key SERIAL PRIMARY KEY,
    source_id INT UNIQUE,
    branch_name TEXT,
    city TEXT,
    region TEXT
);

CREATE TABLE dw.fact_sales (
    sales_key SERIAL PRIMARY KEY,
    source_txn_id INT UNIQUE,
    date_key INT,
    customer_key INT,
    product_key INT,
    branch_key INT,
    qty INT,
    unit_price NUMERIC,
    total_amount NUMERIC,

    FOREIGN KEY (date_key) REFERENCES dw.dim_date(date_key),
    FOREIGN KEY (customer_key) REFERENCES dw.dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dw.dim_product(product_key),
    FOREIGN KEY (branch_key) REFERENCES dw.dim_branch(branch_key)
);

CREATE TABLE dw.etl_log (
    run_ts TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status TEXT,
    rows_loaded INT,
    error_message TEXT
);

CREATE INDEX idx_fact_date ON dw.fact_sales(date_key);
CREATE INDEX idx_fact_branch ON dw.fact_sales(branch_key);
CREATE INDEX idx_fact_product ON dw.fact_sales(product_key);

```
## Part 3: ETL Procedure

### 1. Procedure Code

```sql
CREATE OR REPLACE PROCEDURE dw.run_sales_etl()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_loaded INT := 0;
BEGIN

INSERT INTO dw.dim_customer (source_id, full_name, region_code)
SELECT id, full_name, region_code
FROM public.customers
ON CONFLICT (source_id)
DO UPDATE SET
    full_name = EXCLUDED.full_name,
    region_code = EXCLUDED.region_code;

INSERT INTO dw.dim_product (source_id, product_name, category, unit_price)
SELECT id, product_name, category, unit_price
FROM public.products
ON CONFLICT (source_id)
DO UPDATE SET
    product_name = EXCLUDED.product_name,
    category = EXCLUDED.category,
    unit_price = EXCLUDED.unit_price;

INSERT INTO dw.dim_branch (source_id, branch_name, city, region)
SELECT id, branch_name, city, region
FROM public.branches
ON CONFLICT (source_id)
DO UPDATE SET
    branch_name = EXCLUDED.branch_name,
    city = EXCLUDED.city,
    region = EXCLUDED.region;

INSERT INTO dw.dim_date (full_date, year, month, day, quarter)
SELECT DISTINCT
    txn_date,
    EXTRACT(YEAR FROM txn_date),
    EXTRACT(MONTH FROM txn_date),
    EXTRACT(DAY FROM txn_date),
    EXTRACT(QUARTER FROM txn_date)
FROM public.sales_txn
ON CONFLICT (full_date) DO NOTHING;

INSERT INTO dw.fact_sales
(
source_txn_id,
date_key,
customer_key,
product_key,
branch_key,
qty,
unit_price,
total_amount
)

SELECT
s.id,
d.date_key,
c.customer_key,
p.product_key,
b.branch_key,
s.qty,
s.unit_price,
s.qty * s.unit_price

FROM public.sales_txn s
JOIN dw.dim_date d
ON s.txn_date = d.full_date

JOIN dw.dim_customer c
ON s.customer_id = c.source_id

JOIN dw.dim_product p
ON s.product_id = p.source_id

JOIN dw.dim_branch b
ON s.branch_id = b.source_id

WHERE s.qty > 0
AND s.unit_price > 0
AND NOT EXISTS (
    SELECT 1
    FROM dw.fact_sales f
    WHERE f.source_txn_id = s.id
);

GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;

INSERT INTO dw.etl_log(status, rows_loaded)
VALUES ('SUCCESS', v_rows_loaded);

EXCEPTION
WHEN OTHERS THEN

INSERT INTO dw.etl_log(status, rows_loaded, error_message)
VALUES ('FAIL', 0, SQLERRM);

END;
$$;
```

### 2. Procedure Execution

```sql
CALL dw.run_sales_etl();
```

### 3. ETL Log Output

```sql
SELECT * FROM dw.etl_log ORDER BY run_ts DESC;
```

```txt
           run_ts           | status  | rows_loaded | error_message
----------------------------+---------+-------------+---------------
 2026-03-10 20:26:36.762677 | SUCCESS |          30 |
(1 row)
```

## Part 4: Analytical Queries

### Query 1: Monthly Revenue by Branch Region

```sql
SELECT d.year, d.month, b.region, SUM(f.total_amount) AS revenue
FROM dw.fact_sales f
JOIN dw.dim_date d ON f.date_key = d.date_key
JOIN dw.dim_branch b ON f.branch_key = b.branch_key
GROUP BY d.year, d.month, b.region
ORDER BY d.year, d.month;
```

Interpretation:

- This query shows how much revenue each branch region generates every month, helping management compare regional performance.

### Query 2: Top 5 Products by Total Revenue

```sql
SELECT p.product_name, SUM(f.total_amount) AS revenue
FROM dw.fact_sales f
JOIN dw.dim_product p ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY revenue DESC
LIMIT 5;
```

Interpretation:

- This identifies the five products generating the highest sales revenue, helping guide inventory and marketing strategies.

### Query 3: Customer Region Contribution to Sales

```sql
SELECT c.region_code, SUM(f.total_amount) AS total_sales
FROM dw.fact_sales f
JOIN dw.dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.region_code
ORDER BY total_sales DESC;
```

Interpretation:

- This query shows which customer regions contribute the most revenue, helping the business target marketing campaigns.