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
