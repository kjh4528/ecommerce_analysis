
--============================================
-- 코호트 분석 (Cohort Analysis) - 초기 버전
-- 참고: 이 버전은 CTE로만 처리 & 파생변수 임시 적용
-- 개선 버전: sql/04_cohort_analysis_v2.sql 참고

--CTE 사용 이유:
--1) 데이터의 기준점(Base) 만들기
--코호트 분석은 '이 고객이 언제 처음 왔는가'라는 기준점이 반드시 필요
--CTE를 통해 고객별 '최초 상태'를 정의해두고, 이를 원본 데이터와 JOIN해서 사용
--2) 가독성과 논리적 분리
--CTE 없이 작성하려면 서브쿼리를 복잡하게 중첩시켜야 함
--윈도우함수도 가능하지만 그룹화 다시 한 번 필요하고, 가독성의 이유로 CTE 사용 
--3) 재사용성
한 번 정의해두면, 코호트 분석뿐만 아니라 '신규 고객 추이 분석' 등 다른 쿼리에서도 이 결과물을 가져다 쓰기 매우 편리함
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

-- 1단계: 각 고객의 첫 구매 월 (기준점) 찾기
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
        -- 월 차이 계산(연도의 개월수 차이 + 실제 월의 차이)
        (EXTRACT(YEAR FROM TO_DATE(order_month, 'YYYY-MM')) - 
         EXTRACT(YEAR FROM TO_DATE(cohort_month, 'YYYY-MM'))) * 12 +
        (EXTRACT(MONTH FROM TO_DATE(order_month, 'YYYY-MM')) - 
         EXTRACT(MONTH FROM TO_DATE(cohort_month, 'YYYY-MM'))) AS month_number
    FROM orders_with_cohort
),

-- 4단계: 코호트별 월별 활성 고객 수 집계(구매 이력이 있는 고객 집, 신규 or 재방문 구분x)
cohort_data AS (
    SELECT 
        cohort_month,
        month_number,
        COUNT(DISTINCT customerid) AS active_customers
    FROM cohort_orders
    GROUP BY cohort_month, month_number
),

-- 5단계: 각 코호트의 초기 고객 수 (첫구매 시점엔 첫코호트월과 첫주문일의 월차이 수가 0)
cohort_size AS (
    SELECT 
        cohort_month,
        active_customers AS cohort_size  --리텐션율 계산시 분모가 됨 
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
