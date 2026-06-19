DROP TABLE IF EXISTS fact_events;
DROP TABLE IF EXISTS fact_payments;
DROP TABLE IF EXISTS fact_orders;
DROP TABLE IF EXISTS dim_event_types;
DROP TABLE IF EXISTS dim_products;
DROP TABLE IF EXISTS dim_customers;
DROP TABLE IF EXISTS dim_dates;

PRAGMA foreign_keys = ON;

-- Клиенты
CREATE TABLE dim_customers (
    customer_surr_id INTEGER PRIMARY KEY AUTOINCREMENT,
    customer_id INTEGER UNIQUE,
    full_name TEXT,
    email TEXT,
    city TEXT
);

INSERT OR IGNORE INTO dim_customers (customer_id, full_name, email, city)
SELECT customer_id, full_name, email, city FROM customers;

-- Товары
CREATE TABLE dim_products (
    product_surr_id INTEGER PRIMARY KEY AUTOINCREMENT,
    product_id INTEGER UNIQUE,
    product_name TEXT,
    category TEXT,
    price REAL
);

INSERT OR IGNORE INTO dim_products (product_id, product_name, category, price)
SELECT product_id, product_name, category, price FROM products;

-- Даты
DROP TABLE IF EXISTS dim_dates;

CREATE TABLE dim_dates (
    date_key INTEGER PRIMARY KEY,
    full_date DATE,
    year INTEGER,
    month INTEGER,
    month_name TEXT
);

INSERT OR IGNORE INTO dim_dates (date_key, full_date, year, month, month_name)
SELECT DISTINCT
    CAST(strftime('%Y%m%d', date_col) AS INTEGER) AS date_key,
    date_col AS full_date,
    strftime('%Y', date_col) AS year,
    CAST(strftime('%m', date_col) AS INTEGER) AS month,
    strftime('%B', date_col) AS month_name
FROM (
    SELECT created_at AS date_col FROM customers WHERE created_at IS NOT NULL AND created_at != ''
    UNION
    SELECT payment_timestamp FROM payments WHERE payment_timestamp IS NOT NULL AND payment_timestamp != ''
    UNION
    SELECT order_timestamp FROM orders WHERE order_timestamp IS NOT NULL AND order_timestamp != ''
    UNION
    SELECT event_timestamp FROM events WHERE event_timestamp IS NOT NULL AND event_timestamp != ''
);

-- Тип события
CREATE TABLE dim_event_types (
    event_type_id INTEGER PRIMARY KEY AUTOINCREMENT,
    event_type_name TEXT UNIQUE
);

INSERT OR IGNORE INTO dim_event_types (event_type_name)
SELECT DISTINCT event_type FROM events WHERE event_type IS NOT NULL;

-- Заказы
CREATE TABLE fact_orders (
    order_id INTEGER PRIMARY KEY,
    customer_surr_id INTEGER,
    product_surr_id INTEGER,
    order_date_key INTEGER,
    total_amount REAL,
    status TEXT,
    FOREIGN KEY (customer_surr_id) REFERENCES dim_customers(customer_surr_id),
    FOREIGN KEY (product_surr_id) REFERENCES dim_products(product_surr_id),
    FOREIGN KEY (order_date_key) REFERENCES dim_dates(date_key)
);

INSERT OR IGNORE INTO fact_orders (order_id, customer_surr_id, product_surr_id, order_date_key, total_amount, status)
SELECT 
    o.order_id,
    c.customer_surr_id,
    p.product_surr_id,
    CAST(strftime('%Y%m%d', o.order_timestamp) AS INTEGER),
    o.unit_price * o.quantity,
    o.status
FROM orders o
JOIN dim_customers c ON o.customer_id = c.customer_id
JOIN dim_products p ON o.product_id = p.product_id;

-- Платежи
CREATE TABLE fact_payments (
    payment_id INTEGER PRIMARY KEY,
    order_id INTEGER,
    customer_surr_id INTEGER,
    payment_date_key INTEGER,
    amount REAL,
    payment_method TEXT,
    FOREIGN KEY (order_id) REFERENCES fact_orders(order_id),
    FOREIGN KEY (customer_surr_id) REFERENCES dim_customers(customer_surr_id),
    FOREIGN KEY (payment_date_key) REFERENCES dim_dates(date_key)
);

PRAGMA foreign_keys = OFF;

INSERT OR IGNORE INTO fact_payments (payment_id, order_id, customer_surr_id, payment_date_key, amount, payment_method)
SELECT 
    p.payment_id,
    p.order_id,
    c.customer_surr_id,
    CAST(strftime('%Y%m%d', p.payment_timestamp) AS INTEGER),
    p.amount,
    p.payment_method
FROM payments p
JOIN orders o ON p.order_id = o.order_id
JOIN dim_customers c ON o.customer_id = c.customer_id
WHERE p.amount IS NOT NULL;

PRAGMA foreign_keys = ON;

-- События
CREATE TABLE fact_events (
    event_id INTEGER PRIMARY KEY,
    customer_surr_id INTEGER,
    event_type_id INTEGER,
    event_date_key INTEGER,
    product_id INTEGER,
    FOREIGN KEY (customer_surr_id) REFERENCES dim_customers(customer_surr_id),
    FOREIGN KEY (event_type_id) REFERENCES dim_event_types(event_type_id),
    FOREIGN KEY (event_date_key) REFERENCES dim_dates(date_key)
);

INSERT OR IGNORE INTO fact_events (event_id, customer_surr_id, event_type_id, event_date_key, product_id)
SELECT 
    e.event_id,
    c.customer_surr_id,
    et.event_type_id,
    CAST(strftime('%Y%m%d', e.event_timestamp) AS INTEGER),
    e.product_id
FROM events e
JOIN dim_customers c ON e.customer_id = c.customer_id
JOIN dim_event_types et ON e.event_type = et.event_type_name
WHERE e.customer_id != -1;
