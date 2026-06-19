
/*
 Аналитика данных. Стажировка «ИТ-город». Блок задач №3. 
 Автор: Стукалов Артем Витальевич
 Дата: 18.06.2026
 */

/* 
 Задание 4. SQL-аналитика: Необходимо написать SQL-запросы:
 - Топ-10 клиентов по сумме покупок
 - Выручка по месяцам
 - Самые популярные товары
 - Последняя активность (дата) топ-5 покупателей, которые совершили больше всего покупок
 - Пользователи без заказов
 */
 
-- Топ‑10 клиентов по сумме покупок
SELECT 
    c.full_name,
    SUM(o.total_amount) AS total_spent
FROM fact_orders AS o
JOIN dim_customers AS c ON o.customer_surr_id = c.customer_surr_id
GROUP BY c.full_name, c.customer_surr_id
ORDER BY total_spent DESC
LIMIT 10;

-- Выручка по месяцам
SELECT 
    d.year,
    d.month,
    SUM(o.total_amount) AS monthly_revenue
FROM fact_orders AS o
JOIN dim_dates AS d ON o.order_date_key = d.date_key
GROUP BY d.year, d.month
ORDER BY d.year, d.month;


-- Самые популярные товары
SELECT 
    p.product_name,
    COUNT(o.order_id) AS order_count
FROM fact_orders AS o
JOIN dim_products AS p ON o.product_surr_id = p.product_surr_id
GROUP BY p.product_surr_id
ORDER BY order_count DESC
LIMIT 10;

-- Последняя активность (дата) топ-5 покупателей, которые совершили больше всего покупок
WITH top_customers AS (
    SELECT 
        customer_surr_id,
        COUNT(order_id) AS orders_count
    FROM fact_orders
    GROUP BY customer_surr_id
    ORDER BY orders_count DESC
    LIMIT 5
)

SELECT 
    c.full_name,
    MAX(d.full_date) AS last_activity_date,
    tc.orders_count
FROM top_customers AS tc
JOIN fact_orders AS o ON tc.customer_surr_id = o.customer_surr_id
JOIN dim_customers AS c ON tc.customer_surr_id = c.customer_surr_id
JOIN dim_dates AS d ON o.order_date_key = d.date_key
GROUP BY tc.customer_surr_id
ORDER BY tc.orders_count DESC;

-- Пользователи без заказов
SELECT 
    c.full_name,
    c.email,
    c.city
FROM dim_customers c
LEFT JOIN fact_orders AS o ON c.customer_surr_id = o.customer_surr_id
WHERE o.order_id IS NULL;
