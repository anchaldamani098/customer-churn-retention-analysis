CREATE DATABASE churn_project;
USE churn_project;

CREATE TABLE online_retail_II_Raw_data (
    InvoiceNo VARCHAR(20),
    StockCode VARCHAR(20),
    Description VARCHAR(255),
    Quantity INT,
    InvoiceDate VARCHAR(30),
    Price DECIMAL(10,2),
    CustomerID INT,
    Country VARCHAR(50)
);

SHOW GLOBAL VARIABLES LIKE 'local_infile';
SET GLOBAL local_infile = 1;

LOAD DATA LOCAL INFILE 'C:/Users/hp/Downloads/archive (7)/online_retail_II_Raw_data.csv'
INTO TABLE online_retail_II_Raw_data
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

SELECT COUNT(*) FROM online_retail_II_Raw_data;

-- Missing Customer ID check
SELECT COUNT(*) FROM online_retail_II_Raw_data WHERE CustomerID = 0 OR CustomerID IS NULL;

-- Cancelled orders check
SELECT COUNT(*) FROM online_retail_II_Raw_data WHERE InvoiceNo LIKE 'C%';

-- Negative or zero price check
SELECT COUNT(*) FROM online_retail_II_Raw_data WHERE Price <= 0;

-- Count rows where quantity is zero or negative
SELECT COUNT(*) FROM online_retail_II_Raw_data WHERE Quantity <= 0;

-- Duplicate check
SELECT InvoiceNo, StockCode, CustomerID, COUNT(*) 
FROM online_retail_II_Raw_data
GROUP BY InvoiceNo, StockCode, CustomerID
HAVING COUNT(*) > 1;

-- Create Total Amount column (view ya new table)
SELECT *, (Quantity * Price) AS Total_Amount
FROM online_retail_II_Raw_data;

DESCRIBE online_retail_II_Raw_data;

-- Create a new table with only valid (genuine) transactions
CREATE TABLE valid_transactions AS
SELECT * FROM online_retail_II_Raw_data 
WHERE InvoiceNo NOT LIKE 'C%' 
AND CustomerID IS NOT NULL 
AND Price > 0
AND Quantity > 0;

-- Check how many rows remain in the new table
SELECT COUNT(*) FROM valid_transactions;

-- Find the last (most recent) date in the dataset
SELECT MAX(InvoiceDate) FROM valid_transactions;

-- Create a table with Recency, Frequency, and Monetary value for each customer
-- table updated after 86 number in this query first drop previous table then updated
CREATE TABLE customer_rfm AS
SELECT 
    CustomerID,
    DATEDIFF((SELECT MAX(InvoiceDate) FROM valid_transactions), MAX(InvoiceDate)) AS Recency,
    COUNT(DISTINCT InvoiceNo) AS Frequency,
    SUM(Quantity * Price) AS Monetary
FROM valid_transactions
WHERE CustomerID != 0
GROUP BY CustomerID;

-- Check the table
SELECT * FROM customer_rfm LIMIT 20;

-- Check if CustomerID 0 exists in valid_transactions table
SELECT COUNT(*) FROM valid_transactions WHERE CustomerID = 0;

SET SQL_SAFE_UPDATES = 0;

-- Remove rows where CustomerID is 0 (these were originally blank/missing)
DELETE FROM valid_transactions WHERE CustomerID = 0;

-- See min, max, and average recency across all customers
SELECT 
    MIN(Recency) AS Min_Recency,
    MAX(Recency) AS Max_Recency,
    AVG(Recency) AS Avg_Recency
FROM customer_rfm;

-- See how many customers fall into different recency buckets
SELECT 
    CASE 
        WHEN Recency <= 30 THEN '0-30 days'
        WHEN Recency <= 60 THEN '31-60 days'
        WHEN Recency <= 90 THEN '61-90 days'
        WHEN Recency <= 180 THEN '91-180 days'
        ELSE '180+ days'
    END AS Recency_Bucket,
    COUNT(*) AS Num_Customers
FROM customer_rfm
GROUP BY Recency_Bucket
ORDER BY MIN(Recency);

-- Add a churn status column based on the 90-day threshold
ALTER TABLE customer_rfm ADD COLUMN Churn_Status VARCHAR(20);

UPDATE customer_rfm
SET Churn_Status = CASE 
    WHEN Recency > 90 THEN 'Churned'
    ELSE 'Active'
END;

-- Check overall churn rate
SELECT 
    Churn_Status, 
    COUNT(*) AS Num_Customers,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM customer_rfm), 2) AS Percentage
FROM customer_rfm
GROUP BY Churn_Status;

-- Add scoring columns using NTILE (splits customers into 4 equal groups)
ALTER TABLE customer_rfm ADD COLUMN R_Score INT;
ALTER TABLE customer_rfm ADD COLUMN F_Score INT;
ALTER TABLE customer_rfm ADD COLUMN M_Score INT;

-- Recency score: lower recency (recent buyer) = higher score
UPDATE customer_rfm c
JOIN (
    SELECT CustomerID, 
    5 - NTILE(4) OVER (ORDER BY Recency) AS score
    FROM customer_rfm
) t ON c.CustomerID = t.CustomerID
SET c.R_Score = t.score;

-- Frequency score: higher frequency = higher score
UPDATE customer_rfm c
JOIN (
    SELECT CustomerID, 
    NTILE(4) OVER (ORDER BY Frequency) AS score
    FROM customer_rfm
) t ON c.CustomerID = t.CustomerID
SET c.F_Score = t.score;

-- Monetary score: higher spend = higher score
UPDATE customer_rfm c
JOIN (
    SELECT CustomerID, 
    NTILE(4) OVER (ORDER BY Monetary) AS score
    FROM customer_rfm
) t ON c.CustomerID = t.CustomerID
SET c.M_Score = t.score;

-- Add a combined score column
ALTER TABLE customer_rfm ADD COLUMN RFM_Score INT;

UPDATE customer_rfm
SET RFM_Score = R_Score + F_Score + M_Score;

-- Add a segment name column
ALTER TABLE customer_rfm ADD COLUMN Segment VARCHAR(30);

UPDATE customer_rfm
SET Segment = CASE
    WHEN R_Score >= 4 AND F_Score >= 4 AND M_Score >= 4 THEN 'Champions'
    WHEN R_Score >= 3 AND F_Score >= 3 THEN 'Loyal Customers'
    WHEN R_Score >= 4 AND F_Score <= 2 THEN 'New Customers'
    WHEN R_Score <= 2 AND F_Score >= 3 THEN 'At Risk'
    WHEN R_Score <= 2 AND F_Score <= 2 AND M_Score <= 2 THEN 'Lost'
    ELSE 'Others'
END;

SELECT * FROM customer_rfm;

drop churn_project;

-- See how many customers fall into each segment
SELECT Segment, COUNT(*) AS Num_Customers,
ROUND(AVG(Monetary),2) AS Avg_Spend
FROM customer_rfm
GROUP BY Segment
ORDER BY Num_Customers DESC;

-- Potential revenue at risk from the "At Risk" segment
SELECT 
    Segment,
    COUNT(*) AS Num_Customers,
    SUM(Monetary) AS Total_Revenue_From_Segment
FROM customer_rfm
GROUP BY Segment
ORDER BY Total_Revenue_From_Segment DESC;

-- Churn rate by country
SELECT 
    o.Country,
    c.Churn_Status,
    COUNT(DISTINCT c.CustomerID) AS Num_Customers
FROM customer_rfm c
JOIN valid_transactions o ON c.CustomerID = o.CustomerID
GROUP BY o.Country, c.Churn_Status
ORDER BY o.Country, c.Churn_Status;

-- Get each customer's most frequent country
CREATE TABLE customer_country AS
SELECT CustomerID, Country
FROM (
    SELECT CustomerID, Country, 
    COUNT(*) AS cnt,
    ROW_NUMBER() OVER (PARTITION BY CustomerID ORDER BY COUNT(*) DESC) AS rn
    FROM valid_transactions
    GROUP BY CustomerID, Country
) t
WHERE rn = 1;

-- Now analyze churn by country properly
SELECT 
    cc.Country,
    c.Churn_Status,
    COUNT(*) AS Num_Customers
FROM customer_rfm c
JOIN customer_country cc ON c.CustomerID = cc.CustomerID
GROUP BY cc.Country, c.Churn_Status
ORDER BY cc.Country;

-- Monthly order trend over time
SELECT 
    DATE_FORMAT(InvoiceDate, '%Y-%m') AS Month,
    COUNT(DISTINCT InvoiceNo) AS Num_Orders,
    COUNT(DISTINCT CustomerID) AS Num_Customers,
    SUM(Quantity * Price) AS Revenue
FROM valid_transactions
GROUP BY Month
ORDER BY Month;

-- Export customer_rfm table results (right-click on result grid → Export)
SELECT * FROM customer_rfm;

SELECT 
    v.Description,
    c.Churn_Status,
    COUNT(*) AS Times_Purchased,
    SUM(v.Quantity) AS Total_Quantity
FROM valid_transactions v
JOIN customer_rfm c ON v.CustomerID = c.CustomerID
GROUP BY v.Description, c.Churn_Status
ORDER BY Times_Purchased DESC
LIMIT 50;