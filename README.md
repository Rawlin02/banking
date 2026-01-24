# banking
Banking Analytics Project – Python + Power BI
🔹 Project Overview

This project combines Python (ETL & preprocessing) and Power BI (dashboard visualization) to analyze banking performance across clients, deposits, loans, and engagement accounts. The goal is to transform raw banking data into actionable insights for business decision-making.

## Data Preparation (Python + SQL)
* Connected to SQL Server database (banking_case) using pyodbc.
* Extracted data using SQL: SELECT * FROM banking.
* Cleaned and explored data with Pandas, NumPy, Matplotlib, and Seaborn.
* Performed statistical checks: .head(), .info(), .describe().
* Created derived features:
* Converted Estimated Income into categorical Income Bands (Low, Mid, High).
* Prepared structured datasets for deposits, loans, clients, and accounts.

# Dashboard Development (Power BI)

## The dataset was transformed into an interactive dashboard with 3 main pages:

### 1. Summary Page
* Total Clients: 3,000
* Total Deposits: 3.77bn
* Total Loans: 4.38bn
* Business Lending: 2.60bn
* Checking & Savings Accounts breakdown
* Engagement Accounts, Fees, Credit Card Balance, Foreign Currency

### 2. Deposit Analysis
* Deposits segmented by Banking Relationship (Commercial, Institutional, Private Bank)
* Demographics: Income Band, Occupation, Nationality
* Bank Deposit total: 2.01bn

### 3. Loan Analysis
* Loans segmented by Relationship, Income Band, Occupation, Nationality
* Business Lending: 2.60bn
* Credit Card Balance: 9.53M

## Tools & Skills Used
* Python: Pandas, NumPy, Matplotlib, Seaborn, SQLAlchemy, pyodbc
* SQL Server: Data extraction & queries
* Power BI: Data modeling, DAX, interactive dashboards, KPIs
* Data Analytics: Client segmentation, financial trend analysis

## Impact
* This project enables bank executives and advisors to:
* Track client growth & deposits (2013–2021)
* Assess loan distribution by customer demographics
* Identify income-based lending/deposit patterns
* Make data-driven business decisions through interactive dashboards

