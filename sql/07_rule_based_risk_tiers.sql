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
