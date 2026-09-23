/*
conditional_aggregation.sql
Portfolio version based on the Day 11 training.
Purpose: define delivery KPIs with business rules and conditional aggregation.
*/

WITH order_delivery AS (
    SELECT
        order_id,
        customer_id,
        order_status,
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
            THEN 1 ELSE 0
        END AS is_on_time,
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
    COUNT(*) AS total_orders,
    COUNT(*) FILTER (WHERE order_status = 'delivered') AS delivered_orders,
    SUM(is_valid_delivered) AS valid_delivered_orders,
    SUM(is_on_time) AS on_time_orders,
    SUM(is_late) AS late_orders,
    ROUND(100.0 * SUM(is_on_time)::numeric / NULLIF(SUM(is_valid_delivered), 0), 2) AS on_time_rate_pct,
    ROUND(100.0 * SUM(is_late)::numeric / NULLIF(SUM(is_valid_delivered), 0), 2) AS late_rate_pct,
    ROUND(AVG(late_days), 2) AS avg_late_days
FROM order_delivery;
