-- ============================================================
-- deploy_native_app.sql — Build & Deploy Argus Native App Package
-- Run this script to create the application package and test it
-- ============================================================

USE ROLE ACCOUNTADMIN;

-- ============================================================
-- 1. CREATE APPLICATION PACKAGE
-- ============================================================
CREATE APPLICATION PACKAGE IF NOT EXISTS ARGUS_RISK_COPILOT_PKG;
USE DATABASE ARGUS_RISK_COPILOT_PKG;

-- Stage for app files (setup.sql, manifest.yml, streamlit code)
CREATE SCHEMA IF NOT EXISTS STAGE_CONTENT;
CREATE OR REPLACE STAGE STAGE_CONTENT.APP_CODE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Argus Native App source files';

-- ============================================================
-- 2. SHARED DATA SCHEMA — pre-populated data for consumers
-- ============================================================
CREATE SCHEMA IF NOT EXISTS SHARED_DATA;

-- Copy RAW tables into shared data
CREATE OR REPLACE TABLE SHARED_DATA.CUSTOMERS AS
    SELECT customer_id, name, dob, kyc_risk_rating, address, phone, email,
           onboarding_date, _loaded_at
    FROM ARGUS_RISK_COPILOT.RAW.CUSTOMERS;

CREATE OR REPLACE TABLE SHARED_DATA.ACCOUNTS AS
    SELECT account_id, customer_id, account_type, status, open_date, currency,
           current_balance, _loaded_at
    FROM ARGUS_RISK_COPILOT.RAW.ACCOUNTS;

CREATE OR REPLACE TABLE SHARED_DATA.COUNTERPARTIES AS
    SELECT counterparty_id, name, type, country, is_pep, is_sanctioned, _loaded_at
    FROM ARGUS_RISK_COPILOT.RAW.COUNTERPARTIES;

CREATE OR REPLACE TABLE SHARED_DATA.TRANSACTIONS AS
    SELECT transaction_id, account_id, counterparty_id, amount, currency, channel,
           transaction_type, timestamp, device_id, geo_location, declared_purpose, _loaded_at
    FROM ARGUS_RISK_COPILOT.RAW.TRANSACTIONS;

CREATE OR REPLACE TABLE SHARED_DATA.LOANS AS
    SELECT loan_id, customer_id, principal, outstanding, disbursement_date,
           tenure_months, interest_rate, dpd, restructuring_flag,
           bureau_score_at_origination, latest_bureau_score, _loaded_at
    FROM ARGUS_RISK_COPILOT.RAW.LOANS;

CREATE OR REPLACE TABLE SHARED_DATA.GENERAL_LEDGER AS
    SELECT entry_id, posting_date, gl_code, gl_description, debit_amount,
           credit_amount, balance, department, _loaded_at
    FROM ARGUS_RISK_COPILOT.RAW.GENERAL_LEDGER;

CREATE OR REPLACE TABLE SHARED_DATA.DEVICE_SESSION_LOGS AS
    SELECT session_id, customer_id, device_id, ip_geo, login_timestamp, event_type, _loaded_at
    FROM ARGUS_RISK_COPILOT.RAW.DEVICE_SESSION_LOGS;

CREATE OR REPLACE TABLE SHARED_DATA.WATCHLIST_ENTRIES AS
    SELECT * FROM ARGUS_RISK_COPILOT.RAW.WATCHLIST_ENTRIES;

-- Copy governance tables
CREATE OR REPLACE TABLE SHARED_DATA.CASES AS
    SELECT * FROM ARGUS_RISK_COPILOT.GOVERNANCE.CASES;

CREATE OR REPLACE TABLE SHARED_DATA.FINDINGS AS
    SELECT * FROM ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS;

CREATE OR REPLACE TABLE SHARED_DATA.REVIEWER_ACTIONS AS
    SELECT * FROM ARGUS_RISK_COPILOT.GOVERNANCE.REVIEWER_ACTIONS;

CREATE OR REPLACE TABLE SHARED_DATA.FINDINGS_REPORTS AS
    SELECT * FROM ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS_REPORTS;

CREATE OR REPLACE TABLE SHARED_DATA.NOTIFICATION_CONFIG AS
    SELECT * FROM ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_CONFIG;

CREATE OR REPLACE TABLE SHARED_DATA.NOTIFICATION_LOG AS
    SELECT * FROM ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_LOG;

CREATE OR REPLACE TABLE SHARED_DATA.NOTIFICATION_RECIPIENTS AS
    SELECT * FROM ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_RECIPIENTS;

CREATE OR REPLACE TABLE SHARED_DATA.QUESTION_LOG AS
    SELECT * FROM ARGUS_RISK_COPILOT.GOVERNANCE.QUESTION_LOG;

-- ============================================================
-- 3. UPLOAD FILES TO STAGE
-- Run these PUT commands from SnowSQL or snow CLI:
--
-- PUT 'file://C:/Users/91895/argus/native_app/manifest.yml' @ARGUS_RISK_COPILOT_PKG.STAGE_CONTENT.APP_CODE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT 'file://C:/Users/91895/argus/native_app/setup.sql' @ARGUS_RISK_COPILOT_PKG.STAGE_CONTENT.APP_CODE/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT 'file://C:/Users/91895/argus/native_app/streamlit/streamlit_app.py' @ARGUS_RISK_COPILOT_PKG.STAGE_CONTENT.APP_CODE/streamlit/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- PUT 'file://C:/Users/91895/argus/native_app/streamlit/environment.yml' @ARGUS_RISK_COPILOT_PKG.STAGE_CONTENT.APP_CODE/streamlit/ AUTO_COMPRESS=FALSE OVERWRITE=TRUE;
-- ============================================================

-- ============================================================
-- 4. ADD VERSION (run after PUT commands)
-- ============================================================
-- ALTER APPLICATION PACKAGE ARGUS_RISK_COPILOT_PKG
--     ADD VERSION V1
--     USING '@STAGE_CONTENT.APP_CODE';

-- ============================================================
-- 5. LOCAL TEST — install the app in your own account
-- ============================================================
-- CREATE APPLICATION ARGUS_RISK_COPILOT_APP
--     FROM APPLICATION PACKAGE ARGUS_RISK_COPILOT_PKG
--     USING '@STAGE_CONTENT.APP_CODE';

-- ============================================================
-- 6. PREPARE FOR MARKETPLACE
-- ============================================================
-- ALTER APPLICATION PACKAGE ARGUS_RISK_COPILOT_PKG
--     SET DISTRIBUTION = 'EXTERNAL';
--
-- Then create a listing in Provider Studio:
--   Marketplace -> Provider Studio -> + Create Listing -> Native App
--   Select ARGUS_RISK_COPILOT_PKG as the application package
