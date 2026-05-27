# Query Analysis and Optimization

---

## Scenario 1: The Slow Author Profile Page

### Before Query Plan and Execution times

```
                                                QUERY PLAN
-----------------------------------------------------------------------------------------------------------
 Sort  (cost=555.00..555.05 rows=18 width=528) (actual time=2.294..2.296 rows=34 loops=1)
   Sort Key: date DESC
   Sort Method: quicksort  Memory: 27kB
   ->  Seq Scan on posts  (cost=0.00..554.62 rows=18 width=528) (actual time=0.031..2.240 rows=34 loops=1)
         Filter: (author_id = 136)
         Rows Removed by Filter: 9966
 Planning Time: 0.435 ms
 Execution Time: 2.345 ms
(8 rows)
```

### Query:

```sql
EXPLAIN ANALYZE
SELECT id, title
FROM posts
WHERE author_id = 136
ORDER BY date DESC;
```

### After Query Plan and Execution times

```
                                                               QUERY PLAN
-----------------------------------------------------------------------------------------------------------------------------------------
 Sort  (cost=112.66..112.74 rows=34 width=56) (actual time=0.201..0.203 rows=34 loops=1)
   Sort Key: date DESC
   Sort Method: quicksort  Memory: 27kB
   ->  Bitmap Heap Scan on posts  (cost=4.55..111.79 rows=34 width=56) (actual time=0.026..0.163 rows=34 loops=1)
         Recheck Cond: (author_id = 136)
         Heap Blocks: exact=33
         ->  Bitmap Index Scan on idx_author_id_date  (cost=0.00..4.54 rows=34 width=0) (actual time=0.017..0.017 rows=34 loops=1)
               Index Cond: (author_id = 136)
 Planning Time: 0.435 ms
 Execution Time: 0.250 ms
(10 rows)
```

### Analysis Questions:

- **What is the primary node causing the slowness in the initial execution plan?**
The main bottleneck is the **Sequential Scan (Seq Scan)** on the `posts` table. PostgreSQL reads all 10,000 rows and filters them one by one using `author_id = 136`. As shown by `Rows Removed by Filter: 9966`, 99.66% of all rows are scanned and discarded before returning the 34 matching rows. There is also a separate **Sort** node that runs after the scan to apply `ORDER BY date DESC`, adding extra overhead.

- **How can you optimize both the `WHERE` clause filtering and the `ORDER BY` operation with a single change?**
Create a **composite index on `(author_id, date DESC)`**. The leading `author_id` column lets PostgreSQL jump directly to matching rows, eliminating the full sequential scan. The trailing `date DESC` column stores rows in the exact order the query needs, so the planner can skip the separate sort step entirely.

- **Implement your fix and record the new plan. How much faster is the query now?**

```sql
CREATE INDEX idx_author_id_date ON posts (author_id, date DESC);
```

The query improved from **2.345 ms** down to **0.250 ms** — approximately **9.4× faster**. The planner switched from a Seq Scan scanning all 10,000 rows to a Bitmap Index Scan that only touches the 34 rows belonging to author 136.

---

## Scenario 2: The Unsearchable Blog

### Before Query Plan and Execution times

```
                                            QUERY PLAN
---------------------------------------------------------------------------------------------------
 Seq Scan on posts  (cost=0.00..635.00 rows=505 width=44) (actual time=0.015..4.278 rows=464 loops=1)
   Filter: ((title)::text ~~ '%Dolor%'::text)
   Rows Removed by Filter: 9536
 Planning Time: 0.240 ms
 Execution Time: 4.373 ms
(5 rows)
```

### Query:

```sql
EXPLAIN ANALYZE
SELECT title
FROM posts
WHERE title LIKE '%Dolor%';
```

### After Query Plan and Execution times

```
                                                            QUERY PLAN
----------------------------------------------------------------------------------------------------------------------------------
 Index Only Scan using idx_posts_title_pattern on posts  (cost=0.29..31.42 rows=505 width=44) (actual time=0.047..0.150 rows=464 loops=1)
   Index Cond: ((title ~>=~ 'Dolor'::text) AND (title ~<~ 'Dolos'::text))
   Filter: ((title)::text ~~ 'Dolor%'::text)
   Heap Fetches: 0
 Planning Time: 0.740 ms
 Execution Time: 0.181 ms
(6 rows)
```

### Analysis Questions:

- **First, try adding a standard B-Tree index on the `title` column. Run `EXPLAIN ANALYZE` again. Did the planner use your index? Why or why not?**
No, the planner did **not** use the standard B-Tree index for `LIKE '%Dolor%'`. The plan still showed a Seq Scan with no improvement. This is because the pattern starts with a wildcard `%`, meaning there is no fixed prefix to seek to in the index. PostgreSQL must evaluate every row individually, making the B-Tree index completely useless for contains-style searches.

- **The business team agrees that searching by a prefix is acceptable for the first version. Rewrite the query to use a prefix search (e.g., `database%`).**

```sql
EXPLAIN ANALYZE
SELECT title
FROM posts
WHERE title LIKE 'Dolor%';
```

- **Does the index work for the prefix-style query? Explain the difference in the execution plan.**
Yes, but only after replacing the plain B-Tree with a `text_pattern_ops` index. A standard B-Tree index does not work for `LIKE` prefix searches in PostgreSQL because the default collation is locale-aware and incompatible with byte-level `LIKE` matching. The `text_pattern_ops` operator class uses byte-sorted order that `LIKE` requires. After creating the correct index, the planner used an **Index Only Scan** instead of a Seq Scan, translating `LIKE 'Dolor%'` into a bounded range condition — drastically reducing execution time from **4.373 ms** to **0.181 ms** (~24× faster).

```sql
CREATE INDEX idx_posts_title_pattern ON posts (title text_pattern_ops);
```

---

## Scenario 3: The Monthly Performance Report

### Before Query Plan and Execution times

```
                                              QUERY PLAN
-------------------------------------------------------------------------------------------------------
 Seq Scan on posts  (cost=0.00..710.00 rows=1 width=56) (actual time=0.137..3.537 rows=22 loops=1)
   Filter: ((EXTRACT(year FROM date) = '2015'::numeric) AND (EXTRACT(month FROM date) = '1'::numeric))
   Rows Removed by Filter: 9978
 Planning Time: 0.187 ms
 Execution Time: 3.553 ms
(5 rows)
```

### Query:

```sql
EXPLAIN ANALYZE
SELECT id, title, date
FROM posts
WHERE EXTRACT(YEAR FROM date) = 2015
  AND EXTRACT(MONTH FROM date) = 1;
```

### After Query Plan and Execution times

```
                                                       QUERY PLAN
-------------------------------------------------------------------------------------------------------------------------
 Bitmap Heap Scan on posts  (cost=4.45..60.19 rows=16 width=56) (actual time=0.037..0.062 rows=22 loops=1)
   Recheck Cond: ((date >= '2015-01-01'::date) AND (date < '2015-02-01'::date))
   Heap Blocks: exact=22
   ->  Bitmap Index Scan on idx_posts_date  (cost=0.00..4.45 rows=16 width=0) (actual time=0.031..0.031 rows=22 loops=1)
         Index Cond: ((date >= '2015-01-01'::date) AND (date < '2015-02-01'::date))
 Planning Time: 0.826 ms
 Execution Time: 0.100 ms
(7 rows)
```

### Analysis Questions:

- **This query is not S-ARGable. What does that mean in the context of this query? Why can't the query planner use a simple index on the `date` column effectively?**
**S-ARGable** stands for *Search ARGument ABLE* — a predicate that can be used to directly seek into an index. This query is not S-ARGable because it wraps the `date` column inside `EXTRACT()` functions. The index stores raw date values, not extracted year/month values. To evaluate the filter, PostgreSQL must read every row, call `EXTRACT()` on each one, and compare the result. Even if an index exists on `date`, the planner cannot use it because the column is hidden inside a function call — resulting in a full Seq Scan of all 10,000 rows.

- **Rewrite the query to use a direct date range comparison, making it S-ARGable.**

```sql
SELECT id, title, date
FROM posts
WHERE date >= '2015-01-01'
  AND date < '2015-02-01';
```

- **Create an appropriate index to support your rewritten query.**

```sql
CREATE INDEX idx_posts_date ON posts (date);
```

- **Compare the performance of the original query and your optimized version.**
The original `EXTRACT()` query performed a full sequential scan of all 10,000 rows and took **3.553 ms**. The optimized date range query with `idx_posts_date` only touched the 22 matching rows and executed in **0.100 ms** — approximately **35.5× faster**. The planner switched from a Seq Scan to a Bitmap Index Scan, proving that making the query S-ARGable and adding the right index has a dramatic effect on performance.

---

## Submission and Rubric (20 Points Total)

Please submit the following:

1. Your final `schema_postgres.sql` file.
2. A separate SQL file named `indexes.sql` containing all the `CREATE INDEX` statements you used to optimize the queries.
3. A Markdown document containing your analysis for each of the four scenarios. This document must include:
   - The "before" and "after" execution plans from `EXPLAIN ANALYZE`.
   - The provided queries for each scenario with `EXPLAIN ANALYZE`
   - Your answers to the analysis questions for each scenario.