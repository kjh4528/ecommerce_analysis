--(선택사항)
--DROP TABLE IF EXISTS cleaned_data;
--
--테이블 생성
--CREATE TABLE cleaned_data (
--    InvoiceNo VARCHAR(20),
--    StockCode VARCHAR(20),
--    Description TEXT,
--    Quantity INTEGER,
--    InvoiceDate TIMESTAMP,
--    UnitPrice DECIMAL(10, 2),
--    CustomerID VARCHAR(20),
--    Country VARCHAR(100),
--);

-- 파이썬으로 데이터 적재 후 전체 데이터 개수 확인
select count(*) from cleaned_data;
-- 정상적으로 데이터 적재 완료
select * from cleaned_data limit 10;


