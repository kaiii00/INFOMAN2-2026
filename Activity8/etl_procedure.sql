CREATE OR REPLACE PROCEDURE dw.run_sales_etl()
LANGUAGE plpgsql
AS $$
DECLARE
    v_rows_loaded   INT  := 0;
    v_skipped       INT  := 0;
    v_total_source  INT  := 0;
BEGIN

    -- STEP 1: Upsert dim_customer
    INSERT INTO dw.dim_customer (source_id, full_name, region_code)
    SELECT
        id,
        full_name,
        region_code
    FROM public.customers
    ON CONFLICT (source_id) DO UPDATE
        SET full_name   = EXCLUDED.full_name,
            region_code = EXCLUDED.region_code;

    -- STEP 2: Upsert dim_product
    INSERT INTO dw.dim_product (source_id, product_name, category, unit_price)
    SELECT
        id,
        product_name,
        category,
        unit_price
    FROM public.products
    ON CONFLICT (source_id) DO UPDATE
        SET product_name = EXCLUDED.product_name,
            category     = EXCLUDED.category,
            unit_price   = EXCLUDED.unit_price;

    -- STEP 3: Upsert dim_branch
    INSERT INTO dw.dim_branch (source_id, branch_name, city, region)
    SELECT
        id,
        branch_name,
        city,
        region
    FROM public.branches
    ON CONFLICT (source_id) DO UPDATE
        SET branch_name = EXCLUDED.branch_name,
            city        = EXCLUDED.city,
            region      = EXCLUDED.region;

    -- STEP 4: Populate dim_date
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
    INSERT INTO dw.fact_sales (
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
    FROM public.sales_txn    s
    JOIN dw.dim_date          d ON d.full_date  = s.txn_date
    JOIN dw.dim_customer      c ON c.source_id  = s.customer_id
    JOIN dw.dim_product       p ON p.source_id  = s.product_id
    JOIN dw.dim_branch        b ON b.source_id  = s.branch_id
    WHERE s.qty        > 0
      AND s.unit_price > 0
      AND s.customer_id IS NOT NULL
      AND s.product_id  IS NOT NULL
      AND s.branch_id   IS NOT NULL
      AND NOT EXISTS (
            SELECT 1
            FROM dw.fact_sales f
            WHERE f.source_txn_id = s.id
          );

    GET DIAGNOSTICS v_rows_loaded = ROW_COUNT;

    v_skipped := v_total_source - v_rows_loaded;

    -- STEP 7: Log success
    INSERT INTO dw.etl_log (status, rows_loaded, error_message)
    VALUES (
        'SUCCESS',
        v_rows_loaded,
        FORMAT(
            'Loaded: %s new rows. Skipped (already exists): %s rows.',
            v_rows_loaded,
            v_skipped
        )
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

CALL dw.run_sales_etl();

SELECT * FROM dw.etl_log ORDER BY run_ts DESC;