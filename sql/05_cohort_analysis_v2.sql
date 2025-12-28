-- ============================================
-- 코호트 분석 (Cohort Analysis) - 단순화(개선) 버전
-- 목표: 고객의 첫 구매 월(코호트) 기준 월별 재구매율 계산
-- 이전 버전: sql/02_cohort_analysis.sql
-- 전제조건: sql/04_add_derived_columns.sql 실행 완료
-- 변경점:
-- 1. 파생변수(yearmonth) 활용으로 쿼리 단순화
-- 2. 인덱스 활용으로 성능 향상
-- 3. 기존 cte 쿼리를 리텐션 결과 뷰로 저장
-- ============================================

--1. cte 활용한 리텐션 결과 뷰로 저장
--CREATE OR REPLACE VIEW cohort_retention as
--
---- 1단계: 각 고객의 첫 구매 월 (코호트 월) 찾기
--WITH customer_cohort AS (
--    SELECT 
--        customerid,
--        MIN(yearmonth) AS cohort_month  -- 파생변수 사용으로 단순화
--    FROM cleaned_data
--    WHERE customerid IS NOT NULL
--    GROUP BY customerid
--),
--
---- 2단계: 각 주문에 코호트 월 붙이기
--orders_with_cohort AS (
--    SELECT 
--        c.cohort_month,
--        d.yearmonth AS order_month,
--        d.customerid
--    FROM cleaned_data d
--    JOIN customer_cohort c ON d.customerid = c.customerid
--    WHERE d.customerid IS NOT NULL
--),
--
---- 3단계: 코호트 월로부터 몇 개월 후인지 계산
--cohort_orders AS (
--    SELECT 
--        cohort_month,
--        order_month,
--        customerid,
--        -- 월 차이 계산 (간소화)
--        (EXTRACT(YEAR FROM TO_DATE(order_month, 'YYYY-MM')) - 
--         EXTRACT(YEAR FROM TO_DATE(cohort_month, 'YYYY-MM'))) * 12 +
--        (EXTRACT(MONTH FROM TO_DATE(order_month, 'YYYY-MM')) - 
--         EXTRACT(MONTH FROM TO_DATE(cohort_month, 'YYYY-MM'))) AS month_number
--    FROM orders_with_cohort
--),
--
---- 4단계: 코호트별 월별 활성 고객 수 집계
--cohort_data AS (
--    SELECT 
--        cohort_month,
--        month_number,
--        COUNT(DISTINCT customerid) AS active_customers
--    FROM cohort_orders
--    GROUP BY cohort_month, month_number
--),
--
---- 5단계: 각 코호트의 초기 고객 수 (Month 0)
--cohort_size AS (
--    SELECT 
--        cohort_month,
--        active_customers AS cohort_size
--    FROM cohort_data
--    WHERE month_number = 0
--)
--
---- 6단계: 리텐션율 계산
--SELECT 
--    cd.cohort_month,
--    cd.month_number,
--    cd.active_customers,
--    cs.cohort_size,
--    ROUND(cd.active_customers * 100.0 / cs.cohort_size, 2) AS retention_rate
--FROM cohort_data cd
--JOIN cohort_size cs ON cd.cohort_month = cs.cohort_month
--ORDER BY cd.cohort_month, cd.month_number;

-- ============================================
-- 추가 분석: 코호트별 요약 통계
-- ============================================

-- 코호트별 첫 3개월 평균 리텐션 조회
-- 만들어 둔 cohort_retention 뷰 활용
SELECT 
    cohort_month,
    ROUND(AVG(retention_rate), 2) AS avg_retention_3months
FROM cohort_retention
WHERE month_number BETWEEN 1 AND 3
GROUP BY cohort_month
ORDER BY avg_retention_3months DESC;

-------------------------------------------------------------

-- 가장 성적이 좋은 '2010-12'코호트가 왜 충성도가 높은지 확인하고자 함
-- 2010-12 코호트 고객들이 가장 많이 구매한 상품 리스트 조회 ->'충성 고객을 만드는 킬러 아이템'을 정의하는 데 도움
WITH customer_cohort AS (
    SELECT 
        customerid,
        TO_CHAR(MIN(invoicedate), 'YYYY-MM') AS cohort_month
    FROM cleaned_data
    WHERE customerid IS NOT NULL
    GROUP BY customerid
)
SELECT 
    d.description,  -- 상품명
    COUNT(*) AS order_count,
    SUM(d.quantity) AS total_quantity,
    SUM(d.totalprice) AS total_revenue
FROM cleaned_data d
JOIN customer_cohort c ON d.customerid = c.customerid
WHERE c.cohort_month = '2010-12' -- 가장 성적이 좋은 코호트 지정
GROUP BY d.description
ORDER BY total_quantity DESC
LIMIT 10;


-- 반대로 리텐션이 낮은 '취약 코호트'를 대상으로 이탈 원인을 파악하고자 함
-- 그들의 특성을 파악하기 위해 해당 코호트의 첫 구매 상품을 뽑아보고 만족도가 낮았던 상품 확인
WITH customer_first_order AS (
    -- 고객별 첫 주문의 invoicedate와 ID를 가져옴
    SELECT 
        customerid,
        MIN(invoicedate) AS first_invoicedate
    FROM cleaned_data
    WHERE customerid IS NOT NULL
    GROUP BY customerid
),
cohort_first_items AS (
    -- 첫 주문 시점에 구매했던 구체적인 상품 정보 매칭
    SELECT 
        TO_CHAR(f.first_invoicedate, 'YYYY-MM') AS cohort_month,
        d.description,
        d.quantity,
        d.unitprice
    FROM cleaned_data d
    JOIN customer_first_order f ON d.customerid = f.customerid 
                               AND d.invoicedate = f.first_invoicedate
)
SELECT 
    cohort_month,
    description,
    COUNT(*) AS customer_count, -- 이 상품을 첫 구매로 선택한 고객 수
    ROUND(AVG(unitprice), 2) AS avg_price
FROM cohort_first_items
WHERE cohort_month IN ('2011-03', '2011-09') -- 취약 코호트 지정
GROUP BY cohort_month, description
ORDER BY cohort_month, customer_count DESC
