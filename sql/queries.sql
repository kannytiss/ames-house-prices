-- Business questions answered in SQL (MySQL 8.0+), on the tables from schema.sql.
-- Every query starts with a "-- name:" line, which the notebook uses to run it by name.
--
-- MySQL has no MEDIAN() function. The median is computed with window functions instead:
-- ROW_NUMBER() ranks the prices inside each group, COUNT(*) OVER () gives the group size,
-- and the middle row (or the average of the two middle rows) is kept.


-- name: neighborhood_medians
-- Which neighbourhoods are the most and least expensive?
WITH ranked AS (
    SELECT neighborhood_code,
           sale_price,
           ROW_NUMBER() OVER (PARTITION BY neighborhood_code ORDER BY sale_price) AS price_rank,
           COUNT(*)     OVER (PARTITION BY neighborhood_code)                     AS n_houses
    FROM houses
)
SELECT r.neighborhood_code,
       n.neighborhood_name,
       MAX(r.n_houses)                            AS houses,
       CAST(ROUND(AVG(r.sale_price)) AS UNSIGNED) AS median_price
FROM ranked r
JOIN neighborhoods n ON n.neighborhood_code = r.neighborhood_code
WHERE r.price_rank IN (FLOOR((r.n_houses + 1) / 2), CEIL((r.n_houses + 1) / 2))
GROUP BY r.neighborhood_code, n.neighborhood_name
ORDER BY median_price DESC;


-- name: quality_premium
-- How much does each step in overall quality add to the median price? LAG() compares each level with the one below.
WITH ranked AS (
    SELECT overall_qual,
           sale_price,
           ROW_NUMBER() OVER (PARTITION BY overall_qual ORDER BY sale_price) AS price_rank,
           COUNT(*)     OVER (PARTITION BY overall_qual)                     AS n_houses
    FROM houses
),
medians AS (
    SELECT overall_qual, MAX(n_houses) AS houses, AVG(sale_price) AS median_price
    FROM ranked
    WHERE price_rank IN (FLOOR((n_houses + 1) / 2), CEIL((n_houses + 1) / 2))
    GROUP BY overall_qual
)
SELECT overall_qual,
       houses,
       CAST(ROUND(median_price) AS UNSIGNED)                                         AS median_price,
       ROUND(100 * (median_price / LAG(median_price) OVER (ORDER BY overall_qual) - 1), 1) AS change_vs_level_below_pct
FROM medians
ORDER BY overall_qual;


-- name: sales_by_month
-- When do houses sell? Share of all sales per calendar month (SUM() OVER () is the grand total).
SELECT month_sold,
       ELT(month_sold, 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                       'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec') AS month_name,
       COUNT(*)                                                  AS houses_sold,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS share_pct
FROM houses
GROUP BY month_sold
ORDER BY month_sold;


-- name: yearly_prices
-- Did the 2008 financial crisis lower prices? Median price per year and the change from the year before.
WITH ranked AS (
    SELECT year_sold,
           sale_price,
           ROW_NUMBER() OVER (PARTITION BY year_sold ORDER BY sale_price) AS price_rank,
           COUNT(*)     OVER (PARTITION BY year_sold)                     AS n_houses
    FROM houses
),
medians AS (
    SELECT year_sold, MAX(n_houses) AS houses, AVG(sale_price) AS median_price
    FROM ranked
    WHERE price_rank IN (FLOOR((n_houses + 1) / 2), CEIL((n_houses + 1) / 2))
    GROUP BY year_sold
)
SELECT year_sold,
       houses,
       CAST(ROUND(median_price) AS UNSIGNED)                                      AS median_price,
       ROUND(100 * (median_price / LAG(median_price) OVER (ORDER BY year_sold) - 1), 1) AS change_vs_previous_year_pct
FROM medians
ORDER BY year_sold;


-- name: segment_summary
-- What does a typical house look like in each market segment?
WITH ranked AS (
    SELECT segment_id,
           sale_price,
           ROW_NUMBER() OVER (PARTITION BY segment_id ORDER BY sale_price) AS price_rank,
           COUNT(*)     OVER (PARTITION BY segment_id)                     AS n_houses
    FROM houses
),
medians AS (
    SELECT segment_id, AVG(sale_price) AS median_price
    FROM ranked
    WHERE price_rank IN (FLOOR((n_houses + 1) / 2), CEIL((n_houses + 1) / 2))
    GROUP BY segment_id
)
SELECT s.segment_name,
       COUNT(*)                                         AS houses,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS share_pct,
       CAST(ROUND(m.median_price) AS UNSIGNED)          AS median_price,
       CAST(ROUND(AVG(h.total_sf)) AS UNSIGNED)         AS avg_total_sf,
       ROUND(AVG(h.overall_qual), 1)                    AS avg_quality,
       CAST(ROUND(AVG(h.house_age)) AS UNSIGNED)        AS avg_age,
       ROUND(AVG(h.total_bathrooms), 1)                 AS avg_bathrooms,
       ROUND(AVG(h.garage_cars), 1)                     AS avg_garage_cars
FROM houses h
JOIN segments s ON s.segment_id = h.segment_id
JOIN medians m ON m.segment_id = h.segment_id
GROUP BY h.segment_id, s.segment_name, m.median_price
ORDER BY h.segment_id;


-- name: gaps_by_sale_condition
-- How do sale prices compare with the model's estimate for each type of sale?
-- WITH ROLLUP adds a total row, and GROUPING() labels it.
SELECT IF(GROUPING(sale_condition), 'All sales', sale_condition) AS sale_condition,
       COUNT(*)                                                  AS houses,
       ROUND(AVG(price_gap_pct), 1)                              AS avg_gap_pct,
       ROUND(100 * AVG(valuation = 'Below estimate'), 1)         AS below_estimate_pct,
       ROUND(100 * AVG(valuation = 'In line'), 1)                AS in_line_pct,
       ROUND(100 * AVG(valuation = 'Above estimate'), 1)         AS above_estimate_pct
FROM valuation_gaps
GROUP BY sale_condition WITH ROLLUP
ORDER BY GROUPING(sale_condition), houses DESC;


-- name: largest_gaps
-- The 10 sales furthest from the model's estimate: the first candidates for a closer look.
SELECT house_id,
       neighborhood_name,
       sale_condition,
       sale_price,
       predicted_price,
       price_gap_pct
FROM valuation_gaps
ORDER BY ABS(price_gap_pct) DESC
LIMIT 10;
