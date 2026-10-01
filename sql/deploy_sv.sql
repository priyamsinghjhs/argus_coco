CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(
  'ARGUS_RISK_COPILOT.SEMANTIC.ARGUS_RISK_COPILOT',
  'name: ARGUS_RISK_COPILOT
description: ''Argus Risk Copilot semantic model covering the full fraud, AML, credit
  risk, and liquidity risk ontology for banking/NBFC operations. Entities: Customer,
  Account, Transaction, Counterparty, Loan, GeneralLedger, DeviceSession, Signal/Alert,
  Case, Finding, ReviewerAction. Supports the SIGNAL -> EVIDENCE -> FINDING -> REPORT
  workflow with policy citations and audit trails. Key relationships: Transaction
  -> Account -> Customer, Signal -> Transaction(s)/Account(s), Case -> Signal, Finding
  -> Case, ReviewerAction -> Finding. Regulatory backdrop: India RBI/PMLA/FIU-IND.''
tables:
  - name: CUSTOMERS_CLEAN
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: CONFORMED
      table: CUSTOMERS_CLEAN
    dimensions:
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: NAME
        expr: NAME
        data_type: VARCHAR
      - name: KYC_RISK_RATING
        expr: KYC_RISK_RATING
        data_type: VARCHAR
      - name: ADDRESS
        expr: ADDRESS
        data_type: VARCHAR
      - name: PHONE
        expr: PHONE
        data_type: VARCHAR
      - name: EMAIL
        expr: EMAIL
        data_type: VARCHAR
    time_dimensions:
      - name: DOB
        expr: DOB
        data_type: DATE
      - name: ONBOARDING_DATE
        expr: ONBOARDING_DATE
        data_type: DATE
    unique_keys:
      - columns:
          - CUSTOMER_ID
  - name: ACCOUNTS_CLEAN
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: CONFORMED
      table: ACCOUNTS_CLEAN
    dimensions:
      - name: ACCOUNT_ID
        expr: ACCOUNT_ID
        data_type: NUMBER
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: ACCOUNT_TYPE
        expr: ACCOUNT_TYPE
        data_type: VARCHAR
      - name: STATUS
        expr: STATUS
        data_type: VARCHAR
      - name: CURRENCY
        expr: CURRENCY
        data_type: VARCHAR
    time_dimensions:
      - name: OPEN_DATE
        expr: OPEN_DATE
        data_type: DATE
    facts:
      - name: CURRENT_BALANCE
        expr: CURRENT_BALANCE
        data_type: NUMBER
    unique_keys:
      - columns:
          - ACCOUNT_ID
  - name: TRANSACTIONS_CLEAN
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: CONFORMED
      table: TRANSACTIONS_CLEAN
    dimensions:
      - name: TRANSACTION_ID
        expr: TRANSACTION_ID
        data_type: NUMBER
      - name: ACCOUNT_ID
        expr: ACCOUNT_ID
        data_type: NUMBER
      - name: COUNTERPARTY_ID
        expr: COUNTERPARTY_ID
        data_type: NUMBER
      - name: CURRENCY
        expr: CURRENCY
        data_type: VARCHAR
      - name: CHANNEL
        expr: CHANNEL
        data_type: VARCHAR
      - name: TRANSACTION_TYPE
        expr: TRANSACTION_TYPE
        data_type: VARCHAR
      - name: DEVICE_ID
        expr: DEVICE_ID
        data_type: VARCHAR
      - name: GEO_LOCATION
        expr: GEO_LOCATION
        data_type: VARCHAR
      - name: DECLARED_PURPOSE
        expr: DECLARED_PURPOSE
        data_type: VARCHAR
    time_dimensions:
      - name: TIMESTAMP
        expr: TIMESTAMP
        data_type: TIMESTAMP_NTZ
    facts:
      - name: AMOUNT
        expr: AMOUNT
        data_type: NUMBER
        description: Transaction amount in the transaction currency (typically INR).
    metrics:
      - name: TRANSACTION_COUNT
        expr: COUNT(TRANSACTION_ID)
        data_type: NUMBER
        description: Total number of transactions.
      - name: TOTAL_TRANSACTION_VALUE
        expr: SUM(AMOUNT)
        data_type: NUMBER
        description: Sum of all transaction amounts in INR.
      - name: AVG_TRANSACTION_VALUE
        expr: AVG(AMOUNT)
        data_type: NUMBER
        description: Average transaction amount in INR.
      - name: CREDIT_TRANSACTION_COUNT
        expr: COUNT(CASE WHEN TRANSACTION_TYPE = ''CREDIT'' THEN 1 END)
        data_type: NUMBER
        description: Number of credit (inbound) transactions.
      - name: DEBIT_TRANSACTION_COUNT
        expr: COUNT(CASE WHEN TRANSACTION_TYPE = ''DEBIT'' THEN 1 END)
        data_type: NUMBER
        description: Number of debit (outbound) transactions.
    unique_keys:
      - columns:
          - TRANSACTION_ID
  - name: COUNTERPARTIES_CLEAN
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: CONFORMED
      table: COUNTERPARTIES_CLEAN
    dimensions:
      - name: COUNTERPARTY_ID
        expr: COUNTERPARTY_ID
        data_type: NUMBER
      - name: NAME
        expr: NAME
        data_type: VARCHAR
      - name: _TYPE
        expr: ''"TYPE"''
        data_type: VARCHAR
      - name: COUNTRY
        expr: COUNTRY
        data_type: VARCHAR
      - name: IS_PEP
        expr: IS_PEP
        data_type: BOOLEAN
      - name: IS_SANCTIONED
        expr: IS_SANCTIONED
        data_type: BOOLEAN
    unique_keys:
      - columns:
          - COUNTERPARTY_ID
  - name: LOANS_CLEAN
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: CONFORMED
      table: LOANS_CLEAN
    dimensions:
      - name: LOAN_ID
        expr: LOAN_ID
        data_type: NUMBER
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: TENURE_MONTHS
        expr: TENURE_MONTHS
        data_type: NUMBER
      - name: DPD
        expr: DPD
        data_type: NUMBER
        description: Days Past Due. 0 = current. 1-30 = SMA-0. 31-60 = SMA-1. 61-90 = SMA-2. >90 = NPA.
      - name: DPD_BUCKET
        expr: "CASE WHEN DPD = 0 THEN ''CURRENT'' WHEN DPD <= 30 THEN ''SMA-0'' WHEN DPD <= 60 THEN ''SMA-1'' WHEN DPD <= 90 THEN ''SMA-2'' WHEN DPD <= 180 THEN ''SUB-STANDARD'' ELSE ''DOUBTFUL'' END"
        data_type: VARCHAR
        description: RBI NPA classification bucket based on Days Past Due (DPD).
      - name: BUREAU_SCORE_DROP
        expr: "BUREAU_SCORE_AT_ORIGINATION - LATEST_BUREAU_SCORE"
        data_type: NUMBER
        description: Drop in bureau score since loan origination. Positive means deterioration.
      - name: RESTRUCTURING_FLAG
        expr: RESTRUCTURING_FLAG
        data_type: BOOLEAN
      - name: BUREAU_SCORE_AT_ORIGINATION
        expr: BUREAU_SCORE_AT_ORIGINATION
        data_type: NUMBER
      - name: LATEST_BUREAU_SCORE
        expr: LATEST_BUREAU_SCORE
        data_type: NUMBER
    time_dimensions:
      - name: DISBURSEMENT_DATE
        expr: DISBURSEMENT_DATE
        data_type: DATE
    facts:
      - name: PRINCIPAL
        expr: PRINCIPAL
        data_type: NUMBER
      - name: OUTSTANDING
        expr: OUTSTANDING
        data_type: NUMBER
      - name: INTEREST_RATE
        expr: INTEREST_RATE
        data_type: NUMBER
    metrics:
      - name: TOTAL_LOANS
        expr: COUNT(LOAN_ID)
        data_type: NUMBER
        description: Total number of loans.
      - name: TOTAL_OUTSTANDING
        expr: SUM(OUTSTANDING)
        data_type: NUMBER
        description: Total outstanding loan amount in INR.
      - name: NPA_COUNT
        expr: COUNT(CASE WHEN DPD > 90 THEN 1 END)
        data_type: NUMBER
        description: Number of Non-Performing Assets (DPD > 90 days per RBI norms).
      - name: NPA_RATIO_PCT
        expr: "ROUND(COUNT(CASE WHEN DPD > 90 THEN 1 END) * 100.0 / NULLIF(COUNT(LOAN_ID), 0), 2)"
        data_type: NUMBER
        description: NPA ratio as percentage of total loans.
      - name: AVG_BUREAU_SCORE_DROP
        expr: "AVG(BUREAU_SCORE_AT_ORIGINATION - LATEST_BUREAU_SCORE)"
        data_type: NUMBER
        description: Average bureau score deterioration across the loan portfolio.
    unique_keys:
      - columns:
          - LOAN_ID
  - name: GENERAL_LEDGER_CLEAN
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: CONFORMED
      table: GENERAL_LEDGER_CLEAN
    dimensions:
      - name: ENTRY_ID
        expr: ENTRY_ID
        data_type: NUMBER
      - name: GL_CODE
        expr: GL_CODE
        data_type: VARCHAR
      - name: GL_DESCRIPTION
        expr: GL_DESCRIPTION
        data_type: VARCHAR
      - name: DEPARTMENT
        expr: DEPARTMENT
        data_type: VARCHAR
    time_dimensions:
      - name: POSTING_DATE
        expr: POSTING_DATE
        data_type: DATE
    facts:
      - name: DEBIT_AMOUNT
        expr: DEBIT_AMOUNT
        data_type: NUMBER
      - name: CREDIT_AMOUNT
        expr: CREDIT_AMOUNT
        data_type: NUMBER
      - name: BALANCE
        expr: BALANCE
        data_type: NUMBER
    unique_keys:
      - columns:
          - ENTRY_ID
  - name: DEVICE_SESSIONS_CLEAN
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: CONFORMED
      table: DEVICE_SESSIONS_CLEAN
    dimensions:
      - name: SESSION_ID
        expr: SESSION_ID
        data_type: NUMBER
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: DEVICE_ID
        expr: DEVICE_ID
        data_type: VARCHAR
      - name: IP_GEO
        expr: IP_GEO
        data_type: VARCHAR
      - name: EVENT_TYPE
        expr: EVENT_TYPE
        data_type: VARCHAR
    time_dimensions:
      - name: LOGIN_TIMESTAMP
        expr: LOGIN_TIMESTAMP
        data_type: TIMESTAMP_NTZ
    unique_keys:
      - columns:
          - SESSION_ID
  - name: SIGNALS_ALERTS
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: GOVERNANCE
      table: SIGNALS_ALERTS
    primary_key:
      columns:
        - SIGNAL_ID
    dimensions:
      - name: SIGNAL_ID
        expr: SIGNAL_ID
        data_type: VARCHAR
      - name: SIGNAL_TYPE
        expr: SIGNAL_TYPE
        data_type: VARCHAR
      - name: ENTITY_ID
        expr: ENTITY_ID
        data_type: VARCHAR
      - name: ENTITY_TYPE
        expr: ENTITY_TYPE
        data_type: VARCHAR
      - name: SEVERITY
        expr: SEVERITY
        data_type: VARCHAR
      - name: EVIDENCE_JSON
        expr: EVIDENCE_JSON
        data_type: VARIANT
      - name: RULE_VERSION
        expr: RULE_VERSION
        data_type: VARCHAR
    time_dimensions:
      - name: DETECTED_AT
        expr: DETECTED_AT
        data_type: TIMESTAMP_NTZ
    facts:
      - name: CONFIDENCE
        expr: CONFIDENCE
        data_type: NUMBER
        description: Model confidence score for the signal (0.0 to 1.0).
    metrics:
      - name: ALERT_COUNT
        expr: COUNT(SIGNAL_ID)
        data_type: NUMBER
        description: Total number of alerts/signals.
      - name: CRITICAL_ALERT_COUNT
        expr: COUNT(CASE WHEN SEVERITY = ''CRITICAL'' THEN 1 END)
        data_type: NUMBER
        description: Number of CRITICAL severity alerts.
      - name: HIGH_ALERT_COUNT
        expr: COUNT(CASE WHEN SEVERITY = ''HIGH'' THEN 1 END)
        data_type: NUMBER
        description: Number of HIGH severity alerts.
      - name: AVG_CONFIDENCE
        expr: AVG(CONFIDENCE)
        data_type: NUMBER
        description: Average confidence score across signals.
    unique_keys:
      - columns:
          - ENTITY_ID
  - name: CASES
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: GOVERNANCE
      table: CASES
    primary_key:
      columns:
        - CASE_ID
        - CUSTOMER_ID
    dimensions:
      - name: CASE_ID
        expr: CASE_ID
        data_type: VARCHAR
      - name: SIGNAL_ID
        expr: SIGNAL_ID
        data_type: VARCHAR
      - name: SIGNAL_TYPE
        expr: SIGNAL_TYPE
        data_type: VARCHAR
      - name: CUSTOMER_ID
        expr: CUSTOMER_ID
        data_type: NUMBER
      - name: ACCOUNT_ID
        expr: ACCOUNT_ID
        data_type: NUMBER
      - name: STATUS
        expr: STATUS
        data_type: VARCHAR
      - name: PRIORITY
        expr: PRIORITY
        data_type: VARCHAR
      - name: ASSIGNED_TO
        expr: ASSIGNED_TO
        data_type: VARCHAR
      - name: ASSIGNED_ROLE
        expr: ASSIGNED_ROLE
        data_type: VARCHAR
      - name: RESOLUTION
        expr: RESOLUTION
        data_type: VARCHAR
    time_dimensions:
      - name: CREATED_AT
        expr: CREATED_AT
        data_type: TIMESTAMP_NTZ
      - name: UPDATED_AT
        expr: UPDATED_AT
        data_type: TIMESTAMP_NTZ
      - name: CLOSED_AT
        expr: CLOSED_AT
        data_type: TIMESTAMP_NTZ
    unique_keys:
      - columns:
          - SIGNAL_ID
  - name: FINDINGS
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: GOVERNANCE
      table: FINDINGS
    primary_key:
      columns:
        - CASE_ID
        - FINDING_ID
    dimensions:
      - name: FINDING_ID
        expr: FINDING_ID
        data_type: VARCHAR
      - name: CASE_ID
        expr: CASE_ID
        data_type: VARCHAR
      - name: FINDING_TYPE
        expr: FINDING_TYPE
        data_type: VARCHAR
      - name: NARRATIVE
        expr: NARRATIVE
        data_type: VARCHAR
      - name: EVIDENCE_SUMMARY
        expr: EVIDENCE_SUMMARY
        data_type: VARCHAR
      - name: POLICY_REFERENCE
        expr: POLICY_REFERENCE
        data_type: VARCHAR
      - name: CREATED_BY
        expr: CREATED_BY
        data_type: VARCHAR
    time_dimensions:
      - name: CREATED_AT
        expr: CREATED_AT
        data_type: TIMESTAMP_NTZ
    facts:
      - name: CONFIDENCE
        expr: CONFIDENCE
        data_type: NUMBER
  - name: REVIEWER_ACTIONS
    base_table:
      database: ARGUS_RISK_COPILOT
      schema: GOVERNANCE
      table: REVIEWER_ACTIONS
    primary_key:
      columns:
        - ACTION_ID
        - FINDING_ID
    dimensions:
      - name: ACTION_ID
        expr: ACTION_ID
        data_type: VARCHAR
      - name: FINDING_ID
        expr: FINDING_ID
        data_type: VARCHAR
      - name: CASE_ID
        expr: CASE_ID
        data_type: VARCHAR
      - name: REVIEWER_NAME
        expr: REVIEWER_NAME
        data_type: VARCHAR
      - name: REVIEWER_ROLE
        expr: REVIEWER_ROLE
        data_type: VARCHAR
      - name: ACTION_TYPE
        expr: ACTION_TYPE
        data_type: VARCHAR
      - name: COMMENT
        expr: COMMENT
        data_type: VARCHAR
    time_dimensions:
      - name: ACTION_TIMESTAMP
        expr: ACTION_TIMESTAMP
        data_type: TIMESTAMP_NTZ
    metrics:
      - name: REVIEW_COUNT
        expr: COUNT(ACTION_ID)
        data_type: NUMBER
        description: Total number of reviewer actions taken.
      - name: APPROVAL_COUNT
        expr: COUNT(CASE WHEN ACTION_TYPE = ''APPROVE'' THEN 1 END)
        data_type: NUMBER
        description: Number of findings approved by reviewers.
      - name: REJECTION_COUNT
        expr: COUNT(CASE WHEN ACTION_TYPE = ''REJECT'' THEN 1 END)
        data_type: NUMBER
        description: Number of findings rejected (false positives) by reviewers.
      - name: OVERRIDE_RATE_PCT
        expr: "ROUND(COUNT(CASE WHEN ACTION_TYPE = ''REJECT'' THEN 1 END) * 100.0 / NULLIF(COUNT(ACTION_ID), 0), 2)"
        data_type: NUMBER
        description: Percentage of reviewer actions that were rejections (override rate). High values indicate too many false positives.
    unique_keys:
      - columns:
          - CASE_ID
relationships:
  - name: ACCOUNTS_CLEAN_TO_CUSTOMERS_CLEAN
    left_table: ACCOUNTS_CLEAN
    right_table: CUSTOMERS_CLEAN
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
  - name: LOANS_CLEAN_TO_CUSTOMERS_CLEAN
    left_table: LOANS_CLEAN
    right_table: CUSTOMERS_CLEAN
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
  - name: SIGNALS_ALERTS_TO_CASES
    left_table: SIGNALS_ALERTS
    right_table: CASES
    join_type: inner
    relationship_type: one_to_one
    relationship_columns:
      - left_column: SIGNAL_ID
        right_column: SIGNAL_ID
  - name: TRANSACTIONS_CLEAN_TO_ACCOUNTS_CLEAN
    left_table: TRANSACTIONS_CLEAN
    right_table: ACCOUNTS_CLEAN
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: ACCOUNT_ID
        right_column: ACCOUNT_ID
  - name: TRANSACTIONS_CLEAN_TO_COUNTERPARTIES_CLEAN
    left_table: TRANSACTIONS_CLEAN
    right_table: COUNTERPARTIES_CLEAN
    join_type: left
    relationship_type: many_to_one
    relationship_columns:
      - left_column: COUNTERPARTY_ID
        right_column: COUNTERPARTY_ID
  - name: DEVICE_SESSIONS_TO_CUSTOMERS
    left_table: DEVICE_SESSIONS_CLEAN
    right_table: CUSTOMERS_CLEAN
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
  - name: CASES_TO_CUSTOMERS
    left_table: CASES
    right_table: CUSTOMERS_CLEAN
    join_type: left
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CUSTOMER_ID
        right_column: CUSTOMER_ID
  - name: FINDINGS_TO_CASES
    left_table: FINDINGS
    right_table: CASES
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: CASE_ID
        right_column: CASE_ID
  - name: REVIEWER_ACTIONS_TO_FINDINGS
    left_table: REVIEWER_ACTIONS
    right_table: FINDINGS
    join_type: inner
    relationship_type: many_to_one
    relationship_columns:
      - left_column: FINDING_ID
        right_column: FINDING_ID
verified_queries:
  - name: 0;1
    question: Show me all transactions above INR 10,00,000 in the last 24 hours with
      no declared purpose.
    sql: SELECT t.TRANSACTION_ID, t.AMOUNT, t.CHANNEL, t.TRANSACTION_TYPE, t.TIMESTAMP,
      t.DECLARED_PURPOSE, a.ACCOUNT_ID, c.NAME AS CUSTOMER_NAME, c.KYC_RISK_RATING
      FROM transactions_clean AS t JOIN accounts_clean AS a ON a.ACCOUNT_ID = t.ACCOUNT_ID
      JOIN customers_clean AS c ON c.CUSTOMER_ID = a.CUSTOMER_ID WHERE t.AMOUNT >
      1000000 AND t.TIMESTAMP >= DATEADD(HOUR, -24, CURRENT_TIMESTAMP()) AND (t.DECLARED_PURPOSE
      IS NULL OR t.DECLARED_PURPOSE = '''' OR t.DECLARED_PURPOSE = ''Misc'') ORDER BY
      t.AMOUNT DESC
    verified_at: 1789562359
    verified_by: Semantic Model Generator
  - name: 1;1
    question: Which customers show structuring patterns this week?
    sql: SELECT s.SIGNAL_ID, s.ENTITY_ID AS CUSTOMER_ID, s.DETECTED_AT, s.SEVERITY,
      s.CONFIDENCE, s.EVIDENCE_JSON, c.NAME AS CUSTOMER_NAME, cs.STATUS AS CASE_STATUS
      FROM signals_alerts AS s LEFT JOIN customers_clean AS c ON c.CUSTOMER_ID = CAST(s.ENTITY_ID
      AS INT) LEFT JOIN cases AS cs ON cs.SIGNAL_ID = s.SIGNAL_ID WHERE s.SIGNAL_TYPE
      = ''STRUCTURING'' AND s.DETECTED_AT >= DATEADD(DAY, -7, CURRENT_TIMESTAMP()) ORDER
      BY s.CONFIDENCE DESC
    verified_at: 1789562359
    verified_by: Semantic Model Generator
  - name: 2;1
    question: What is our current liquidity coverage ratio?
    sql: WITH hqla AS (SELECT SUM(BALANCE) AS total_hqla FROM general_ledger_clean
      WHERE GL_CODE IN (''GL1009'', ''GL1010'', ''GL2001'', ''GL2002'') AND POSTING_DATE =
      (SELECT MAX(POSTING_DATE) FROM general_ledger_clean)), outflows AS (SELECT SUM(BALANCE)
      * 0.10 AS net_outflows FROM general_ledger_clean WHERE GL_CODE IN (''GL1001'',
      ''GL1002'', ''GL1003'', ''GL1004'', ''GL1005'') AND POSTING_DATE = (SELECT MAX(POSTING_DATE)
      FROM general_ledger_clean)) SELECT ROUND(hqla.total_hqla / NULLIF(outflows.net_outflows,
      0) * 100, 2) AS lcr_ratio_pct, hqla.total_hqla, outflows.net_outflows FROM hqla,
      outflows
    verified_at: 1789562359
    verified_by: Semantic Model Generator
  - name: 3;1
    question: Which borrowers had a credit score drop of 50 or more points among loans
      disbursed in the last 60 days?
    sql: SELECT l.LOAN_ID, l.CUSTOMER_ID, c.NAME AS CUSTOMER_NAME, l.BUREAU_SCORE_AT_ORIGINATION,
      l.LATEST_BUREAU_SCORE, (l.BUREAU_SCORE_AT_ORIGINATION - l.LATEST_BUREAU_SCORE)
      AS SCORE_DROP, l.PRINCIPAL, l.OUTSTANDING, l.DPD FROM loans_clean AS l JOIN
      customers_clean AS c ON c.CUSTOMER_ID = l.CUSTOMER_ID WHERE (l.BUREAU_SCORE_AT_ORIGINATION
      - l.LATEST_BUREAU_SCORE) >= 50 AND l.DISBURSEMENT_DATE >= DATEADD(DAY, -60,
      CURRENT_DATE) ORDER BY SCORE_DROP DESC
    verified_at: 1789562359
    verified_by: Semantic Model Generator
  - name: 4;1
    question: Why was this customer flagged and what are the signals, evidence, and
      findings?
    sql: SELECT s.SIGNAL_ID, s.SIGNAL_TYPE, s.SEVERITY, s.CONFIDENCE, s.DETECTED_AT,
      s.EVIDENCE_JSON, s.RULE_VERSION, cs.CASE_ID, cs.STATUS AS CASE_STATUS, f.NARRATIVE,
      f.POLICY_REFERENCE FROM signals_alerts AS s LEFT JOIN cases AS cs ON cs.SIGNAL_ID
      = s.SIGNAL_ID LEFT JOIN findings AS f ON f.CASE_ID = cs.CASE_ID WHERE s.ENTITY_ID
      = ''{{customer_id}}'' ORDER BY s.DETECTED_AT DESC
    verified_at: 1789562359
    verified_by: Semantic Model Generator
',
  FALSE
)