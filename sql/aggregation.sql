/*
aggregation.sql
Portfolio version based on the Day 9 aggregation training.
Purpose: grouped summaries and order-level freight/value metrics.
*/

-- Monthly order volume
SELECT
    DATE_TRUNC('month', order_purchase_timestamp) AS order_month,
    COUNT(*) AS order_count
FROM orders
GROUP BY DATE_TRUNC('month', order_purchase_timestamp)
ORDER BY order_month;

-- Item counts and values by order
SELECT
    order_id,
    COUNT(*) AS item_count,
    SUM(price) AS product_value,
    SUM(freight_value) AS freight_value
FROM order_items
GROUP BY order_id
ORDER BY product_value DESC;

-- Platform-level freight and order-value KPIs
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
    ROUND(AVG(product_value), 2) AS avg_product_value_per_order,
    ROUND(AVG(freight_value), 2) AS avg_freight_per_order,
    ROUND(AVG(product_value + freight_value), 2) AS avg_order_value,
    ROUND(
        100.0 * SUM(freight_value)
        / NULLIF(SUM(product_value + freight_value), 0),
        2
    ) AS freight_share_pct
FROM item_summary;
