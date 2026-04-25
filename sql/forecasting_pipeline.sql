-- ============================================================
-- Project 2: Retail Sales Forecasting
-- Database: Ecommerce_Analytics
-- ============================================================

-- Step 1: Verify raw table imported correctly
SELECT COUNT(*) AS TotalRows FROM Raw_Superstore;
-- Expected: 9,994 rows

SELECT TOP 5 
    Order_ID, Order_Date, Category, Region, Sales, Profit 
FROM Raw_Superstore;

-- Step 2: Create the forecasting View
-- This View is the stable contract between raw data and Power BI.
-- Power BI always connects to this View, never the raw table.

CREATE OR ALTER VIEW vw_SalesForecast AS
SELECT 
    Order_ID     AS OrderID,
    Order_Date   AS OrderDate,
    Category,
    Sub_Category AS SubCategory,
    Region,
    CAST(Sales   AS FLOAT) AS Revenue,
    CAST(Profit  AS FLOAT) AS Profit
FROM Raw_Superstore
WHERE Sales > 0;

-- Step 3: Verify the View
SELECT TOP 10 * FROM vw_SalesForecast;

-- Step 4: Quick data quality check
SELECT 
    COUNT(*)                    AS TotalRows,
    COUNT(OrderDate)            AS RowsWithDate,
    COUNT(Profit)               AS RowsWithProfit,
    MIN(OrderDate)              AS EarliestOrder,
    MAX(OrderDate)              AS LatestOrder,
    ROUND(SUM(Revenue), 2)      AS TotalRevenue,
    ROUND(AVG(Revenue), 2)      AS AvgOrderRevenue,
    MIN(Profit)                 AS MinProfit,
    MAX(Profit)                 AS MaxProfit
FROM vw_SalesForecast;