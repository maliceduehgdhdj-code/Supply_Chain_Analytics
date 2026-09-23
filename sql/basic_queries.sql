/*
basic_queries.sql
Portfolio version based on the Day 8 training work.
Purpose: basic inspection, filtering, NULL checks, and distinct counts.
*/

-- Core table sizes
SELECT COUNT(*) AS total_orders
FROM orders;

SELECT COUNT(*) AS item_rows
FROM order_items;

SELECT COUNT(DISTINCT order_id) AS orders_with_items
FROM order_items;

SELECT COUNT(DISTINCT seller_id) AS active_sellers
FROM order_items;

-- Order-status distribution
SELECT
    order_status,
    COUNT(*) AS order_count
FROM orders
GROUP BY order_status
ORDER BY order_count DESC;

-- Delivery-date quality checks
SELECT
    COUNT(*) FILTER (
        WHERE order_status = 'delivered'
          AND order_delivered_customer_date IS NULL
    ) AS delivered_missing_actual_date,
    COUNT(*) FILTER (
        WHERE order_status <> 'delivered'
          AND order_delivered_customer_date IS NOT NULL
    ) AS non_delivered_with_actual_date
FROM orders;

-- Orders without matching item rows
SELECT COUNT(*) AS orders_without_items
FROM orders AS o
LEFT JOIN order_items AS oi
    ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;
