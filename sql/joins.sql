/*
joins.sql
Portfolio version based on the Day 10 JOIN training.
Purpose: validate table relationships and avoid order duplication after one-to-many joins.
*/

-- Validate customer relationship
SELECT
    COUNT(*) AS joined_orders,
    COUNT(DISTINCT o.order_id) AS distinct_orders
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id;

-- Demonstrate one-to-many expansion after joining order_items
SELECT
    COUNT(*) AS joined_rows,
    COUNT(DISTINCT o.order_id) AS distinct_orders
FROM orders AS o
INNER JOIN order_items AS oi
    ON o.order_id = oi.order_id;

-- Regional order volume using the validated customer_id relationship
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS order_count
FROM orders AS o
INNER JOIN customers AS c
    ON o.customer_id = c.customer_id
GROUP BY c.customer_state
ORDER BY order_count DESC;

-- Seller order bridge: one row per seller + order
SELECT DISTINCT
    seller_id,
    order_id
FROM order_items;
