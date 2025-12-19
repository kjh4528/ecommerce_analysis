\# 세그먼트별 상품 선호도 분석 (Segment Product Preference Analysis)



\## 1. 분석 개요



\### 1.1 분석 목적

RFM 분석을 통해 도출된 고객 세그먼트별로 선호하는 상품 및 카테고리 패턴을 분석하여,

타겟 마케팅, 상품 추천, MD 및 재고 전략 수립에 활용한다.



\### 1.2 핵심 분석 질문

\- 각 RFM 세그먼트는 어떤 상품 카테고리를 선호하는가?

\- VIP(Champions) 고객과 신규(New) 고객의 구매 패턴은 어떻게 다른가?

\- 세그먼트별 구매 빈도, 객단가, 카테고리 다양성은 어떻게 다른가?



\### 1.3 기대 효과

\- 세그먼트별 맞춤형 상품 추천 전략 수립

\- 타겟 프로모션 및 캠페인 기획

\- 세그먼트 기반 재고·MD 전략 최적화



---



\## 2. 분석 프로세스



\### Step 1. SQL 뷰 준비 및 데이터 로드



기존 RFM 분석 결과를 기반으로 세그먼트별 구매 데이터를 집계하였다.



\#### 기존 뷰

\- `rfm\_customer\_segments\_v2` : 고객별 RFM 세그먼트 정보

\- `rfm\_summary\_v2` : 세그먼트별 요약 통계



\#### 추가 생성 뷰

\- `segment\_product\_purchases`  

&nbsp; : 세그먼트별 상품 구매 상세 내역 (메인 분석 테이블)

\- `segment\_product\_summary`  

&nbsp; : 세그먼트 × 상품 단위 요약

\- `champions\_vs\_new\_products`  

&nbsp; : VIP(Champions) vs 신규 고객 구매 비교

\- `segment\_top\_products`  

&nbsp; : 세그먼트별 상위 상품 TOP N

\- `segment\_purchase\_patterns`  

&nbsp; : 세그먼트별 구매 패턴 요약 (빈도, 금액, 다양성 등)



> 본 분석에서는 SQL에서 집계 및 정합성을 확보한 후,

> Python에서 탐색적 분석 및 시각화를 수행하였다.



---



\### Step 2. Python 환경 설정

\- pandas, numpy

\- matplotlib, seaborn

\- dotenv / sqlalchemy (DB 연결)



---



\### Step 3. 세그먼트별 상품 선호도 분석



\#### 주요 분석 항목

1\. 세그먼트별 구매 카테고리 분포

2\. 세그먼트별 TOP 카테고리 및 상품

3\. 카테고리별 구매 빈도 및 구매 금액

4\. 세그먼트 간 선호도 차이 시각화



\#### 사용 지표

\- \*\*카테고리별 구매 비중\*\*

\- \*\*평균 구매 금액\*\*

\- \*\*구매 빈도\*\*

\- \*\*선호도 지수\*\*

&nbsp; - (세그먼트 내 특정 카테고리 구매 비중)  

&nbsp;   ÷ (전체 고객의 해당 카테고리 구매 비중)



---



\### Step 4. VIP(Champions) vs 신규(New) 고객 비교



\#### 비교 목적

\- 충성 고객과 신규 고객의 소비 성향 차이를 정량적으로 파악



\#### 비교 지표

\- 카테고리 다양성 (구매한 카테고리 수)

\- 객단가 (1회 구매당 평균 금액)

\- 구매 빈도

\- 프리미엄 상품 구매 비중



---



\### Step 5. 시각화 산출물



\- `spa\_segment\_purchase\_patterns.png`  

&nbsp; : 세그먼트별 구매 패턴 비교

\- `spa\_champions\_vs\_new\_comparison.png`  

&nbsp; : Champions vs New 주요 지표 비교

\- `spa\_champions\_vs\_new\_top\_products.png`  

&nbsp; : 두 그룹의 TOP 10 상품

\- `spa\_segment\_top5\_products.png`  

&nbsp; : 주요 세그먼트별 TOP 5 상품

\- `spa\_segment\_product\_heatmap.png`  

&nbsp; : 세그먼트 × 상품/카테고리 히트맵



---



\### Step 6. 인사이트 도출 및 비즈니스 활용

분석 결과를 바탕으로 세그먼트별 차별화된

상품 추천, 프로모션, MD 전략을 도출한다.



