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
