-- =============================================================================
-- RFM 분석_v2 (개선 버전)
-- 한계: 특정 segment의 비율이 너무 적거나 많은 문제 발견
-- 조정 사항:
-- 1) Others 너무 많음(전체의 21.53%) -> 세그먼트 기준 세분화 :더 명확한 분류 필요
-- 2) Big의 높은 Recency(102.5일) ->At Risk로 재분류	:R≤2인 고액 고객은 이탈 위험
-- 3) Promising 너무 적음(0.69%) -> 기준 완화 :M≥2로 낮춤
-- =============================================================================

-- =============================================================================
-- RFM 분석 개선 버전 (데이터 특성 반영)
-- =============================================================================


--CREATE VIEW rfm_customer_segments_v2 AS
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
--        -- Champions: 최고의 고객 (모든 지표 최상위)
--        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 
--            THEN 'Champions'
--        
--        -- Loyal: 충성 고객 (자주 구매, 최근 활동)
--        WHEN r_score >= 3 AND f_score >= 4 
--            THEN 'Loyal'
--        
--        -- Big : 고액 구매자 (단, 최근 활동 있어야 함)
--        -- 변경: Recency 조건 추가 (R >= 3)
--        WHEN r_score >= 3 AND m_score >= 4 AND f_score >= 2 
--            THEN 'Big'
--        
--        -- Risk: 이탈 위험 (과거 좋은 고객 + 최근 구매 없음)
--        -- 변경: Big 중 r_score 낮은 고객 포함
--        WHEN r_score <= 2 AND (f_score >= 3 OR m_score >= 4)
--            THEN 'Risk'
--        
--        -- Promising: 유망 신규 (최근 가입 + 구매력)
--        -- 변경: m_score >= 2로 완화
--        WHEN r_score >= 4 AND f_score <= 2 AND m_score >= 2 
--            THEN 'Promising'
--        
--        -- New: 신규 고객 (첫 구매)
--        WHEN r_score >= 4 AND f_score = 1 
--            THEN 'New'
--        
--        -- Need Attention: 관심 필요 (중간 단계)
--        -- 신규 세그먼트: Others를 세분화
--        WHEN r_score = 3 AND f_score >= 2 AND m_score >= 2
--            THEN 'Need Attention'
--        
--        -- Hibernating: 휴면 고객 (오래전 + 적게 구매)
--        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2
--            THEN 'Hibernating'
--        
--        -- Lost: 이탈 고객 (장기간 구매 없음)
--        WHEN r_score = 1 AND recency_days >= 200
--            THEN 'Lost'
--        
--        -- Others: 기타 (나머지)
--        ELSE 'Others'
--    END AS segment_name
--FROM 
--    rfm_scores;

-- 개선 결과 확인 및 뷰 생성
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
FROM 
    rfm_customer_segments_v2
GROUP BY 
    segment_name
ORDER BY 
    total_revenue DESC;
