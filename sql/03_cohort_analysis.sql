
--============================================
-- 코호트 분석 (Cohort Analysis) - 초기 버전
-- 참고: 이 버전은 CTE로만 처리 (파생변수 소수 적용)
-- 개선 버전: sql/04_cohort_analysis_v2.sql 참고
-- ============================================




-- 파생변수 컬럼 추가
--ALTER TABLE cleaned_data 
--    ADD COLUMN totalprice DECIMAL(10, 2),
--    ADD COLUMN yearmonth VARCHAR(7);

-- 데이터 업데이트
--UPDATE cleaned_data
--SET 
--    totalprice = quantity * unitprice,
--    yearmonth = TO_CHAR(invoicedate, 'YYYY-MM');


-- 확인
--SELECT invoiceno, quantity, unitprice, totalprice, yearmonth 
--FROM cleaned_data 
--LIMIT 10;

--------------------------------------------------------------------
--코호트 분석: 고객의 첫 구매 월 기준 월별 재구매율 계산

-- 1단계: 각 고객의 첫 구매 월 (코호트 월) 찾기
WITH customer_cohort AS (
    SELECT 
        customerid,
        TO_CHAR(MIN(invoicedate), 'YYYY-MM') AS cohort_month
    FROM cleaned_data
    WHERE customerid IS NOT NULL
    GROUP BY customerid
),
-- 2단계: 각 주문에 코호트 월 붙이기
orders_with_cohort AS (
    SELECT 
        c.cohort_month,
        TO_CHAR(d.invoicedate, 'YYYY-MM') AS order_month,
        d.customerid
    FROM cleaned_data d
    JOIN customer_cohort c ON d.customerid = c.customerid
    WHERE d.customerid IS NOT NULL
),

-- 3단계: 코호트 월로부터 몇 개월 후인지 계산
cohort_orders AS (
    SELECT 
        cohort_month,
        order_month,
        customerid,
        -- 월 차이 계산
        (EXTRACT(YEAR FROM TO_DATE(order_month, 'YYYY-MM')) - 
         EXTRACT(YEAR FROM TO_DATE(cohort_month, 'YYYY-MM'))) * 12 +
        (EXTRACT(MONTH FROM TO_DATE(order_month, 'YYYY-MM')) - 
         EXTRACT(MONTH FROM TO_DATE(cohort_month, 'YYYY-MM'))) AS month_number
    FROM orders_with_cohort
),

-- 4단계: 코호트별 월별 활성 고객 수 집계
cohort_data AS (
    SELECT 
        cohort_month,
        month_number,
        COUNT(DISTINCT customerid) AS active_customers
    FROM cohort_orders
    GROUP BY cohort_month, month_number
),

-- 5단계: 각 코호트의 초기 고객 수 (Month 0)
cohort_size AS (
    SELECT 
        cohort_month,
        active_customers AS cohort_size
    FROM cohort_data
    WHERE month_number = 0
)

-- 6단계: 리텐션율 계산
SELECT 
    cd.cohort_month,
    cd.month_number,
    cd.active_customers,
    cs.cohort_size,
    ROUND(cd.active_customers * 100.0 / cs.cohort_size, 2) AS retention_rate
FROM cohort_data cd
JOIN cohort_size cs ON cd.cohort_month = cs.cohort_month
ORDER BY cd.cohort_month, cd.month_number;