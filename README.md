# House Prices in Ames, Iowa: Price Drivers, Market Segments and Prediction

An end-to-end data analysis and machine learning project: cleaning messy real-estate data, finding what drives house prices, segmenting the market, predicting prices with **11 compared models**, and analysing the results in **SQL (MySQL)**.

**Main result:** a blend of Lasso regression and Gradient Boosting predicts the prices of unseen houses with **R² = 0.93** and a mean absolute error of **$12.7k (7.7%)**. **75%** of predictions fall within ±10% of the actual price.

👉 **[Open the full analysis notebook](analysis.ipynb)**

---

## Results at a glance

| Task | Question | Best approach | Result |
|---|---|---|---|
| **Exploratory analysis** | What drives the price? | Spearman correlation, η², Kruskal–Wallis tests | Size, quality, location and age; the neighbourhood alone explains 57% of price variance |
| **Regression** | How much is a house worth? | Lasso + Gradient Boosting blend | R² 0.93, MAE $12.7k, MAPE 7.7% on the hold-out set |
| **Clustering** | Are there natural market segments? | K-Means (k = 3), compared with Ward and GMM | 3 segments that explain 65% of price variance, found without using the price |
| **Classification** | Is a house Budget, Mid-range or Premium? | Random Forest, compared with 5 other classifiers | 86.6% accuracy; only 1 of 292 houses confused between Budget and Premium |
| **SQL analysis (MySQL)** | Which sales are far from the estimated value? | Database with 4 linked tables and a valuation view; CTEs and window functions | 75% of sales within ±10% of the estimate, but only half of foreclosures and short sales |

## Business questions

1. Which property characteristics have the strongest relationship with the sale price?
2. How accurately can the sale price be predicted, and which model works best?
3. Do houses form natural market segments?
4. Can a house be classified into a price segment (Budget / Mid-range / Premium)?
5. Which sales are priced far from the model's estimate, and why?

## Dataset

[Kaggle: House Prices – Advanced Regression Techniques](https://www.kaggle.com/competitions/house-prices-advanced-regression-techniques): **1,460 houses** sold in Ames, Iowa in 2006–2010, described by **79 features** (size, quality, age, location, amenities and more), plus 1,459 houses without prices for the Kaggle submission.

## Approach

**1. Data cleaning and feature engineering**
- Found and fixed data-quality issues *before* imputation: 2 documented outliers, an impossible garage year (2207), a garage type recorded for a house with no garage, and 23 values where a feature exists but its description was missing.
- Imputed missing values according to their meaning: a missing value that means *absence* (no garage, no pool) became `"None"` / `0`, and a genuinely *unknown* value got the median or mode, calculated on training data only.
- Encoded 14 quality ratings as ordered scores and created 11 new features (`TotalSF`, `HouseAge`, `TotalBathrooms`, amenity flags and others).
- Log-transformed the skewed target (skewness 1.9 → 0.1).

**2. Exploratory analysis:** correlation analysis, a multicollinearity check, effect sizes and significance tests for categorical features, and seasonality.

**3. Modelling:** every model is a scikit-learn `Pipeline` (log transform, scaling and one-hot encoding fitted only on the training folds, so nothing leaks from validation data), compared with 5-fold cross-validation and then tested once on a 20% hold-out set.

**4. SQL (MySQL):** the cleaned data, the market segments and the model's out-of-fold price estimates are loaded into a MySQL database (4 tables linked by foreign keys, plus a view). The key questions are then answered again in SQL, and the results are checked against pandas.

## Key findings

### What drives the price

![Top correlations with price](images/price_correlations.png)

- **Size and quality dominate.** The engineered `TotalSF` (ρ = 0.82) and `OverallQual` (ρ = 0.81) are the strongest predictors, and each quality point adds ~26% to the median price.
- **Location matters.** The median price in the most expensive neighbourhood is **3.6×** that of the cheapest ($315k vs $88k).
- **Newer houses are more expensive:** house age (ρ = −0.65) is the strongest negative factor.
- **Seasonal demand:** 47% of sales happen in May–July, while prices stayed stable through the 2008 crisis.

### Price prediction: model comparison

![Model comparison](images/model_comparison.png)

| Model | CV RMSE (log) | CV R² | CV MAE |
|---|---|---|---|
| **Blend: Lasso + Gradient Boosting** | **0.110** | **0.922** | **$13.4k** |
| Gradient Boosting | 0.113 | 0.918 | $13.9k |
| Lasso | 0.114 | 0.915 | $14.3k |
| Ridge / ElasticNet | 0.115 | 0.915 | $14.3k |
| Random Forest | 0.130 | 0.892 | $16.1k |
| Linear Regression (no regularisation) | 0.155 | 0.819 | $15.5k |
| KNN | 0.164 | 0.827 | $21.6k |
| Decision Tree | 0.185 | 0.780 | $24.3k |
| Baseline (median price) | 0.397 | −0.01 | $55.3k |

- Regularised linear models are almost as accurate as gradient boosting and much easier to explain. Plain linear regression is **7× less stable** across folds because of the many correlated features.
- Blending a linear model with boosting gives the best result, because the two model families make different errors.
- A randomised hyper-parameter search did not improve gradient boosting beyond the normal variation between folds, so the original configuration was kept.

![Predicted vs actual prices](images/actual_vs_predicted.png)

**Hold-out set (292 unseen houses):** R² = 0.930 · RMSE (log) = 0.109 · MAE = $12.7k · median error = $9.1k

![Feature importance](images/feature_importance.png)

### Market segments (clustering)

![Market segments](images/market_segments.png)

| Segment | Share | Median price | Typical house |
|---|---|---|---|
| Older compact homes | 42% | $127k | ~57 years old, 2,000 sq ft, quality 5/10 |
| Mid-size family homes | 38% | $179k | ~13 years old, 2,600 sq ft, quality 6/10 |
| New premium homes | 20% | $278k | ~6 years old, 3,500 sq ft, quality 8/10, 3-car garage |

The segments were found **without using the price**, yet they differ strongly in price (p ≈ 1e-219). The number of clusters and the algorithm were chosen by silhouette score *and* by how much of the price variance each segmentation explains.

### Price segment (classification)

![Confusion matrix](images/confusion_matrix.png)

- Random Forest reaches **86.6% accuracy** (ROC AUC 0.96 in cross-validation). Logistic Regression and Gradient Boosting are close behind.
- Almost all errors fall between neighbouring classes, near the price thresholds. *Mid-range* is the hardest class, because it is a narrow $140k–$190k band.
- Converting the regression predictions into classes works just as well (87.0%), so one good regression model can serve both purposes.

### SQL analysis and automated valuation (MySQL)

The database ([`sql/schema.sql`](sql/schema.sql)) holds the houses, the neighbourhood and segment lookup tables, and the best model's price estimate for every house. The estimates are out-of-fold: each house is predicted by a model that did not see it during training. The queries ([`sql/queries.sql`](sql/queries.sql)) use:
- **CTEs and window functions** to compute medians, because MySQL has no `MEDIAN()` function: `ROW_NUMBER()` ranks the prices in each group and the middle row is kept.
- **`LAG()`** for the price change between quality levels and between years, **`SUM() OVER ()`** for shares of the total, and **`WITH ROLLUP`** for a total row.
- A **view** that compares every sale price with the model's estimate:

```sql
CREATE VIEW valuation_gaps AS
SELECT h.house_id, n.neighborhood_name, h.sale_condition, h.sale_price, p.predicted_price,
       ROUND(100 * (h.sale_price - p.predicted_price) / p.predicted_price, 1) AS price_gap_pct,
       CASE
           WHEN h.sale_price > 1.1 * p.predicted_price THEN 'Above estimate'
           WHEN h.sale_price < 0.9 * p.predicted_price THEN 'Below estimate'
           ELSE 'In line'
       END AS valuation
FROM houses h
JOIN predictions p ON p.house_id = h.house_id
JOIN neighborhoods n ON n.neighborhood_code = h.neighborhood_code;
```

| Type of sale | Houses | Within ±10% of the estimate | More than 10% below | More than 10% above |
|---|---|---|---|---|
| Normal | 1,198 | 78.4% | 9.5% | 12.1% |
| New home, not finished when assessed (Partial) | 123 | 73.2% | 8.1% | 18.7% |
| Abnormal (foreclosure, short sale, trade) | 101 | 50.5% | 26.7% | 22.8% |
| Between family members | 20 | 40.0% | 25.0% | 35.0% |
| **All sales** (incl. 16 rare sale types) | **1,458** | **75.2%** | **11.0%** | **13.9%** |

- The SQL results reproduce the Python analysis: the neighbourhood medians match pandas exactly, May–July account for 47% of sales, and each quality step adds ~26% to the median price.
- For a **normal sale**, a gap of more than 10% is a strong signal that the listing is mispriced or that the house has something the data does not describe.
- **Foreclosures and family sales** are much harder to value: only about half of them are within 10% of the estimate, and 8 of the 10 largest gaps are not normal sales.

## Business recommendations

- **Sellers and investors:** quality improvements (overall, kitchen, exterior) and extra living space are the strongest *controllable* drivers of price.
- **Agents and buyers:** the model can work as an automated valuation tool. Listings priced more than ~10% away from the prediction deserve a closer look (the `valuation_gaps` view flags them), except for foreclosures and family sales, where large gaps are common.
- **Marketing:** almost half of all sales happen in May–July, so listing and advertising efforts should peak in late spring.

## Project structure

```
├── analysis.ipynb      # Full analysis: cleaning → EDA → regression → clustering → classification → SQL
├── sql/
│   ├── schema.sql      # MySQL tables, keys, constraints and the valuation view
│   └── queries.sql     # Business questions answered in SQL
├── images/             # Charts used in this README (generated by the notebook)
├── submission.csv      # Kaggle submission with predicted prices for the test set
├── requirements.txt    # Python dependencies
└── README.md
```

## How to run

```bash
git clone https://github.com/kannytiss/ames-house-prices.git
cd ames-house-prices
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
jupyter lab analysis.ipynb
```

The notebook downloads the data with [`kagglehub`](https://github.com/Kaggle/kagglehub). You need a [Kaggle API token](https://www.kaggle.com/docs/api), and you must accept the competition rules on the [competition page](https://www.kaggle.com/competitions/house-prices-advanced-regression-techniques) first. A full run takes about 2 minutes.

**SQL section (optional).** It needs a running MySQL 8 server. Before starting Jupyter, set the connection (the notebook creates the `ames_housing` database itself):

```bash
export MYSQL_URL="mysql+pymysql://root:your_password@localhost:3306"
```

Without `MYSQL_URL`, the database steps are skipped and the rest of the notebook runs as usual. The `.sql` files can also be run by hand, for example in MySQL Workbench.

## Tools and skills

- **Python:** pandas, NumPy, SciPy, scikit-learn, Matplotlib, Seaborn, SQLAlchemy
- **SQL (MySQL 8):** schema design with primary and foreign keys and CHECK constraints, CTEs, window functions (`ROW_NUMBER`, `LAG`, `SUM() OVER`), views, `WITH ROLLUP`
- **Data cleaning:** missing-value strategy, data-quality checks, outlier handling, feature engineering, encoding
- **Statistics:** Spearman correlation, effect size (η²), Kruskal–Wallis test, multicollinearity analysis
- **Machine learning:** regression (linear, regularised, KNN, trees, ensembles, blending), clustering (K-Means, hierarchical, Gaussian Mixture, PCA), classification (Logistic Regression, KNN, trees, Random Forest, Gradient Boosting)
- **Model evaluation:** cross-validation, hold-out testing, hyper-parameter search, leakage-free pipelines, permutation importance

## Limitations and next steps

- The data covers one city in 2006–2010, prices are not adjusted for inflation, and the results may not transfer to other markets.
- Model coefficients show associations, not causal effects.
- Next steps: XGBoost, LightGBM or CatBoost and model stacking, SHAP explanations for individual predictions, and an interactive valuation app (e.g. Streamlit).
