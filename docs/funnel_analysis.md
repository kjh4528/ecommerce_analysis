# Funnel Analysis


## 1. 퍼널 분석 개요

퍼널 분석(Funnel Analysis)은 고객이 특정 목표(구매, 가입 등)에 도달하기까지  

거치는 **단계별 전환율과 이탈률을 분석**하는 방법

이를 통해:

- 어느 단계에서 고객 이탈이 가장 많이 발생하는지 확인

- 이탈률이 높은 단계를 우선적으로 개선할 수 있다





## 2. Online Retail 데이터 특징과 퍼널 정의



### 데이터 특징: 최종 구매 데이터

- 방문, 조회, 장바구니 등 **중간 행동 데이터 부재**

- 고객의 **구매 이력만 존재**

따라서 구매 횟수를 기준으로 퍼널을 재정의하였다.



### 퍼널 단계 정의

1. **First Purchase**  

&nbsp;  → 첫 구매 고객 (신규 유입)

2. **Second Purchase**  

&nbsp;  → 2회 구매 고객 (재구매 성공)

3. **Regular Customer**  

&nbsp;  → 3회 이상 구매 고객

4. **Loyal Customer (VIP)**  

&nbsp;  → RFM 기준 상위 20% 고객


---



## 3. 분석 프로세스 및 산출물



### 1) SQL 분석

- 단계별 고객 수 집계

- 단계 간 전환율 / 이탈률 계산

**산출물**

- `08_funnel_analysis.sql`






### 2) Python 시각화

- SQL View를 Python에서 로드하여 시각화

**산출물**

- `06_funnel_visualization.ipynb`



### 생성된 시각화 결과물

1. **01_funnel_overview.png**  

&nbsp;  - 전체 퍼널 깔때기 + 전환율/이탈률 바 차트

2. **02_segment_stage_heatmap.png**  

&nbsp;  - 세그먼트별 구매 단계 분포 히트맵

3. **03_segment_conversion_comparison.png**  

&nbsp;  - 주요 세그먼트 전환율 비교 (Risk 이탈 시점 강조)

4. **04_segment_stacked_with_risk.png**  

&nbsp;  - 누적 막대 + Risk 전환 흐름 강조

5. **05_stage_segment_composition.png**  

&nbsp;  - 각 단계별 세그먼트 구성 비율

6. **06_funnel_dashboard.png**  

&nbsp;  - 주요 차트 종합 대시보드







### 주요 시각화 기능

- **깔때기 차트**: 고객 수 감소 흐름 직관적 표현

- **전환율 화살표**: 단계 간 전환/이탈 명확화

- **히트맵**: 세그먼트-단계 분포 한눈에 파악

- **Risk 세그먼트 강조**: 이탈 위험 구간 시각적 강조

- **Stacked Bar**: 단계별 세그먼트 구성 비교




---



## 4. 전체 퍼널 전환율 분석 결과

| 단계 | 고객 수 | 비중 |
|----|----|----|
| First Purchase | 1,493명 | 34.42% |
| Second Purchase | 835명 | 19.25% |
| Regular Customer | 896명 | 20.65% |
| Loyal Customer | 1,114명 | 25.68% |


### 단계별 전환율

- First → Second: **55.93%** (이탈 44.07%)
- Second → Regular: **107.31%**
- Regular → Loyal: **124.33%**







## 5. 퍼널 해석



### ① 재구매 장벽이 가장 큼

- 첫 구매 고객의 **44% 이탈**

- 가장 큰 병목 구간은 **1회 → 2회 구매**

- **액션**: 첫 구매 후 30일 이내 리텐션 캠페인 필수



### ② 2회 구매가 터닝 포인트 

- 2회 구매 이후 빠르게 충성 고객으로 성장

- “2회 구매 경험”이 습관 형성의 시작



### ③ Regular → Loyal 전환 우수

- 구매 패턴이 자리 잡으면 충성 고객으로 빠르게 이동



---



## 6. 퍼널 단계별 주요 세그먼트

| 구매 단계 | 주요 세그먼트 |
|----|----|
| First Purchase | New, Promising, Hibernating, Lost |
| Second Purchase | Promising, Risk, Need Attention |
| Regular Customer | Loyal, Risk, Big |
| Loyal Customer | Champions, Loyal |






## 7. 세그먼트별 핵심 인사이트


### Champions

- 평균 12.68회 구매, £6,924 지출

- 이미 충성도 확보

- **전략**: VIP 혜택 유지, 신제품 우선 제공


### Loyal

- Regular → Loyal 전환율 **85.94%**

- Champions 후보군

- **전략**: 승급 프로모션 운영


###  Risk

- 3 → 4단계 전환율 **37.5%**

- 충성 고객 전환 직전 이탈 위험

- **전략**: 재구매 쿠폰, 리마케팅 집중



### Hibernating

- 대부분 1회 구매 후 이탈

- 평균 지출 낮음

- **전략**: 할인 기반 재활성화



### Promising

- 첫 구매 금액 높음

- 육성 가치 높음

- **전략**: 2회 구매 유도 집중



### Big

- 구매 횟수는 적으나 객단가 매우 높음

- **전략**: 고가 상품 추천, 프리미엄 서비스


---


## 8. 전략적 제안
 

### **우선순위 1: 첫 구매 → 재구매 전환율 개선** 
- 44% 이탈률을 30%로 줄이는 게 최우선 

### **우선순위 2: Risk 세그먼트 이탈 방지** 
- 3-4회 구매 고객 중 Risk 세그먼트 집중 관리 


### **우선순위 3: Promising → Loyal 육성** 
- 첫 구매 금액 높은 고객은 잠재력 높음 



