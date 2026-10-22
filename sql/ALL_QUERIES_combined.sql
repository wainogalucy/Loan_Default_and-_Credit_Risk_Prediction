-- Setup: cleaning view + banded view (SQLite syntax)

-- Raw table is loaded from cs-training.csv by the notebook (table name: credit_raw)
--   borrower_id, defaulted, utilization, age, late_30_59, debt_ratio, income,
--   open_lines, late_90, real_estate, late_60_89, dependents

DROP VIEW IF EXISTS credit_clean;
CREATE VIEW credit_clean AS
SELECT
    borrower_id,
    defaulted,
    age,
    -- 96 / 98 are placeholder codes, not real counts -> flag them and reset the count to 0
    CASE WHEN late_30_59 >= 96 OR late_60_89 >= 96 OR late_90 >= 96 THEN 1 ELSE 0 END AS delinq_code_flag,
    CASE WHEN late_30_59 >= 96 THEN 0 ELSE late_30_59 END AS late_30_59,
    CASE WHEN late_60_89 >= 96 THEN 0 ELSE late_60_89 END AS late_60_89,
    CASE WHEN late_90    >= 96 THEN 0 ELSE late_90    END AS late_90,
    MIN(utilization, 2.0)                                AS utilization,   -- cap at 200%
    CASE WHEN income IS NULL THEN NULL ELSE MIN(income, 50000) END AS income,  -- cap outliers
    -- debt ratio is only credible when income is known and the value is plausible
    CASE WHEN income IS NULL OR debt_ratio > 5 THEN NULL ELSE debt_ratio END AS debt_ratio,
    open_lines,
    real_estate,
    dependents
FROM credit_raw
WHERE age >= 18;                                   -- removes the impossible age-0 record

-- NOTE: MIN(a, b) with two arguments is SQLite's "smaller of". Use LEAST(a, b) in PostgreSQL / MySQL.

DROP VIEW IF EXISTS credit_banded;
CREATE VIEW credit_banded AS
SELECT
    c.*,
    CASE WHEN age <= 25 THEN '1: 18-25'  WHEN age <= 35 THEN '2: 26-35'  WHEN age <= 45 THEN '3: 36-45'
         WHEN age <= 55 THEN '4: 46-55'  WHEN age <= 65 THEN '5: 56-65'  ELSE '6: 65+' END       AS age_band,
    CASE WHEN income IS NULL  THEN '7: Unknown'  WHEN income <= 2500 THEN '1: <2.5k'
         WHEN income <= 4000  THEN '2: 2.5-4k'   WHEN income <= 5500 THEN '3: 4-5.5k'
         WHEN income <= 7500  THEN '4: 5.5-7.5k' WHEN income <= 10000 THEN '5: 7.5-10k'
         ELSE '6: 10k+' END                                                                       AS income_band,
    CASE WHEN utilization <= 0.10 THEN '1: 0-10%'   WHEN utilization <= 0.30 THEN '2: 10-30%'
         WHEN utilization <= 0.50 THEN '3: 30-50%'  WHEN utilization <= 0.75 THEN '4: 50-75%'
         WHEN utilization <= 1.00 THEN '5: 75-100%' ELSE '6: >100%' END                           AS utilization_band,
    CASE WHEN debt_ratio IS NULL THEN '6: Unknown'  WHEN debt_ratio <= 0.2 THEN '1: 0-0.2'
         WHEN debt_ratio <= 0.4  THEN '2: 0.2-0.4'  WHEN debt_ratio <= 0.6 THEN '3: 0.4-0.6'
         WHEN debt_ratio <= 1.0  THEN '4: 0.6-1.0'  ELSE '5: 1.0-5.0' END                         AS debt_ratio_band,
    CASE WHEN open_lines <= 2 THEN '1: 0-2'  WHEN open_lines <= 5  THEN '2: 3-5'
         WHEN open_lines <= 8 THEN '3: 6-8'  WHEN open_lines <= 12 THEN '4: 9-12' ELSE '5: 13+' END AS open_lines_band,
    CASE WHEN late_90 > 0 OR late_60_89 > 0 THEN '3: 60+ days late'
         WHEN late_30_59 > 0                THEN '2: 30-59 days late only'
         ELSE '1: Never late' END                                                                 AS past_due_history
FROM credit_clean AS c;


-- ==========================================================================
-- Data-quality checks
-- Before analysing anything, count the problems in the *raw* table. These checks justify the cleaning rules in credit_clean.
-- ==========================================================================
-- Requires the views from 00_setup_and_cleaning.sql

-- Query 1: Row count and missing values
-- COUNT(col) ignores NULLs while COUNT(*) counts every row, so the difference is the number of missing values.
SELECT COUNT(*)                          AS total_rows,
       COUNT(*) - COUNT(income)          AS missing_income,
       COUNT(*) - COUNT(dependents)      AS missing_dependents,
       ROUND(100.0 * (COUNT(*) - COUNT(income)) / COUNT(*), 1) AS missing_income_pct
FROM credit_raw;

-- Query 2: Impossible or suspicious values
-- Each SUM(CASE WHEN ... THEN 1 ELSE 0 END) is a conditional count: how many rows break a rule.
SELECT SUM(CASE WHEN age < 18 THEN 1 ELSE 0 END)                                         AS age_under_18,
       SUM(CASE WHEN late_30_59 >= 96 OR late_60_89 >= 96 OR late_90 >= 96 THEN 1 ELSE 0 END)   AS placeholder_codes_96_98,
       SUM(CASE WHEN utilization > 2 THEN 1 ELSE 0 END)                                         AS utilization_over_200pct,
       SUM(CASE WHEN income IS NULL OR debt_ratio > 5 THEN 1 ELSE 0 END)                        AS unreliable_debt_ratio
FROM credit_raw;

-- Query 3: Are the 96/98 'placeholder' rows special?
-- Their default rate is about 8x the rest, so we keep them (flagged) rather than delete them.
SELECT CASE WHEN late_30_59 >= 96 OR late_60_89 >= 96 OR late_90 >= 96
            THEN 'Placeholder code (96/98)' ELSE 'Normal rows' END AS row_type,
       COUNT(*)                                  AS borrowers,
       ROUND(100.0 * AVG(defaulted), 1)          AS default_rate_pct
FROM credit_raw
GROUP BY row_type;


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


-- ==========================================================================
-- Bonus - A simple rules-based risk tier (no machine learning)
-- Many lenders start with transparent business rules. Here is one that can be written in SQL, followed by how well it separates good and bad borrowers. It is a useful benchmark for the ML model (see the Python notebook).
-- ==========================================================================
-- Requires the views from 00_setup_and_cleaning.sql

-- Query 1: Rule-based tiers and their actual default rates
-- Rules are checked top to bottom; the first match wins.
WITH tiered AS (
    SELECT defaulted,
           CASE WHEN late_90 > 0 OR late_60_89 > 0 OR utilization > 1.0 THEN 'Tier 4 - High risk'
                WHEN late_30_59 > 0 OR utilization > 0.75             THEN 'Tier 3 - Elevated'
                WHEN utilization > 0.30 OR age < 35                   THEN 'Tier 2 - Moderate'
                ELSE 'Tier 1 - Low risk' END AS risk_tier
    FROM credit_clean
)
SELECT risk_tier,
       COUNT(*)                          AS borrowers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_portfolio,
       SUM(defaulted)                    AS defaults,
       ROUND(100.0 * AVG(defaulted), 2)  AS default_rate_pct
FROM tiered
GROUP BY risk_tier
ORDER BY risk_tier;

-- Query 2: Cumulative defaults captured as we review tiers from riskiest down
-- A running total (SUM() OVER (ORDER BY ...)) shows how many defaults we find if we only look at the riskiest tiers.
WITH tiered AS (
    SELECT defaulted,
           CASE WHEN late_90 > 0 OR late_60_89 > 0 OR utilization > 1.0 THEN 'Tier 4 - High risk'
                WHEN late_30_59 > 0 OR utilization > 0.75             THEN 'Tier 3 - Elevated'
                WHEN utilization > 0.30 OR age < 35                   THEN 'Tier 2 - Moderate'
                ELSE 'Tier 1 - Low risk' END AS risk_tier
    FROM credit_clean
),
tier_stats AS (
    SELECT risk_tier, COUNT(*) AS borrowers, SUM(defaulted) AS defaults
    FROM tiered GROUP BY risk_tier
)
SELECT risk_tier, borrowers, defaults,
       ROUND(100.0 * SUM(borrowers) OVER (ORDER BY risk_tier DESC) / SUM(borrowers) OVER (), 1) AS cum_pct_of_borrowers,
       ROUND(100.0 * SUM(defaults)  OVER (ORDER BY risk_tier DESC) / SUM(defaults)  OVER (), 1) AS cum_pct_of_defaults
FROM tier_stats
ORDER BY risk_tier DESC;
