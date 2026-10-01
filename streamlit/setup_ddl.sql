-- =============================================================================
-- ARGUS RISK COPILOT -- Complete Database DDL
-- =============================================================================
-- Every object needed to run the Argus dashboard from scratch.
-- Safe to re-run (uses IF NOT EXISTS / CREATE OR REPLACE).
--
-- Object inventory:
--   6 Schemas | 8 RAW tables | 7 CONFORMED dynamic tables | 9 GOVERNANCE tables
--   1 UNSTRUCTURED table | 5 Masking policies | 1 Dynamic table (SIGNALS_ALERTS)
--   5 Stored procedures | 1 Semantic view | 1 Stage | 1 Streamlit app
-- =============================================================================

USE ROLE ACCOUNTADMIN;

-- ═════════════════════════════════════════════════════════════════════════════
-- 1. DATABASE & SCHEMAS
-- ═════════════════════════════════════════════════════════════════════════════

CREATE DATABASE IF NOT EXISTS ARGUS_RISK_COPILOT;

CREATE SCHEMA IF NOT EXISTS ARGUS_RISK_COPILOT.RAW;
CREATE SCHEMA IF NOT EXISTS ARGUS_RISK_COPILOT.CONFORMED;
CREATE SCHEMA IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE;
CREATE SCHEMA IF NOT EXISTS ARGUS_RISK_COPILOT.SEMANTIC;
CREATE SCHEMA IF NOT EXISTS ARGUS_RISK_COPILOT.UNSTRUCTURED;
CREATE SCHEMA IF NOT EXISTS ARGUS_RISK_COPILOT.PUBLIC;


-- ═════════════════════════════════════════════════════════════════════════════
-- 2. RAW SCHEMA -- Source tables (8 tables)
-- ═════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.RAW.CUSTOMERS (
    CUSTOMER_ID           NUMBER(38,0) NOT NULL PRIMARY KEY,
    NAME                  VARCHAR(200) NOT NULL,
    DOB                   DATE,
    KYC_RISK_RATING       VARCHAR(10) NOT NULL,
    ADDRESS               VARCHAR(500),
    PHONE                 VARCHAR(20),
    EMAIL                 VARCHAR(200),
    ONBOARDING_DATE       DATE NOT NULL,
    _GT_STRUCTURING       BOOLEAN DEFAULT FALSE,
    _GT_MULE              BOOLEAN DEFAULT FALSE,
    _GT_ATO               BOOLEAN DEFAULT FALSE,
    _GT_LOAN_STACKING     BOOLEAN DEFAULT FALSE,
    _LOADED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.RAW.ACCOUNTS (
    ACCOUNT_ID            NUMBER(38,0) NOT NULL PRIMARY KEY,
    CUSTOMER_ID           NUMBER(38,0) NOT NULL,
    ACCOUNT_TYPE          VARCHAR(20) NOT NULL,
    STATUS                VARCHAR(20) NOT NULL,
    OPEN_DATE             DATE NOT NULL,
    CURRENCY              VARCHAR(3) DEFAULT 'INR',
    CURRENT_BALANCE       NUMBER(18,2) NOT NULL,
    _GT_MULE              BOOLEAN DEFAULT FALSE,
    _LOADED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.RAW.TRANSACTIONS (
    TRANSACTION_ID        NUMBER(38,0) NOT NULL PRIMARY KEY,
    ACCOUNT_ID            NUMBER(38,0) NOT NULL,
    COUNTERPARTY_ID       NUMBER(38,0),
    AMOUNT                NUMBER(18,2) NOT NULL,
    CURRENCY              VARCHAR(3) DEFAULT 'INR',
    CHANNEL               VARCHAR(20) NOT NULL,
    TRANSACTION_TYPE      VARCHAR(10) NOT NULL,
    TIMESTAMP             TIMESTAMP_NTZ NOT NULL,
    DEVICE_ID             VARCHAR(50),
    GEO_LOCATION          VARCHAR(100),
    DECLARED_PURPOSE      VARCHAR(200),
    _GT_STRUCTURING       BOOLEAN DEFAULT FALSE,
    _GT_MULE              BOOLEAN DEFAULT FALSE,
    _GT_ATO               BOOLEAN DEFAULT FALSE,
    _LOADED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.RAW.LOANS (
    LOAN_ID               NUMBER(38,0) NOT NULL PRIMARY KEY,
    CUSTOMER_ID           NUMBER(38,0) NOT NULL,
    PRINCIPAL             NUMBER(18,2) NOT NULL,
    OUTSTANDING           NUMBER(18,2) NOT NULL,
    DISBURSEMENT_DATE     DATE NOT NULL,
    TENURE_MONTHS         NUMBER(38,0) NOT NULL,
    INTEREST_RATE         NUMBER(5,2) NOT NULL,
    DPD                   NUMBER(38,0) DEFAULT 0,
    RESTRUCTURING_FLAG    BOOLEAN DEFAULT FALSE,
    BUREAU_SCORE_AT_ORIGINATION NUMBER(38,0),
    LATEST_BUREAU_SCORE   NUMBER(38,0),
    _GT_LOAN_STACKING     BOOLEAN DEFAULT FALSE,
    _LOADED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.RAW.GENERAL_LEDGER (
    ENTRY_ID              NUMBER(38,0) NOT NULL PRIMARY KEY,
    POSTING_DATE          DATE NOT NULL,
    GL_CODE               VARCHAR(20) NOT NULL,
    GL_DESCRIPTION        VARCHAR(200) NOT NULL,
    DEBIT_AMOUNT          NUMBER(18,2) DEFAULT 0,
    CREDIT_AMOUNT         NUMBER(18,2) DEFAULT 0,
    BALANCE               NUMBER(18,2) NOT NULL,
    DEPARTMENT            VARCHAR(50),
    _LOADED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.RAW.COUNTERPARTIES (
    COUNTERPARTY_ID       NUMBER(38,0) NOT NULL PRIMARY KEY,
    NAME                  VARCHAR(200) NOT NULL,
    TYPE                  VARCHAR(20) NOT NULL,
    COUNTRY               VARCHAR(5) NOT NULL,
    IS_PEP                BOOLEAN DEFAULT FALSE,
    IS_SANCTIONED         BOOLEAN DEFAULT FALSE,
    _LOADED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.RAW.DEVICE_SESSION_LOGS (
    SESSION_ID            NUMBER(38,0) NOT NULL PRIMARY KEY,
    CUSTOMER_ID           NUMBER(38,0) NOT NULL,
    DEVICE_ID             VARCHAR(50) NOT NULL,
    IP_GEO                VARCHAR(100),
    LOGIN_TIMESTAMP       TIMESTAMP_NTZ NOT NULL,
    EVENT_TYPE            VARCHAR(20) NOT NULL,
    _GT_ATO               BOOLEAN DEFAULT FALSE,
    _LOADED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.RAW.WATCHLIST_ENTRIES (
    WATCHLIST_ID          NUMBER(38,0) NOT NULL PRIMARY KEY,
    ENTITY_NAME           VARCHAR(200) NOT NULL,
    ALIASES               VARCHAR(500),
    LIST_TYPE             VARCHAR(20) NOT NULL,
    SOURCE                VARCHAR(100) NOT NULL,
    EFFECTIVE_DATE        DATE NOT NULL,
    _LOADED_AT            TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);


-- ═════════════════════════════════════════════════════════════════════════════
-- 3. UNSTRUCTURED SCHEMA (1 table)
-- ═════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.UNSTRUCTURED.REFERENCE_DOCUMENTS (
    DOC_ID                NUMBER(38,0) NOT NULL PRIMARY KEY,
    DOC_TYPE              VARCHAR(50) NOT NULL,
    TITLE                 VARCHAR(500) NOT NULL,
    CONTENT               VARCHAR(16777216) NOT NULL,
    VERSION               VARCHAR(20) DEFAULT '1.0',
    EFFECTIVE_DATE        DATE NOT NULL
);


-- ═════════════════════════════════════════════════════════════════════════════
-- 4. GOVERNANCE SCHEMA -- Masking Policies (5 policies)
-- ═════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE MASKING POLICY ARGUS_RISK_COPILOT.GOVERNANCE.MASK_NAME
    AS (VAL VARCHAR) RETURNS VARCHAR ->
    CASE WHEN CURRENT_ROLE() IN ('PLATFORM_ADMIN','COMPLIANCE_OFFICER','AUDITOR','ACCOUNTADMIN')
         THEN val ELSE '***MASKED***' END;

CREATE OR REPLACE MASKING POLICY ARGUS_RISK_COPILOT.GOVERNANCE.MASK_EMAIL
    AS (VAL VARCHAR) RETURNS VARCHAR ->
    CASE WHEN CURRENT_ROLE() IN ('PLATFORM_ADMIN','COMPLIANCE_OFFICER','AUDITOR','ACCOUNTADMIN')
         THEN val ELSE REGEXP_REPLACE(val, '.+@', '****@') END;

CREATE OR REPLACE MASKING POLICY ARGUS_RISK_COPILOT.GOVERNANCE.MASK_PHONE
    AS (VAL VARCHAR) RETURNS VARCHAR ->
    CASE WHEN CURRENT_ROLE() IN ('PLATFORM_ADMIN','COMPLIANCE_OFFICER','AUDITOR','ACCOUNTADMIN')
         THEN val ELSE CONCAT('+91XXXXX', RIGHT(val, 4)) END;

CREATE OR REPLACE MASKING POLICY ARGUS_RISK_COPILOT.GOVERNANCE.MASK_ADDRESS
    AS (VAL VARCHAR) RETURNS VARCHAR ->
    CASE WHEN CURRENT_ROLE() IN ('PLATFORM_ADMIN','COMPLIANCE_OFFICER','AUDITOR','ACCOUNTADMIN')
         THEN val ELSE '***REDACTED***' END;

CREATE OR REPLACE MASKING POLICY ARGUS_RISK_COPILOT.GOVERNANCE.MASK_DEVICE_ID
    AS (VAL VARCHAR) RETURNS VARCHAR ->
    CASE WHEN CURRENT_ROLE() IN ('PLATFORM_ADMIN','COMPLIANCE_OFFICER','FRAUD_ANALYST','AUDITOR','ACCOUNTADMIN')
         THEN val ELSE CONCAT('DEV-', RIGHT(SHA2(val), 6)) END;


-- ═════════════════════════════════════════════════════════════════════════════
-- 5. CONFORMED SCHEMA -- Dynamic Tables (7 tables)
-- ═════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE DYNAMIC TABLE ARGUS_RISK_COPILOT.CONFORMED.CUSTOMERS_CLEAN(
    CUSTOMER_ID, NAME, DOB, KYC_RISK_RATING, ADDRESS, PHONE, EMAIL, ONBOARDING_DATE, _LOADED_AT
) TARGET_LAG = 'DOWNSTREAM' REFRESH_MODE = AUTO INITIALIZE = ON_CREATE WAREHOUSE = COMPUTE_WH
AS
SELECT customer_id, INITCAP(TRIM(name)) AS name, dob, UPPER(TRIM(kyc_risk_rating)) AS kyc_risk_rating,
    TRIM(address) AS address, TRIM(phone) AS phone, LOWER(TRIM(email)) AS email, onboarding_date, _loaded_at
FROM ARGUS_RISK_COPILOT.RAW.CUSTOMERS
QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY _loaded_at DESC) = 1;

CREATE OR REPLACE DYNAMIC TABLE ARGUS_RISK_COPILOT.CONFORMED.ACCOUNTS_CLEAN(
    ACCOUNT_ID, CUSTOMER_ID, ACCOUNT_TYPE, STATUS, OPEN_DATE, CURRENCY, CURRENT_BALANCE, _LOADED_AT
) TARGET_LAG = 'DOWNSTREAM' REFRESH_MODE = AUTO INITIALIZE = ON_CREATE WAREHOUSE = COMPUTE_WH
AS
SELECT account_id, customer_id, UPPER(TRIM(account_type)) AS account_type, UPPER(TRIM(status)) AS status,
    open_date, currency, current_balance, _loaded_at
FROM ARGUS_RISK_COPILOT.RAW.ACCOUNTS
QUALIFY ROW_NUMBER() OVER (PARTITION BY account_id ORDER BY _loaded_at DESC) = 1;

CREATE OR REPLACE DYNAMIC TABLE ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN(
    TRANSACTION_ID, ACCOUNT_ID, COUNTERPARTY_ID, AMOUNT, CURRENCY, CHANNEL, TRANSACTION_TYPE,
    TIMESTAMP, DEVICE_ID, GEO_LOCATION, DECLARED_PURPOSE, _LOADED_AT
) TARGET_LAG = 'DOWNSTREAM' REFRESH_MODE = AUTO INITIALIZE = ON_CREATE WAREHOUSE = COMPUTE_WH
AS
SELECT transaction_id, account_id, counterparty_id, amount, currency,
    UPPER(TRIM(channel)) AS channel, UPPER(TRIM(transaction_type)) AS transaction_type,
    timestamp, device_id, TRIM(geo_location) AS geo_location, TRIM(declared_purpose) AS declared_purpose, _loaded_at
FROM ARGUS_RISK_COPILOT.RAW.TRANSACTIONS
QUALIFY ROW_NUMBER() OVER (PARTITION BY transaction_id ORDER BY _loaded_at DESC) = 1;

CREATE OR REPLACE DYNAMIC TABLE ARGUS_RISK_COPILOT.CONFORMED.LOANS_CLEAN(
    LOAN_ID, CUSTOMER_ID, PRINCIPAL, OUTSTANDING, DISBURSEMENT_DATE, TENURE_MONTHS,
    INTEREST_RATE, DPD, RESTRUCTURING_FLAG, BUREAU_SCORE_AT_ORIGINATION, LATEST_BUREAU_SCORE, _LOADED_AT
) TARGET_LAG = 'DOWNSTREAM' REFRESH_MODE = AUTO INITIALIZE = ON_CREATE WAREHOUSE = COMPUTE_WH
AS
SELECT loan_id, customer_id, principal, outstanding, disbursement_date, tenure_months,
    interest_rate, dpd, restructuring_flag, bureau_score_at_origination, latest_bureau_score, _loaded_at
FROM ARGUS_RISK_COPILOT.RAW.LOANS
QUALIFY ROW_NUMBER() OVER (PARTITION BY loan_id ORDER BY _loaded_at DESC) = 1;

CREATE OR REPLACE DYNAMIC TABLE ARGUS_RISK_COPILOT.CONFORMED.GENERAL_LEDGER_CLEAN(
    ENTRY_ID, POSTING_DATE, GL_CODE, GL_DESCRIPTION, DEBIT_AMOUNT, CREDIT_AMOUNT,
    BALANCE, DEPARTMENT, _LOADED_AT
) TARGET_LAG = 'DOWNSTREAM' REFRESH_MODE = AUTO INITIALIZE = ON_CREATE WAREHOUSE = COMPUTE_WH
AS
SELECT entry_id, posting_date, UPPER(TRIM(gl_code)) AS gl_code, TRIM(gl_description) AS gl_description,
    debit_amount, credit_amount, balance, TRIM(department) AS department, _loaded_at
FROM ARGUS_RISK_COPILOT.RAW.GENERAL_LEDGER
QUALIFY ROW_NUMBER() OVER (PARTITION BY entry_id ORDER BY _loaded_at DESC) = 1;

CREATE OR REPLACE DYNAMIC TABLE ARGUS_RISK_COPILOT.CONFORMED.COUNTERPARTIES_CLEAN(
    COUNTERPARTY_ID, NAME, TYPE, COUNTRY, IS_PEP, IS_SANCTIONED, _LOADED_AT
) TARGET_LAG = 'DOWNSTREAM' REFRESH_MODE = AUTO INITIALIZE = ON_CREATE WAREHOUSE = COMPUTE_WH
AS
SELECT counterparty_id, INITCAP(TRIM(name)) AS name, UPPER(TRIM(type)) AS type,
    UPPER(TRIM(country)) AS country, is_pep, is_sanctioned, _loaded_at
FROM ARGUS_RISK_COPILOT.RAW.COUNTERPARTIES
QUALIFY ROW_NUMBER() OVER (PARTITION BY counterparty_id ORDER BY _loaded_at DESC) = 1;

CREATE OR REPLACE DYNAMIC TABLE ARGUS_RISK_COPILOT.CONFORMED.DEVICE_SESSIONS_CLEAN(
    SESSION_ID, CUSTOMER_ID, DEVICE_ID, IP_GEO, LOGIN_TIMESTAMP, EVENT_TYPE, _LOADED_AT
) TARGET_LAG = 'DOWNSTREAM' REFRESH_MODE = AUTO INITIALIZE = ON_CREATE WAREHOUSE = COMPUTE_WH
AS
SELECT session_id, customer_id, device_id, TRIM(ip_geo) AS ip_geo,
    login_timestamp, UPPER(TRIM(event_type)) AS event_type, _loaded_at
FROM ARGUS_RISK_COPILOT.RAW.DEVICE_SESSION_LOGS
QUALIFY ROW_NUMBER() OVER (PARTITION BY session_id ORDER BY _loaded_at DESC) = 1;


-- ═════════════════════════════════════════════════════════════════════════════
-- 6. GOVERNANCE SCHEMA -- Application Tables (9 tables)
-- ═════════════════════════════════════════════════════════════════════════════

-- 6a. SIGNALS_ALERTS -- Dynamic table: fraud/AML/credit signal detection engine
CREATE OR REPLACE DYNAMIC TABLE ARGUS_RISK_COPILOT.GOVERNANCE.SIGNALS_ALERTS(
    SIGNAL_ID, SIGNAL_TYPE, ENTITY_ID, ENTITY_TYPE, DETECTED_AT,
    SEVERITY, CONFIDENCE, EVIDENCE_JSON, RULE_VERSION
) TARGET_LAG = '15 minutes' REFRESH_MODE = AUTO INITIALIZE = ON_CREATE WAREHOUSE = COMPUTE_WH
AS
WITH
structuring_pairs AS (
    SELECT t1.account_id, a.customer_id, t1.transaction_id AS anchor_txn, t1.timestamp AS anchor_ts,
        t2.transaction_id AS paired_txn, t2.timestamp AS paired_ts, t2.amount, t2.geo_location
    FROM ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN t1
    JOIN ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN t2
        ON t2.account_id = t1.account_id AND t2.transaction_type = 'CREDIT'
        AND t2.channel IN ('BRANCH', 'ATM') AND t2.amount BETWEEN 250000 AND 350000
        AND t2.timestamp BETWEEN t1.timestamp AND DATEADD(hour, 48, t1.timestamp)
    JOIN ARGUS_RISK_COPILOT.CONFORMED.ACCOUNTS_CLEAN a ON a.account_id = t1.account_id
    WHERE t1.transaction_type = 'CREDIT' AND t1.channel IN ('BRANCH', 'ATM') AND t1.amount BETWEEN 250000 AND 350000
),
structuring_signals AS (
    SELECT account_id, customer_id, anchor_txn,
        MIN(paired_ts) AS window_start, MAX(paired_ts) AS window_end,
        COUNT(DISTINCT paired_txn) AS deposit_count, SUM(DISTINCT amount) AS total_amount,
        COUNT(DISTINCT geo_location) AS distinct_geos,
        ARRAY_AGG(DISTINCT paired_txn) AS evidence_txn_ids, ARRAY_AGG(DISTINCT geo_location) AS evidence_geos
    FROM structuring_pairs
    GROUP BY account_id, customer_id, anchor_txn
    HAVING deposit_count >= 3 AND total_amount BETWEEN 700000 AND 1100000 AND distinct_geos >= 2
),
structuring_out AS (
    SELECT MD5(customer_id::VARCHAR || '|STRUCTURING|' || window_start::VARCHAR) AS signal_id,
        'STRUCTURING' AS signal_type, customer_id::VARCHAR AS entity_id, 'CUSTOMER' AS entity_type,
        window_end AS detected_at, 'HIGH' AS severity,
        CASE WHEN total_amount >= 900000 THEN 0.95 WHEN total_amount >= 800000 THEN 0.85 ELSE 0.75 END AS confidence,
        OBJECT_CONSTRUCT('account_id', account_id, 'deposit_count', deposit_count, 'total_amount', total_amount,
            'distinct_geos', distinct_geos, 'transaction_ids', evidence_txn_ids, 'geolocations', evidence_geos,
            'policy_ref', 'AML Policy Manual, Section 4.2')::VARIANT AS evidence_json,
        'v1.0' AS rule_version
    FROM structuring_signals
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_amount DESC) = 1
),
account_activity_gaps AS (
    SELECT account_id, timestamp,
        LAG(timestamp) OVER (PARTITION BY account_id ORDER BY timestamp) AS prev_ts,
        DATEDIFF(day, LAG(timestamp) OVER (PARTITION BY account_id ORDER BY timestamp), timestamp) AS gap_days
    FROM ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN
),
dormant_reactivations AS (
    SELECT DISTINCT account_id, timestamp AS reactivation_ts
    FROM account_activity_gaps WHERE gap_days >= 60
),
mule_inbound AS (
    SELECT t.account_id, dr.reactivation_ts, COUNT(DISTINCT t.counterparty_id) AS distinct_senders,
        COUNT(*) AS inbound_count, SUM(t.amount) AS inbound_total, ARRAY_AGG(DISTINCT t.transaction_id) AS inbound_txn_ids
    FROM ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN t
    JOIN dormant_reactivations dr ON dr.account_id = t.account_id
    WHERE t.transaction_type = 'CREDIT' AND t.timestamp BETWEEN dr.reactivation_ts AND DATEADD(hour, 48, dr.reactivation_ts)
    GROUP BY t.account_id, dr.reactivation_ts HAVING distinct_senders >= 10
),
mule_outbound AS (
    SELECT t.account_id, mi.reactivation_ts, COUNT(*) AS outbound_count, SUM(t.amount) AS outbound_total,
        ARRAY_AGG(DISTINCT t.transaction_id) AS outbound_txn_ids
    FROM ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN t
    JOIN mule_inbound mi ON mi.account_id = t.account_id
    WHERE t.transaction_type = 'DEBIT' AND t.timestamp BETWEEN mi.reactivation_ts AND DATEADD(hour, 72, mi.reactivation_ts)
    GROUP BY t.account_id, mi.reactivation_ts
),
mule_out AS (
    SELECT MD5(mi.account_id::VARCHAR || '|MONEY_MULE|' || mi.reactivation_ts::VARCHAR) AS signal_id,
        'MONEY_MULE' AS signal_type, a.customer_id::VARCHAR AS entity_id, 'CUSTOMER' AS entity_type,
        mi.reactivation_ts AS detected_at, 'CRITICAL' AS severity, 0.90 AS confidence,
        OBJECT_CONSTRUCT('account_id', mi.account_id, 'dormancy_reactivation', mi.reactivation_ts,
            'distinct_senders', mi.distinct_senders, 'inbound_count', mi.inbound_count,
            'inbound_total', mi.inbound_total, 'outbound_count', COALESCE(mo.outbound_count, 0),
            'outbound_total', COALESCE(mo.outbound_total, 0), 'inbound_txn_ids', mi.inbound_txn_ids,
            'outbound_txn_ids', mo.outbound_txn_ids, 'policy_ref', 'AML Policy Manual, Section 4.3')::VARIANT AS evidence_json,
        'v1.0' AS rule_version
    FROM mule_inbound mi
    JOIN ARGUS_RISK_COPILOT.CONFORMED.ACCOUNTS_CLEAN a ON a.account_id = mi.account_id
    LEFT JOIN mule_outbound mo ON mo.account_id = mi.account_id AND mo.reactivation_ts = mi.reactivation_ts
),
new_device_logins AS (
    SELECT s.customer_id, s.device_id, s.login_timestamp, s.session_id
    FROM ARGUS_RISK_COPILOT.CONFORMED.DEVICE_SESSIONS_CLEAN s
    WHERE s.event_type = 'LOGIN'
      AND NOT EXISTS (
          SELECT 1 FROM ARGUS_RISK_COPILOT.CONFORMED.DEVICE_SESSIONS_CLEAN older
          WHERE older.customer_id = s.customer_id AND older.device_id = s.device_id AND older.login_timestamp < s.login_timestamp
      )
),
ato_contact_changes AS (
    SELECT ndl.customer_id, ndl.device_id, ndl.login_timestamp, ndl.session_id AS login_session_id,
        cc.session_id AS change_session_id, cc.login_timestamp AS change_timestamp
    FROM new_device_logins ndl
    JOIN ARGUS_RISK_COPILOT.CONFORMED.DEVICE_SESSIONS_CLEAN cc
        ON cc.customer_id = ndl.customer_id AND cc.event_type IN ('CONTACT_CHANGE', 'PASSWORD_RESET')
        AND cc.login_timestamp BETWEEN ndl.login_timestamp AND DATEADD(minute, 60, ndl.login_timestamp)
),
ato_transfers AS (
    SELECT acc.customer_id, acc.device_id, acc.login_timestamp, acc.change_timestamp,
        t.transaction_id, t.amount, t.counterparty_id, t.timestamp AS transfer_timestamp
    FROM ato_contact_changes acc
    JOIN ARGUS_RISK_COPILOT.CONFORMED.ACCOUNTS_CLEAN a ON a.customer_id = acc.customer_id
    JOIN ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN t ON t.account_id = a.account_id
        AND t.transaction_type = 'DEBIT' AND t.amount >= 200000
        AND t.timestamp BETWEEN acc.change_timestamp AND DATEADD(minute, 120, acc.change_timestamp)
),
ato_out AS (
    SELECT MD5(customer_id::VARCHAR || '|ACCOUNT_TAKEOVER|' || login_timestamp::VARCHAR) AS signal_id,
        'ACCOUNT_TAKEOVER' AS signal_type, customer_id::VARCHAR AS entity_id, 'CUSTOMER' AS entity_type,
        transfer_timestamp AS detected_at, 'CRITICAL' AS severity, 0.92 AS confidence,
        OBJECT_CONSTRUCT('customer_id', customer_id, 'new_device_id', device_id, 'login_timestamp', login_timestamp,
            'contact_change_timestamp', change_timestamp, 'transfer_timestamp', transfer_timestamp,
            'transfer_amount', amount, 'counterparty_id', counterparty_id, 'transaction_id', transaction_id,
            'policy_ref', 'ATO Response Procedure, Section 2.1')::VARIANT AS evidence_json,
        'v1.0' AS rule_version
    FROM ato_transfers
    UNION ALL
    SELECT MD5(acc.customer_id::VARCHAR || '|ATO_SUSPICIOUS|' || acc.login_timestamp::VARCHAR) AS signal_id,
        'ACCOUNT_TAKEOVER' AS signal_type, acc.customer_id::VARCHAR AS entity_id, 'CUSTOMER' AS entity_type,
        acc.change_timestamp AS detected_at, 'HIGH' AS severity, 0.78 AS confidence,
        OBJECT_CONSTRUCT('customer_id', acc.customer_id, 'new_device_id', acc.device_id,
            'login_timestamp', acc.login_timestamp, 'suspicious_event_timestamp', acc.change_timestamp,
            'policy_ref', 'ATO Response Procedure, Section 1.3')::VARIANT AS evidence_json,
        'v1.1' AS rule_version
    FROM ato_contact_changes acc
    WHERE NOT EXISTS (
        SELECT 1 FROM ato_transfers at2
        WHERE at2.customer_id = acc.customer_id AND at2.login_timestamp = acc.login_timestamp
    )
),
loan_windows AS (
    SELECT l1.customer_id, l1.loan_id AS anchor_loan_id, l1.disbursement_date AS window_start,
        DATEADD(day, 14, l1.disbursement_date) AS window_end, COUNT(l2.loan_id) AS loans_in_window,
        SUM(l2.principal) AS total_principal, ARRAY_AGG(DISTINCT l2.loan_id) AS loan_ids,
        MIN(l2.latest_bureau_score) AS min_bureau_score
    FROM ARGUS_RISK_COPILOT.CONFORMED.LOANS_CLEAN l1
    JOIN ARGUS_RISK_COPILOT.CONFORMED.LOANS_CLEAN l2
        ON l2.customer_id = l1.customer_id
        AND l2.disbursement_date BETWEEN l1.disbursement_date AND DATEADD(day, 14, l1.disbursement_date)
    GROUP BY l1.customer_id, l1.loan_id, l1.disbursement_date
    HAVING loans_in_window >= 3 AND total_principal > 2500000
),
loan_stacking_out AS (
    SELECT MD5(customer_id::VARCHAR || '|LOAN_STACKING|' || window_start::VARCHAR) AS signal_id,
        'LOAN_STACKING' AS signal_type, customer_id::VARCHAR AS entity_id, 'CUSTOMER' AS entity_type,
        window_end AS detected_at, 'HIGH' AS severity,
        CASE WHEN total_principal > 5000000 THEN 0.95 WHEN total_principal > 3500000 THEN 0.85 ELSE 0.75 END AS confidence,
        OBJECT_CONSTRUCT('customer_id', customer_id, 'window_start', window_start, 'window_end', window_end,
            'loans_in_window', loans_in_window, 'total_principal', total_principal, 'loan_ids', loan_ids,
            'min_bureau_score', min_bureau_score, 'policy_ref', 'Credit Risk Policy, Section 2.1-2.3')::VARIANT AS evidence_json,
        'v1.0' AS rule_version
    FROM loan_windows
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_principal DESC) = 1
)
SELECT * FROM structuring_out
UNION ALL SELECT * FROM mule_out
UNION ALL SELECT * FROM ato_out
UNION ALL SELECT * FROM loan_stacking_out;

-- 6b. CASES
CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE.CASES (
    CASE_ID         VARCHAR(40) NOT NULL PRIMARY KEY,
    SIGNAL_ID       VARCHAR(40) NOT NULL,
    SIGNAL_TYPE     VARCHAR(30) NOT NULL,
    CUSTOMER_ID     NUMBER(38,0),
    ACCOUNT_ID      NUMBER(38,0),
    STATUS          VARCHAR(30) NOT NULL,
    PRIORITY        VARCHAR(10) NOT NULL,
    ASSIGNED_TO     VARCHAR(50),
    ASSIGNED_ROLE   VARCHAR(30),
    CREATED_AT      TIMESTAMP_NTZ NOT NULL,
    UPDATED_AT      TIMESTAMP_NTZ NOT NULL,
    CLOSED_AT       TIMESTAMP_NTZ,
    RESOLUTION      VARCHAR(50)
);

-- 6c. FINDINGS
CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS (
    FINDING_ID       VARCHAR(40) NOT NULL PRIMARY KEY,
    CASE_ID          VARCHAR(40) NOT NULL,
    FINDING_TYPE     VARCHAR(30) NOT NULL,
    CONFIDENCE       NUMBER(3,2) NOT NULL,
    NARRATIVE        VARCHAR(4000),
    EVIDENCE_SUMMARY VARCHAR(2000),
    POLICY_REFERENCE VARCHAR(500),
    CREATED_BY       VARCHAR(50),
    CREATED_AT       TIMESTAMP_NTZ NOT NULL
);

-- 6d. REVIEWER_ACTIONS
CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE.REVIEWER_ACTIONS (
    ACTION_ID        VARCHAR(40) NOT NULL PRIMARY KEY,
    FINDING_ID       VARCHAR(40) NOT NULL,
    CASE_ID          VARCHAR(40) NOT NULL,
    REVIEWER_NAME    VARCHAR(50) NOT NULL,
    REVIEWER_ROLE    VARCHAR(30) NOT NULL,
    ACTION_TYPE      VARCHAR(20) NOT NULL,
    COMMENT          VARCHAR(1000),
    ACTION_TIMESTAMP TIMESTAMP_NTZ NOT NULL
);

-- 6e. FINDINGS_REPORTS
CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS_REPORTS (
    REPORT_ID        VARCHAR NOT NULL PRIMARY KEY,
    CASE_ID          VARCHAR,
    REPORT_TYPE      VARCHAR,
    TITLE            VARCHAR,
    NARRATIVE        VARCHAR,
    EVIDENCE_SUMMARY VARCHAR,
    POLICY_CITATIONS VARCHAR,
    TYPOLOGY         VARCHAR,
    CUSTOMER_ID      NUMBER(38,0),
    CONFIDENCE       FLOAT,
    STATUS           VARCHAR DEFAULT 'DRAFT',
    VERSION          NUMBER(38,0) DEFAULT 1,
    CREATED_BY       VARCHAR,
    CREATED_AT       TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    APPROVED_BY      VARCHAR,
    APPROVED_AT      TIMESTAMP_LTZ
);

-- 6f. QUESTION_LOG
CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE.QUESTION_LOG (
    LOG_ID           NUMBER(38,0) NOT NULL AUTOINCREMENT PRIMARY KEY,
    SESSION_ID       VARCHAR,
    QUESTION         VARCHAR,
    TOOL_USED        VARCHAR,
    CONFIDENCE       FLOAT,
    RESPONSE_SUMMARY VARCHAR,
    USER_ROLE        VARCHAR,
    QUERIED_BY       VARCHAR,
    TIMESTAMP        TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 6g. NOTIFICATION_RECIPIENTS
CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_RECIPIENTS (
    RECIPIENT_ID   NUMBER(38,0) NOT NULL AUTOINCREMENT PRIMARY KEY,
    EMAIL          VARCHAR NOT NULL,
    DISPLAY_NAME   VARCHAR,
    ROLE_FILTER    VARCHAR,
    ALERT_SIGNALS  BOOLEAN DEFAULT TRUE,
    ALERT_FINDINGS BOOLEAN DEFAULT TRUE,
    ALERT_REPORTS  BOOLEAN DEFAULT TRUE,
    ALERT_DIGEST   BOOLEAN DEFAULT TRUE,
    MIN_SEVERITY   VARCHAR DEFAULT 'HIGH',
    ACTIVE         BOOLEAN DEFAULT TRUE,
    ADDED_AT       TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 6h. NOTIFICATION_CONFIG
CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_CONFIG (
    CHANNEL      VARCHAR NOT NULL,
    LOOP_STAGE   VARCHAR NOT NULL,
    ENABLED      BOOLEAN DEFAULT FALSE,
    DESTINATION  VARCHAR,
    MIN_SEVERITY VARCHAR DEFAULT 'HIGH',
    UPDATED_AT   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (CHANNEL, LOOP_STAGE)
);

-- 6i. NOTIFICATION_LOG
CREATE TABLE IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_LOG (
    NOTIF_ID      NUMBER(38,0) NOT NULL AUTOINCREMENT PRIMARY KEY,
    EVENT_TYPE    VARCHAR,
    ENTITY_TYPE   VARCHAR,
    ENTITY_ID     VARCHAR,
    CHANNEL       VARCHAR,
    LOOP_STAGE    VARCHAR,
    DESTINATION   VARCHAR,
    STATUS        VARCHAR,
    ERROR_MESSAGE VARCHAR,
    SENT_AT       TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);


-- ═════════════════════════════════════════════════════════════════════════════
-- 7. SEED DATA -- Default Notification Channel Config (13 rows)
-- ═════════════════════════════════════════════════════════════════════════════

MERGE INTO ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_CONFIG AS t
USING (
    SELECT column1 AS CHANNEL, column2 AS LOOP_STAGE, column3 AS ENABLED, column4 AS MIN_SEVERITY
    FROM VALUES
        ('EMAIL',  'SIGNAL_DETECTED',     TRUE,  'HIGH'),
        ('EMAIL',  'FINDING_CREATED',     TRUE,  'MEDIUM'),
        ('EMAIL',  'REPORT_DRAFTED',      TRUE,  'MEDIUM'),
        ('EMAIL',  'CASE_STATUS_CHANGE',  TRUE,  'LOW'),
        ('EMAIL',  'DAILY_DIGEST',        TRUE,  'LOW'),
        ('SLACK',  'SIGNAL_DETECTED',     FALSE, 'HIGH'),
        ('SLACK',  'FINDING_CREATED',     FALSE, 'HIGH'),
        ('SLACK',  'CASE_STATUS_CHANGE',  FALSE, 'MEDIUM'),
        ('SMS',    'SIGNAL_DETECTED',     FALSE, 'CRITICAL'),
        ('TEAMS',  'SIGNAL_DETECTED',     FALSE, 'HIGH'),
        ('TEAMS',  'CASE_STATUS_CHANGE',  FALSE, 'HIGH'),
        ('JIRA',   'FINDING_CREATED',     FALSE, 'MEDIUM'),
        ('JIRA',   'REPORT_DRAFTED',      FALSE, 'MEDIUM')
) AS s ON t.CHANNEL = s.CHANNEL AND t.LOOP_STAGE = s.LOOP_STAGE
WHEN NOT MATCHED THEN INSERT (CHANNEL, LOOP_STAGE, ENABLED, MIN_SEVERITY)
    VALUES (s.CHANNEL, s.LOOP_STAGE, s.ENABLED, s.MIN_SEVERITY);


-- ═════════════════════════════════════════════════════════════════════════════
-- 8. STORED PROCEDURES (5 procedures)
-- ═════════════════════════════════════════════════════════════════════════════

-- 8a. DRAFT_FINDING_REPORT
CREATE OR REPLACE PROCEDURE ARGUS_RISK_COPILOT.GOVERNANCE.DRAFT_FINDING_REPORT(
    P_CASE_ID VARCHAR, P_REPORT_TYPE VARCHAR, P_TITLE VARCHAR,
    P_NARRATIVE VARCHAR, P_EVIDENCE VARCHAR, P_POLICY VARCHAR,
    P_CONFIDENCE FLOAT, P_TYPOLOGY VARCHAR, P_CUSTOMER_ID NUMBER
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    LET v_report_id VARCHAR := 'RPT-' || REPLACE(:P_CASE_ID, 'CASE-', '') || '-' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS');
    INSERT INTO ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS_REPORTS
        (REPORT_ID, CASE_ID, REPORT_TYPE, TITLE, NARRATIVE, EVIDENCE_SUMMARY,
         POLICY_CITATIONS, TYPOLOGY, CUSTOMER_ID, CONFIDENCE, STATUS, CREATED_BY, CREATED_AT)
    VALUES (:v_report_id, :P_CASE_ID, :P_REPORT_TYPE, :P_TITLE, :P_NARRATIVE, :P_EVIDENCE,
            :P_POLICY, :P_TYPOLOGY, :P_CUSTOMER_ID, :P_CONFIDENCE, 'DRAFT', CURRENT_USER(), CURRENT_TIMESTAMP());
    RETURN 'Report ' || :v_report_id || ' drafted successfully.';
END;

-- 8b. APPROVE_REPORT
CREATE OR REPLACE PROCEDURE ARGUS_RISK_COPILOT.GOVERNANCE.APPROVE_REPORT(
    P_REPORT_ID VARCHAR, P_ACTION VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    IF (:P_ACTION = 'APPROVE') THEN
        UPDATE ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS_REPORTS
        SET STATUS = 'APPROVED', APPROVED_BY = CURRENT_USER(), APPROVED_AT = CURRENT_TIMESTAMP()
        WHERE REPORT_ID = :P_REPORT_ID;
        RETURN 'Report ' || :P_REPORT_ID || ' approved by ' || CURRENT_USER();
    ELSEIF (:P_ACTION = 'RETURN') THEN
        UPDATE ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS_REPORTS SET STATUS = 'RETURNED' WHERE REPORT_ID = :P_REPORT_ID;
        RETURN 'Report ' || :P_REPORT_ID || ' returned for edits.';
    ELSEIF (:P_ACTION = 'REJECT') THEN
        UPDATE ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS_REPORTS SET STATUS = 'REJECTED' WHERE REPORT_ID = :P_REPORT_ID;
        RETURN 'Report ' || :P_REPORT_ID || ' rejected.';
    ELSE
        RETURN 'Unknown action: ' || :P_ACTION;
    END IF;
END;

-- 8c. NOTIFY_STATE_CHANGE
CREATE OR REPLACE PROCEDURE ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFY_STATE_CHANGE(
    P_ENTITY_TYPE VARCHAR, P_ENTITY_ID VARCHAR,
    P_OLD_STATUS VARCHAR, P_NEW_STATUS VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    INSERT INTO ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_LOG
        (EVENT_TYPE, ENTITY_TYPE, ENTITY_ID, CHANNEL, LOOP_STAGE, STATUS, SENT_AT)
    VALUES ('STATE_CHANGE', :P_ENTITY_TYPE, :P_ENTITY_ID, 'EMAIL', 'CASE_STATUS_CHANGE',
            'SENT', CURRENT_TIMESTAMP());
    RETURN :P_ENTITY_TYPE || ' ' || :P_ENTITY_ID || ' notification logged: ' || :P_OLD_STATUS || ' -> ' || :P_NEW_STATUS;
END;

-- 8d. REBUILD_EMAIL_INTEGRATION
CREATE OR REPLACE PROCEDURE ARGUS_RISK_COPILOT.GOVERNANCE.REBUILD_EMAIL_INTEGRATION()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    LET v_emails VARCHAR;
    SELECT LISTAGG('''' || EMAIL || '''', ', ') INTO :v_emails
    FROM ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_RECIPIENTS WHERE ACTIVE = TRUE;

    IF (:v_emails IS NULL OR :v_emails = '') THEN
        RETURN 'No active recipients found. Add recipients first.';
    END IF;

    EXECUTE IMMEDIATE
        'CREATE OR REPLACE NOTIFICATION INTEGRATION ARGUS_EMAIL_INTEGRATION ' ||
        'TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = (' || :v_emails || ')';
    RETURN 'Email integration rebuilt with active recipients.';
END;

-- 8e. SEND_TEST_EMAIL
CREATE OR REPLACE PROCEDURE ARGUS_RISK_COPILOT.GOVERNANCE.SEND_TEST_EMAIL(P_EMAIL VARCHAR)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    CALL SYSTEM$SEND_EMAIL(
        'ARGUS_EMAIL_INTEGRATION',
        :P_EMAIL,
        'Argus Test Notification',
        'This is a test notification from Argus Risk Copilot. If you received this, your email integration is working correctly.'
    );
    RETURN 'Test email sent to ' || :P_EMAIL;
EXCEPTION
    WHEN OTHER THEN
        RETURN 'Failed to send test email: ' || SQLERRM;
END;


-- ═════════════════════════════════════════════════════════════════════════════
-- 9. SEMANTIC VIEW
-- ═════════════════════════════════════════════════════════════════════════════

CREATE OR REPLACE SEMANTIC VIEW ARGUS_RISK_COPILOT.SEMANTIC.ARGUS_COPILOT_SV
    TABLES (
        CUSTOMERS AS ARGUS_RISK_COPILOT.CONFORMED.CUSTOMERS_CLEAN PRIMARY KEY (CUSTOMER_ID),
        ACCOUNTS AS ARGUS_RISK_COPILOT.CONFORMED.ACCOUNTS_CLEAN PRIMARY KEY (ACCOUNT_ID),
        TRANSACTIONS AS ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN PRIMARY KEY (TRANSACTION_ID),
        COUNTERPARTIES AS ARGUS_RISK_COPILOT.CONFORMED.COUNTERPARTIES_CLEAN PRIMARY KEY (COUNTERPARTY_ID),
        LOANS AS ARGUS_RISK_COPILOT.CONFORMED.LOANS_CLEAN PRIMARY KEY (LOAN_ID),
        GENERAL_LEDGER AS ARGUS_RISK_COPILOT.CONFORMED.GENERAL_LEDGER_CLEAN PRIMARY KEY (ENTRY_ID),
        DEVICE_SESSIONS AS ARGUS_RISK_COPILOT.CONFORMED.DEVICE_SESSIONS_CLEAN PRIMARY KEY (SESSION_ID),
        SIGNALS AS ARGUS_RISK_COPILOT.GOVERNANCE.SIGNALS_ALERTS PRIMARY KEY (SIGNAL_ID),
        ARGUS_RISK_COPILOT.GOVERNANCE.CASES PRIMARY KEY (CASE_ID) UNIQUE (SIGNAL_ID),
        ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS PRIMARY KEY (FINDING_ID),
        ARGUS_RISK_COPILOT.GOVERNANCE.REVIEWER_ACTIONS PRIMARY KEY (ACTION_ID)
    )
    RELATIONSHIPS (
        ACCOUNTS_TO_CUSTOMERS AS ACCOUNTS(CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID),
        TRANSACTIONS_TO_ACCOUNTS AS TRANSACTIONS(ACCOUNT_ID) REFERENCES ACCOUNTS(ACCOUNT_ID),
        TRANSACTIONS_TO_COUNTERPARTIES AS TRANSACTIONS(COUNTERPARTY_ID) REFERENCES COUNTERPARTIES(COUNTERPARTY_ID),
        LOANS_TO_CUSTOMERS AS LOANS(CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID),
        DEVICE_SESSIONS_TO_CUSTOMERS AS DEVICE_SESSIONS(CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID),
        CASES_TO_CUSTOMERS AS CASES(CUSTOMER_ID) REFERENCES CUSTOMERS(CUSTOMER_ID),
        CASES_TO_SIGNALS AS CASES(SIGNAL_ID) REFERENCES SIGNALS(SIGNAL_ID),
        FINDINGS_TO_CASES AS FINDINGS(CASE_ID) REFERENCES CASES(CASE_ID),
        ACTIONS_TO_FINDINGS AS REVIEWER_ACTIONS(FINDING_ID) REFERENCES FINDINGS(FINDING_ID)
    )
    FACTS (
        ACCOUNTS.BALANCE AS ACCOUNTS.CURRENT_BALANCE,
        TRANSACTIONS.AMOUNT AS TRANSACTIONS.AMOUNT,
        LOANS.PRINCIPAL AS LOANS.PRINCIPAL,
        LOANS.OUTSTANDING AS LOANS.OUTSTANDING,
        LOANS.SCORE_DROP AS LOANS.BUREAU_SCORE_AT_ORIGINATION - LOANS.LATEST_BUREAU_SCORE,
        GENERAL_LEDGER.GL_BALANCE AS GENERAL_LEDGER.BALANCE,
        SIGNALS.CONFIDENCE AS SIGNALS.CONFIDENCE,
        FINDINGS.FINDING_CONFIDENCE AS FINDINGS.CONFIDENCE
    )
    DIMENSIONS (
        CUSTOMERS.CUSTOMER_NAME AS CUSTOMERS.NAME,
        CUSTOMERS.KYC_RISK AS CUSTOMERS.KYC_RISK_RATING,
        CUSTOMERS.ONBOARDING AS CUSTOMERS.ONBOARDING_DATE,
        ACCOUNTS.ACCT_TYPE AS ACCOUNTS.ACCOUNT_TYPE,
        ACCOUNTS.ACCT_STATUS AS ACCOUNTS.STATUS,
        TRANSACTIONS.CHANNEL AS TRANSACTIONS.CHANNEL,
        TRANSACTIONS.TXN_TYPE AS TRANSACTIONS.TRANSACTION_TYPE,
        TRANSACTIONS.TXN_TIME AS TRANSACTIONS.TIMESTAMP,
        TRANSACTIONS.PURPOSE AS TRANSACTIONS.DECLARED_PURPOSE,
        TRANSACTIONS.GEO AS TRANSACTIONS.GEO_LOCATION,
        COUNTERPARTIES.CP_NAME AS COUNTERPARTIES.NAME,
        COUNTERPARTIES.CP_COUNTRY AS COUNTERPARTIES.COUNTRY,
        COUNTERPARTIES.CP_IS_PEP AS COUNTERPARTIES.IS_PEP,
        COUNTERPARTIES.CP_IS_SANCTIONED AS COUNTERPARTIES.IS_SANCTIONED,
        LOANS.DPD AS LOANS.DPD,
        LOANS.DPD_BUCKET AS CASE WHEN LOANS.DPD = 0 THEN 'CURRENT' WHEN LOANS.DPD <= 30 THEN 'SMA-0' WHEN LOANS.DPD <= 60 THEN 'SMA-1' WHEN LOANS.DPD <= 90 THEN 'SMA-2' WHEN LOANS.DPD <= 180 THEN 'SUB-STANDARD' ELSE 'DOUBTFUL' END,
        LOANS.DISB_DATE AS LOANS.DISBURSEMENT_DATE,
        GENERAL_LEDGER.GL_CODE AS GENERAL_LEDGER.GL_CODE,
        GENERAL_LEDGER.GL_DESC AS GENERAL_LEDGER.GL_DESCRIPTION,
        GENERAL_LEDGER.POSTING_DATE AS GENERAL_LEDGER.POSTING_DATE,
        SIGNALS.SIGNAL_TYPE AS SIGNALS.SIGNAL_TYPE,
        SIGNALS.SEVERITY AS SIGNALS.SEVERITY,
        SIGNALS.DETECTED_AT AS SIGNALS.DETECTED_AT,
        SIGNALS.EVIDENCE AS SIGNALS.EVIDENCE_JSON,
        CASES.CASE_STATUS AS CASES.STATUS,
        CASES.CASE_PRIORITY AS CASES.PRIORITY,
        CASES.ASSIGNED_TO AS CASES.ASSIGNED_TO,
        CASES.CASE_RESOLUTION AS CASES.RESOLUTION,
        FINDINGS.NARRATIVE AS FINDINGS.NARRATIVE,
        FINDINGS.POLICY_REF AS FINDINGS.POLICY_REFERENCE,
        FINDINGS.FINDING_TYPE AS FINDINGS.FINDING_TYPE,
        REVIEWER_ACTIONS.ACTION_TYPE AS REVIEWER_ACTIONS.ACTION_TYPE,
        REVIEWER_ACTIONS.REVIEWER AS REVIEWER_ACTIONS.REVIEWER_NAME,
        REVIEWER_ACTIONS.ACTION_TIME AS REVIEWER_ACTIONS.ACTION_TIMESTAMP
    )
    METRICS (
        TRANSACTIONS.TXN_COUNT AS COUNT(TRANSACTIONS.TRANSACTION_ID),
        TRANSACTIONS.TOTAL_VALUE AS SUM(TRANSACTIONS.AMOUNT),
        TRANSACTIONS.AVG_VALUE AS AVG(TRANSACTIONS.AMOUNT),
        LOANS.TOTAL_LOANS AS COUNT(LOANS.LOAN_ID),
        LOANS.NPA_COUNT AS COUNT(CASE WHEN LOANS.DPD > 90 THEN 1 END),
        LOANS.TOTAL_OUTSTANDING AS SUM(LOANS.OUTSTANDING),
        SIGNALS.ALERT_COUNT AS COUNT(SIGNALS.SIGNAL_ID),
        SIGNALS.CRITICAL_ALERTS AS COUNT(CASE WHEN SIGNALS.SEVERITY = 'CRITICAL' THEN 1 END)
    )
    COMMENT = 'Argus Risk Copilot: fraud, AML, credit risk, liquidity risk semantic model';


-- ═════════════════════════════════════════════════════════════════════════════
-- 10. STAGE & STREAMLIT APP
-- ═════════════════════════════════════════════════════════════════════════════

CREATE STAGE IF NOT EXISTS ARGUS_RISK_COPILOT.GOVERNANCE.STREAMLIT_STAGE;

-- Upload streamlit_app.py and environment.yml to the stage, then:
CREATE OR REPLACE STREAMLIT ARGUS_RISK_COPILOT.GOVERNANCE.ARGUS_DASHBOARD
    FROM '@ARGUS_RISK_COPILOT.GOVERNANCE.STREAMLIT_STAGE'
    MAIN_FILE = 'streamlit_app.py'
    QUERY_WAREHOUSE = COMPUTE_WH
    COMMENT = 'Argus Risk Copilot — governed fraud, AML, credit risk, and regulatory reporting dashboard';


-- =============================================================================
-- COMPLETE. All objects for the Argus Risk Copilot are now in place.
--
-- Object summary:
--   RAW tables:           8  (CUSTOMERS, ACCOUNTS, TRANSACTIONS, LOANS,
--                              GENERAL_LEDGER, COUNTERPARTIES, DEVICE_SESSION_LOGS,
--                              WATCHLIST_ENTRIES)
--   CONFORMED DTs:        7  (CUSTOMERS_CLEAN, ACCOUNTS_CLEAN, TRANSACTIONS_CLEAN,
--                              LOANS_CLEAN, GENERAL_LEDGER_CLEAN,
--                              COUNTERPARTIES_CLEAN, DEVICE_SESSIONS_CLEAN)
--   GOVERNANCE tables:    9  (SIGNALS_ALERTS [DT], CASES, FINDINGS,
--                              REVIEWER_ACTIONS, FINDINGS_REPORTS, QUESTION_LOG,
--                              NOTIFICATION_RECIPIENTS, NOTIFICATION_CONFIG,
--                              NOTIFICATION_LOG)
--   UNSTRUCTURED tables:  1  (REFERENCE_DOCUMENTS)
--   Masking policies:     5  (MASK_NAME, MASK_EMAIL, MASK_PHONE,
--                              MASK_ADDRESS, MASK_DEVICE_ID)
--   Stored procedures:    5  (DRAFT_FINDING_REPORT, APPROVE_REPORT,
--                              NOTIFY_STATE_CHANGE, REBUILD_EMAIL_INTEGRATION,
--                              SEND_TEST_EMAIL)
--   Semantic view:        1  (ARGUS_COPILOT_SV)
--   Stage:                1  (STREAMLIT_STAGE)
--   Streamlit app:        1  (ARGUS_DASHBOARD)
-- =============================================================================
