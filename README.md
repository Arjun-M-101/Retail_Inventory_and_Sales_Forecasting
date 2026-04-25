# Retail Inventory and Sales Forecasting

<img width="1319" height="742" alt="dashboard_overview" src="https://github.com/user-attachments/assets/08a3b46c-9ba1-460e-9dca-d1c5b3d67ace" />

## Business Problem

A US retail company's inventory procurement decisions were driven by intuition — 
leading to two costly outcomes: **overstocking** (capital tied up in deadstock) 
and **stockouts** (missed sales from insufficient inventory). Neither problem 
can be solved without knowing what demand will look like 3 months from now.

This project builds a full analytics pipeline — from raw transactional data 
through a SQL data warehouse to a Power BI forecasting dashboard — that gives 
operations managers a statistically grounded 3-month demand forecast with 
product category and regional breakdowns.

## Pipeline Architecture

```txt
Raw CSV — 9,994 rows (US retail orders, Jan 2014 – Dec 2017)
Kaggle: Superstore Dataset (vivek468/superstore-dataset-final)
│
▼ SQL Server (SSMS) — staging, schema hardening, View creation
Raw_Superstore table → vw_SalesForecast View
│
▼ Power Query — monthly aggregation (Start of Month grouping)
573 monthly rows | OrderDate | Category | Region | Revenue | Profit
│
▼ Power BI Desktop — Time Intelligence DAX + AI Forecasting
Retail Sales Forecasting Dashboard
```

## Tools & Stack

| Layer | Tool | Purpose |
|-------|------|---------|
| Data Warehouse | SQL Server + SSMS | Staging, schema hardening, View creation |
| Data Transformation | Power Query (M) | Monthly aggregation via Group By |
| Time Dimension | Power BI DAX (ADDCOLUMNS + CALENDARAUTO) | Continuous calendar for Time Intelligence |
| BI & Visualisation | Power BI Desktop | DAX measures (Total Revenue, Revenue YTD, YoY Growth, AI Forecast, interactive dashboard |

## Dataset

- **Source:** Kaggle — [Superstore Dataset by vivek468](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)
- **Raw size:** 9,994 rows — individual order-level transactions
- **After Power Query aggregation:** 573 monthly rows grouped by OrderDate + Category + Region
- **Date range:** January 2014 – December 2017 (4 years)
- **Scope:** 3 product categories (Furniture, Office Supplies, Technology) × 4 US regions

## What I Built

### Phase 1 — SQL Server: Data Pipeline

**File:** `sql/forecasting_pipeline.sql`

**Raw table import:**
- Imported `train.csv` into SQL Server as `Raw_Superstore` via SSMS Import Flat File
- Set `Postal_Code` to Allow Nulls during import (some international orders have no postcode)
- Set `Order_Date` and `Ship_Date` as `date` type; `Sales` as `float`

**SQL View — `vw_SalesForecast`:**
```sql
CREATE OR ALTER VIEW vw_SalesForecast AS
SELECT 
    Order_ID    AS OrderID,
    Order_Date  AS OrderDate,
    Category,
    Sub_Category AS SubCategory,
    Region,
    CAST(Sales   AS FLOAT) AS Revenue,
    CAST(Profit  AS FLOAT) AS Profit
FROM Raw_Superstore
WHERE Sales > 0;
```

**Why a View:** The View acts as a stable contract between the raw data layer 
and the Power BI reporting layer. If the raw table changes, the dashboard 
always receives correctly typed, filtered data. This is enterprise-grade 
pipeline design — Power BI connects to the View, never the raw table.

---

### Phase 2 — Power Query: Monthly Aggregation

Connected Power BI to `vw_SalesForecast`. Applied two Power Query transformations:

1. **Calculated Start of Month** — converted each `OrderDate` to the first 
   day of its month (e.g. 15-Mar-2016 → 01-Mar-2016) using `Date.StartOfMonth`
2. **Group By** — aggregated to monthly level:
   - Group columns: OrderDate, Category, Region
   - Aggregations: Revenue (Sum), Profit (Sum)

**Result:** 9,994 daily rows → 573 clean monthly rows. This eliminates visual 
noise from daily fluctuations and gives the AI Forecast algorithm consistent, 
evenly-spaced time series data to pattern-match against.

---

### Phase 3 — Power BI: Time Intelligence Model

**Date Table:**
```dax
DateTable = 
ADDCOLUMNS(
    CALENDARAUTO(),
    "Year",      YEAR([Date]),
    "Month",     FORMAT([Date], "MMMM"),
    "MonthNum",  MONTH([Date]),
    "Quarter",   "Q" & FORMAT([Date], "Q"),
    "MonthYear", FORMAT([Date], "MMM-YYYY")
)
```

- Marked as date table (Date column)
- Relationship: `DateTable[Date]` → `vw_SalesForecast[OrderDate]` (Many-to-One)
- `CALENDARAUTO()` auto-generates every calendar date from Jan 2014 to Dec 2017 
  with no gaps — mandatory for SAMEPERIODLASTYEAR and TOTALYTD to work correctly

**DAX Measures:**
```dax
Total Revenue = SUM(vw_SalesForecast[Revenue])

Revenue LY = CALCULATE([Total Revenue], SAMEPERIODLASTYEAR('DateTable'[Date]))

YoY Growth = 
VAR CurrentRev  = SUM(vw_SalesForecast[Revenue])
VAR LastYearRev = CALCULATE(SUM(vw_SalesForecast[Revenue]), 
                            SAMEPERIODLASTYEAR('DateTable'[Date]))
RETURN
IF(
    ISBLANK(CurrentRev) || ISBLANK(LastYearRev) || LastYearRev = 0,
    BLANK(),
    DIVIDE(CurrentRev - LastYearRev, LastYearRev)
)

Revenue YTD = TOTALYTD(SUM(vw_SalesForecast[Revenue]), 'DateTable'[Date])

ProfitMargin = DIVIDE(SUM(vw_SalesForecast[Profit]), [Total Revenue], 0)
```

**Why SAMEPERIODLASTYEAR and not subtract 365 days:**
SAMEPERIODLASTYEAR navigates the DateTable calendar to the exact same period 
one year prior — handling leap years correctly and working at any granularity 
(year, quarter, month). Subtracting 365 days is brittle and produces wrong 
results for leap years and monthly comparisons.

**Why the YoY measure uses ISBLANK guards:**
The dataset starts in 2014. Selecting 2014 gives `LastYearRev = BLANK()` 
(no 2013 data). Without the guard, DAX returns 0 or errors. With the guard, 
it returns BLANK() — a clean, honest "no comparison available" rather than 
a misleading 0%.

---

### Phase 4 — Dashboard

**Visual 1 — AI Forecast Line Chart (headline feature)**
- X-axis: `DateTable[Date]` at monthly level
- Y-axis: `Total Revenue`
- AI Forecast: Analytics pane → Forecast → 3 months | Seasonality: 12 | CI: 95%
- Seasonality = 12 tells the algorithm to detect annual demand cycles 
  (e.g. Technology Q4 holiday spikes)
- 95% CI: shaded band within which actual future revenue will fall 
  95 out of 100 times — gives procurement managers a conservative (lower bound) 
  and aggressive (upper bound) stocking scenario

**Visual 2 — YoY Growth Alert Card**
- Measure: `YoY Growth`
- Conditional formatting: Green if ≥ 0, Red if < 0
- An operations manager can scan all years/categories in seconds 
  without reading a table of numbers

**Visual 3 — Revenue by Category (Horizontal Bar Chart)**
- Y-axis: Category | X-axis: Total Revenue
- Provides context for the forecast — which categories to prioritise in procurement

**Visual 4 — KPI Cards (top row)**
- Total Revenue | Revenue YTD | Profit Margin

**Visual 5 — Category Slicer**
- Cross-filters all visuals simultaneously

**Visual 6 — Year Slicer**
- Filtered to 2014–2017 (excludes future ghost years from DateTable)

**Tooltip Page**
- Hidden page containing a mini bar chart (Category × Revenue)
- Linked to Line Chart: hovering over a monthly spike shows which category 
  drove it — enables root-cause analysis without cluttering the main canvas

## Key Findings

- **Total revenue across 4 years:** $2.30M
- **Strongest YoY growth:** 2016 vs 2015 — 29.47% growth
- **2015 performance:** -2.83% YoY — a slight decline worth investigating
- **Technology** shows the clearest Q4 seasonal spike — consistent with 
  holiday-period purchasing
- **Office Supplies** has the most consistent demand pattern — forecast 
  confidence band is narrowest for this category
- **Profit Margin** averages ~12–13% across all categories; Furniture 
  has the thinnest margin (~3%)

## Technical Challenges Solved

| Challenge | Solution |
|-----------|----------|
| Profit column missing from initial dataset (train.csv — 18 columns only) | Re-imported full Superstore dataset (vivek468 — 21 columns including Profit) |
| Postal_Code null values blocking import | Set Allow Nulls = True for all columns during import |
| AI Forecast not appearing in Analytics pane | Root cause: two measures on Y-axis blocks Forecast. Removed Revenue 30D Moving Avg from Y-axis to enable Forecast |
| DateTable starting from wrong year (2016 instead of 2014) | Replaced custom VAR formula with ADDCOLUMNS(CALENDARAUTO(),...) which auto-detects full data range |
| Daily data producing 1,400+ noisy data points on chart | Applied Power Query Group By to aggregate to 573 monthly rows |
| X-axis showing Month text column (out of chronological order) | Used DateTable[Date] on X-axis instead of DateTable[Month] text column |
| YoY showing -100% for future/empty date ranges | Added ISBLANK guards in YoY VAR measure |
| Forecast appearing for Office Supplies only | Expected behaviour — Technology and Furniture have lumpy/sparse demand; algorithm correctly declines to forecast when pattern confidence is insufficient |

<!--
## Why the Forecast Only Appears for Office Supplies

Power BI's AI Forecast uses exponential smoothing. It requires sufficient 
data density and pattern consistency to generate a prediction. 

- **Office Supplies:** High transaction frequency, consistent monthly patterns → forecast generated ✅
- **Technology:** Large sporadic orders (big spikes, then gaps) → insufficient pattern consistency → no forecast generated
- **Furniture:** Same as Technology — lumpy demand profile

This is correct statistical behaviour. A forecast that cannot find a 
reliable pattern declines to produce one rather than generating a 
misleading prediction. This demonstrates statistical 
maturity — what the model is doing and why.
-->


## Repository Structure

```txt
Retail_Sales_Forecasting/
├── README.md
├── sql/
│   └── forecasting_pipeline.sql     ← Raw_Superstore import notes + vw_SalesForecast
├── dashboard/
│   └── Retail_Sales_Forecasting.pbix ← Power BI dashboard file
└── screenshots/
    ├── dashboard_overview.png        ← Full dashboard, all years, with forecast
    ├── yoy_2016_green.png            ← 2016 selected, green YoY card
    ├── yoy_2015_red.png              ← 2015 selected, red YoY card
    └── tooltip_category.png          ← Hover tooltip showing category breakdown
```

## How to Reproduce

1. Download dataset: [Superstore Dataset — vivek468](https://www.kaggle.com/datasets/vivek468/superstore-dataset-final)
2. In SSMS: create or use existing `Ecommerce_Analytics` database
3. Import CSV as `Raw_Superstore` — set all columns to Allow Nulls, `Order_Date` and `Ship_Date` as date, `Sales` and `Profit` as float
4. Run `forecasting_pipeline.sql` to create `vw_SalesForecast`
5. Open `Retail_Sales_Forecasting.pbix` in Power BI Desktop
6. Update data source: Home → Transform Data → Data Source Settings → change server to your local instance name
7. Apply Refresh — Power Query aggregation runs automatically

## Screenshots

<p align="center">
  <img width="400" alt="dashboard_overview" src="https://github.com/user-attachments/assets/39980fa4-948c-4555-bc37-b6b210e0146b" />
  <img width="400" alt="yoy_2016_green" src="https://github.com/user-attachments/assets/df303071-79b5-49df-95db-47da2949e40f" />
</p>

<p align="center">
  <img width="400" alt="yoy_2015_red" src="https://github.com/user-attachments/assets/d83cb67b-7ba9-4096-8718-56bec80e69ec" />
  <img width="400" alt="tooltip_category" src="https://github.com/user-attachments/assets/3457813c-418d-4c2f-9892-8ed2f70b14be" />
</p>

<!--
## Loom Walkthrough
[LINK TO BE ADDED]
-->

## About

**Tools:** SQL Server | Power BI Desktop | Power Query | DAX  
**Skills demonstrated:** Time Intelligence DAX | AI Forecasting | Power Query M | Conditional Formatting | Cross-filter interactivity | Tooltip pages
