# Customer Churn & Retention Intelligence

An end-to-end data analytics project that identifies which customers are likely to churn, quantifies the revenue at stake, and translates the findings into concrete retention recommendations — using SQL for data processing, Excel for validation, and Power BI for an interactive dashboard.

---

## Business Problem

The client is a UK-based online retailer specializing in gift and novelty items, serving both wholesale and individual customers across multiple countries. Like most subscription-free, repeat-purchase businesses, the company had no systematic way of identifying which customers were at risk of disengaging — making retention efforts reactive rather than proactive.

**Core question:** Which customers are likely to churn, how much revenue is at risk, and where should retention efforts be focused for maximum impact?

---

## Data Source

**Dataset:** [Online Retail II](https://www.kaggle.com/datasets/mashlyn/online-retail-ii-uci) — UCI Machine Learning Repository
**Scope:** Over 1 million transaction-level records from December 2009 to December 2011
**Fields:** Invoice number, product code and description, quantity, price, invoice date, customer ID, and country

Unlike many churn datasets used for portfolio projects, this dataset provides only raw transactional data — with no pre-existing "churn" label. The churn definition used in this analysis was derived directly from the data (see Methodology).

---

## Methodology

**1. Data Cleaning (SQL — MySQL)**
- Removed cancelled orders (invoices flagged with a "C" prefix)
- Removed records with missing or invalid customer IDs
- Removed transactions with zero or negative price/quantity (adjustments, samples, corrections)
- Resolved invalid date values introduced during import

**2. RFM Feature Engineering**
- **Recency:** Days since each customer's most recent purchase, relative to the dataset's last recorded date
- **Frequency:** Number of distinct orders placed
- **Monetary:** Total amount spent

**3. Churn Definition**
A 90-day inactivity threshold was selected based on the distribution of customer recency values in the dataset, producing a near-balanced split between active and churned customers (49% vs. 51%) — supporting reliable segment-level comparison.

**4. Customer Segmentation**
Customers were scored on each RFM dimension (quartile-based scoring) and grouped into six segments: **Champions, Loyal Customers, At Risk, Lost, New Customers,** and **Others.**

**5. Validation**
Segment-level metrics (customer counts, average spend, total revenue) were cross-checked in Excel using pivot tables to confirm consistency with the SQL output.

**6. Dashboard**
Findings were consolidated into an interactive Power BI dashboard with KPI summaries, segment and revenue breakdowns, a monthly trend view, country-level churn comparison, and an RFM scatter plot.

---

## Key Insights

- **Overall churn rate: 50.9%** across 5,878 customers.
- **Revenue concentration:** Champions (11% of customers) generate **54% of total revenue** ($9.5M of $17.7M) — a clear Pareto pattern.
- **At-risk revenue:** The At-Risk segment (888 customers) has already generated $2.24M in revenue and represents the most cost-effective retention opportunity.
- **Seasonality:** Order volume and revenue peak consistently every November, driven by holiday gift purchasing.
- **Geographic variance:** The UK (core market) has a ~51% churn rate, while Germany and France show notably stronger retention (~35%), suggesting transferable best practices.

---

## Recommendations

Full detail in [`Business_Recommendations.md`](./Business_Recommendations.md). Summary:

1. Protect and reward the Champions segment — highest revenue concentration.
2. Launch targeted win-back campaigns for At-Risk customers — highest ROI opportunity.
3. Time retention campaigns for September–October, ahead of the November seasonal peak.
4. Study Germany/France retention practices for applicability to the UK market.
5. Minimize investment in the Lost segment; redirect budget to higher-return segments.

---

## Tools Used

| Tool | Purpose |
|---|---|
| **SQL (MySQL)** | Data cleaning, RFM calculation, churn labeling, segmentation logic |
| **Excel** | Pivot table validation, conditional formatting, cross-verification |
| **Power BI** | Interactive dashboard — KPIs, segment analysis, trend and geographic views |

---

## Repository Contents

```
├── README.md                          # Project overview (this file)
├── Business_Recommendations.md        # Detailed retention recommendations
├── churn_analysis_queries.sql         # Full SQL script (cleaning → RFM → segmentation)
├── Customer_Churn_Retention_Dashboard.pbix   # Power BI dashboard
├── Churn_Analysis_Excel.xlsx          # Pivot table validation workbook
└── dashboard_screenshot.png           # Dashboard preview image
```

---

## Author

Analysis by **[Anchal Damani]**
Data source: Online Retail II, UCI Machine Learning Repository
