/*
window_functions.sql
Portfolio version based on the Day 13 window-function training.
Purpose: analyze monthly order volume with LAG, cumulative SUM, and ranking.

Note: LAG() returns the previous observed row in order_month order. If a calendar
month is missing from the dataset, LAG() does not create that month automatically.
*/

WITH monthly_orders AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp) AS order_month,
        COUNT(*) AS order_count
    FROM orders
    GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
),
monthly_metrics AS (
    SELECT
        order_month,
        order_count,
        LAG(order_count) OVER (
            ORDER BY order_month
        ) AS previous_observed_month_orders,
        SUM(order_count) OVER (
            ORDER BY order_month
        ) AS cumulative_orders,
        RANK() OVER (
            ORDER BY order_count DESC
        ) AS volume_rank
    FROM monthly_orders
)
SELECT
    order_month,
    order_count,
    previous_observed_month_orders,
    ROUND(
        100.0 * (order_count - previous_observed_month_orders)
        / NULLIF(previous_observed_month_orders, 0),
        2
    ) AS change_vs_previous_observed_month_pct,
    cumulative_orders,
    volume_rank
FROM monthly_metrics
ORDER BY order_month;


-- Optional continuity check: identify gaps between observed months
WITH monthly_orders AS (
    SELECT DISTINCT
        DATE_TRUNC('month', order_purchase_timestamp)::date AS order_month
    FROM orders
),
with_previous AS (
    SELECT
        order_month,
        LAG(order_month) OVER (ORDER BY order_month) AS previous_month
    FROM monthly_orders
)
SELECT
    order_month,
    previous_month,
    (EXTRACT(YEAR FROM age(order_month, previous_month)) * 12
     + EXTRACT(MONTH FROM age(order_month, previous_month)))::int AS month_gap
FROM with_previous
WHERE previous_month IS NOT NULL
  AND (
      EXTRACT(YEAR FROM age(order_month, previous_month)) * 12
      + EXTRACT(MONTH FROM age(order_month, previous_month))
  ) > 1
ORDER BY order_month;
