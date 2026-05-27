# Activity 8 Answer Template

## Part 1: Star Schema Design

### 1. Fact Table Grain

One row per sales transaction per day — tracking each individual product sold across all coffee chain branches.

### 2. Fact Measures

| Measure | Description |
|---|---|
| `qty` | Number of units sold in the transaction |
| `unit_price` | Selling price per unit at time of transaction |
| `total_amount` | Derived revenue: qty × unit_price |

### 3. Dimension Tables and Attributes

**`dim_date`**
- `date_key` — surrogate key
- `full_date` — actual calendar date
- `year`, `month`, `day`, `quarter`

**`dim_customer`**
- `customer_key` — surrogate key
- `source_id` — maps to `customers.id` in OLTP
- `full_name`, `region_code`

**`dim_product`**
- `product_key` — surrogate key
- `source_id` — maps to `products.id` in OLTP
- `product_name`, `category`, `unit_price`

**`dim_branch`**
- `branch_key` — surrogate key
- `source_id` — maps to `branches.id` in OLTP
- `branch_name`, `city`, `region`

**`fact_sales`**
- `sales_key` — surrogate key
- `source_txn_id` — original transaction ID for incremental tracking
- `date_key`, `customer_key`, `product_key`, `branch_key` — FK references to dimensions
- `qty`, `unit_price`, `total_amount` — measures

### 4. Relationship Summary

The fact table sits at the center of the schema, linked to each dimension via foreign keys:

- `fact_sales.date_key` → `dim_date.date_key`
- `fact_sales.customer_key` → `dim_customer.customer_key`
- `fact_sales.product_key` → `dim_product.product_key`
- `fact_sales.branch_key` → `dim_branch.branch_key`

---

## Part 2: Warehouse DDL

```sql
CREATE SCHEMA IF NOT EXISTS dw;

CREATE TABLE dw.etl_log (
    id            SERIAL PRIMARY KEY,
    run_ts        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status        TEXT,
    rows_loaded   INT,
    error_message TEXT
);

CREATE TABLE dw.dim_date (
    date_key  SERIAL PRIMARY KEY,
    full_date DATE UNIQUE NOT NULL,
    year      INT,
    month     INT,
    day       INT,
    quarter   INT
);

CREATE TABLE dw.dim_customer (
    customer_key SERIAL PRIMARY KEY,
    source_id    INT  UNIQUE NOT NULL,
    full_name    TEXT NOT NULL,
    region_code  TEXT
);

CREATE TABLE dw.dim_product (
    product_key  SERIAL PRIMARY KEY,
    source_id    INT     UNIQUE NOT NULL,
    product_name TEXT    NOT NULL,
    category     TEXT,
    unit_price   NUMERIC NOT NULL
);

CREATE TABLE dw.dim_branch (
    branch_key  SERIAL PRIMARY KEY,
    source_id   INT  UNIQUE NOT NULL,
    branch_name TEXT NOT NULL,
    city        TEXT,
    region      TEXT
);

CREATE TABLE dw.fact_sales (
    sales_key     SERIAL  PRIMARY KEY,
    source_txn_id INT     UNIQUE NOT NULL,
    date_key      INT     NOT NULL REFERENCES dw.dim_date(date_key),
    customer_key  INT     NOT NULL REFERENCES dw.dim_customer(customer_key),
    product_key   INT     NOT NULL REFERENCES dw.dim_product(product_key),
    branch_key    INT     NOT NULL REFERENCES dw.dim_branch(branch_key),
    qty           INT     NOT NULL CHECK (qty > 0),
    unit_price    NUMERIC NOT NULL CHECK (unit_price > 0),
    total_amount  NUMERIC NOT NULL
);

CREATE INDEX idx_fact_date     ON dw.fact_sales(date_key);
CREATE INDEX idx_fact_branch   ON dw.fact_sales(branch_key);
CREATE INDEX idx_fact_product  ON dw.fact_sales(product_key);
CREATE INDEX idx_fact_customer ON dw.fact_sales(customer_key);
```

---

## Part 3: ETL Procedure

### 1. Procedure Code

```sql
CREATE OR REPLACE PROCEDURE dw.run_sales_etl()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_loaded   INT := 0;
    v_skipped       INT := 0;
    v_total_source  INT := 0;
BEGIN

    -- STEP 1: Upsert dim_customer
    -- Pulls latest customer info from OLTP; updates on conflict.
    INSERT INTO dw.dim_customer (source_id, full_name, region_code)
    SELECT id, full_name, region_code
    FROM public.customers
    ON CONFLICT (source_id) DO UPDATE
        SET full_name   = EXCLUDED.full_name,
            region_code = EXCLUDED.region_code;

    -- STEP 2: Upsert dim_product
    -- Captures product catalog changes (price, category updates).
    INSERT INTO dw.dim_product (source_id, product_name, category, unit_price)
    SELECT id, product_name, category, unit_price
    FROM public.products
    ON CONFLICT (source_id) DO UPDATE
        SET product_name = EXCLUDED.product_name,
            category     = EXCLUDED.category,
            unit_price   = EXCLUDED.unit_price;

    -- STEP 3: Upsert dim_branch
    -- Keeps branch location data current.
    INSERT INTO dw.dim_branch (source_id, branch_name, city, region)
    SELECT id, branch_name, city, region
    FROM public.branches
    ON CONFLICT (source_id) DO UPDATE
        SET branch_name = EXCLUDED.branch_name,
            city        = EXCLUDED.city,
            region      = EXCLUDED.region;

    -- STEP 4: Populate dim_date
    -- Inserts only new transaction dates; skips existing ones.
    INSERT INTO dw.dim_date (full_date, year, month, day, quarter)
    SELECT DISTINCT
        txn_date,
        EXTRACT(YEAR    FROM txn_date)::INT,
        EXTRACT(MONTH   FROM txn_date)::INT,
        EXTRACT(DAY     FROM txn_date)::INT,
        EXTRACT(QUARTER FROM txn_date)::INT
    FROM public.sales_txn
    WHERE txn_date IS NOT NULL
    ON CONFLICT (full_date) DO NOTHING;

    -- STEP 5: Count total valid source rows for reporting
    SELECT COUNT(*) INTO v_total_source
    FROM public.sales_txn
    WHERE qty > 0
      AND unit_price > 0
      AND customer_id IS NOT NULL
      AND product_id  IS NOT NULL
      AND branch_id   IS NOT NULL;

    -- STEP 6: Incremental fact load
    -- Only loads transactions not yet present in fact_sales.
    -- Applies data quality filters before inserting.
    INSERT INTO dw.fact_sales (
        source_txn_id, date_key, customer_key,
        product_key, branch_key, qty, unit_price, total_amount
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
    JOIN dw.dim_date     d ON d.full_date = s.txn_date
    JOIN dw.dim_customer c ON c.source_id = s.customer_id
    JOIN dw.dim_product  p ON p.source_id = s.product_id
    JOIN dw.dim_branch   b ON b.source_id = s.branch_id
    WHERE s.qty        > 0
      AND s.unit_price > 0
      AND s.customer_id IS NOT NULL
      AND s.product_id  IS NOT NULL
      AND s.branch_id   IS NOT NULL
      AND NOT EXISTS (
            SELECT 1 FROM dw.fact_sales f
            WHERE f.source_txn_id = s.id
          );

    GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;
    v_skipped := v_total_source - v_rows_loaded;

    -- STEP 7: Log success with row counts
    INSERT INTO dw.etl_log (status, rows_loaded, error_message)
    VALUES (
        'SUCCESS',
        v_rows_loaded,
        FORMAT('Loaded: %s new rows. Skipped (already exists): %s rows.',
               v_rows_loaded, v_skipped)
    );

    COMMIT;

EXCEPTION
    WHEN OTHERS THEN
        INSERT INTO dw.etl_log (status, rows_loaded, error_message)
        VALUES ('FAIL', 0, SQLERRM);

        COMMIT;
        RAISE;
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

```
 id |           run_ts           | status  | rows_loaded |                         error_message
----+----------------------------+---------+-------------+----------------------------------------------------------------
  1 | 2026-03-10 20:26:36.762677 | SUCCESS |          10 | Loaded: 10 new rows. Skipped (already exists): 0 rows.
(1 row)
```

---

## Part 4: Analytical Queries

### Query 1: Monthly Revenue by Branch Region

```sql
SELECT
    d.year,
    d.month,
    b.region,
    SUM(f.total_amount) AS revenue
FROM dw.fact_sales f
JOIN dw.dim_date   d ON f.date_key   = d.date_key
JOIN dw.dim_branch b ON f.branch_key = b.branch_key
GROUP BY d.year, d.month, b.region
ORDER BY d.year, d.month, revenue DESC;
```

**Interpretation:** This query aggregates total sales per region for each month, allowing management to spot which regions are driving growth or falling behind over time.

---

### Query 2: Top 5 Products by Total Revenue

```sql
SELECT
    p.product_name,
    SUM(f.total_amount) AS revenue
FROM dw.fact_sales  f
JOIN dw.dim_product p ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY revenue DESC
LIMIT 5;
```

**Interpretation:** This ranks the five highest-earning products across all branches and periods, helping the team prioritize stock and promotional efforts on best-sellers.

---

### Query 3: Customer Region Contribution to Sales

```sql
SELECT
    c.region_code,
    SUM(f.total_amount)                            AS total_sales,
    ROUND(100.0 * SUM(f.total_amount)
          / SUM(SUM(f.total_amount)) OVER (), 2)   AS pct_of_total
FROM dw.fact_sales   f
JOIN dw.dim_customer c ON f.customer_key = c.customer_key
GROUP BY c.region_code
ORDER BY total_sales DESC;
```

**Interpretation:** Beyond just totals, this query adds a percentage column showing each region's share of overall revenue, making it easy to compare relative contributions at a glance.