--Part 1
--Create a table
CREATE TABLE IF NOT EXISTS employees (
    id          SERIAL PRIMARY KEY,
    first_name  VARCHAR(50),
    last_name   VARCHAR(50),
    salary      NUMERIC(10, 2),
    hire_date   DATE
);

--Part 2
--Run this 10 times to create 10,000 rows
\i C:/Users/ANKIE/Downloads/employees.sql

--Part 3
--Verify Row Count
SELECT COUNT(*) FROM employees;

--Part 4
EXPLAIN ANALYZE SELECT * FROM employees WHERE first_name = 'Maria';

--Part 5
CREATE INDEX idx_first_name ON employees(first_name);
EXPLAIN ANALYZE SELECT * FROM employees WHERE first_name = 'Maria';

--Part 6
INSERT INTO employees (first_name, last_name, salary, hire_date)
VALUES ('TestUser', 'IndexTest', 55000.00, '2024-01-15');


1. How did the query execution time change after creating the index? Was it faster or slower? By approximately how much?
        After creating the index on first_name, the query became much faster.

        Before the index: 12.302 ms
        After the index: 0.085 ms

        It got faster by about 12 ms, which is roughly 145 times faster.
        
2. Why do you think the query performance changed as you observed?
        The query got faster because the index lets PostgreSQL find the rows directly instead of looking through every
        ow one by one. Before the index, it had to check all 100,000 rows (sequential scan). With the index, it only
        looked at the rows that matched.

3. What is the trade-off of having an index on a table?
        Indexes make reading/querying data faster, but they make inserting or updating data a little slower because
        PostgreSQL has to also update the index. That's why inserting a single row after adding the index takes
        slightly more time than inserting into a table without an index.
   