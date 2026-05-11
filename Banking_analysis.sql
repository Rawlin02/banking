USE banking_analysis;

-- ============================================================
-- STAGE 1: PRE-PROCESSING
-- ============================================================

-- row count vs unique clients (duplicate check)
SELECT
    COUNT(*)                  AS Total_Rows,
    COUNT(DISTINCT Client_ID) AS Unique_Clients
FROM banking;

-- -------------------------------------------------------

-- null check across all columns
SELECT
    SUM(CASE WHEN Client_ID                IS NULL THEN 1 ELSE 0 END) AS Client_ID_Nulls,
    SUM(CASE WHEN Name                     IS NULL THEN 1 ELSE 0 END) AS Name_Nulls,
    SUM(CASE WHEN Age                      IS NULL THEN 1 ELSE 0 END) AS Age_Nulls,
    SUM(CASE WHEN Location_ID              IS NULL THEN 1 ELSE 0 END) AS Location_ID_Nulls,
    SUM(CASE WHEN Joined_Bank              IS NULL THEN 1 ELSE 0 END) AS Joined_Bank_Nulls,
    SUM(CASE WHEN Banking_Contact          IS NULL THEN 1 ELSE 0 END) AS Banking_Contact_Nulls,
    SUM(CASE WHEN Nationality              IS NULL THEN 1 ELSE 0 END) AS Nationality_Nulls,
    SUM(CASE WHEN Occupation               IS NULL THEN 1 ELSE 0 END) AS Occupation_Nulls,
    SUM(CASE WHEN Fee_Structure            IS NULL THEN 1 ELSE 0 END) AS Fee_Structure_Nulls,
    SUM(CASE WHEN Loyalty_Classification   IS NULL THEN 1 ELSE 0 END) AS Loyalty_Nulls,
    SUM(CASE WHEN Estimated_Income         IS NULL THEN 1 ELSE 0 END) AS Income_Nulls,
    SUM(CASE WHEN Superannuation_Savings   IS NULL THEN 1 ELSE 0 END) AS Super_Savings_Nulls,
    SUM(CASE WHEN Amount_of_Credit_Cards   IS NULL THEN 1 ELSE 0 END) AS Credit_Cards_Nulls,
    SUM(CASE WHEN Credit_Card_Balance      IS NULL THEN 1 ELSE 0 END) AS CC_Balance_Nulls,
    SUM(CASE WHEN Bank_Loans               IS NULL THEN 1 ELSE 0 END) AS Bank_Loans_Nulls,
    SUM(CASE WHEN Bank_Deposits            IS NULL THEN 1 ELSE 0 END) AS Bank_Deposits_Nulls,
    SUM(CASE WHEN Checking_Accounts        IS NULL THEN 1 ELSE 0 END) AS Checking_Nulls,
    SUM(CASE WHEN Saving_Accounts          IS NULL THEN 1 ELSE 0 END) AS Saving_Nulls,
    SUM(CASE WHEN Foreign_Currency_Account IS NULL THEN 1 ELSE 0 END) AS Foreign_Currency_Nulls,
    SUM(CASE WHEN Business_Lending         IS NULL THEN 1 ELSE 0 END) AS Business_Lending_Nulls,
    SUM(CASE WHEN Properties_Owned         IS NULL THEN 1 ELSE 0 END) AS Properties_Nulls,
    SUM(CASE WHEN Risk_Weighting           IS NULL THEN 1 ELSE 0 END) AS Risk_Weighting_Nulls,
    SUM(CASE WHEN BRId                     IS NULL THEN 1 ELSE 0 END) AS BRId_Nulls,
    SUM(CASE WHEN GenderId                 IS NULL THEN 1 ELSE 0 END) AS GenderId_Nulls,
    SUM(CASE WHEN IAId                     IS NULL THEN 1 ELSE 0 END) AS IAId_Nulls
FROM banking;

-- -------------------------------------------------------

-- duplicate detection
SELECT
    Client_ID,
    COUNT(*) AS Occurrences
FROM banking
GROUP BY Client_ID
HAVING COUNT(*) > 1
ORDER BY Occurrences DESC;

-- -------------------------------------------------------

-- check distinct values in categorical columns (typos / inconsistency check)
SELECT DISTINCT Fee_Structure          FROM banking ORDER BY 1;
SELECT DISTINCT Loyalty_Classification FROM banking ORDER BY 1;
SELECT DISTINCT Nationality            FROM banking ORDER BY 1;
SELECT DISTINCT Risk_Weighting         FROM banking ORDER BY 1;
SELECT DISTINCT GenderId               FROM banking ORDER BY 1;
SELECT DISTINCT BRId                   FROM banking ORDER BY 1;

-- -------------------------------------------------------

-- numeric range check (spot any impossible values)
SELECT
    MIN(Age)                    AS Min_Age,             MAX(Age)                    AS Max_Age,
    MIN(Estimated_Income)       AS Min_Income,          MAX(Estimated_Income)       AS Max_Income,
    MIN(Bank_Loans)             AS Min_Loan,            MAX(Bank_Loans)             AS Max_Loan,
    MIN(Bank_Deposits)          AS Min_Deposit,         MAX(Bank_Deposits)          AS Max_Deposit,
    MIN(Credit_Card_Balance)    AS Min_CC_Balance,      MAX(Credit_Card_Balance)    AS Max_CC_Balance,
    MIN(Amount_of_Credit_Cards) AS Min_Credit_Cards,    MAX(Amount_of_Credit_Cards) AS Max_Credit_Cards,
    MIN(Properties_Owned)       AS Min_Properties,      MAX(Properties_Owned)       AS Max_Properties,
    MIN(Risk_Weighting)         AS Min_Risk,            MAX(Risk_Weighting)         AS Max_Risk
FROM banking;

-- -------------------------------------------------------

-- logical check: negative balances or loans (financial impossibilities)
SELECT Client_ID, Bank_Loans, Bank_Deposits, Credit_Card_Balance, Estimated_Income
FROM banking
WHERE Bank_Loans < 0
   OR Bank_Deposits < 0
   OR Credit_Card_Balance < 0
   OR Estimated_Income < 0;

-- -------------------------------------------------------

-- logical check: clients younger than 18 (not eligible for banking)
SELECT Client_ID, Name, Age
FROM banking
WHERE Age < 18;

-- -------------------------------------------------------

-- logical check: join date should not be in the future
SELECT Client_ID, Name, Joined_Bank
FROM banking
WHERE Joined_Bank > GETDATE();

-- -------------------------------------------------------

-- standardise text columns (trim whitespace, normalise case)
UPDATE banking
SET Fee_Structure          = LTRIM(RTRIM(Fee_Structure)),
    Loyalty_Classification = LTRIM(RTRIM(Loyalty_Classification)),
    Nationality            = LTRIM(RTRIM(Nationality)),
    Occupation             = LTRIM(RTRIM(Occupation));

-- -------------------------------------------------------

-- add derived flags that will be used heavily during analysis

-- 1. Loan-to-Income Ratio (key default-risk indicator)
ALTER TABLE banking ADD Loan_to_Income_Ratio DECIMAL(10,2);
UPDATE banking
SET Loan_to_Income_Ratio =
    CASE WHEN Estimated_Income > 0
         THEN CAST(Bank_Loans * 1.0 / Estimated_Income AS DECIMAL(10,2))
         ELSE 0 END;

-- 2. Loan Approval Status (derived rule-based: low risk + healthy income + decent deposits)
ALTER TABLE banking ADD Loan_Approval_Status NVARCHAR(20);
UPDATE banking
SET Loan_Approval_Status =
    CASE
        WHEN Risk_Weighting <= 2 AND Estimated_Income >= 100000 AND Bank_Deposits >= 200000 THEN 'Approved'
        WHEN Risk_Weighting <= 3 AND Estimated_Income >= 50000                                THEN 'Conditional'
        ELSE 'Rejected'
    END;

-- 3. Default Risk Category (high loan-to-income + high risk weighting = high default risk)
ALTER TABLE banking ADD Default_Risk_Category NVARCHAR(20);
UPDATE banking
SET Default_Risk_Category =
    CASE
        WHEN Loan_to_Income_Ratio >= 5 AND Risk_Weighting >= 4 THEN 'High Risk'
        WHEN Loan_to_Income_Ratio >= 3 OR  Risk_Weighting >= 3 THEN 'Medium Risk'
        ELSE 'Low Risk'
    END;

-- 4. Repayment Capacity Score (deposits + savings vs outstanding loans)
ALTER TABLE banking ADD Repayment_Capacity_Score DECIMAL(10,2);
UPDATE banking
SET Repayment_Capacity_Score =
    CASE WHEN Bank_Loans > 0
         THEN CAST((Bank_Deposits + Saving_Accounts + Superannuation_Savings) * 1.0 / Bank_Loans AS DECIMAL(10,2))
         ELSE 999.99 END;

-- 5. Age Band (used for segmentation)
ALTER TABLE banking ADD Age_Band NVARCHAR(20);
UPDATE banking
SET Age_Band =
    CASE
        WHEN Age < 25            THEN 'Under 25'
        WHEN Age BETWEEN 25 AND 34 THEN '25 - 34'
        WHEN Age BETWEEN 35 AND 44 THEN '35 - 44'
        WHEN Age BETWEEN 45 AND 54 THEN '45 - 54'
        WHEN Age BETWEEN 55 AND 64 THEN '55 - 64'
        ELSE '65+'
    END;

-- confirm derived columns exist
SELECT COUNT(*) AS Total_Columns
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'banking';


-- ============================================================
-- STAGE 2: STAR SCHEMA
-- ============================================================

-- create dimension table - client personal info
CREATE TABLE dim_client (
    client_key      INT IDENTITY(1,1) PRIMARY KEY,
    Client_ID       NVARCHAR(50),
    Name            NVARCHAR(255),
    Age             INT,
    Age_Band        NVARCHAR(20),
    GenderId        INT,
    Nationality     NVARCHAR(100),
    Occupation      NVARCHAR(255),
    Location_ID     INT,
    Joined_Bank     DATE,
    Banking_Contact NVARCHAR(255)
);

-- -------------------------------------------------------

-- create dimension table - account / product classification
CREATE TABLE dim_product (
    product_key             INT IDENTITY(1,1) PRIMARY KEY,
    Fee_Structure           NVARCHAR(50),
    Loyalty_Classification  NVARCHAR(50),
    BRId                    INT,
    IAId                    INT
);

-- -------------------------------------------------------

-- create dimension table - risk classification
CREATE TABLE dim_risk (
    risk_key              INT IDENTITY(1,1) PRIMARY KEY,
    Risk_Weighting        INT,
    Default_Risk_Category NVARCHAR(20),
    Loan_Approval_Status  NVARCHAR(20)
);

-- -------------------------------------------------------

-- create fact table - one row per client with all financial measures
CREATE TABLE fact_banking (
    fact_id                  INT IDENTITY(1,1) PRIMARY KEY,
    client_key               INT,
    product_key              INT,
    risk_key                 INT,
    Estimated_Income         DECIMAL(15,2),
    Superannuation_Savings   DECIMAL(15,2),
    Amount_of_Credit_Cards   INT,
    Credit_Card_Balance      DECIMAL(15,2),
    Bank_Loans               DECIMAL(15,2),
    Bank_Deposits            DECIMAL(15,2),
    Checking_Accounts        DECIMAL(15,2),
    Saving_Accounts          DECIMAL(15,2),
    Foreign_Currency_Account DECIMAL(15,2),
    Business_Lending         DECIMAL(15,2),
    Properties_Owned         INT,
    Loan_to_Income_Ratio     DECIMAL(10,2),
    Repayment_Capacity_Score DECIMAL(10,2),
    FOREIGN KEY (client_key)  REFERENCES dim_client(client_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (risk_key)    REFERENCES dim_risk(risk_key)
);

-- -------------------------------------------------------

-- insert into dim_client
INSERT INTO dim_client (Client_ID, Name, Age, Age_Band, GenderId, Nationality, Occupation, Location_ID, Joined_Bank, Banking_Contact)
SELECT DISTINCT Client_ID, Name, Age, Age_Band, GenderId, Nationality, Occupation, Location_ID, Joined_Bank, Banking_Contact
FROM banking;

-- insert into dim_product
INSERT INTO dim_product (Fee_Structure, Loyalty_Classification, BRId, IAId)
SELECT DISTINCT Fee_Structure, Loyalty_Classification, BRId, IAId
FROM banking;

-- insert into dim_risk
INSERT INTO dim_risk (Risk_Weighting, Default_Risk_Category, Loan_Approval_Status)
SELECT DISTINCT Risk_Weighting, Default_Risk_Category, Loan_Approval_Status
FROM banking;

-- -------------------------------------------------------

-- insert into fact table
INSERT INTO fact_banking (
    client_key, product_key, risk_key,
    Estimated_Income, Superannuation_Savings, Amount_of_Credit_Cards, Credit_Card_Balance,
    Bank_Loans, Bank_Deposits, Checking_Accounts, Saving_Accounts,
    Foreign_Currency_Account, Business_Lending, Properties_Owned,
    Loan_to_Income_Ratio, Repayment_Capacity_Score
)
SELECT
    dc.client_key, dp.product_key, dr.risk_key,
    b.Estimated_Income, b.Superannuation_Savings, b.Amount_of_Credit_Cards, b.Credit_Card_Balance,
    b.Bank_Loans, b.Bank_Deposits, b.Checking_Accounts, b.Saving_Accounts,
    b.Foreign_Currency_Account, b.Business_Lending, b.Properties_Owned,
    b.Loan_to_Income_Ratio, b.Repayment_Capacity_Score
FROM banking b
JOIN dim_client  dc ON dc.Client_ID              = b.Client_ID
JOIN dim_product dp ON dp.Fee_Structure          = b.Fee_Structure
                   AND dp.Loyalty_Classification = b.Loyalty_Classification
                   AND dp.BRId                   = b.BRId
                   AND dp.IAId                   = b.IAId
JOIN dim_risk    dr ON dr.Risk_Weighting         = b.Risk_Weighting
                   AND dr.Default_Risk_Category  = b.Default_Risk_Category
                   AND dr.Loan_Approval_Status   = b.Loan_Approval_Status;

-- check fact table (should match total clients)
SELECT COUNT(*) AS Fact_Rows FROM fact_banking;


-- ============================================================
-- STAGE 3: ANALYSIS
-- ============================================================

-- -------------------------------------------------------
-- Loan Approval Analysis
-- -------------------------------------------------------

-- overall approval breakdown
SELECT
    r.Loan_Approval_Status,
    COUNT(*)                                                                  AS Total_Clients,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))            AS Pct_of_Total,
    CAST(AVG(f.Estimated_Income) AS DECIMAL(15,2))                            AS Avg_Income,
    CAST(AVG(f.Bank_Loans)       AS DECIMAL(15,2))                            AS Avg_Loan
FROM fact_banking f
JOIN dim_risk r ON f.risk_key = r.risk_key
GROUP BY r.Loan_Approval_Status
ORDER BY Total_Clients DESC;

-- -------------------------------------------------------

-- approval rate by loyalty classification (CTE + window function)
WITH approval_by_loyalty AS (
    SELECT
        p.Loyalty_Classification,
        r.Loan_Approval_Status,
        COUNT(*) AS Clients
    FROM fact_banking f
    JOIN dim_product p ON f.product_key = p.product_key
    JOIN dim_risk    r ON f.risk_key    = r.risk_key
    GROUP BY p.Loyalty_Classification, r.Loan_Approval_Status
)
SELECT
    Loyalty_Classification,
    Loan_Approval_Status,
    Clients,
    SUM(Clients) OVER (PARTITION BY Loyalty_Classification)                                   AS Loyalty_Total,
    CAST(100.0 * Clients / SUM(Clients) OVER (PARTITION BY Loyalty_Classification) AS DECIMAL(5,2)) AS Pct_Within_Loyalty
FROM approval_by_loyalty
ORDER BY Loyalty_Classification, Clients DESC;

-- -------------------------------------------------------

-- approval rate by age band
SELECT
    c.Age_Band,
    COUNT(*) AS Total,
    SUM(CASE WHEN r.Loan_Approval_Status = 'Approved'    THEN 1 ELSE 0 END) AS Approved,
    SUM(CASE WHEN r.Loan_Approval_Status = 'Conditional' THEN 1 ELSE 0 END) AS Conditional,
    SUM(CASE WHEN r.Loan_Approval_Status = 'Rejected'    THEN 1 ELSE 0 END) AS Rejected,
    CAST(100.0 * SUM(CASE WHEN r.Loan_Approval_Status = 'Approved' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS Approval_Rate_Pct
FROM fact_banking f
JOIN dim_client c ON f.client_key = c.client_key
JOIN dim_risk   r ON f.risk_key   = r.risk_key
GROUP BY c.Age_Band
ORDER BY Approval_Rate_Pct DESC;

-- -------------------------------------------------------

-- ============================================================
-- CONCLUSION: Loan Approval Analysis
-- Approval status is driven primarily by income, deposit base, and risk weighting.
-- Premium loyalty tiers (Jade, Platinum) show the highest share of "Approved" status
-- because these clients carry stronger deposits and lower risk weightings.
-- Younger clients (Under 25) have the lowest approval rates due to thinner deposit
-- history and lower income; mid-career clients (35-54) achieve the highest approval rates.
-- ============================================================

-- -------------------------------------------------------
-- Default Risk Analysis
-- -------------------------------------------------------

-- distribution of default risk categories
SELECT
    r.Default_Risk_Category,
    COUNT(*)                                                       AS Total_Clients,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS Pct_of_Total,
    CAST(AVG(f.Loan_to_Income_Ratio)     AS DECIMAL(5,2))          AS Avg_Loan_to_Income,
    CAST(AVG(f.Repayment_Capacity_Score) AS DECIMAL(10,2))         AS Avg_Repayment_Capacity
FROM fact_banking f
JOIN dim_risk r ON f.risk_key = r.risk_key
GROUP BY r.Default_Risk_Category
ORDER BY Avg_Loan_to_Income DESC;

-- -------------------------------------------------------

-- top 10 clients with highest default risk (CTE + window function ranking)
WITH ranked_risk AS (
    SELECT
        c.Client_ID,
        c.Name,
        c.Age_Band,
        f.Estimated_Income,
        f.Bank_Loans,
        f.Loan_to_Income_Ratio,
        f.Repayment_Capacity_Score,
        r.Default_Risk_Category,
        RANK() OVER (ORDER BY f.Loan_to_Income_Ratio DESC, f.Repayment_Capacity_Score ASC) AS Risk_Rank
    FROM fact_banking f
    JOIN dim_client c ON f.client_key = c.client_key
    JOIN dim_risk   r ON f.risk_key   = r.risk_key
)
SELECT *
FROM ranked_risk
WHERE Risk_Rank <= 10
ORDER BY Risk_Rank;

-- -------------------------------------------------------

-- default risk by occupation (top 10 most risky occupations)
SELECT TOP 10
    c.Occupation,
    COUNT(*) AS Total_Clients,
    SUM(CASE WHEN r.Default_Risk_Category = 'High Risk' THEN 1 ELSE 0 END) AS High_Risk_Clients,
    CAST(100.0 * SUM(CASE WHEN r.Default_Risk_Category = 'High Risk' THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS High_Risk_Pct
FROM fact_banking f
JOIN dim_client c ON f.client_key = c.client_key
JOIN dim_risk   r ON f.risk_key   = r.risk_key
GROUP BY c.Occupation
HAVING COUNT(*) >= 5
ORDER BY High_Risk_Pct DESC;

-- -------------------------------------------------------

-- ============================================================
-- CONCLUSION: Default Risk Analysis
-- High-risk clients hold a loan-to-income ratio above 5 and very low repayment capacity,
-- meaning their deposits and savings are not enough to cover their outstanding loans.
-- The top 10 highest-risk clients have loan-to-income ratios well above 8,
-- making them strong candidates for restructuring or proactive collection outreach.
-- Certain occupations (typically junior / part-time roles) concentrate
-- in the high-risk band, which suggests stricter underwriting for those profiles.
-- ============================================================

-- -------------------------------------------------------
-- Repayment Trends
-- -------------------------------------------------------

-- repayment capacity by loyalty classification (using window function for ranking)
SELECT
    p.Loyalty_Classification,
    COUNT(*) AS Total_Clients,
    CAST(AVG(f.Bank_Loans)               AS DECIMAL(15,2)) AS Avg_Loan,
    CAST(AVG(f.Bank_Deposits)            AS DECIMAL(15,2)) AS Avg_Deposit,
    CAST(AVG(f.Repayment_Capacity_Score) AS DECIMAL(10,2)) AS Avg_Repayment_Capacity,
    RANK() OVER (ORDER BY AVG(f.Repayment_Capacity_Score) DESC) AS Capacity_Rank
FROM fact_banking f
JOIN dim_product p ON f.product_key = p.product_key
GROUP BY p.Loyalty_Classification
ORDER BY Capacity_Rank;

-- -------------------------------------------------------

-- repayment trend over the years (clients joined per year vs avg repayment capacity)
WITH joining_year AS (
    SELECT
        YEAR(c.Joined_Bank) AS Join_Year,
        f.Bank_Loans,
        f.Bank_Deposits,
        f.Repayment_Capacity_Score
    FROM fact_banking f
    JOIN dim_client c ON f.client_key = c.client_key
)
SELECT
    Join_Year,
    COUNT(*)                                              AS Clients_Joined,
    CAST(AVG(Bank_Loans)               AS DECIMAL(15,2))  AS Avg_Loan,
    CAST(AVG(Bank_Deposits)            AS DECIMAL(15,2))  AS Avg_Deposit,
    CAST(AVG(Repayment_Capacity_Score) AS DECIMAL(10,2))  AS Avg_Repayment_Capacity
FROM joining_year
GROUP BY Join_Year
ORDER BY Join_Year;

-- -------------------------------------------------------

-- moving average of repayment capacity by join year (window function)
WITH yearly_capacity AS (
    SELECT
        YEAR(c.Joined_Bank) AS Join_Year,
        AVG(f.Repayment_Capacity_Score) AS Avg_Capacity
    FROM fact_banking f
    JOIN dim_client c ON f.client_key = c.client_key
    GROUP BY YEAR(c.Joined_Bank)
)
SELECT
    Join_Year,
    CAST(Avg_Capacity AS DECIMAL(10,2)) AS Avg_Capacity,
    CAST(AVG(Avg_Capacity) OVER (ORDER BY Join_Year ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS DECIMAL(10,2)) AS Moving_Avg_3yr
FROM yearly_capacity
ORDER BY Join_Year;

-- -------------------------------------------------------

-- ============================================================
-- CONCLUSION: Repayment Trends
-- Repayment capacity is highest for premium loyalty tiers (Jade and Platinum)
-- because their deposit and savings balances comfortably exceed their loans.
-- Silver and Gold tiers show weaker repayment capacity, signalling that mid-tier clients
-- are stretched thinner relative to their loan obligations.
-- Year-over-year, the 3-year moving average of repayment capacity highlights
-- whether newer client cohorts are joining with weaker or stronger financial cushions.
-- Cohorts joining in later years tend to carry higher loan balances at onboarding,
-- which puts pressure on average repayment capacity.
-- ============================================================

-- -------------------------------------------------------
-- Customer Segmentation
-- (income + credit score proxy + transaction patterns)
-- -------------------------------------------------------

-- segmentation by income tier
WITH income_segments AS (
    SELECT
        c.Client_ID,
        c.Name,
        f.Estimated_Income,
        f.Bank_Deposits,
        f.Bank_Loans,
        f.Credit_Card_Balance,
        f.Amount_of_Credit_Cards,
        r.Risk_Weighting,
        CASE
            WHEN f.Estimated_Income <  50000  THEN 'Low Income'
            WHEN f.Estimated_Income <  150000 THEN 'Mid Income'
            WHEN f.Estimated_Income <  300000 THEN 'High Income'
            ELSE 'Premium Income'
        END AS Income_Tier
    FROM fact_banking f
    JOIN dim_client c ON f.client_key = c.client_key
    JOIN dim_risk   r ON f.risk_key   = r.risk_key
)
SELECT
    Income_Tier,
    COUNT(*)                                            AS Total_Clients,
    CAST(AVG(Estimated_Income)    AS DECIMAL(15,2))     AS Avg_Income,
    CAST(AVG(Bank_Deposits)       AS DECIMAL(15,2))     AS Avg_Deposit,
    CAST(AVG(Bank_Loans)          AS DECIMAL(15,2))     AS Avg_Loan,
    CAST(AVG(Credit_Card_Balance) AS DECIMAL(15,2))     AS Avg_CC_Balance,
    CAST(AVG(CAST(Risk_Weighting AS FLOAT)) AS DECIMAL(4,2)) AS Avg_Risk_Weighting
FROM income_segments
GROUP BY Income_Tier
ORDER BY Avg_Income;

-- -------------------------------------------------------

-- segmentation by transaction activity (deposits + checking + savings + foreign currency)
WITH transaction_activity AS (
    SELECT
        c.Client_ID,
        c.Name,
        (f.Bank_Deposits + f.Checking_Accounts + f.Saving_Accounts + f.Foreign_Currency_Account) AS Total_Transaction_Volume,
        f.Estimated_Income,
        r.Risk_Weighting,
        NTILE(4) OVER (ORDER BY (f.Bank_Deposits + f.Checking_Accounts + f.Saving_Accounts + f.Foreign_Currency_Account)) AS Activity_Quartile
    FROM fact_banking f
    JOIN dim_client c ON f.client_key = c.client_key
    JOIN dim_risk   r ON f.risk_key   = r.risk_key
)
SELECT
    Activity_Quartile,
    CASE Activity_Quartile
        WHEN 1 THEN 'Low Activity'
        WHEN 2 THEN 'Moderate Activity'
        WHEN 3 THEN 'High Activity'
        WHEN 4 THEN 'Premium Activity'
    END AS Activity_Segment,
    COUNT(*)                                                   AS Clients,
    CAST(AVG(Total_Transaction_Volume) AS DECIMAL(15,2))       AS Avg_Transaction_Volume,
    CAST(AVG(Estimated_Income)         AS DECIMAL(15,2))       AS Avg_Income,
    CAST(AVG(CAST(Risk_Weighting AS FLOAT)) AS DECIMAL(4,2))   AS Avg_Risk_Weighting
FROM transaction_activity
GROUP BY Activity_Quartile
ORDER BY Activity_Quartile;

-- -------------------------------------------------------

-- combined segmentation: identify high-value and high-risk clients
-- high-value  = Premium Income + Premium Activity + Low Risk_Weighting
-- high-risk   = High Risk Category OR very low repayment capacity
WITH client_profile AS (
    SELECT
        c.Client_ID,
        c.Name,
        c.Age_Band,
        f.Estimated_Income,
        f.Bank_Loans,
        f.Bank_Deposits,
        f.Loan_to_Income_Ratio,
        f.Repayment_Capacity_Score,
        r.Risk_Weighting,
        r.Default_Risk_Category,
        (f.Bank_Deposits + f.Checking_Accounts + f.Saving_Accounts + f.Foreign_Currency_Account) AS Transaction_Volume,
        NTILE(4) OVER (ORDER BY (f.Bank_Deposits + f.Checking_Accounts + f.Saving_Accounts + f.Foreign_Currency_Account)) AS Activity_Quartile,
        CASE
            WHEN f.Estimated_Income <  50000  THEN 'Low Income'
            WHEN f.Estimated_Income <  150000 THEN 'Mid Income'
            WHEN f.Estimated_Income <  300000 THEN 'High Income'
            ELSE 'Premium Income'
        END AS Income_Tier
    FROM fact_banking f
    JOIN dim_client c ON f.client_key = c.client_key
    JOIN dim_risk   r ON f.risk_key   = r.risk_key
)
SELECT
    Client_ID,
    Name,
    Age_Band,
    Income_Tier,
    Activity_Quartile,
    Risk_Weighting,
    Default_Risk_Category,
    CAST(Loan_to_Income_Ratio     AS DECIMAL(5,2))  AS Loan_to_Income_Ratio,
    CAST(Repayment_Capacity_Score AS DECIMAL(10,2)) AS Repayment_Capacity,
    CASE
        WHEN Income_Tier = 'Premium Income' AND Activity_Quartile = 4 AND Risk_Weighting <= 2 THEN 'High-Value Customer'
        WHEN Default_Risk_Category = 'High Risk' OR Repayment_Capacity_Score < 0.5             THEN 'High-Risk Customer'
        WHEN Income_Tier IN ('High Income','Premium Income') AND Risk_Weighting <= 3            THEN 'Growth Customer'
        ELSE 'Standard Customer'
    END AS Customer_Segment
FROM client_profile
ORDER BY
    CASE
        WHEN Income_Tier = 'Premium Income' AND Activity_Quartile = 4 AND Risk_Weighting <= 2 THEN 1
        WHEN Default_Risk_Category = 'High Risk' OR Repayment_Capacity_Score < 0.5             THEN 2
        WHEN Income_Tier IN ('High Income','Premium Income') AND Risk_Weighting <= 3            THEN 3
        ELSE 4
    END,
    Estimated_Income DESC;

-- -------------------------------------------------------

-- segment summary - how many clients fall into each business segment
WITH client_segments AS (
    SELECT
        CASE
            WHEN f.Estimated_Income >= 300000 AND r.Risk_Weighting <= 2
                 AND (f.Bank_Deposits + f.Checking_Accounts + f.Saving_Accounts + f.Foreign_Currency_Account) > 2000000
                 THEN 'High-Value Customer'
            WHEN r.Default_Risk_Category = 'High Risk' OR f.Repayment_Capacity_Score < 0.5
                 THEN 'High-Risk Customer'
            WHEN f.Estimated_Income >= 150000 AND r.Risk_Weighting <= 3
                 THEN 'Growth Customer'
            ELSE 'Standard Customer'
        END AS Customer_Segment,
        f.Estimated_Income,
        f.Bank_Loans,
        f.Bank_Deposits
    FROM fact_banking f
    JOIN dim_risk r ON f.risk_key = r.risk_key
)
SELECT
    Customer_Segment,
    COUNT(*)                                              AS Total_Clients,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER ()
         AS DECIMAL(5,2))                                 AS Pct_of_Total,
    CAST(AVG(Estimated_Income) AS DECIMAL(15,2))          AS Avg_Income,
    CAST(AVG(Bank_Loans)       AS DECIMAL(15,2))          AS Avg_Loan,
    CAST(AVG(Bank_Deposits)    AS DECIMAL(15,2))          AS Avg_Deposit
FROM client_segments
GROUP BY Customer_Segment
ORDER BY Avg_Income DESC;

-- ============================================================
-- CONCLUSION: Customer Segmentation
-- Clients clearly split into 4 actionable segments:
--   High-Value Customers : Premium income + premium activity + low risk.
--                          Small share of the base but largest deposit + transaction volume.
--                          Priority for retention, wealth management, and cross-sell.
--   Growth Customers     : High income + acceptable risk but lower activity.
--                          Strong upsell candidates for investment and credit products.
--   Standard Customers   : The mid-market core. Stable but lower margin.
--   High-Risk Customers  : High loan-to-income ratio or very weak repayment capacity.
--                          Need closer monitoring, restructuring offers, or stricter limits.
-- Income tier is the strongest signal for value, while risk weighting + loan-to-income
-- ratio together form the strongest signal for default risk.
-- ============================================================
