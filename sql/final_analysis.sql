/*
final_analysis.sql

The goal is to demonstrate the full workflow:
1. validate data grain
2. define delivery KPIs
3. compare regions
4. compare seller risk with minimum sample control
5. analyze freight economics
6. use window functions for monthly trends
*/

/* ================================================================
   PART 1 — DATA QUALITY / GRAIN CHECK
   ================================================================ */

SELECT
    (SELECT COUNT(*) FROM orders) AS total_orders,
    (SELECT COUNT(*) FROM order_items) AS item_rows,
    (SELECT COUNT(DISTINCT order_id) FROM order_items) AS orders_with_items,
    (SELECT COUNT(DISTINCT seller_id) FROM order_items) AS active_sellers;

SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT o.order_id) AS distinct_orders_after_join
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id;


/* ================================================================
   PART 2 — OVERALL DELIVERY KPI
   ================================================================ */

WITH order_delivery AS (
    SELECT
        order_id,
        customer_id,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN 1 ELSE 0
        END AS is_valid_delivered,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
             AND order_delivered_customer_date::date <= order_estimated_delivery_date::date
            THEN 'On Time'
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
             AND order_delivered_customer_date::date > order_estimated_delivery_date::date
            THEN 'Late'
            ELSE 'Not Applicable'
        END AS delivery_performance,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN order_delivered_customer_date::date - order_estimated_delivery_date::date
        END AS delivery_delta_days
    FROM orders
)
SELECT
    SUM(is_valid_delivered) AS valid_delivered_orders,
    COUNT(*) FILTER (WHERE delivery_performance = 'On Time') AS on_time_orders,
    COUNT(*) FILTER (WHERE delivery_performance = 'Late') AS late_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE delivery_performance = 'On Time')
        / NULLIF(SUM(is_valid_delivered), 0), 2
    ) AS on_time_rate_pct,
    ROUND(
        AVG(delivery_delta_days) FILTER (WHERE delivery_performance = 'Late'), 2
    ) AS avg_late_days
FROM order_delivery;


/* ================================================================
   PART 3 — REGIONAL DELIVERY RISK
   Compare frequency (late rate) and severity (avg late days).
   Keep only states with >= 500 valid delivered orders.
   ================================================================ */

WITH order_delivery AS (
    SELECT
        order_id,
        customer_id,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN 1 ELSE 0
        END AS is_valid_delivered,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
             AND order_delivered_customer_date::date > order_estimated_delivery_date::date
            THEN 1 ELSE 0
        END AS is_late,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
             AND order_delivered_customer_date::date > order_estimated_delivery_date::date
            THEN order_delivered_customer_date::date - order_estimated_delivery_date::date
        END AS late_days
    FROM orders
)
SELECT
    c.customer_state,
    SUM(od.is_valid_delivered) AS valid_delivered_orders,
    SUM(od.is_late) AS late_orders,
    ROUND(
        100.0 * SUM(od.is_late)::numeric
        / NULLIF(SUM(od.is_valid_delivered), 0), 2
    ) AS late_rate_pct,
    ROUND(AVG(od.late_days), 2) AS avg_late_days
FROM order_delivery AS od
INNER JOIN customers AS c
    ON od.customer_id = c.customer_id
GROUP BY c.customer_state
HAVING SUM(od.is_valid_delivered) >= 500
ORDER BY late_rate_pct DESC;


/* ================================================================
   PART 4 — SELLER RISK
   First establish seller+order grain, then apply eligibility threshold,
   then rank eligible sellers.
   ================================================================ */

WITH seller_order_bridge AS (
    SELECT DISTINCT seller_id, order_id
    FROM order_items
),
order_delivery AS (
    SELECT
        order_id,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
            THEN 1 ELSE 0
        END AS is_valid_delivered,
        CASE
            WHEN order_status = 'delivered'
             AND order_delivered_customer_date IS NOT NULL
             AND order_estimated_delivery_date IS NOT NULL
             AND order_delivered_customer_date::date > order_estimated_delivery_date::date
            THEN 1 ELSE 0
        END AS is_late
    FROM orders
),
seller_kpis AS (
    SELECT
        sob.seller_id,
        COUNT(*) AS seller_orders,
        SUM(od.is_valid_delivered) AS valid_delivered_orders,
        SUM(od.is_late) AS late_orders,
        SUM(od.is_late)::numeric
            / NULLIF(SUM(od.is_valid_delivered), 0) AS late_rate
    FROM seller_order_bridge AS sob
    INNER JOIN order_delivery AS od
        ON sob.order_id = od.order_id
    GROUP BY sob.seller_id
),
eligible_sellers AS (
    SELECT *
    FROM seller_kpis
    WHERE valid_delivered_orders >= 100
),
ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (ORDER BY late_rate DESC) AS risk_rank
    FROM eligible_sellers
)
SELECT
    seller_id,
    seller_orders,
    valid_delivered_orders,
    late_orders,
    ROUND(100.0 * late_rate, 2) AS late_rate_pct,
    risk_rank
FROM ranked
WHERE risk_rank <= 10
ORDER BY risk_rank, seller_orders DESC;


/* ================================================================
   PART 5 — FREIGHT ECONOMICS
   Aggregate item rows to order grain before calculating order-level KPIs.
   ================================================================ */

WITH item_summary AS (
    SELECT
        order_id,
        SUM(price) AS product_value,
        SUM(freight_value) AS freight_value
    FROM order_items
    GROUP BY order_id
)
SELECT
    COUNT(*) AS orders_with_items,
    SUM(product_value) AS total_product_value,
    SUM(freight_value) AS total_freight_value,
    ROUND(AVG(product_value + freight_value), 2) AS avg_order_value,
    ROUND(AVG(freight_value), 2) AS avg_freight_per_order,
    ROUND(
        100.0 * SUM(freight_value)
        / NULLIF(SUM(product_value + freight_value), 0), 2
    ) AS freight_share_pct
FROM item_summary;


/* ================================================================
   PART 6 — MONTHLY TREND / WINDOW FUNCTIONS
   ================================================================ */

WITH monthly_orders AS (
    SELECT
        DATE_TRUNC('month', order_purchase_timestamp) AS order_month,
        COUNT(*) AS order_count
    FROM orders
    GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
),
monthly_windows AS (
    SELECT
        order_month,
        order_count,
        LAG(order_count) OVER (ORDER BY order_month) AS previous_observed_month_orders,
        SUM(order_count) OVER (ORDER BY order_month) AS cumulative_orders,
        RANK() OVER (ORDER BY order_count DESC) AS volume_rank
    FROM monthly_orders
)
SELECT
    order_month,
    order_count,
    previous_observed_month_orders,
    ROUND(
        100.0 * (order_count - previous_observed_month_orders)
        / NULLIF(previous_observed_month_orders, 0), 2
    ) AS change_vs_previous_observed_month_pct,
    cumulative_orders,
    volume_rank
FROM monthly_windows
ORDER BY order_month;
