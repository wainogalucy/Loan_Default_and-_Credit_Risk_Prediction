-- ==========================================================================
-- Q3 - Does loan amount (credit exposure) affect default?
-- The dataset has no loan-amount column, so we use the closest measures of how much credit someone carries: utilization, debt ratio and number of open lines.
-- ==========================================================================
-- Requires the views from 00_setup_and_cleaning.sql

-- Query 1: Default rate by credit utilization
SELECT utilization_band,
       COUNT(*)                          AS borrowers,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_banded
GROUP BY utilization_band
ORDER BY utilization_band;

-- Query 2: Default rate by debt ratio
-- Debt ratio = monthly debt payments / monthly income. 'Unknown' = no income reported.
SELECT debt_ratio_band,
       COUNT(*)                          AS borrowers,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_banded
GROUP BY debt_ratio_band
ORDER BY debt_ratio_band;

-- Query 3: Default rate by number of open credit lines
SELECT open_lines_band,
       COUNT(*)                          AS borrowers,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM credit_banded
GROUP BY open_lines_band
ORDER BY open_lines_band;
