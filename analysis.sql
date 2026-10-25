-- ============================================================
-- Retail Sales Analysis (Superstore dataset)
-- Tool: SQLite (DB Browser for SQLite)
-- Source table: orders (imported from the Orders CSV, 9,994 rows)
-- ============================================================


-- ------------------------------------------------------------
-- PART 1: DATA QUALITY CHECKS
-- ------------------------------------------------------------

-- 1.1 Row count (result: 9,994)
SELECT COUNT(*) FROM orders;

-- 1.2 Missing values (result: 0, 0, 0)
SELECT
  SUM(CASE WHEN "Sales"       IS NULL OR "Sales"       = '' THEN 1 ELSE 0 END) AS missing_sales,
  SUM(CASE WHEN "Profit"      IS NULL OR "Profit"      = '' THEN 1 ELSE 0 END) AS missing_profit,
  SUM(CASE WHEN "Postal Code" IS NULL OR "Postal Code" = '' THEN 1 ELSE 0 END) AS missing_postal
FROM orders;

-- 1.3 Duplicate Row IDs (result: no rows)
SELECT "Row ID", COUNT(*) AS n
FROM orders
GROUP BY "Row ID"
HAVING n > 1;

-- 1.4 Inconsistent text values (all clean)
SELECT DISTINCT "Region"   FROM orders;   -- Central, East, South, West
SELECT DISTINCT "Category" FROM orders;   -- Furniture, Office Supplies, Technology
SELECT DISTINCT "Segment"  FROM orders;   -- Consumer, Corporate, Home Office


-- ------------------------------------------------------------
-- PART 2: CREATE CLEAN TABLE
-- Converts text dates (e.g. 11/8/2016) to ISO format (2016-11-08),
-- sets numeric data types and simplifies column names.
-- ------------------------------------------------------------
CREATE TABLE orders_clean AS
WITH d AS (
  SELECT *,
    substr("Order Date", instr("Order Date", '/') + 1) AS rest
  FROM orders
)
SELECT
  "Order ID"      AS order_id,
  substr("Order Date", length("Order Date") - 3, 4) || '-' ||
    printf('%02d', CAST(substr("Order Date", 1, instr("Order Date", '/') - 1) AS INTEGER)) || '-' ||
    printf('%02d', CAST(substr(rest, 1, instr(rest, '/') - 1) AS INTEGER)) AS order_date,
  "Segment"       AS segment,
  "State"         AS state,
  "Region"        AS region,
  "Category"      AS category,
  "Sub-Category"  AS sub_category,
  CAST("Sales" AS REAL)       AS sales,
  CAST("Quantity" AS INTEGER) AS quantity,
  CAST("Discount" AS REAL)    AS discount,
  CAST("Profit" AS REAL)      AS profit
FROM d;

-- Sanity check: row count must still be 9,994
SELECT COUNT(*) FROM orders_clean;


-- ------------------------------------------------------------
-- PART 3: ANALYSIS
-- ------------------------------------------------------------

-- Q1: Which categories and sub-categories make or lose money?
-- Finding: Tables (-$17.7K), Bookcases (-$3.5K) and Supplies (-$1.2K) lose money.
SELECT category, sub_category,
       ROUND(SUM(sales), 0)  AS total_sales,
       ROUND(SUM(profit), 0) AS total_profit,
       ROUND(100.0 * SUM(profit) / SUM(sales), 1) AS margin_pct
FROM orders_clean
GROUP BY category, sub_category
ORDER BY total_profit;

-- Q2: Which regions perform best and worst?
-- Finding: West is best (14.9% margin), Central is weakest (7.9% margin).
SELECT region,
       ROUND(SUM(sales), 0)  AS total_sales,
       ROUND(SUM(profit), 0) AS total_profit,
       ROUND(100.0 * SUM(profit) / SUM(sales), 1) AS margin_pct
FROM orders_clean
GROUP BY region
ORDER BY total_profit DESC;

-- Q3: How do discounts affect profit?
-- Finding: discounts above 20% are unprofitable.
SELECT
  CASE WHEN discount = 0   THEN '0%'
       WHEN discount <= 0.2 THEN '1-20%'
       WHEN discount <= 0.4 THEN '21-40%'
       ELSE '40%+' END AS discount_band,
  COUNT(*)              AS lines,
  ROUND(SUM(sales), 0)  AS total_sales,
  ROUND(SUM(profit), 0) AS total_profit
FROM orders_clean
GROUP BY discount_band
ORDER BY MIN(discount);

-- Q4a: Yearly trend
-- Finding: sales +51% and profit +89% from 2014 to 2017.
SELECT substr(order_date, 1, 4) AS year,
       ROUND(SUM(sales), 0)  AS total_sales,
       ROUND(SUM(profit), 0) AS total_profit
FROM orders_clean
GROUP BY year
ORDER BY year;

-- Q4b: Monthly trend (used for the Excel line chart)
-- Finding: sales peak every Sep-Dec and are lowest in Jan-Feb.
SELECT substr(order_date, 1, 7) AS month,
       ROUND(SUM(sales), 0)  AS total_sales,
       ROUND(SUM(profit), 0) AS total_profit
FROM orders_clean
GROUP BY month
ORDER BY month;
