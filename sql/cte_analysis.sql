/*
cte_analysis.sql
Portfolio version based on the Day 12 CTE training.
Purpose: build reusable business-rule layers for regional, seller, and freight analysis.
*/

-- Regional delivery risk: frequency and severity
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
),
state_kpis AS (
    SELECT
        c.customer_state,
        SUM(od.is_valid_delivered) AS valid_delivered_orders,
        SUM(od.is_late) AS late_orders,
        SUM(od.is_late)::numeric / NULLIF(SUM(od.is_valid_delivered), 0) AS late_rate,
        AVG(od.late_days) AS avg_late_days
    FROM order_delivery AS od
    INNER JOIN customers AS c
        ON od.customer_id = c.customer_id
    GROUP BY c.customer_state
)
SELECT
    customer_state,
    valid_delivered_orders,
    late_orders,
    ROUND(100.0 * late_rate, 2) AS late_rate_pct,
    ROUND(avg_late_days, 2) AS avg_late_days
FROM state_kpis
WHERE valid_delivered_orders >= 500
ORDER BY late_rate DESC;

-- Seller risk with minimum-sample control
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
        SUM(od.is_late)::numeric / NULLIF(SUM(od.is_valid_delivered), 0) AS late_rate
    FROM seller_order_bridge AS sob
    INNER JOIN order_delivery AS od
        ON sob.order_id = od.order_id
    GROUP BY sob.seller_id
)
SELECT
    seller_id,
    seller_orders,
    valid_delivered_orders,
    late_orders,
    ROUND(100.0 * late_rate, 2) AS late_rate_pct
FROM seller_kpis
WHERE valid_delivered_orders >= 100
ORDER BY late_rate DESC;
