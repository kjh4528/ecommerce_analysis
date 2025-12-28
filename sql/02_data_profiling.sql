
-- 이상치, 결측치 조회 
-- 무조건 삭제하기 보단 최대한 원본 데이터 유지하고 각 분석에서 필요에 따라 처리
--------------------------------------------------------------------------

--1) 'customerid' 고객번호가 널값인 데이터 조회
--SELECT COUNT(*) FROM cleaned_data WHERE customerid IS NULL;
--널값 135,077건 발견 -> 고객번호가 없는 주문은 비회원 주문으로 가정하여 삭제하지 않았음

--2) 동일 InvoiceNo, StockCode 중복 체크 
--SELECT invoiceno, stockcode, COUNT(*)
--FROM cleaned_data
--GROUP BY invoiceno, stockcode
--HAVING COUNT(*) > 1;

--3) 분석 대상 기간 확인 -> 2010.12 ~2011.12(373일)
--SELECT 
--    MIN(invoicedate) AS start_date,
--    MAX(invoicedate) AS end_date,
--    MAX(invoicedate) - MIN(invoicedate) AS date_range
--FROM cleaned_data;

--4) 음수 수량 조회 -> 취소나 반품 주문으로 가정하여 삭제하지 않음 
--SELECT COUNT(*) FROM cleaned_data WHERE quantity < 0;

--5) 너무 비싸거나 싼 상품 확인 -> 금액이 0인 제품들(description이 널,check,damaged,missing 등)이 많았음
--SELECT stockcode, description, unitprice
--FROM cleaned_data
--WHERE unitprice > 1000 OR unitprice < 0.01
--GROUP BY stockcode, description, unitprice;


---------------------------------------------------------------------------------
---------------------------------------------------------------------------------
-- 총구매금액, 연, 월 등 분석에 자주 사용할 파생변수 추가 예정 -> 04.sql 파일 확인
-- 테이블에 추가할지 뷰를 생성하여 관리할지 방법 찾아보기
-- 최종 결정: 방법 1 
-- 이유: 데이터 규모도 작고, 파생변수의 계산 복잡도도 낮아서 원본 테이블 자체를 분석하기 좋게 개조하는 방법이 훨씬 경제적이고 효율적
-- 인덱스가 있으면 해당 월을 바로 조회할 수 있고 분석용 데이터라면 보통 한 번 적재 후 조회만 함
---------------------------------------------------------------------------------
---------------------------------------------------------------------------------

--방법 1: 파생변수를 원본 테이블에 영구 추가
--특징: 재사용 가능, 쿼리속도 빠름,데이터 수정시 파생변수도 업데이트 필요(나의 경우 데이터 수정할 일 없음) 
--방법 1 사용시 예시:
--ALTER TABLE cleaned_data 
--    ADD COLUMN totalprice DECIMAL(10, 2);

---- 데이터 업데이트
--UPDATE cleaned_data
--SET 
--    totalprice = quantity * unitprice;

---- 인덱스 추가 (성능 향상)
--CREATE INDEX idx_customerid ON cleaned_data(customerid);
--
-------------------------------------------------------------
--방법2: 파생변수가 포함된 view 생성
--특징: 원본 보존, 매번 계산해서 속도 느림, 인덱스 사용 불가
--CREATE OR REPLACE VIEW vw_cleaned_data_enhanced AS
--SELECT 
--    *,
--    quantity * unitprice AS totalprice
--FROM cleaned_data;

---- 이후 분석에서는 뷰 사용
--SELECT * FROM vw_cleaned_data_enhanced LIMIT 10;
--
----------------------------------------------------------------
--방법 3: MATERIALIZED VIEW
--특징: 대용량 데이터에서 유리, view처럼 사용하나 속도는 빠름, 인덱스 사용 가능, 원본 변경시 수동 refresh 필요
--물리적으로 저장되는 뷰 (복사본 개념, 데이터 중복과 저장공간 차지)
--> 용량을 더 사용하더라도 원본의 안정성은 유지하면서 빠른 조회속도가 필요할때 사용
--CREATE MATERIALIZED VIEW mv_cleaned_data_enhanced AS
--SELECT 
--    *,
--    quantity * unitprice AS totalprice
--FROM cleaned_data;
--
---- 인덱스 추가 가능
--CREATE INDEX idx_mv_customerid ON mv_cleaned_data_enhanced(customerid);
--
---- 데이터 갱신 필요 시
--REFRESH MATERIALIZED VIEW mv_cleaned_data_enhanced;
