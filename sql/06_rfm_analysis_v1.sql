-- =============================================================================
-- RFM 분석_v1
-- 한계: 특정 segment의 비율이 너무 적거나 많은 문제 발견
-- 조정 예정:
-- 1) 분류 기준이 엄격, 기준 완화 필요
-- 2) 세그먼트 기준 세분화 하여 더 명확히 분류하기
-- =============================================================================

-- 분석 과정 코드 

----1단계. 기준일 설정 및 고객별 RFM 원시값 계산
---- 각 고객의 최근 구매일, 구매 횟수, 총 구매 금액을 계산
--
---- 기준일 설정: 데이터의 마지막 날짜 확인
--SELECT MAX(invoicedate) AS max_date
--FROM cleaned_data;
---- 결과를 확인하고 기준일로 사용 (예: 2011-12-09)
--
---- 고객별 RFM 계산
--SELECT 
--    customerid,
--    -- Recency: 기준일로부터 마지막 구매일까지의 일수 (PostgreSQL은 날짜 빼기)
--    DATE '2011-12-09' - MAX(invoicedate::DATE) AS recency_days,
--    
--    -- Frequency: 총 구매 횟수 (InvoiceNo 기준, 취소 주문 제외)
--    COUNT(DISTINCT invoiceno) AS frequency,
--    
--    -- Monetary: 총 구매 금액 (파생 변수 totalprice 활용)
--    SUM(totalprice) AS monetary_value
--FROM 
--    cleaned_data
--WHERE 
--    customerid IS NOT NULL  -- CustomerID가 있는 경우만
--    AND quantity > 0        -- 양수 수량만 (취소 주문 제외)
--    AND unitprice > 0       -- 양수 가격만
--    AND totalprice > 0      -- 총액도 양수
--GROUP BY 
--    customerid
--ORDER BY 
--    monetary_value DESC
--LIMIT 20;  -- 상위 20명만 확인


---- Step 2: RFM 점수 부여 (Quantile 기반 1-5점)
--WITH rfm_raw AS (
--    SELECT 
--        customerid,
--        DATE '2011-12-09' - MAX(invoicedate::DATE) AS recency_days,
--        COUNT(DISTINCT invoiceno) AS frequency,
--        SUM(totalprice) AS monetary_value
--    FROM 
--        cleaned_data
--    WHERE 
--        customerid IS NOT NULL
--        AND quantity > 0
--        AND unitprice > 0
--        AND totalprice > 0
--    GROUP BY 
--        customerid
--)
--SELECT 
--    customerid,
--    recency_days,
--    frequency,
--    monetary_value,
--    
--     R 점수: Recency는 낮을수록 좋으므로 역순 (6 - NTILE)
--    6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,
--    
--     F 점수: Frequency는 높을수록 좋음
--    NTILE(5) OVER (ORDER BY frequency) AS f_score,
--    
--     M 점수: Monetary는 높을수록 좋음
--    NTILE(5) OVER (ORDER BY monetary_value) AS m_score
--FROM 
--    rfm_raw
--ORDER BY 
--    r_score DESC, f_score DESC, m_score DESC
--LIMIT 20;


---- Step 3: RFM 세그먼트 정의
--WITH rfm_raw AS (
--    SELECT 
--        customerid,
--        DATE '2011-12-09' - MAX(invoicedate::DATE) AS recency_days,
--        COUNT(DISTINCT invoiceno) AS frequency,
--        SUM(totalprice) AS monetary_value
--    FROM 
--        cleaned_data
--    WHERE 
--        customerid IS NOT NULL
--        AND quantity > 0
--        AND unitprice > 0
--        AND totalprice > 0
--    GROUP BY 
--        customerid
--),
--rfm_scores AS (
--    SELECT 
--        customerid,
--        recency_days,
--        frequency,
--        monetary_value,
--        6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,
--        NTILE(5) OVER (ORDER BY frequency) AS f_score,
--        NTILE(5) OVER (ORDER BY monetary_value) AS m_score  --ntile은 int
--    FROM 
--        rfm_raw
--)
--SELECT 
--    customerid,
--    recency_days,
--    frequency,
--    ROUND(monetary_value::NUMERIC, 2) AS monetary_value,
--    r_score,
--    f_score,
--    m_score,
--    r_score::text || f_score::text || m_score::text AS rfm_segment,  -- PostgreSQL은 || 로 문자열 연결
--    
--     세그먼트 이름 부여
--    CASE
--         Champions: 최고의 고객
--        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
--        
--         Loyal: 충성 고객 (자주 구매)
--        WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal'
--        
--         Big: 고액 구매자
--        WHEN m_score >= 4 AND f_score >= 2 THEN 'Big'
--        
--         Promising: 잠재력 있는 신규 고객
--        WHEN r_score >= 4 AND f_score <= 2 AND m_score >= 3 THEN 'Promising'
--        
--         New: 신규 고객
--        WHEN r_score >= 4 AND f_score = 1 THEN 'New'
--        
--         Risk: 이탈 위험 (과거 충성 고객이었으나 최근 구매 없음)
--        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'Risk'
--        
--         Hibernating: 휴면 고객
--        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
--        
--         Lost: 이탈 고객
--        WHEN r_score = 1 THEN 'Lost'
--        
--         Others: 기타
--        ELSE 'Others'
--    END AS segment_name
--FROM 
--    rfm_scores
--ORDER BY 
--    r_score DESC, f_score DESC, m_score DESC
--LIMIT 50;


---- Step 4: 세그먼트별 통계 분석
--WITH rfm_raw AS (
--    SELECT 
--        customerid,
--        DATE '2011-12-09' - MAX(invoicedate::DATE) AS recency_days,
--        COUNT(DISTINCT invoiceno) AS frequency,
--        SUM(totalprice) AS monetary_value
--    FROM 
--        cleaned_data
--    WHERE 
--        customerid IS NOT NULL
--        AND quantity > 0
--        AND unitprice > 0
--        AND totalprice > 0
--    GROUP BY 
--        customerid
--),
--rfm_scores AS (
--    SELECT 
--        customerid,
--        recency_days,
--        frequency,
--        monetary_value,
--        6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,
--        NTILE(5) OVER (ORDER BY frequency) AS f_score,
--        NTILE(5) OVER (ORDER BY monetary_value) AS m_score
--    FROM 
--        rfm_raw
--),
--rfm_segments AS (
--    SELECT 
--        customerid,
--        recency_days,
--        frequency,
--        monetary_value,
--        r_score,
--        f_score,
--        m_score,
--        CASE
--            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
--            WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal'
--            WHEN m_score >= 4 AND f_score >= 2 THEN 'Big'
--            WHEN r_score >= 4 AND f_score <= 2 AND m_score >= 3 THEN 'Promising'
--            WHEN r_score >= 4 AND f_score = 1 THEN 'New'
--            WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'Risk'
--            WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
--            WHEN r_score = 1 THEN 'Lost'
--            ELSE 'Others'
--        END AS segment_name
--    FROM 
--        rfm_scores
--)
--SELECT 
--    segment_name,
--    COUNT(*) AS customer_count,
--    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS percentage,
--    ROUND(AVG(recency_days)::NUMERIC, 1) AS avg_recency,
--    ROUND(AVG(frequency)::NUMERIC, 1) AS avg_frequency,
--    ROUND(AVG(monetary_value)::NUMERIC, 2) AS avg_monetary,
--    ROUND(AVG(r_score)::NUMERIC, 2) AS avg_r_score,
--    ROUND(AVG(f_score)::NUMERIC, 2) AS avg_f_score,
--    ROUND(AVG(m_score)::NUMERIC, 2) AS avg_m_score
--FROM 
--    rfm_segments
--GROUP BY 
--    segment_name
--ORDER BY 
--    customer_count DESC;


-- =============================================================================
-- RFM 분석 통합 코드 (뷰 생성하여 조회)
-- =============================================================================

-- 1) 기존 뷰가 있다면 삭제
--DROP VIEW IF EXISTS rfm_customer_segments;
--
-- 2) RFM 세그먼트 뷰 생성
--CREATE VIEW rfm_customer_segments AS
--WITH rfm_raw AS (
--    SELECT 
--        customerid,
--        DATE '2011-12-09' - MAX(invoicedate::DATE) AS recency_days,
--        COUNT(DISTINCT invoiceno) AS frequency,
--        SUM(totalprice) AS monetary_value
--    FROM 
--        cleaned_data
--    WHERE 
--        customerid IS NOT NULL
--        AND quantity > 0
--        AND unitprice > 0
--        AND totalprice > 0
--    GROUP BY 
--        customerid
--),
--rfm_scores AS (
--    SELECT 
--        customerid,
--        recency_days,
--        frequency,
--        monetary_value,
--        6 - NTILE(5) OVER (ORDER BY recency_days) AS r_score,
--        NTILE(5) OVER (ORDER BY frequency) AS f_score,
--        NTILE(5) OVER (ORDER BY monetary_value) AS m_score
--    FROM 
--        rfm_raw
--)
--SELECT 
--    customerid,
--    recency_days,
--    frequency,
--    ROUND(monetary_value::NUMERIC, 2) AS monetary_value,
--    r_score,
--    f_score,
--    m_score,
--    r_score::text || f_score::text || m_score::text AS rfm_segment,
--    CASE
--        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
--        WHEN r_score >= 3 AND f_score >= 4 THEN 'Loyal'
--        WHEN m_score >= 4 AND f_score >= 2 THEN 'Big'
--        WHEN r_score >= 4 AND f_score <= 2 AND m_score >= 3 THEN 'Promising'
--        WHEN r_score >= 4 AND f_score = 1 THEN 'New'
--        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'Risk'
--        WHEN r_score <= 2 AND f_score <= 2 THEN 'Hibernating'
--        WHEN r_score = 1 THEN 'Lost'
--        ELSE 'Others'
--    END AS segment_name
--FROM 
--    rfm_scores;

-- 3) 뷰 확인: 전체 고객 세그먼트 조회
SELECT * FROM rfm_customer_segments
ORDER BY monetary_value DESC
LIMIT 100;

-- 4) 세그먼트별 요약 통계 뷰 만들기
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
FROM 
    rfm_customer_segments
GROUP BY 
    segment_name
ORDER BY 
    total_revenue DESC;

-- 5) Champions 세그먼트 상세 조회 (VIP 고객 리스트)
SELECT 
    customerid,
    recency_days,
    frequency,
    monetary_value,
    rfm_segment
FROM 
    rfm_customer_segments
WHERE 
    segment_name = 'Champions'
ORDER BY 
    monetary_value DESC;

-- 6) Risk 세그먼트 조회 (재구매 유도 타겟)
SELECT 
    customerid,
    recency_days,
    frequency,
    monetary_value,
    rfm_segment
FROM 
    rfm_customer_segments
WHERE 
    segment_name = 'Risk'
ORDER BY 
    monetary_value DESC;