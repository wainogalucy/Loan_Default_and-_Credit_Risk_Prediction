-- ==========================================================================
-- Q2 - Which customer characteristics are associated with default?
-- Same pattern each time: GROUP BY a band, count borrowers, and compute the default rate. credit_banded already contains the bands.
-- ==========================================================================
-- Requires the views from 00_setup_and_cleaning.sql

-- Query 1: Default rate by age band
SELECT age_band,
       COUNT(*)                          AS borrowers,
       SUM(defaulted)                    AS defaults,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_banded
GROUP BY age_band
ORDER BY age_band;

-- Query 2: Default rate by payment history
SELECT past_due_history,
       COUNT(*)                          AS borrowers,
       SUM(defaulted)                    AS defaults,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_banded
GROUP BY past_due_history
ORDER BY past_due_history;

-- Query 3: Default rate by number of 90+ day lates
-- MIN(late_90, 4) lumps '4 or more' together.
SELECT MIN(late_90, 4)                  AS times_90_days_late,
       COUNT(*)                          AS borrowers,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_clean
GROUP BY MIN(late_90, 4)
ORDER BY times_90_days_late;

-- Query 4: Default rate by number of dependents
SELECT COALESCE(CAST(CAST(MIN(dependents, 4) AS INTEGER) AS TEXT), 'Unknown') AS dependents_4_means_4plus,
       COUNT(*)                          AS borrowers,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_clean
GROUP BY dependents_4_means_4plus
ORDER BY dependents_4_means_4plus;
