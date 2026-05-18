--- STEP 1: Append all montly sales table together
CREATE OR REPLACE TABLE `rfm2028.sales.sales2025` AS 
SELECT * FROM `rfm2028.sales.202501` 
UNION ALL SELECT * FROM `rfm2028.sales.202502` 
UNION ALL SELECT * FROM `rfm2028.sales.202503` 
UNION ALL SELECT * FROM `rfm2028.sales.202504` 
UNION ALL SELECT * FROM `rfm2028.sales.202505` 
UNION ALL SELECT * FROM `rfm2028.sales.202506` 
UNION ALL SELECT * FROM `rfm2028.sales.202507` 
UNION ALL SELECT * FROM `rfm2028.sales.202508` 
UNION ALL SELECT * FROM `rfm2028.sales.202509` 
UNION ALL SELECT * FROM `rfm2028.sales.202510` 
UNION ALL SELECT * FROM `rfm2028.sales.202511` 
UNION ALL SELECT * FROM `rfm2028.sales.202512`; 

---STEP 2: Calculate recency frequency, monetary, r, f, m ranks
---Combine views with CTEs

CREATE OR REPLACE VIEW `rfm2028.sales.rfm_metrics` AS 
WITH current_date AS (
  SELECT DATE ('2026-03-06') AS analysis_date
),
rfm AS(
  SELECT
    CustomerID,
    MAX(OrderDate) AS last_order_date,
    date_diff((SELECT analysis_date FROM current_date), MAX(OrderDate), DAY) AS recency,
    COUNT(*) AS frequency,
    SUM(OrderValue) AS monetary,
  FROM `rfm2028.sales.sales2025`
  GROUP BY CustomerID
)
SELECT 
  rfm. *,
  ROW_NUMBER() OVER(ORDER BY recency ASC) AS r_rank,
  ROW_NUMBER() OVER(ORDER BY frequency DESC) AS f_rank,
  ROW_NUMBER() OVER(ORDER BY monetary DESC) AS m_rank,
FROM rfm;


---STEP 3: Assign deciles(10=best, 1=worst)

CREATE OR REPLACE VIEW `rfm2028.sales.rfm_scores`
AS
SELECT 
  *,
  NTILE(10) OVER(ORDER BY r_rank DESC) AS r_score,
  NTILE(10) OVER(ORDER BY f_rank DESC) AS f_score,
  NTILE(10) OVER(ORDER BY m_rank DESC) AS m_score,

FROM `rfm2028.sales.rfm_metrics`;

---STEP 4: Total Score

CREATE OR REPLACE VIEW `rfm2028.sales.rfm_total_scores`
AS
SELECT 
  CustomerID,
  recency,
  frequency,
  monetary,
  r_score,
  f_score,
  m_score,
  (r_score + f_score + m_score) AS rfm_total_score,
FROM `rfm2028.sales.rfm_scores`
ORDER BY rfm_total_score DESC;

---STEP 5: BI ready rfm segments table

CREATE OR REPLACE TABLE `rfm2028.sales.rfm_segments_final`
AS
SELECT
  CustomerID,
  recency,
  frequency, 
  monetary,
  r_score,
  f_score,
  m_score,
  rfm_total_score,
  CASE
    WHEN rfm_total_score >= 28 THEN 'Champions' --28-30
    WHEN rfm_total_score >= 24 THEN 'Loyal VIPs'
    WHEN rfm_total_score >= 20 THEN 'Potential Loyalists'
    WHEN rfm_total_score >= 16 THEN 'Promising'
    WHEN rfm_total_score >= 12 THEN 'Engaged'
    WHEN rfm_total_score >= 8 THEN 'Requires Attention'
    WHEN rfm_total_score >= 4 THEN 'At Risk'
    ELSE 'Lost/Inactive'
  END AS rfm_segment
FROM `rfm2028.sales.rfm_total_scores`
ORDER BY rfm_total_score DESC;

