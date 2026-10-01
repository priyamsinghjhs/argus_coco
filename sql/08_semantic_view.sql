-- ============================================================
-- 08_semantic_view.sql  —  Semantic View DDL
-- Covers full ontology: Customer, Account, Transaction,
-- Counterparty, Loan, GL, DeviceSession, Signal, Case,
-- Finding, ReviewerAction
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE WAREHOUSE COMPUTE_WH;

-- Create supporting tables for the SIGNAL -> FINDING -> REPORT workflow
CREATE OR REPLACE TABLE GOVERNANCE.CASES (
    case_id VARCHAR(40) NOT NULL, signal_id VARCHAR(40) NOT NULL,
    signal_type VARCHAR(30) NOT NULL, customer_id INT, account_id INT,
    status VARCHAR(30) NOT NULL, priority VARCHAR(10) NOT NULL,
    assigned_to VARCHAR(50), assigned_role VARCHAR(30),
    created_at TIMESTAMP_NTZ NOT NULL, updated_at TIMESTAMP_NTZ NOT NULL,
    closed_at TIMESTAMP_NTZ, resolution VARCHAR(50),
    CONSTRAINT pk_cases PRIMARY KEY (case_id)
);

CREATE OR REPLACE TABLE GOVERNANCE.FINDINGS (
    finding_id VARCHAR(40) NOT NULL, case_id VARCHAR(40) NOT NULL,
    finding_type VARCHAR(30) NOT NULL, confidence NUMBER(3,2) NOT NULL,
    narrative VARCHAR(4000), evidence_summary VARCHAR(2000),
    policy_reference VARCHAR(500), created_by VARCHAR(50),
    created_at TIMESTAMP_NTZ NOT NULL,
    CONSTRAINT pk_findings PRIMARY KEY (finding_id)
);

CREATE OR REPLACE TABLE GOVERNANCE.REVIEWER_ACTIONS (
    action_id VARCHAR(40) NOT NULL, finding_id VARCHAR(40) NOT NULL,
    case_id VARCHAR(40) NOT NULL, reviewer_name VARCHAR(50) NOT NULL,
    reviewer_role VARCHAR(30) NOT NULL, action_type VARCHAR(20) NOT NULL,
    comment VARCHAR(1000), action_timestamp TIMESTAMP_NTZ NOT NULL,
    CONSTRAINT pk_reviewer_actions PRIMARY KEY (action_id)
);

-- Deploy semantic view
CREATE OR REPLACE SEMANTIC VIEW SEMANTIC.ARGUS_COPILOT_SV

  TABLES (
    customers AS ARGUS_RISK_COPILOT.CONFORMED.CUSTOMERS_CLEAN PRIMARY KEY (CUSTOMER_ID),
    accounts AS ARGUS_RISK_COPILOT.CONFORMED.ACCOUNTS_CLEAN PRIMARY KEY (ACCOUNT_ID),
    transactions AS ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN PRIMARY KEY (TRANSACTION_ID),
    counterparties AS ARGUS_RISK_COPILOT.CONFORMED.COUNTERPARTIES_CLEAN PRIMARY KEY (COUNTERPARTY_ID),
    loans AS ARGUS_RISK_COPILOT.CONFORMED.LOANS_CLEAN PRIMARY KEY (LOAN_ID),
    general_ledger AS ARGUS_RISK_COPILOT.CONFORMED.GENERAL_LEDGER_CLEAN PRIMARY KEY (ENTRY_ID),
    device_sessions AS ARGUS_RISK_COPILOT.CONFORMED.DEVICE_SESSIONS_CLEAN PRIMARY KEY (SESSION_ID),
    signals AS ARGUS_RISK_COPILOT.GOVERNANCE.SIGNALS_ALERTS PRIMARY KEY (SIGNAL_ID),
    cases AS ARGUS_RISK_COPILOT.GOVERNANCE.CASES PRIMARY KEY (CASE_ID) UNIQUE (SIGNAL_ID),
    findings AS ARGUS_RISK_COPILOT.GOVERNANCE.FINDINGS PRIMARY KEY (FINDING_ID),
    reviewer_actions AS ARGUS_RISK_COPILOT.GOVERNANCE.REVIEWER_ACTIONS PRIMARY KEY (ACTION_ID)
  )

  RELATIONSHIPS (
    accounts_to_customers AS accounts(CUSTOMER_ID) REFERENCES customers,
    loans_to_customers AS loans(CUSTOMER_ID) REFERENCES customers,
    transactions_to_accounts AS transactions(ACCOUNT_ID) REFERENCES accounts,
    transactions_to_counterparties AS transactions(COUNTERPARTY_ID) REFERENCES counterparties,
    device_sessions_to_customers AS device_sessions(CUSTOMER_ID) REFERENCES customers,
    cases_to_signals AS cases(SIGNAL_ID) REFERENCES signals,
    cases_to_customers AS cases(CUSTOMER_ID) REFERENCES customers,
    findings_to_cases AS findings(CASE_ID) REFERENCES cases,
    actions_to_findings AS reviewer_actions(FINDING_ID) REFERENCES findings
  )

  FACTS (
    accounts.balance AS accounts.CURRENT_BALANCE,
    transactions.amount AS transactions.AMOUNT,
    loans.principal AS loans.PRINCIPAL,
    loans.outstanding AS loans.OUTSTANDING,
    loans.score_drop AS loans.BUREAU_SCORE_AT_ORIGINATION - loans.LATEST_BUREAU_SCORE,
    general_ledger.gl_balance AS general_ledger.BALANCE,
    signals.confidence AS signals.CONFIDENCE,
    findings.finding_confidence AS findings.CONFIDENCE
  )

  DIMENSIONS (
    customers.customer_name AS customers.NAME,
    customers.kyc_risk AS customers.KYC_RISK_RATING,
    customers.onboarding AS customers.ONBOARDING_DATE,
    accounts.acct_type AS accounts.ACCOUNT_TYPE,
    accounts.acct_status AS accounts.STATUS,
    transactions.channel AS transactions.CHANNEL,
    transactions.txn_type AS transactions.TRANSACTION_TYPE,
    transactions.txn_time AS transactions.TIMESTAMP,
    transactions.purpose AS transactions.DECLARED_PURPOSE,
    transactions.geo AS transactions.GEO_LOCATION,
    counterparties.cp_name AS counterparties.NAME,
    counterparties.cp_country AS counterparties.COUNTRY,
    counterparties.cp_is_pep AS counterparties.IS_PEP,
    counterparties.cp_is_sanctioned AS counterparties.IS_SANCTIONED,
    loans.dpd AS loans.DPD,
    loans.dpd_bucket AS CASE WHEN loans.DPD = 0 THEN 'CURRENT' WHEN loans.DPD <= 30 THEN 'SMA-0' WHEN loans.DPD <= 60 THEN 'SMA-1' WHEN loans.DPD <= 90 THEN 'SMA-2' WHEN loans.DPD <= 180 THEN 'SUB-STANDARD' ELSE 'DOUBTFUL' END,
    loans.disb_date AS loans.DISBURSEMENT_DATE,
    general_ledger.gl_code AS general_ledger.GL_CODE,
    general_ledger.gl_desc AS general_ledger.GL_DESCRIPTION,
    general_ledger.posting_date AS general_ledger.POSTING_DATE,
    signals.signal_type AS signals.SIGNAL_TYPE,
    signals.severity AS signals.SEVERITY,
    signals.detected_at AS signals.DETECTED_AT,
    signals.evidence AS signals.EVIDENCE_JSON,
    cases.case_status AS cases.STATUS,
    cases.case_priority AS cases.PRIORITY,
    cases.assigned_to AS cases.ASSIGNED_TO,
    cases.case_resolution AS cases.RESOLUTION,
    findings.narrative AS findings.NARRATIVE,
    findings.policy_ref AS findings.POLICY_REFERENCE,
    findings.finding_type AS findings.FINDING_TYPE,
    reviewer_actions.action_type AS reviewer_actions.ACTION_TYPE,
    reviewer_actions.reviewer AS reviewer_actions.REVIEWER_NAME,
    reviewer_actions.action_time AS reviewer_actions.ACTION_TIMESTAMP
  )

  METRICS (
    transactions.txn_count AS COUNT(transactions.TRANSACTION_ID),
    transactions.total_value AS SUM(transactions.AMOUNT),
    transactions.avg_value AS AVG(transactions.AMOUNT),
    loans.total_loans AS COUNT(loans.LOAN_ID),
    loans.npa_count AS COUNT(CASE WHEN loans.DPD > 90 THEN 1 END),
    loans.total_outstanding AS SUM(loans.OUTSTANDING),
    signals.alert_count AS COUNT(signals.SIGNAL_ID),
    signals.critical_alerts AS COUNT(CASE WHEN signals.SEVERITY = 'CRITICAL' THEN 1 END)
  )

  COMMENT = 'Argus Risk Copilot: fraud, AML, credit risk, liquidity risk semantic model';

-- Grants
GRANT SELECT ON SEMANTIC VIEW SEMANTIC.ARGUS_COPILOT_SV TO ROLE PLATFORM_ADMIN;
GRANT SELECT ON SEMANTIC VIEW SEMANTIC.ARGUS_COPILOT_SV TO ROLE COMPLIANCE_OFFICER;
GRANT SELECT ON SEMANTIC VIEW SEMANTIC.ARGUS_COPILOT_SV TO ROLE FRAUD_ANALYST;
GRANT SELECT ON SEMANTIC VIEW SEMANTIC.ARGUS_COPILOT_SV TO ROLE CREDIT_ANALYST;
GRANT SELECT ON SEMANTIC VIEW SEMANTIC.ARGUS_COPILOT_SV TO ROLE AUDITOR;
