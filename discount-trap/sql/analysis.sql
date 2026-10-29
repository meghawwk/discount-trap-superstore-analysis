-- ============================================================
-- The Discount Trap: Revenue Growth vs Real Profit
-- Dataset: Sample Superstore (Kaggle)
-- Table name: superstore
-- Columns used: Order_ID, Order_Date, Region, Category,
--               Sub_Category, Sales, Quantity, Discount, Profit
-- Dialect: SQLite (also works in MySQL/PostgreSQL with small changes,
--          noted where they differ)
-- ============================================================


-- ------------------------------------------------------------
-- 1. Overall KPIs
-- ------------------------------------------------------------
SELECT
    COUNT(*)                                        AS total_rows,
    ROUND(SUM(Sales), 0)                            AS total_sales,
    ROUND(SUM(Profit), 0)                           AS total_profit,
    ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2)      AS profit_margin_pct,
    ROUND(AVG(Discount) * 100, 1)                   AS avg_discount_pct
FROM superstore;


-- ------------------------------------------------------------
-- 2. The growth story: sales vs profit by year
--    (MySQL: use YEAR(Order_Date); PostgreSQL: EXTRACT(YEAR FROM Order_Date))
-- ------------------------------------------------------------
SELECT
    STRFTIME('%Y', Order_Date)                      AS year,
    ROUND(SUM(Sales), 0)                            AS sales,
    ROUND(SUM(Profit), 0)                           AS profit,
    ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2)      AS margin_pct
FROM superstore
GROUP BY year
ORDER BY year;


-- ------------------------------------------------------------
-- 3. Profit by discount band (the main analysis)
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN Discount = 0    THEN '1) 0%'
        WHEN Discount <= 0.10 THEN '2) 1-10%'
        WHEN Discount <= 0.20 THEN '3) 11-20%'
        WHEN Discount <= 0.30 THEN '4) 21-30%'
        WHEN Discount <= 0.50 THEN '5) 31-50%'
        ELSE                       '6) 50%+'
    END                                             AS discount_band,
    COUNT(*)                                        AS orders,
    ROUND(SUM(Sales), 0)                            AS sales,
    ROUND(SUM(Profit), 0)                           AS profit,
    ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2)      AS margin_pct,
    ROUND(AVG(CASE WHEN Profit < 0 THEN 1.0 ELSE 0 END) * 100, 1) AS loss_rate_pct
FROM superstore
GROUP BY discount_band
ORDER BY discount_band;


-- ------------------------------------------------------------
-- 4. Break-even point: exact discount levels
--    Find the highest discount where profit is still positive.
-- ------------------------------------------------------------
SELECT
    Discount,
    COUNT(*)                                        AS orders,
    ROUND(SUM(Sales), 0)                            AS sales,
    ROUND(SUM(Profit), 0)                           AS profit,
    ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2)      AS margin_pct
FROM superstore
GROUP BY Discount
ORDER BY Discount;


-- ------------------------------------------------------------
-- 5. Where the damage is: profit by sub-category
-- ------------------------------------------------------------
SELECT
    Sub_Category,
    ROUND(SUM(Sales), 0)                            AS sales,
    ROUND(SUM(Profit), 0)                           AS profit,
    ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2)      AS margin_pct,
    ROUND(AVG(Discount) * 100, 1)                   AS avg_discount_pct
FROM superstore
GROUP BY Sub_Category
ORDER BY profit ASC;


-- ------------------------------------------------------------
-- 6. Profit by region
-- ------------------------------------------------------------
SELECT
    Region,
    ROUND(SUM(Sales), 0)                            AS sales,
    ROUND(SUM(Profit), 0)                           AS profit,
    ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2)      AS margin_pct,
    ROUND(AVG(Discount) * 100, 1)                   AS avg_discount_pct
FROM superstore
GROUP BY Region
ORDER BY avg_discount_pct DESC;


-- ------------------------------------------------------------
-- 7. Region x sub-category: where heavy discounts lose money
--    Only shows combinations that lost money.
-- ------------------------------------------------------------
SELECT
    Region,
    Sub_Category,
    ROUND(SUM(Sales), 0)                            AS sales,
    ROUND(SUM(Profit), 0)                           AS profit,
    ROUND(AVG(Discount) * 100, 1)                   AS avg_discount_pct
FROM superstore
GROUP BY Region, Sub_Category
HAVING SUM(Profit) < 0
ORDER BY profit ASC;


-- ------------------------------------------------------------
-- 8. Cost of the trap: loss-making orders vs profitable orders
-- ------------------------------------------------------------
SELECT
    CASE WHEN Profit < 0 THEN 'Loss-making' ELSE 'Profitable' END AS order_type,
    COUNT(*)                                        AS orders,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM superstore), 1) AS pct_of_orders,
    ROUND(SUM(Sales), 0)                            AS sales,
    ROUND(SUM(Profit), 0)                           AS profit,
    ROUND(AVG(Discount) * 100, 1)                   AS avg_discount_pct
FROM superstore
GROUP BY order_type;


-- ------------------------------------------------------------
-- 9. Share of sales from heavy-discount orders (> 20%)
--    This gives the headline: "X% of sales came from orders that lost $Y"
-- ------------------------------------------------------------
SELECT
    COUNT(*)                                        AS heavy_discount_orders,
    ROUND(SUM(Sales), 0)                            AS sales,
    ROUND(SUM(Sales) * 100.0 / (SELECT SUM(Sales) FROM superstore), 1) AS pct_of_total_sales,
    ROUND(SUM(Profit), 0)                           AS profit
FROM superstore
WHERE Discount > 0.20;


-- ------------------------------------------------------------
-- 10. What-if: cap discounts at 20%
--     Assumes the same quantity sold. Cost is inferred as Sales - Profit.
--     list_price = Sales / (1 - Discount)
--     new_profit = list_price * (1 - cap) - cost
-- ------------------------------------------------------------
SELECT
    COUNT(*)                                        AS orders_above_cap,
    ROUND(SUM(Profit), 0)                           AS actual_profit,
    ROUND(SUM((Sales / (1 - Discount)) * (1 - 0.20) - (Sales - Profit)), 0) AS simulated_profit,
    ROUND(
        SUM((Sales / (1 - Discount)) * (1 - 0.20) - (Sales - Profit)) - SUM(Profit),
        0
    )                                               AS estimated_profit_recovered
FROM superstore
WHERE Discount > 0.20;


-- ------------------------------------------------------------
-- 11. Do discounts even drive volume? Average quantity per order line
-- ------------------------------------------------------------
SELECT
    CASE
        WHEN Discount = 0    THEN '1) 0%'
        WHEN Discount <= 0.10 THEN '2) 1-10%'
        WHEN Discount <= 0.20 THEN '3) 11-20%'
        WHEN Discount <= 0.30 THEN '4) 21-30%'
        WHEN Discount <= 0.50 THEN '5) 31-50%'
        ELSE                       '6) 50%+'
    END                                             AS discount_band,
    ROUND(AVG(Quantity), 2)                         AS avg_quantity,
    ROUND(AVG(Sales), 0)                            AS avg_sales_per_line
FROM superstore
GROUP BY discount_band
ORDER BY discount_band;


-- ------------------------------------------------------------
-- 12. Best places for promotions: highest-margin sub-categories
-- ------------------------------------------------------------
SELECT
    Sub_Category,
    ROUND(SUM(Profit) * 100.0 / SUM(Sales), 2)      AS margin_pct,
    ROUND(AVG(Discount) * 100, 1)                   AS avg_discount_pct,
    ROUND(SUM(Profit), 0)                           AS profit
FROM superstore
GROUP BY Sub_Category
ORDER BY margin_pct DESC
LIMIT 5;
