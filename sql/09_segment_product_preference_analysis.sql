-- segment_product_preference_analysis.sql
-- 세그먼트별 상품 구매 분석을 위한 뷰 생성

-- 1. 세그먼트별 상품 구매 내역 뷰
CREATE OR REPLACE VIEW segment_product_purchases AS
SELECT 
    rcs.customerid,
    rcs.rfm_segment,
    rcs.segment_name,
    rcs.recency_days,
    rcs.frequency,
    rcs.monetary_value,
    rcs.r_score,
    rcs.f_score,
    rcs.m_score,
    cd.invoiceno,
    cd.invoicedate,
    cd.stockcode,
    cd.description,
    cd.quantity,
    cd.unitprice,
    cd.totalprice,
    cd.country,
    cd.yearmonth,
    cd.year,
    cd.month,
    cd.dayofweek,
    cd.hour
FROM 
    rfm_customer_segments_v2 rcs
INNER JOIN 
    cleaned_data cd ON rcs.customerid = cd.customerid;

-- 뷰 생성 확인
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT customerid) as unique_customers,
    COUNT(DISTINCT rfm_segment) as unique_segments,
    COUNT(DISTINCT segment_name) as unique_segment_names,
    COUNT(DISTINCT stockcode) as unique_products
FROM segment_product_purchases;


-- 2. 세그먼트별 상품 구매 요약 뷰
CREATE OR REPLACE VIEW segment_product_summary AS
SELECT 
    segment_name,
    rfm_segment,
    stockcode,
    description,
    COUNT(DISTINCT customerid) AS customer_count,
    COUNT(DISTINCT invoiceno) AS order_count,
    SUM(quantity) AS total_quantity,
    SUM(totalprice) AS total_revenue,
    AVG(totalprice) AS avg_purchase_value,
    AVG(quantity) AS avg_quantity,
    COUNT(*) AS purchase_count
FROM 
    segment_product_purchases
GROUP BY 
    segment_name,
    rfm_segment,
    stockcode,
    description;



-- 3. Champions vs New 고객 상품 비교 뷰
CREATE OR REPLACE VIEW champions_vs_new_products AS
SELECT 
    segment_name AS customer_group,
    stockcode,
    description,
    COUNT(DISTINCT customerid) AS customer_count,
    COUNT(DISTINCT invoiceno) AS order_count,
    SUM(totalprice) AS total_revenue,
    AVG(totalprice) AS avg_purchase_value,
    SUM(quantity) AS total_quantity,
    AVG(quantity) AS avg_quantity,
    COUNT(*) AS purchase_count
FROM 
    segment_product_purchases
WHERE 
    segment_name IN ('Champions', 'New')
GROUP BY 
    segment_name,
    stockcode,
    description;

-- 확인
SELECT 
    customer_group,
    COUNT(DISTINCT stockcode) as unique_products,
    SUM(total_revenue) as total_revenue,
    SUM(customer_count) as total_customers
FROM champions_vs_new_products
GROUP BY customer_group;



-- 4. 세그먼트별 상위 상품 뷰 (TOP 50)
CREATE OR REPLACE VIEW segment_top_products AS
WITH ranked_products AS (
    SELECT 
        segment_name,
        rfm_segment,
        stockcode,
        description,
        SUM(totalprice) AS total_revenue,
        SUM(quantity) AS total_quantity,
        COUNT(DISTINCT customerid) AS customer_count,
        COUNT(DISTINCT invoiceno) AS order_count,
        ROW_NUMBER() OVER (PARTITION BY segment_name ORDER BY SUM(totalprice) DESC) as revenue_rank
    FROM 
        segment_product_purchases
    GROUP BY 
        segment_name,
        rfm_segment,
        stockcode,
        description
)
SELECT *
FROM ranked_products
WHERE revenue_rank <= 50;



-- 5. 세그먼트별 구매 패턴 요약 뷰
CREATE OR REPLACE VIEW segment_purchase_patterns AS
SELECT 
    segment_name,
    COUNT(DISTINCT customerid) AS customer_count,
    COUNT(DISTINCT invoiceno) AS total_orders,
    COUNT(DISTINCT stockcode) AS unique_products,
    SUM(totalprice) AS total_revenue,
    AVG(totalprice) AS avg_purchase_value,
    SUM(quantity) AS total_quantity,
    AVG(quantity) AS avg_quantity_per_transaction,
    COUNT(DISTINCT stockcode) * 1.0 / COUNT(DISTINCT customerid) AS products_per_customer
FROM 
    segment_product_purchases
GROUP BY 
    segment_name
ORDER BY 
    total_revenue DESC;
