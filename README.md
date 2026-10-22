<<<<<<< HEAD
# Loan Default & Credit Risk Prediction

**Which borrowers are likely to default, what characteristics go with repayment problems, and can we predict it?**
An end-to-end credit-risk analytics project on the Kaggle [*Give Me Some Credit*](https://www.kaggle.com/competitions/GiveMeSomeCredit) dataset (150,000 borrowers), combining **SQL, Python (EDA + machine learning) and Tableau**.

| | |
|---|---|
| **Tools** | SQL (SQLite), Python (pandas, NumPy, scikit-learn, matplotlib, seaborn), Tableau |
| **Models** | Logistic Regression, Random Forest, Gradient Boosting (XGBoost-ready) |
| **Best result** | ROC AUC **0.869**, KS **0.58**, well-calibrated probabilities |
| **Business impact** | Reviewing the riskiest 10% of applicants finds **55%** of defaults; the cost-based decision rule cuts expected loss cost by about **36%** vs approving everyone (illustrative cost assumption) |

---

## Key findings

| Question | Answer |
|---|---|
| What % of borrowers default? | **6.68%** (10,026 of 149,999), about 1 in 15 |
| Which characteristics matter? | **Payment history** (2.8% default if never late vs 35% if 60+ days late), **credit utilization** (1.8% to 37%), **age** (11% for under-36s vs 2.4% for 65+) |
| Does loan amount matter? | *No loan-amount field exists.* Using credit-exposure proxies: utilization above 75% and debt ratio above 0.6 raise risk sharply; a thin file (0-2 credit lines) doubles it |
| How does income relate to repayment? | Steady but moderate: about 9% default below 4k/month vs 4% above 10k. Missing income is *not* riskier |
| Highest-risk segments? | **60+ days late + high utilization**: 41-46% default (6-7x average). The top 5 segments are 6% of borrowers but 37% of defaults |
| Can we predict default? | **Yes.** ROC AUC 0.87 (hold-out) / 0.866 (5-fold CV) |
| What matters most to the model? | Payment-history counts, then utilization, then age |

### Model comparison (20% hold-out set, 30,000 borrowers)

| Model | ROC AUC | PR AUC | KS |
|---|---|---|---|
| Gradient Boosting | **0.869** | **0.403** | 0.582 |
| Random Forest | 0.866 | 0.390 | 0.583 |
| Logistic Regression | 0.861 | 0.382 | 0.565 |

*(Random baseline for PR AUC is 0.067, the default rate.)*

### Predicted risk bands behave as intended (out-of-fold predictions)

| Risk band | Borrowers | Actual default rate |
|---|---|---|
| 1 - Very Low (<2%) | 73,011 | 0.9% |
| 2 - Low (2-5%) | 30,893 | 3.2% |
| 3 - Medium (5-10%) | 21,269 | 7.3% |
| 4 - High (10-20%) | 11,476 | 14.1% |
| 5 - Very High (>20%) | 13,350 | 38.9% |

---

## Repository structure

```text
credit-risk-project/
|-- README.md                      <- you are here
|-- requirements.txt
|-- data/
|   |-- raw/                       <- Kaggle files (cs-training.csv, cs-test.csv, data dictionary)
|   `-- processed/                 <- generated: SQLite database, Kaggle submission file
|-- notebooks/
|   |-- 01_credit_risk_eda_and_modeling.ipynb   <- Python: cleaning, EDA, ML, exports
|   `-- 02_sql_analysis.ipynb                   <- SQL: all business questions answered in SQL
|-- sql/                           <- the same queries as stand-alone .sql scripts
|   |-- 00_setup_and_cleaning.sql      views for cleaning + banding
|   |-- 01_data_quality_checks.sql
|   |-- 02_portfolio_overview.sql      Q1
|   |-- 03_default_by_characteristics.sql   Q2
|   |-- 04_credit_exposure.sql         Q3
|   |-- 05_income_analysis.sql         Q4
|   |-- 06_risk_segmentation.sql       Q5
|   `-- 07_rule_based_risk_tiers.sql   bonus: transparent rules vs ML
|-- tableau/
|   |-- TABLEAU_GUIDE.md           <- step-by-step dashboard build (fields, calcs, layout)
|   |-- data/                      <- CSVs for Tableau
|   `-- screenshots/               <- add dashboard screenshots here
`-- reports/
    |-- Credit_Risk_Project_Report.docx   <- full written report
    `-- figures/                          <- charts saved by the notebook
```

## How to run

```bash
git clone <your-repo-url> && cd credit-risk-project
python -m venv .venv && source .venv/bin/activate     # Windows: .venv\Scripts\activate
pip install -r requirements.txt
cd notebooks
jupyter notebook          # open and run 01_... then 02_... (Kernel -> Restart & Run All)
```
- Notebook 01 takes about 2-3 minutes. It writes the Tableau CSVs, chart images and a Kaggle-format prediction file.
- Notebook 02 builds `data/processed/credit_risk.db` (SQLite) and runs the SQL.
- To run a single script: load the CSV into `credit_raw` (notebook 02 does this), then run `sql/00_setup_and_cleaning.sql` followed by any other script.
- **XGBoost (optional):** `pip install xgboost` and re-run; notebook 01 switches to it automatically. The published numbers use scikit-learn's gradient boosting.

## Method summary

### 1. Data cleaning (rules applied identically in Python and SQL)

| Problem | Treatment |
|---|---|
| 19.8% missing income | Flag `income_missing`; median-fill inside the model pipeline (no leakage) |
| 2.6% missing dependents | Flag + median |
| 1 borrower aged 0 | Dropped |
| 269 rows with past-due counts of 96/98 (placeholder codes; 55% default rate) | Count reset to 0 **and flagged**, so the information is kept |
| Utilization up to 50,708x | Capped at 2.0 |
| Debt ratio is a raw dollar amount when income is missing | Blanked out + flagged (`debt_ratio_unreliable`) |
| Income outliers (to 3M/month) | Capped at 50,000 |

### 2. Modelling
- 80/20 stratified split; the median-fill and scaling are learned from training data only.
- Class imbalance (6.7% default) handled with class weights (LR, RF); evaluated with **ROC AUC, PR AUC and KS**, not accuracy.
- Robustness: 5-fold cross-validation (AUC 0.866 vs 0.869 hold-out).
- **Calibration** checked: predicted probabilities match actual default rates.
- **Decision threshold** from a cost assumption (missing a default costs 5x a wrongly declined good loan), giving the cut-off 1/(1+5) = 16.7%. At this cut-off: 10.4% declined, 56.4% of defaulters caught, 36% lower cost than approving everyone.
- **Explainability:** permutation importance and Logistic Regression odds ratios.

### 3. Visualisation
Tableau dashboards are built from the CSVs in `tableau/data/`; see [`tableau/TABLEAU_GUIDE.md`](tableau/TABLEAU_GUIDE.md).
Dashboard link: *add your Tableau Public URL here*

## Limitations
- **No loan amount, rate, term or purpose** in the data; exposure is analysed through proxies.
- The 5:1 cost ratio is an **illustrative assumption**, not a real business figure.
- **Age** is predictive but is restricted in credit decisions in many jurisdictions; a production model would need a fairness review and likely exclude it.
- Associations, not causal effects. Data is a historical snapshot, so a live model needs monitoring and retraining.

## Possible next steps
Hyper-parameter tuning, SHAP explanations, a weight-of-evidence scorecard, fairness audit, and a Streamlit app for scoring a single applicant.

## Data and credits
Data: Kaggle *Give Me Some Credit* competition (Credit Fusion, Will Cukierski). Use is subject to the competition's terms. Analysis code and documentation in this repository are original.
=======
# Loan_Default_and-_Credit_Risk_Prediction
End-to-end credit risk project on 150K borrowers: SQL analysis, Python EDA, and ML models (Logistic Regression, Random Forest, Gradient Boosting) to predict loan default. ROC AUC 0.87, with risk segmentation and Tableau-ready outputs.
>>>>>>> 664033308cfdeb00f62e9c924f52629e21fc18b7
