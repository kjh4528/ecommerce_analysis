
-- 이상치, 결측치 조회 

-- 0이 아니면 널 처리 안함 -> 처리 안함
--SELECT COUNT(*) FROM cleaned_data WHERE customerid IS NULL;

-- 동일 InvoiceNo, StockCode 중복 체크 -> 동일 일보이스에 동일 코드 존재
--SELECT invoiceno, stockcode, COUNT(*)
--FROM cleaned_data
--GROUP BY invoiceno, stockcode
--HAVING COUNT(*) > 1;

-- 분석 대상 기간 확인 -> 2010.12 ~2011.12(373일)
--SELECT 
--    MIN(invoicedate) AS start_date,
--    MAX(invoicedate) AS end_date,
--    MAX(invoicedate) - MIN(invoicedate) AS date_range
--FROM cleaned_data;

-- 취소주문 제거 안함(음수 수량)
--SELECT COUNT(*) FROM cleaned_data WHERE quantity < 0;

-- 너무 비싸거나 싼 상품 -> 금액이 0인 제품들(description이 널,check,damaged,missing 등이 많음)
--SELECT stockcode, description, unitprice
--FROM cleaned_data
--WHERE unitprice > 1000 OR unitprice < 0.01
--GROUP BY stockcode, description, unitprice;



---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--참고: 파생변수 테이블에 추가 or view 생성 등 방법 
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

--방법 1: 파생변수 테이블에 추가(재사용 가능, 쿼리속도 빠름,데이터 수정시 파생변수도 업데이트 필요)
-- 자주 쓰는 파생변수를 테이블에 영구 추가
--ALTER TABLE cleaned_data 
--    ADD COLUMN totalprice DECIMAL(10, 2),
--    ADD COLUMN year INTEGER,
--    ADD COLUMN month INTEGER,
--    ADD COLUMN yearmonth VARCHAR(7),
--    ADD COLUMN dayofweek INTEGER,
--    ADD COLUMN hour INTEGER;
--
---- 데이터 업데이트
--UPDATE cleaned_data
--SET 
--    totalprice = quantity * unitprice,
--    year = EXTRACT(YEAR FROM invoicedate),
--    month = EXTRACT(MONTH FROM invoicedate),
--    yearmonth = TO_CHAR(invoicedate, 'YYYY-MM'),
--    dayofweek = EXTRACT(DOW FROM invoicedate),
--    hour = EXTRACT(HOUR FROM invoicedate);
--
---- 인덱스 추가 (성능 향상)
--CREATE INDEX idx_customerid ON cleaned_data(customerid);
--CREATE INDEX idx_invoicedate ON cleaned_data(invoicedate);
--CREATE INDEX idx_yearmonth ON cleaned_data(yearmonth);
--
--
-------------------------------------------------------------
----방법2: view 생성(원본 보존, 매번 계산해서 속도 느림, 인덱스 사용 불가)
---- 파생변수가 포함된 뷰 생성
--CREATE OR REPLACE VIEW vw_cleaned_data_enhanced AS
--SELECT 
--    *,
--    quantity * unitprice AS totalprice,
--    EXTRACT(YEAR FROM invoicedate) AS year,
--    EXTRACT(MONTH FROM invoicedate) AS month,
--    TO_CHAR(invoicedate, 'YYYY-MM') AS yearmonth,
--    EXTRACT(DOW FROM invoicedate) AS dayofweek,
--    EXTRACT(HOUR FROM invoicedate) AS hour
--FROM cleaned_data;
--
---- 이후 분석에서는 뷰 사용
--SELECT * FROM vw_cleaned_data_enhanced LIMIT 10;
--
----------------------------------------------------------------
----방법 3: MATERIALIZED VIEW(대용량용, view처럼 사용하나 속도는 빠름, 인덱스 사용 가능, 원본 변경시 수동 refresh 필요)
---- 물리적으로 저장되는 뷰
--CREATE MATERIALIZED VIEW mv_cleaned_data_enhanced AS
--SELECT 
--    *,
--    quantity * unitprice AS totalprice,
--    EXTRACT(YEAR FROM invoicedate) AS year,
--    EXTRACT(MONTH FROM invoicedate) AS month,
--    TO_CHAR(invoicedate, 'YYYY-MM') AS yearmonth,
--    EXTRACT(DOW FROM invoicedate) AS dayofweek,
--    EXTRACT(HOUR FROM invoicedate) AS hour
--FROM cleaned_data;
--
---- 인덱스 추가 가능
--CREATE INDEX idx_mv_customerid ON mv_cleaned_data_enhanced(customerid);
--CREATE INDEX idx_mv_yearmonth ON mv_cleaned_data_enhanced(yearmonth);
--
---- 데이터 갱신 필요 시
--REFRESH MATERIALIZED VIEW mv_cleaned_data_enhanced;