-- ==========================================================================
-- Q1 - What percentage of borrowers default?
-- The headline numbers for the whole portfolio. AVG(defaulted) works because defaulted is 0/1, so its average *is* the default rate.
-- ==========================================================================
-- Requires the views from 00_setup_and_cleaning.sql

-- Query 1: Overall default rate
SELECT COUNT(*)                          AS borrowers,
       SUM(defaulted)                    AS defaults,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_clean;

-- Query 2: Portfolio profile: defaulters vs non-defaulters
-- Side-by-side averages show how the two groups differ at a glance.
SELECT CASE defaulted WHEN 1 THEN 'Defaulted' ELSE 'Did not default' END AS outcome,
       COUNT(*)                          AS borrowers,
       ROUND(AVG(age), 1)                AS avg_age,
       ROUND(AVG(income), 0)             AS avg_income,
       ROUND(AVG(utilization), 2)        AS avg_utilization,
       ROUND(AVG(late_30_59 + late_60_89 + late_90), 2) AS avg_late_events
FROM credit_clean
GROUP BY defaulted;
