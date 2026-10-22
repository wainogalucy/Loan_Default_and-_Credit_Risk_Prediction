# Tableau Dashboard Build Guide

Credit-risk dashboard built from the exported CSVs in `tableau/data/`.
Works in **Tableau Public** (free) or Tableau Desktop. Estimated build time: 60-90 minutes.

> The CSVs are ready to connect. The `.twbx` workbook itself is **not included**: it has to be built and saved in Tableau.
> This guide gives every field, calculation and layout so the result is quick to reproduce.
> After building, save screenshots into `tableau/screenshots/` and link your Tableau Public URL in the main README.

---

## 1. Data sources

| File | Rows | Grain | Use for |
|---|---|---|---|
| `borrower_risk_scores.csv` | 149,999 | one row per borrower | **Main source**: all KPIs, driver charts, risk bands, heat-map |
| `segment_summary.csv` | 27 | one row per segment (min 300 borrowers) | Top-risk segments chart |
| `risk_decile_lift.csv` | 10 | one row per risk decile | Lift / gains chart |
| `model_comparison.csv` | 3 | one row per model | Model-performance table |
| `feature_importance.csv` | 15 | one row per feature | Feature-importance bar chart |

Connect with **Text file** and add each CSV as a separate data source (they do **not** need to be joined; each feeds its own sheets).

Key columns in `borrower_risk_scores.csv`:
`default` (0/1), `predicted_pd` (model probability, out-of-fold), `risk_band`, `risk_decile`, `model_decision`,
`age_band`, `income_band`, `utilization_band`, `debt_ratio_band`, `open_lines_band`, `dependents_band`, `past_due_history`, `segment`.

**Set data types:** `default` -> Number (whole), `predicted_pd` -> Number (decimal), `borrower_id` -> String (so Tableau does not sum it).

---

## 2. Parameters (Analysis -> Create Parameter)

| Name | Type | Current value | Range / step |
|---|---|---|---|
| `Decline Threshold` | Float | 0.167 | 0.02 to 0.50, step 0.01 |
| `Cost of Missed Default` | Float | 5 | 1 to 20, step 1 |
| `Cost of Wrong Decline` | Float | 1 | 1 to 5, step 1 |

Right-click each -> **Show Parameter**. These make the dashboard interactive: users can see how the approval cut-off changes the cost.

---

## 3. Calculated fields (on `borrower_risk_scores`)

```text
// Borrowers
COUNTD([borrower_id])

// Defaults
SUM([default])

// Default Rate    (format: Percentage, 1 decimal)
SUM([default]) / COUNT([borrower_id])

// Avg Predicted PD   (format: Percentage, 1 decimal)
AVG([predicted_pd])

// Portfolio Default Rate  (reference line value)
{ FIXED : SUM([default]) / COUNT([borrower_id]) }

// Risk vs Average (lift)
[Default Rate] / [Portfolio Default Rate]

// Share of All Defaults
SUM([default]) / TOTAL(SUM([default]))

// Decision (dynamic, responds to the parameter)
IF [predicted_pd] > [Decline Threshold] THEN "Decline / review" ELSE "Approve" END

// Cost with Model
SUM(
  IF [Decision] = "Approve" AND [default] = 1 THEN [Cost of Missed Default]
  ELSEIF [Decision] = "Decline / review" AND [default] = 0 THEN [Cost of Wrong Decline]
  ELSE 0 END
)

// Cost if Approving Everyone
SUM([default]) * [Cost of Missed Default]

// Cost Reduction %    (format: Percentage, 1 decimal)
1 - [Cost with Model] / [Cost if Approving Everyone]

// Defaulters Caught %  (recall)
SUM(IF [Decision] = "Decline / review" AND [default] = 1 THEN 1 ELSE 0 END) / SUM([default])

// Declined %
SUM(IF [Decision] = "Decline / review" THEN 1 ELSE 0 END) / COUNT([borrower_id])
```

**Expected values at the default parameters (threshold 0.167, costs 5 / 1):** default rate 6.7%, declined 10.4%, defaulters caught 56.4%, cost reduction about 36%.
Use these to check your calculations.

---

## 4. Worksheets

| # | Sheet name | Chart | Columns | Rows / Marks |
|---|---|---|---|---|
| 1 | KPI - Borrowers | Text | - | `Borrowers` |
| 2 | KPI - Default Rate | Text | - | `Default Rate` |
| 3 | KPI - Avg PD | Text | - | `Avg Predicted PD` |
| 4 | KPI - Cost Reduction | Text | - | `Cost Reduction %` |
| 5 | Default by Age | Bar | `age_band` | `Default Rate`; reference line = `Portfolio Default Rate` |
| 6 | Default by Payment History | Bar | `past_due_history` | `Default Rate`; reference line |
| 7 | Default by Utilization | Bar | `utilization_band` | `Default Rate`; reference line |
| 8 | Default by Income | Bar | `income_band` | `Default Rate`; reference line |
| 9 | Default by Debt Ratio | Bar | `debt_ratio_band` | `Default Rate`; reference line |
| 10 | Heat-map History x Age | Highlight table | Columns: `age_band`; Rows: `past_due_history` | Colour + label = `Default Rate` (red-sequential); size/tooltip = `Borrowers` |
| 11 | Risk Band Calibration | Bar (side-by-side) | `risk_band` | `Avg Predicted PD` and `Default Rate` (Measure Names/Values): they should match closely |
| 12 | Borrowers per Risk Band | Bar | `risk_band` | `Borrowers`; colour = `risk_band` |
| 13 | Top Risk Segments | Horizontal bar (from `segment_summary`) | `default_rate_pct` | `segment`, sorted descending; tooltip: `borrowers`, `share_of_all_defaults_%` |
| 14 | Lift Curve | Line (from `risk_decile_lift`) | `risk_decile` | `cum_defaults_captured_%` plus a reference line from (0,0) to (10,100) |
| 15 | Feature Importance | Horizontal bar (from `feature_importance`) | `auc_drop` | `feature`, sorted descending, top 10 |
| 16 | Model Comparison | Text table (from `model_comparison`) | Measure Names | `model` x ROC AUC, PR AUC, KS |

**Tips**
- **Sorting bands:** text bands sort alphabetically, which breaks `<2.5k`, `10k+`, `>100%` ordering. For `income_band`, `utilization_band` and `debt_ratio_band` use right-click -> **Sort -> Manual** and set the logical order (lowest to highest). `age_band`, `open_lines_band`, and `risk_band` already sort correctly (`risk_band` is prefixed 1-5).
- **Colours:** use one blue for normal bars, red (`#C0392B`) for the highest-risk bar/band, and a diverging or sequential red palette for the heat-map. Keep one consistent palette across sheets.
- **Reference line:** Analytics pane -> Reference Line -> Per Pane -> Value = `Portfolio Default Rate` -> dashed, label "Average".
- **Tooltips:** add `Borrowers` to every tooltip so users see group size, not just the rate.
- **Formatting:** Default Rate as `0.0%`; hide field labels for rows where redundant; remove grid lines.

---

## 5. Dashboards

### Dashboard 1: "Portfolio & Risk Drivers" (size: 1400 x 900, Automatic or Fixed)

```text
+--------------------------------------------------------------------------------+
|  Credit Risk Dashboard: Give Me Some Credit                    [Filters]       |
|  KPI: Borrowers | KPI: Default Rate | KPI: Avg Predicted PD | KPI: High-risk % |
+--------------------------------------------------------------------------------+
|  Default by Payment History      |  Default by Utilization                     |
|  (sheet 6)                       |  (sheet 7)                                  |
+----------------------------------+---------------------------------------------+
|  Default by Age (sheet 5)        |  Default by Income (sheet 8)                |
+----------------------------------+---------------------------------------------+
|  Heat-map: Payment history x Age (sheet 10)  |  Default by Debt Ratio (sheet 9) |
+--------------------------------------------------------------------------------+
```
Filters (apply to all sheets using this data source): `age_band`, `income_band`, `risk_band`, `past_due_history`.
Add **Use as Filter** on the payment-history and risk-band charts so clicking a bar filters the rest.

### Dashboard 2: "Risk Model & Decisions"

```text
+--------------------------------------------------------------------------------+
|  Parameters: [Decline Threshold] [Cost of Missed Default] [Cost of Wrong Decline] |
|  KPI: Declined %  | KPI: Defaulters Caught % | KPI: Cost Reduction %             |
+------------------------------------------+-------------------------------------+
|  Borrowers per Risk Band (sheet 12)      |  Predicted vs Actual by Band (11)   |
+------------------------------------------+-------------------------------------+
|  Lift Curve (sheet 14)                   |  Feature Importance (sheet 15)      |
+------------------------------------------+-------------------------------------+
|  Top Risk Segments (sheet 13)            |  Model Comparison (sheet 16)        |
+--------------------------------------------------------------------------------+
```

---

## 6. Insights to call out in text boxes on the dashboard

1. **6.7%** of borrowers default (about 1 in 15).
2. Payment history: **2.8%** (never late) vs **35%** (60+ days late).
3. Utilization above 75% -> **18%** default; over the limit -> **37%**.
4. Predicted risk band 5 (>20% PD) -> **39%** actual default vs **0.9%** in band 1.
5. Reviewing the riskiest **10%** of borrowers captures **55%** of defaults.

## 7. Publishing checklist
- [ ] Both dashboards render without scroll at the chosen size
- [ ] Parameters visible and working (try threshold 0.10 and 0.30)
- [ ] KPI values match the expected values in section 3
- [ ] Titles, axis labels and tooltips are readable
- [ ] Save to **Tableau Public**, copy the URL into the main `README.md`
- [ ] Save PNG screenshots of both dashboards to `tableau/screenshots/`
