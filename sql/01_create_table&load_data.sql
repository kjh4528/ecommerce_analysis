-- 테이블이 이미 있으면 삭제 (선택사항)
--DROP TABLE IF EXISTS cleaned_data;
--
-- 테이블 생성
--CREATE TABLE cleaned_data (
--    InvoiceNo VARCHAR(20),
--    StockCode VARCHAR(20),
--    Description TEXT,
--    Quantity INTEGER,
--    InvoiceDate TIMESTAMP,
--    UnitPrice DECIMAL(10, 2),
--    CustomerID VARCHAR(20),
--    Country VARCHAR(100),
--    TotalPrice DECIMAL(10, 2),
--    Year INTEGER,
--    Month INTEGER,
--    YearMonth VARCHAR(7),
--    DayOfWeek INTEGER,
--    Hour INTEGER
--);

-- 파이썬으로 데이터 적재 후 전체 데이터 개수 확인
select count(*) from cleaned_data;

select * from cleaned_data limit 10;

-- 정상적으로 데이터 적재되었으나
-- 테이블 생성시 원본 데이터에 없는 파생변수 컬럼을 만들어서 파생 변수 컬럼들에 널값이 들어감

-- 일단 원본만 남기기 (파생변후 컬럼 제거)
--ALTER TABLE cleaned_data 
--    DROP COLUMN totalprice,
--    DROP COLUMN year,
--    DROP COLUMN month,
--    DROP COLUMN yearmonth,
--    DROP COLUMN dayofweek,
--    DROP COLUMN hour;

