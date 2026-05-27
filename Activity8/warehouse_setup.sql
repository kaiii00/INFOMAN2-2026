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
    full_date DATE    UNIQUE NOT NULL,
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