-- ==========================================================================
-- Q5 - Which customer segments have the highest risk?
-- A segment = payment history x utilization group x age group. We then rank segments and measure how much of the total default volume each one holds.
-- ==========================================================================
-- Requires the views from 00_setup_and_cleaning.sql

-- Query 1: Segment risk league table
-- Step by step:
-- 1. segmented assigns each borrower to a segment.
-- 2. segment_stats counts borrowers and defaults per segment.
-- 3. The final SELECT adds window functions: SUM(...) OVER () gives portfolio totals, so we can compute each segment's share and 'lift' (risk vs average); RANK() OVER (ORDER BY ...) ranks the segments.
-- 4. HAVING removes tiny segments (under 300 borrowers) whose rates are unreliable.
WITH segmented AS (
    SELECT defaulted,
           past_due_history,
           CASE WHEN utilization <= 0.30 THEN 'Low util (<30%)'
                WHEN utilization <= 0.75 THEN 'Medium util (30-75%)'
                ELSE 'High util (>75%)' END AS utilization_group,
           CASE WHEN age < 35 THEN 'Under 35' WHEN age < 55 THEN '35-54' ELSE '55+' END AS age_group
    FROM credit_banded
),
segment_stats AS (
    SELECT past_due_history, utilization_group, age_group,
           COUNT(*)       AS borrowers,
           SUM(defaulted) AS defaults
    FROM segmented
    GROUP BY past_due_history, utilization_group, age_group
    HAVING COUNT(*) >= 300
)
SELECT RANK() OVER (ORDER BY 1.0 * defaults / borrowers DESC)                    AS risk_rank,
       past_due_history, utilization_group, age_group,
       borrowers,
       ROUND(100.0 * defaults / borrowers, 1)                                    AS default_rate_pct,
       ROUND(100.0 * defaults / SUM(defaults) OVER (), 1)                        AS share_of_all_defaults_pct,
       ROUND((1.0 * defaults / borrowers) / (1.0 * SUM(defaults) OVER () / SUM(borrowers) OVER ()), 2) AS lift_vs_average
FROM segment_stats
ORDER BY risk_rank
LIMIT 12;

-- Query 2: Heat-map data: payment history x age band
-- Ready to paste into a heat-map: one row per combination.
SELECT past_due_history, age_band,
       COUNT(*)                          AS borrowers,
       ROUND(100.0 * AVG(defaulted), 1)  AS default_rate_pct
FROM credit_banded
GROUP BY past_due_history, age_band
ORDER BY past_due_history, age_band;
