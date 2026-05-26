# 🏦 Banking Analytics Project

> End-to-end banking client analytics pipeline — from raw CSV data through SQL transformation and star schema modelling, to an interactive Power BI dashboard covering deposits, loans, and client summaries.

---

## 📁 Repository Structure

```
├── Banking.csv                  # Raw banking client dataset — 3,000 rows × 25 columns
├── Banking_analysis.sql         # 3-stage SQL pipeline: pre-processing → star schema → analysis
├── banking_analysis.pbix        # Power BI dashboard — 4 report pages
└── README.md
```

---

## 📊 Dataset — `Banking.csv`

**3,000 client records · 25 columns**

| Column | Type | Description | Range / Values |
|---|---|---|---|
| `Client ID` | String | Unique client identifier | e.g. `IND81288` |
| `Name` | String | Full name | — |
| `Age` | Integer | Client age | 17 – 85 (mean: 51) |
| `Location ID` | Integer | Branch / location reference | 12 – 43,369 |
| `Joined Bank` | Date | Account open date | DD-MM-YYYY |
| `Banking Contact` | String | Assigned relationship manager | — |
| `Nationality` | String | Client nationality | African, American, Asian, Australian, European |
| `Occupation` | String | Job title | — |
| `Fee Structure` | String | Fee tier | High, Mid, Low |
| `Loyalty Classification` | String | Loyalty tier | Jade, Platinum, Gold, Silver |
| `Estimated Income` | Decimal | Annual income (AUD) | $15,919 – $522,330 (mean: $171,305) |
| `Superannuation Savings` | Decimal | Retirement savings balance | $1,482 – $75,964 |
| `Amount of Credit Cards` | Integer | Number of credit cards held | 1 – 3 |
| `Credit Card Balance` | Decimal | Outstanding CC balance | $1 – $13,992 |
| `Bank Loans` | Decimal | Total outstanding loans | $0 – $2,667,557 |
| `Bank Deposits` | Decimal | Total deposit balance | $0 – $3,890,598 |
| `Checking Accounts` | Decimal | Checking account balance | $0 – $1,969,923 |
| `Saving Accounts` | Decimal | Savings account balance | $0 – $1,724,118 |
| `Foreign Currency Account` | Decimal | Foreign currency holding | $45 – $124,705 |
| `Business Lending` | Decimal | Business loan balance | $0 – $3,825,962 |
| `Properties Owned` | Integer | Number of properties owned | 0 – 3 |
| `Risk Weighting` | Integer | Internal risk score | 1 (lowest) – 5 (highest) |
| `BRId` | Integer | Business relationship ID | 1 – 4 |
| `GenderId` | Integer | Gender reference (1 = Male, 2 = Female) | 1, 2 |
| `IAId` | Integer | Industry / advisor ID | 1 – 22 |

---

## 🛢️ SQL Pipeline — `Banking_analysis.sql`

Three-stage T-SQL pipeline targeting **SQL Server**.

---

### Stage 1 — Pre-Processing

Data quality checks run before any modelling begins.

**Quality checks:**
- Row count vs. `COUNT(DISTINCT Client_ID)` — duplicate detection
- NULL audit across all 25 columns
- Categorical consistency check (`DISTINCT` on `Fee_Structure`, `Loyalty_Classification`, `Nationality`, `Risk_Weighting`, `GenderId`, `BRId`)
- Numeric range validation — impossible ages, negative balances, future join dates
- Text standardisation — `LTRIM` / `RTRIM` on all string columns

**5 derived columns added to the base table:**

| Column | Formula / Logic | Purpose |
|---|---|---|
| `Loan_to_Income_Ratio` | `Bank_Loans / Estimated_Income` | Primary default-risk signal |
| `Loan_Approval_Status` | Rule-based: `Approved` / `Conditional` / `Rejected` from income, deposits & risk weighting | Loan decisioning |
| `Default_Risk_Category` | `High` / `Medium` / `Low Risk` from LTI ratio + risk weighting | Risk segmentation |
| `Repayment_Capacity_Score` | `(Deposits + Savings + Super) / Bank_Loans` | Ability to cover outstanding loans |
| `Age_Band` | Bucketed: Under 25, 25–34, 35–44, 45–54, 55–64, 65+ | Demographic segmentation |

---

### Stage 2 — Star Schema

```
fact_banking
  ├── dim_client    (client_key)   — demographics, age band, location, contact
  ├── dim_product   (product_key)  — fee structure, loyalty tier, BRId, IAId
  └── dim_risk      (risk_key)     — risk weighting, default category, approval status
```

**`dim_client`** — client personal information
| Column | Type |
|---|---|
| `client_key` | INT (PK) |
| `Client_ID` | NVARCHAR |
| `Name` | NVARCHAR |
| `Age` | INT |
| `Age_Band` | NVARCHAR |
| `GenderId` | INT |
| `Nationality` | NVARCHAR |
| `Occupation` | NVARCHAR |
| `Location_ID` | INT |
| `Joined_Bank` | DATE |
| `Banking_Contact` | NVARCHAR |

**`dim_product`** — account / product classification
| Column | Type |
|---|---|
| `product_key` | INT (PK) |
| `Fee_Structure` | NVARCHAR |
| `Loyalty_Classification` | NVARCHAR |
| `BRId` | INT |
| `IAId` | INT |

**`dim_risk`** — risk classification
| Column | Type |
|---|---|
| `risk_key` | INT (PK) |
| `Risk_Weighting` | INT |
| `Default_Risk_Category` | NVARCHAR |
| `Loan_Approval_Status` | NVARCHAR |

**`fact_banking`** — one row per client, all financial measures
| Column | Type |
|---|---|
| `fact_id` | INT (PK) |
| `client_key` | INT (FK → dim_client) |
| `product_key` | INT (FK → dim_product) |
| `risk_key` | INT (FK → dim_risk) |
| `Estimated_Income` | DECIMAL |
| `Superannuation_Savings` | DECIMAL |
| `Amount_of_Credit_Cards` | INT |
| `Credit_Card_Balance` | DECIMAL |
| `Bank_Loans` | DECIMAL |
| `Bank_Deposits` | DECIMAL |
| `Checking_Accounts` | DECIMAL |
| `Saving_Accounts` | DECIMAL |
| `Foreign_Currency_Account` | DECIMAL |
| `Business_Lending` | DECIMAL |
| `Properties_Owned` | INT |
| `Loan_to_Income_Ratio` | DECIMAL |
| `Repayment_Capacity_Score` | DECIMAL |

---

### Stage 3 — Analysis

Three analytical themes, each with a written business conclusion embedded in the script.

**Loan Approval Analysis**
- Overall approval breakdown — counts, %, average income, average loan
- Approval rate by loyalty classification (CTE + window functions)
- Approval rate by age band

**Default Risk Analysis**
- Distribution of `Default_Risk_Category` with LTI and repayment capacity averages
- Top 10 highest-risk clients ranked with `RANK()` window function
- Default risk concentration by occupation (clients with ≥ 5 records)

**Customer Segmentation**
- Income tier segmentation: Low / Mid / High / Premium Income
- Transaction activity quartiles using `NTILE(4)`
- Combined 4-segment client profiling:

| Segment | Definition |
|---|---|
| **High-Value Customer** | Premium income + Q4 activity + Risk Weighting ≤ 2 |
| **Growth Customer** | High / Premium income + Risk Weighting ≤ 3 |
| **High-Risk Customer** | `High Risk` category OR Repayment Capacity Score < 0.5 |
| **Standard Customer** | All remaining clients |

---

## 📈 Power BI Report — `banking_analysis.pbix`

**4 report pages · built on the `banking` table with calculated columns**

### Calculated Columns (Power BI)

| Column | Description |
|---|---|
| `Income Band` | Income-based bucketing used across visuals |
| `year of joining` | Year extracted from `Joined Bank` for time slicing |

### DAX Measures

| Measure | Description |
|---|---|
| `total loan` | Sum of all bank loans across filtered clients |
| `total deposits` | Sum of all bank deposits across filtered clients |

---

### Report Pages

#### 🏠 Home
Overview KPI cards and navigation hub.

| Visual | Field |
|---|---|
| Card | Client count (`Name`) |
| Card | Total Loan |
| Card | Total Deposits |
| Card | Sum of Checking Accounts |
| Card | Sum of Business Lending |
| Card | Sum of Saving Accounts |
| Slicer | Gender (`GenderId`) |
| Slicer | Year of Joining |
| Navigation Buttons | → Deposit Analysis, Loan Analysis, Summary |

---

#### 💰 Deposit Analysis
Breakdown of deposit balances across client segments.

| Visual | X-Axis / Legend | Value |
|---|---|---|
| Card | — | Total Deposits |
| Card | — | Sum of Bank Deposits |
| Card | — | Sum of Saving Accounts |
| Card | — | Sum of Checking Accounts |
| Donut Chart | Income Band | Sum of Bank Deposits |
| Clustered Column Chart | BRId | Sum of Bank Deposits |
| Clustered Column Chart | Nationality | Sum of Bank Deposits |
| Clustered Column Chart | BRId | Sum of Bank Deposits |
| Slicers | BRId · GenderId · IAId | — |

---

#### 🏦 Loan Analysis
Breakdown of loan balances and risk across client segments.

| Visual | Type | Fields |
|---|---|---|
| KPI Cards (×4) | Card | Loan-related measures |
| Distribution | Donut Chart | Loans by segment |
| Comparisons | Clustered Column Charts (×3) | Loans by dimension |
| Filters | Slicers (×3) | Client dimension filters |

---

#### 📋 Summary
High-level cross-metric scorecard for executive overview.

| Visual | Count |
|---|---|
| KPI Cards | 12 |
| Slicers | 3 |
| Navigation Buttons | 3 |

---

## 🛠️ Tech Stack

| Layer | Tool |
|---|---|
| Raw data | CSV (3,000 rows) |
| Data quality & transformation | SQL Server (T-SQL) |
| Star schema design | T-SQL DDL + DML |
| BI visualisation | Power BI Desktop |
| DAX | Measures + Calculated Columns |

---

## 🚀 Getting Started

### 1. SQL Pipeline

```sql
-- 1. Create database
CREATE DATABASE banking_analysis;

-- 2. Import Banking.csv into a table named [banking]

-- 3. Run Banking_analysis.sql top to bottom
--    Stage 1 → Stage 2 → Stage 3 execute sequentially
```

### 2. Power BI Report

1. Open `banking_analysis.pbix` in Power BI Desktop
2. In **Transform Data**, update the data source path to point to your `Banking.csv`
3. Click **Refresh** — all 4 report pages will populate

---

## 📌 Key Insights

- **Loan-to-income ratio + risk weighting** are the two strongest predictors of default risk
- **Jade and Platinum** loyalty clients carry the highest deposit balances and best repayment capacity
- **Younger clients (Under 25)** have the lowest loan approval rates due to thinner deposit history
- **Mid-career clients (35–54)** achieve the highest approval rates
- **High-Value Customers** are a small share of the base but represent the largest deposit and transaction volumes
- **High-Risk Customers** — those with LTI > 5 and repayment capacity < 0.5 — are strong candidates for loan restructuring outreach
