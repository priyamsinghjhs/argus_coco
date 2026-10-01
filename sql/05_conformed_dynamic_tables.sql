-- ============================================================
-- 05_conformed_dynamic_tables.sql
-- RAW -> CONFORMED via Dynamic Tables
-- Ground-truth _gt_* columns are EXCLUDED from all DTs
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE WAREHOUSE COMPUTE_WH;

-- ---- CUSTOMERS_CLEAN ----
CREATE OR REPLACE DYNAMIC TABLE CONFORMED.CUSTOMERS_CLEAN
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = COMPUTE_WH
AS
SELECT
    customer_id,
    INITCAP(TRIM(name))         AS name,
    dob,
    UPPER(TRIM(kyc_risk_rating)) AS kyc_risk_rating,
    TRIM(address)                AS address,
    TRIM(phone)                  AS phone,
    LOWER(TRIM(email))           AS email,
    onboarding_date,
    _loaded_at
FROM RAW.CUSTOMERS
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY _loaded_at DESC) = 1;

-- ---- ACCOUNTS_CLEAN ----
CREATE OR REPLACE DYNAMIC TABLE CONFORMED.ACCOUNTS_CLEAN
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = COMPUTE_WH
AS
SELECT
    account_id,
    customer_id,
    UPPER(TRIM(account_type)) AS account_type,
    UPPER(TRIM(status))       AS status,
    open_date,
    currency,
    current_balance,
    _loaded_at
FROM RAW.ACCOUNTS
QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _loaded_at DESC) = 1;

-- ---- COUNTERPARTIES_CLEAN ----
CREATE OR REPLACE DYNAMIC TABLE CONFORMED.COUNTERPARTIES_CLEAN
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = COMPUTE_WH
AS
SELECT
    counterparty_id,
    INITCAP(TRIM(name))       AS name,
    UPPER(TRIM(type))         AS type,
    UPPER(TRIM(country))      AS country,
    is_pep,
    is_sanctioned,
    _loaded_at
FROM RAW.COUNTERPARTIES
QUALIFY ROW_NUMBER() OVER (PARTITION BY counterparty_id ORDER BY _loaded_at DESC) = 1;

-- ---- TRANSACTIONS_CLEAN ----
CREATE OR REPLACE DYNAMIC TABLE CONFORMED.TRANSACTIONS_CLEAN
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = COMPUTE_WH
AS
SELECT
    transaction_id,
    account_id,
    counterparty_id,
    amount,
    currency,
    UPPER(TRIM(channel))          AS channel,
    UPPER(TRIM(transaction_type)) AS transaction_type,
    timestamp,
    device_id,
    TRIM(geo_location)            AS geo_location,
    TRIM(declared_purpose)        AS declared_purpose,
    _loaded_at
FROM RAW.TRANSACTIONS
QUALIFY ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY _loaded_at DESC) = 1;

-- ---- LOANS_CLEAN ----
CREATE OR REPLACE DYNAMIC TABLE CONFORMED.LOANS_CLEAN
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = COMPUTE_WH
AS
SELECT
    loan_id,
    customer_id,
    principal,
    outstanding,
    disbursement_date,
    tenure_months,
    interest_rate,
    dpd,
    restructuring_flag,
    bureau_score_at_origination,
    latest_bureau_score,
    _loaded_at
FROM RAW.LOANS
QUALIFY ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY _loaded_at DESC) = 1;

-- ---- GENERAL_LEDGER_CLEAN ----
CREATE OR REPLACE DYNAMIC TABLE CONFORMED.GENERAL_LEDGER_CLEAN
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = COMPUTE_WH
AS
SELECT
    entry_id,
    posting_date,
    UPPER(TRIM(gl_code))       AS gl_code,
    TRIM(gl_description)       AS gl_description,
    debit_amount,
    credit_amount,
    balance,
    TRIM(department)           AS department,
    _loaded_at
FROM RAW.GENERAL_LEDGER
QUALIFY ROW_NUMBER() OVER (PARTITION BY entry_id ORDER BY _loaded_at DESC) = 1;

-- ---- DEVICE_SESSIONS_CLEAN ----
CREATE OR REPLACE DYNAMIC TABLE CONFORMED.DEVICE_SESSIONS_CLEAN
    TARGET_LAG = DOWNSTREAM
    WAREHOUSE = COMPUTE_WH
AS
SELECT
    session_id,
    customer_id,
    device_id,
    TRIM(ip_geo)               AS ip_geo,
    login_timestamp,
    UPPER(TRIM(event_type))    AS event_type,
    _loaded_at
FROM RAW.DEVICE_SESSION_LOGS
QUALIFY ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY _loaded_at DESC) = 1;
