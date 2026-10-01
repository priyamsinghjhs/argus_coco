-- ============================================================
-- 01_raw_tables.sql  —  RAW table DDL
-- Ground-truth _gt_* columns are on RAW only; excluded from CONFORMED
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE SCHEMA RAW;

-- ---- CUSTOMERS ----
CREATE OR REPLACE TABLE CUSTOMERS (
    customer_id       INT            NOT NULL,
    name              VARCHAR(200)   NOT NULL,
    dob               DATE,
    kyc_risk_rating   VARCHAR(10)    NOT NULL,   -- LOW / MEDIUM / HIGH
    address           VARCHAR(500),
    phone             VARCHAR(20),
    email             VARCHAR(200),
    onboarding_date   DATE           NOT NULL,
    -- ground-truth flags (never exposed to agent / semantic layer)
    _gt_structuring     BOOLEAN DEFAULT FALSE,
    _gt_mule            BOOLEAN DEFAULT FALSE,
    _gt_ato             BOOLEAN DEFAULT FALSE,
    _gt_loan_stacking   BOOLEAN DEFAULT FALSE,
    _loaded_at        TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_customers PRIMARY KEY (customer_id)
);

-- ---- ACCOUNTS ----
CREATE OR REPLACE TABLE ACCOUNTS (
    account_id      INT            NOT NULL,
    customer_id     INT            NOT NULL,
    account_type    VARCHAR(20)    NOT NULL,   -- SAVINGS / CURRENT / LOAN / FD
    status          VARCHAR(20)    NOT NULL,   -- ACTIVE / DORMANT / CLOSED / FROZEN
    open_date       DATE           NOT NULL,
    currency        VARCHAR(3)     DEFAULT 'INR',
    current_balance NUMBER(18,2)   NOT NULL,
    _gt_mule        BOOLEAN DEFAULT FALSE,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_accounts PRIMARY KEY (account_id)
);

-- ---- COUNTERPARTIES ----
CREATE OR REPLACE TABLE COUNTERPARTIES (
    counterparty_id INT            NOT NULL,
    name            VARCHAR(200)   NOT NULL,
    type            VARCHAR(20)    NOT NULL,   -- INDIVIDUAL / CORPORATE / GOVERNMENT
    country         VARCHAR(5)     NOT NULL,
    is_pep          BOOLEAN        DEFAULT FALSE,
    is_sanctioned   BOOLEAN        DEFAULT FALSE,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_counterparties PRIMARY KEY (counterparty_id)
);

-- ---- WATCHLIST_ENTRIES ----
CREATE OR REPLACE TABLE WATCHLIST_ENTRIES (
    watchlist_id    INT            NOT NULL,
    entity_name     VARCHAR(200)   NOT NULL,
    aliases         VARCHAR(500),
    list_type       VARCHAR(20)    NOT NULL,   -- PEP / SANCTIONS
    source          VARCHAR(100)   NOT NULL,
    effective_date  DATE           NOT NULL,
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_watchlist PRIMARY KEY (watchlist_id)
);

-- ---- TRANSACTIONS ----
CREATE OR REPLACE TABLE TRANSACTIONS (
    transaction_id   INT            NOT NULL,
    account_id       INT            NOT NULL,
    counterparty_id  INT,
    amount           NUMBER(18,2)   NOT NULL,
    currency         VARCHAR(3)     DEFAULT 'INR',
    channel          VARCHAR(20)    NOT NULL,   -- BRANCH/ATM/MOBILE/NETBANKING/UPI/RTGS/NEFT
    transaction_type VARCHAR(10)    NOT NULL,   -- CREDIT / DEBIT
    timestamp        TIMESTAMP_NTZ  NOT NULL,
    device_id        VARCHAR(50),
    geo_location     VARCHAR(100),
    declared_purpose VARCHAR(200),
    _gt_structuring  BOOLEAN DEFAULT FALSE,
    _gt_mule         BOOLEAN DEFAULT FALSE,
    _gt_ato          BOOLEAN DEFAULT FALSE,
    _loaded_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_transactions PRIMARY KEY (transaction_id)
);

-- ---- LOANS ----
CREATE OR REPLACE TABLE LOANS (
    loan_id                     INT            NOT NULL,
    customer_id                 INT            NOT NULL,
    principal                   NUMBER(18,2)   NOT NULL,
    outstanding                 NUMBER(18,2)   NOT NULL,
    disbursement_date           DATE           NOT NULL,
    tenure_months               INT            NOT NULL,
    interest_rate               NUMBER(5,2)    NOT NULL,
    dpd                         INT            DEFAULT 0,    -- days past due
    restructuring_flag          BOOLEAN        DEFAULT FALSE,
    bureau_score_at_origination INT,
    latest_bureau_score         INT,
    _gt_loan_stacking           BOOLEAN DEFAULT FALSE,
    _loaded_at                  TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_loans PRIMARY KEY (loan_id)
);

-- ---- GENERAL_LEDGER ----
CREATE OR REPLACE TABLE GENERAL_LEDGER (
    entry_id        INT            NOT NULL,
    posting_date    DATE           NOT NULL,
    gl_code         VARCHAR(20)    NOT NULL,
    gl_description  VARCHAR(200)   NOT NULL,
    debit_amount    NUMBER(18,2)   DEFAULT 0,
    credit_amount   NUMBER(18,2)   DEFAULT 0,
    balance         NUMBER(18,2)   NOT NULL,
    department      VARCHAR(50),
    _loaded_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_gl PRIMARY KEY (entry_id)
);

-- ---- DEVICE_SESSION_LOGS ----
CREATE OR REPLACE TABLE DEVICE_SESSION_LOGS (
    session_id       INT            NOT NULL,
    customer_id      INT            NOT NULL,
    device_id        VARCHAR(50)    NOT NULL,
    ip_geo           VARCHAR(100),
    login_timestamp  TIMESTAMP_NTZ  NOT NULL,
    event_type       VARCHAR(20)    NOT NULL,   -- LOGIN / CONTACT_CHANGE / PASSWORD_RESET
    _gt_ato          BOOLEAN DEFAULT FALSE,
    _loaded_at       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_sessions PRIMARY KEY (session_id)
);
