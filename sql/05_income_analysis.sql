-- ==========================================================================
-- Q4 - How does income relate to repayment?
-- Includes a window function (NTILE) to cut borrowers into five equal-sized income groups.
-- ==========================================================================
-- Requires the views from 00_setup_and_cleaning.sql

-- Query 1: Default rate by income band
SELECT income_band,
       COUNT(*)                          AS borrowers,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_banded
GROUP BY income_band
ORDER BY income_band;

-- Query 2: Default rate by income quintile (NTILE)
-- NTILE(5) OVER (ORDER BY income) ranks borrowers by income and splits them into 5 groups of equal size. The inner query (a *CTE*, the WITH block) does the ranking; the outer query summarises it.
WITH ranked AS (
    SELECT defaulted, income,
           NTILE(5) OVER (ORDER BY income) AS income_quintile      -- 1 = lowest income
    FROM credit_clean
    WHERE income IS NOT NULL
)
SELECT income_quintile,
       COUNT(*)                          AS borrowers,
       ROUND(MIN(income), 0)             AS min_income,
       ROUND(MAX(income), 0)             AS max_income,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM ranked
GROUP BY income_quintile
ORDER BY income_quintile;

-- Query 3: Is a missing income a warning sign?
SELECT CASE WHEN income IS NULL THEN 'Income not reported' ELSE 'Income reported' END AS income_status,
       COUNT(*)                          AS borrowers,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_clean
GROUP BY income_status;
