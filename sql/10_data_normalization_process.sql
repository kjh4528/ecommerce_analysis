-- 기존 cleaned_data 데이터 수 541,906

-- ============================================
-- 정규화 작업 SQL 스크립트
-- cleaned_data (1개 테이블) → 4개 정규화 테이블
-- 작성일: 2024-12-22
-- ============================================

-- ============================================
-- STEP 1: 정규화된 테이블 생성 (1NF → 3NF)
-- ============================================

-- 1) customers 테이블
--CREATE TABLE customers (
--    customer_id VARCHAR(20) PRIMARY KEY,
--    country VARCHAR(100)
--);
--
-- 2) products 테이블
--CREATE TABLE products (
--    stock_code VARCHAR(20) PRIMARY KEY,
--    description TEXT,
--    unit_price NUMERIC(10, 2)
--);
--
-- 3) orders 테이블
--CREATE TABLE orders (
--    invoice_no VARCHAR(20) PRIMARY KEY,
--    customer_id VARCHAR(20),
--    invoice_date TIMESTAMP NOT NULL,
--    country VARCHAR(100),
--    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
--);
--
-- 4) order_items 테이블
--CREATE TABLE order_items (
--    item_id SERIAL PRIMARY KEY,
--    invoice_no VARCHAR(20) NOT NULL,
--    stock_code VARCHAR(20) NOT NULL,
--    quantity INT4,
--    unit_price NUMERIC(10, 2),
--    total_price NUMERIC(10, 2),
--    FOREIGN KEY (invoice_no) REFERENCES orders(invoice_no),
--    FOREIGN KEY (stock_code) REFERENCES products(stock_code)
--);

-- ============================================
-- STEP 2: 데이터 이관 (cleaned_data → 4개 테이블)
-- ============================================

-- 1) customers 테이블 적재
--INSERT INTO customers (customer_id, country)
--SELECT DISTINCT 
--    customerid, 
--    country
--FROM cleaned_data
--WHERE customerid IS NOT NULL
--ON CONFLICT (customer_id) DO NOTHING;
--
-- 확인
--SELECT COUNT(*) as customer_count FROM customers;
-- 4,372건
--
-- 2) products 테이블 적재
-- 동일 stock_code의 경우 가장 최근 description과 unitprice 사용
--INSERT INTO products (stock_code, description, unit_price)
--SELECT DISTINCT ON (stockcode)
--    stockcode,
--    description,
--    unitprice
--FROM cleaned_data
--WHERE stockcode IS NOT NULL
--ORDER BY stockcode, invoicedate DESC
--ON CONFLICT (stock_code) DO NOTHING;
--
-- 확인
--SELECT COUNT(*) as product_count FROM products;
--4,069
--
-- 3) orders 테이블 적재(NULL 포함)
--DELETE FROM orders;  -- 기존 데이터 삭제
--
--INSERT INTO orders (invoice_no, customer_id, invoice_date, country)
--SELECT DISTINCT
--    invoiceno,
--    customerid,  -- NULL 허용
--    invoicedate,
--    country
--FROM cleaned_data
--WHERE invoiceno IS NOT NULL
--ON CONFLICT (invoice_no) DO NOTHING;
--
-- 확인
--SELECT COUNT(*) as order_count FROM orders;
--22,190건  -> 널 포함으로 수정 후 25,897
--SELECT COUNT(*) as null_customer_count 
--FROM orders 
--WHERE customer_id IS NULL;   --널 3,707건
--
--
-- 4) order_items 테이블 적재
--INSERT INTO order_items (invoice_no, stock_code, quantity, unit_price, total_price)
--SELECT 
--    invoiceno,
--    stockcode,
--    quantity,
--    unitprice,
--    totalprice
--FROM cleaned_data
--WHERE invoiceno IS NOT NULL
--  AND stockcode IS NOT NULL;
--
-- 확인
--SELECT COUNT(*) as order_item_count FROM order_items;
--541,906건


-- ============================================
-- STEP 3: 인덱스 생성 (성능 최적화)
-- ============================================

-- orders 테이블 인덱스
--CREATE INDEX idx_orders_customer_id ON orders(customer_id);
--CREATE INDEX idx_orders_invoice_date ON orders(invoice_date);
--CREATE INDEX idx_orders_country ON orders(country);
--
-- order_items 테이블 인덱스
--CREATE INDEX idx_order_items_invoice_no ON order_items(invoice_no);
--CREATE INDEX idx_order_items_stock_code ON order_items(stock_code);
--
-- 확인
--SELECT 
--    tablename, 
--    indexname, 
--    indexdef 
--FROM pg_indexes 
--WHERE tablename IN ('customers', 'products', 'orders', 'order_items')
--ORDER BY tablename, indexname;


-- ============================================
-- STEP 4: 분석용 통합 VIEW 생성
-- (기존 cleaned_data처럼 사용하기 위함 - null 포함)
-- ============================================

--CREATE OR REPLACE VIEW analysis_base AS
--SELECT 
--    -- 고객 정보
--    c.customer_id,
--    c.country as customer_country,
--    
--    -- 주문 정보
--    o.invoice_no,
--    o.invoice_date,
--    o.country as order_country,
--    
--    -- 상품 정보
--    p.stock_code,
--    p.description,
--    
--    -- 주문 상세
--    oi.quantity,
--    oi.unit_price,
--    oi.total_price,
--    
--    -- 파생변수 (기존과 동일)
--    TO_CHAR(o.invoice_date, 'YYYY-MM') as yearmonth,
--    EXTRACT(YEAR FROM o.invoice_date)::INT4 as year,
--    EXTRACT(MONTH FROM o.invoice_date)::INT4 as month,
--    EXTRACT(DOW FROM o.invoice_date)::INT4 as dayofweek,
--    EXTRACT(HOUR FROM o.invoice_date)::INT4 as hour
--FROM order_items oi  -- 시작점을 order_items로 변경
--LEFT JOIN orders o ON oi.invoice_no = o.invoice_no
--LEFT JOIN customers c ON o.customer_id = c.customer_id
--LEFT JOIN products p ON oi.stock_code = p.stock_code;

---- 확인
--SELECT COUNT(*) as total_rows FROM analysis_base;  --406,829-> 널 포함 541,906으로 정상
--SELECT * FROM analysis_base LIMIT 10;



-- ============================================
-- STEP 5: 기존 VIEW들 수정 (cleaned_data → analysis_base)
-- ============================================

-- 1) cohort_retention VIEW 재생성
CREATE OR REPLACE VIEW cohort_retention AS
WITH customer_cohort AS (
    SELECT 
        customer_id,
        MIN(yearmonth) AS cohort_month
    FROM analysis_base
    WHERE customer_id IS NOT NULL
    GROUP BY customer_id
),
orders_with_cohort AS (
    SELECT 
        c.cohort_month,
        a.yearmonth AS order_month,
        a.customer_id
    FROM analysis_base a
    JOIN customer_cohort c ON a.customer_id = c.customer_id
    WHERE a.customer_id IS NOT NULL
),
cohort_orders AS (
    SELECT 
        cohort_month,
        order_month,
        customer_id,
        (EXTRACT(YEAR FROM TO_DATE(order_month, 'YYYY-MM')) - 
         EXTRACT(YEAR FROM TO_DATE(cohort_month, 'YYYY-MM'))) * 12 +
        (EXTRACT(MONTH FROM TO_DATE(order_month, 'YYYY-MM')) - 
         EXTRACT(MONTH FROM TO_DATE(cohort_month, 'YYYY-MM'))) AS month_number
    FROM orders_with_cohort
),
cohort_data AS (
    SELECT 
        cohort_month,
        month_number,
        COUNT(DISTINCT customer_id) AS active_customers
    FROM cohort_orders
    GROUP BY cohort_month, month_number
),
cohort_size AS (
    SELECT 
        cohort_month,
        active_customers AS cohort_size
    FROM cohort_data
    WHERE month_number = 0
)
SELECT 
    cd.cohort_month,
    cd.month_number,
    cd.active_customers,
    cs.cohort_size,
    ROUND(cd.active_customers * 100.0 / cs.cohort_size, 2) AS retention_rate
FROM cohort_data cd
JOIN cohort_size cs ON cd.cohort_month = cs.cohort_month
ORDER BY cd.cohort_month, cd.month_number;


-- 2) rfm_customer_segments VIEW 재생성
CREATE OR REPLACE VIEW rfm_customer_segments AS
WITH rfm_raw AS (
    SELECT 
        customer_id as customerid,  --기존뷰 컬럼명이 customerid라 내부적으로 맞추기
        DATE '2011-12-09' - MAX(invoice_date::DATE) AS recency_days,
        COUNT(DISTINCT invoice_no) AS frequency,
        SUM(total_price) AS monetary_value
    FROM analysis_base
    WHERE customer_id IS NOT NULL
      AND quantity > 0
      AND total_price > 0
      AND unit_price > 0
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT 
        customerid,  --수정
        recency_days,
        frequency,
        monetary_value,
        6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value) AS m_score
    FROM rfm_raw
)
SELECT 
    customerid,  --수정
    recency_days,
    frequency,
    ROUND(monetary_value::NUMERIC, 2) AS monetary_value,
    r_score,
    f_score,
    m_score,
    r_score::text || f_score::text || m_score::text AS rfm_segment,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal'
        WHEN m_score >= 4 AND f_score >= 2 THEN 'Big'
        WHEN r_score >= 4 AND f_score <= 2 AND m_score >= 3 THEN 'Promising'
        WHEN r_score >= 4 AND f_score = 1 THEN 'New'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
        WHEN r_score = 1 THEN 'Lost'
        ELSE 'Others'
    END AS segment_name
FROM rfm_scores;


-- 3) rfm_customer_segments_v2 VIEW 재생성
CREATE OR REPLACE VIEW rfm_customer_segments_v2 AS
WITH rfm_raw AS (
    SELECT 
        customer_id as customerid,  --수정
        DATE '2011-12-09' - MAX(invoice_date::DATE) AS recency_days,
        COUNT(DISTINCT invoice_no) AS frequency,
        SUM(total_price) AS monetary_value
    FROM analysis_base
    WHERE customer_id IS NOT NULL
      AND quantity > 0
      AND total_price > 0
      AND unit_price > 0
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT 
        customerid,  --수정
        recency_days,
        frequency,
        monetary_value,
        6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,
        NTILE(5) OVER (ORDER BY frequency) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value) AS m_score
    FROM rfm_raw
)
SELECT 
    customerid,   --수정
    recency_days,
    frequency,
    ROUND(monetary_value::NUMERIC, 2) AS monetary_value,
    r_score,
    f_score,
    m_score,
    r_score::text || f_score::text || m_score::text AS rfm_segment,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal'
        WHEN r_score >= 3 AND m_score >= 4 AND f_score >= 2 THEN 'Big'
        WHEN r_score <= 2 AND (f_score >= 3 OR m_score >= 4) THEN 'Risk'
        WHEN r_score >= 4 AND f_score <= 2 AND m_score >= 2 THEN 'Promising'
        WHEN r_score >= 4 AND f_score = 1 THEN 'New'
        WHEN r_score = 3 AND f_score >= 2 AND m_score >= 2 THEN 'Need Attention'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Hibernating'
        WHEN r_score = 1 AND recency_days >= 200 THEN 'Lost'
        ELSE 'Others'
    END AS segment_name
FROM rfm_scores;


-- 4) rfm_summary_v1, v2 VIEW 재생성
CREATE OR REPLACE VIEW rfm_summary_v1 AS
SELECT 
    segment_name,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
    ROUND(AVG(recency_days)::NUMERIC, 1) AS avg_recency,
    ROUND(AVG(frequency)::NUMERIC, 1) AS avg_frequency,
    ROUND(AVG(monetary_value)::NUMERIC, 2) AS avg_monetary,
    ROUND(AVG(r_score)::NUMERIC, 2) AS avg_r_score,
    ROUND(AVG(f_score)::NUMERIC, 2) AS avg_f_score,
    ROUND(AVG(m_score)::NUMERIC, 2) AS avg_m_score,
    ROUND(SUM(monetary_value)::NUMERIC, 2) AS total_revenue
FROM rfm_customer_segments
GROUP BY segment_name
ORDER BY total_revenue DESC;

CREATE OR REPLACE VIEW rfm_summary_v2 AS
SELECT 
    segment_name,
    COUNT(*) AS customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
    ROUND(AVG(recency_days)::NUMERIC, 1) AS avg_recency,
    ROUND(AVG(frequency)::NUMERIC, 1) AS avg_frequency,
    ROUND(AVG(monetary_value)::NUMERIC, 2) AS avg_monetary,
    ROUND(AVG(r_score)::NUMERIC, 2) AS avg_r_score,
    ROUND(AVG(f_score)::NUMERIC, 2) AS avg_f_score,
    ROUND(AVG(m_score)::NUMERIC, 2) AS avg_m_score,
    ROUND(SUM(monetary_value)::NUMERIC, 2) AS total_revenue
FROM rfm_customer_segments_v2
GROUP BY segment_name
ORDER BY total_revenue DESC;


-- 5) customer_purchase_stages VIEW 재생성
CREATE OR REPLACE VIEW customer_purchase_stages AS
WITH customer_orders AS (
    SELECT 
        customer_id AS customerid,
        invoice_no AS invoiceno,
        invoice_date AS invoicedate,
        total_price AS totalprice,
        quantity,
        CASE 
            WHEN invoice_no LIKE 'C%' OR quantity < 0 THEN TRUE 
            ELSE FALSE 
        END AS is_cancelled
    FROM analysis_base
    WHERE customer_id IS NOT NULL
),
valid_orders AS (
    SELECT *
    FROM customer_orders
    WHERE is_cancelled = FALSE 
      AND totalprice > 0   --수정
),
customer_metrics AS (
    SELECT 
        customerid,   --수정
        COUNT(DISTINCT invoiceno) AS total_orders,    --수정
        MIN(invoicedate) AS first_purchase_date,   --수정
        MAX(invoicedate) AS last_purchase_date,   --수정
        SUM(totalprice) AS total_spent   --수정
    FROM valid_orders
    GROUP BY customerid   --수정
)
SELECT 
    customerid,   --수정
    total_orders,
    first_purchase_date,
    last_purchase_date,
    total_spent,
    CASE 
        WHEN total_orders = 1 THEN '1. First Purchase'
        WHEN total_orders = 2 THEN '2. Second Purchase'
        WHEN total_orders >= 3 AND total_orders < 5 THEN '3. Regular Customer'
        WHEN total_orders >= 5 THEN '4. Loyal Customer'
    END AS purchase_stage
FROM customer_metrics;


-- 6) funnel_conversion_rates VIEW 재생성
CREATE OR REPLACE VIEW funnel_conversion_rates AS
WITH stage_counts AS (
    SELECT 
        purchase_stage,
        COUNT(DISTINCT customerid) AS customer_count    --수정
    FROM customer_purchase_stages
    GROUP BY purchase_stage
),
total_customers AS (
    SELECT COUNT(DISTINCT customerid) AS total    --수정
    FROM customer_purchase_stages
)
SELECT 
    sc.purchase_stage,
    sc.customer_count,
    ROUND(sc.customer_count * 100.0 / tc.total, 2) AS percentage_of_total,
    ROUND(sc.customer_count * 100.0 / 
          LAG(sc.customer_count) OVER (ORDER BY sc.purchase_stage), 2) AS conversion_rate,
    ROUND(100 - (sc.customer_count * 100.0 / 
          LAG(sc.customer_count) OVER (ORDER BY sc.purchase_stage)), 2) AS drop_off_rate
FROM stage_counts sc
CROSS JOIN total_customers tc
ORDER BY sc.purchase_stage;


-- 7) funnel_by_rfm_segment VIEW 재생성
CREATE OR REPLACE VIEW funnel_by_rfm_segment AS
WITH customer_stage_segment AS (
    SELECT 
        cps.customerid,    --수정
        cps.purchase_stage,
        cps.total_orders,
        cps.total_spent,
        rfm.segment_name,
        rfm.rfm_segment
    FROM customer_purchase_stages cps
    LEFT JOIN rfm_customer_segments_v2 rfm 
        ON cps.customerid = rfm.customerid    --수정
)
SELECT 
    segment_name,
    purchase_stage,
    COUNT(DISTINCT customerid) AS customer_count,    --수정
    ROUND(AVG(total_orders), 2) AS avg_orders,
    ROUND(AVG(total_spent), 2) AS avg_spent
FROM customer_stage_segment
WHERE segment_name IS NOT NULL
GROUP BY segment_name, purchase_stage
ORDER BY 
    CASE segment_name
        WHEN 'Champions' THEN 1
        WHEN 'Loyal' THEN 2
        WHEN 'Promising' THEN 3
        WHEN 'Big' THEN 4
        WHEN 'Need Attention' THEN 5
        WHEN 'Risk' THEN 6
        WHEN 'Hibernating' THEN 7
        WHEN 'Lost' THEN 8
        WHEN 'New' THEN 9
        ELSE 10
    END,
    purchase_stage;


-- 8) funnel_segment_conversion VIEW 재생성
CREATE OR REPLACE VIEW funnel_segment_conversion AS
WITH segment_funnel AS (
    SELECT 
        segment_name,
        purchase_stage,
        COUNT(DISTINCT customerid) AS customer_count    --수정
    FROM (
        SELECT 
            cps.customerid,     --수정
            cps.purchase_stage,
            rfm.segment_name
        FROM customer_purchase_stages cps
        LEFT JOIN rfm_customer_segments_v2 rfm 
            ON cps.customerid = rfm.customerid    --수정
        WHERE rfm.segment_name IS NOT NULL
    ) sub
    GROUP BY segment_name, purchase_stage
)
SELECT 
    segment_name,
    purchase_stage,
    customer_count,
    ROUND(customer_count * 100.0 / 
          SUM(customer_count) OVER (PARTITION BY segment_name), 2) AS pct_within_segment,
    ROUND(customer_count * 100.0 / 
          LAG(customer_count) OVER (PARTITION BY segment_name ORDER BY purchase_stage), 2) AS stage_conversion_rate
FROM segment_funnel
ORDER BY 
    CASE segment_name
        WHEN 'Champions' THEN 1
        WHEN 'Loyal' THEN 2
        WHEN 'Promising' THEN 3
        WHEN 'Big' THEN 4
        WHEN 'Need Attention' THEN 5
        WHEN 'Risk' THEN 6
        WHEN 'Hibernating' THEN 7
        WHEN 'Lost' THEN 8
        WHEN 'New' THEN 9
        ELSE 10
    END,
    purchase_stage;


-- 9) segment_product_purchases VIEW 재생성
CREATE OR REPLACE VIEW segment_product_purchases AS
SELECT 
    rcs.customerid,   --수정
    rcs.rfm_segment,
    rcs.segment_name,
    rcs.recency_days,
    rcs.frequency,
    rcs.monetary_value,
    rcs.r_score,
    rcs.f_score,
    rcs.m_score,
    ab.invoice_no as invoiceno,   --수정  
    ab.invoice_date as invoicedate, --수정
    ab.stock_code as stockcode,   --수정
    ab.description,
    ab.quantity,
    ab.unit_price as unitprice,   --수정
    ab.total_price as totalprice, --수정
    ab.customer_country as country, --수정
    ab.yearmonth::VARCHAR(7) AS yearmonth, --수정
    ab.year,
    ab.month,
    ab.dayofweek,
    ab.hour
FROM rfm_customer_segments_v2 rcs
INNER JOIN analysis_base ab ON rcs.customerid = ab.customer_id;  --수정


-- 10) segment_product_summary VIEW 재생성
CREATE OR REPLACE VIEW segment_product_summary AS
SELECT 
    segment_name,
    rfm_segment,
    stockcode,  --수정
    description,
    COUNT(DISTINCT customerid) AS customer_count,  --수정
    COUNT(DISTINCT invoiceno) AS order_count,  --수정
    SUM(quantity) AS total_quantity,
    SUM(totalprice) AS total_revenue,  --수정
    AVG(totalprice) AS avg_purchase_value,  --수정
    AVG(quantity) AS avg_quantity,
    COUNT(*) AS purchase_count
FROM segment_product_purchases
GROUP BY segment_name, rfm_segment, stockcode, description;  --수정


-- 11) champions_vs_new_products VIEW 재생성
CREATE OR REPLACE VIEW champions_vs_new_products AS
SELECT 
    segment_name AS customer_group,
    stockcode,  --수정
    description,
    COUNT(DISTINCT customerid) AS customer_count,  --수정
    COUNT(DISTINCT invoiceno) AS order_count,  --수정
    SUM(totalprice) AS total_revenue,  --수정
    AVG(totalprice) AS avg_purchase_value,  --수정
    SUM(quantity) AS total_quantity,
    AVG(quantity) AS avg_quantity,
    COUNT(*) AS purchase_count
FROM segment_product_purchases
WHERE segment_name IN ('Champions', 'New')
GROUP BY segment_name, stockcode, description;  --수정


-- 12) segment_top_products VIEW 재생성
CREATE OR REPLACE VIEW segment_top_products AS
WITH ranked_products AS (
    SELECT 
        segment_name,
        rfm_segment,
        stockcode,  --수정
        description,
        SUM(totalprice) AS total_revenue,  --수정
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT customerid) AS customer_count,  --수정
        COUNT(DISTINCT invoiceno) AS order_count,  --수정
        ROW_NUMBER() OVER (PARTITION BY segment_name ORDER BY SUM(totalprice) DESC) as revenue_rank  --수정
    FROM segment_product_purchases
    GROUP BY segment_name, rfm_segment, stockcode, description  --수정
)
SELECT *
FROM ranked_products
WHERE revenue_rank <= 50;


-- 13) segment_purchase_patterns VIEW 재생성
CREATE OR REPLACE VIEW segment_purchase_patterns AS
SELECT 
    segment_name,
    COUNT(DISTINCT customerid) AS customer_count,  --수정
    COUNT(DISTINCT invoiceno) AS total_orders,  --수정
    COUNT(DISTINCT stockcode) AS unique_products,  --수정
    SUM(totalprice) AS total_revenue,  --수정
    AVG(totalprice) AS avg_purchase_value,  --수정
    SUM(quantity) AS total_quantity,
    AVG(quantity) AS avg_quantity_per_transaction,
    COUNT(DISTINCT stockcode) * 1.0 / COUNT(DISTINCT customerid) AS products_per_customer  --수정
FROM segment_product_purchases
GROUP BY segment_name
ORDER BY total_revenue DESC;

-- ============================================
-- STEP 6: 전체 검증
-- ============================================

-- 1) 테이블 데이터 개수 확인
SELECT 
    'customers' as table_name, 
    COUNT(*) as row_count 
FROM customers
UNION ALL
SELECT 'products', COUNT(*) FROM products
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'analysis_base', COUNT(*) FROM analysis_base
UNION ALL
SELECT 'cleaned_data', COUNT(*) FROM cleaned_data;

-- 2) VIEW 목록 확인
SELECT 
    table_name,
    CASE 
        WHEN table_name = 'analysis_base' THEN '✅ 분석용 통합 VIEW'
        WHEN table_name LIKE 'cohort%' THEN '📊 코호트 분석'
        WHEN table_name LIKE 'rfm%' THEN '🎯 RFM 분석'
        WHEN table_name LIKE 'funnel%' THEN '🔽 퍼널 분석'
        WHEN table_name LIKE 'segment%' THEN '🏷️ 세그먼트 분석'
        ELSE '기타'
    END as category
FROM information_schema.views
WHERE table_schema = 'public'
ORDER BY category, table_name;

-- 3) 인덱스 확인
SELECT 
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('customers', 'products', 'orders', 'order_items', 'cleaned_data')
ORDER BY tablename, indexname;


