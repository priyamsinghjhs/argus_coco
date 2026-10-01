-- ============================================================
-- 10_agent.sql  —  Argus Cortex Agent + supporting objects
-- Tables, stored procedures (tools), and agent deployment
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================
-- 1. Supporting tables
-- ============================================================
CREATE OR REPLACE TABLE GOVERNANCE.FINDINGS_REPORTS (
    report_id VARCHAR(40) NOT NULL, case_id VARCHAR(40), finding_id VARCHAR(40),
    report_type VARCHAR(30) NOT NULL, status VARCHAR(20) DEFAULT 'DRAFT',
    title VARCHAR(500) NOT NULL, narrative VARCHAR(16000), evidence_summary VARCHAR(8000),
    policy_citations VARCHAR(4000), confidence NUMBER(3,2), typology VARCHAR(30),
    customer_id INT, created_by VARCHAR(50) DEFAULT 'ARGUS_AGENT',
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(), approved_by VARCHAR(50),
    approved_at TIMESTAMP_NTZ, version INT DEFAULT 1,
    CONSTRAINT pk_findings_reports PRIMARY KEY (report_id)
);

CREATE OR REPLACE TABLE GOVERNANCE.QUESTION_LOG (
    log_id VARCHAR(40) NOT NULL, session_id VARCHAR(100), question VARCHAR(4000) NOT NULL,
    tool_used VARCHAR(50), sql_generated VARCHAR(8000), evidence_refs VARCHAR(4000),
    policy_citations VARCHAR(2000), confidence NUMBER(3,2), response_summary VARCHAR(4000),
    user_role VARCHAR(30), timestamp TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_question_log PRIMARY KEY (log_id)
);

-- ============================================================
-- 2. Agent tool procedures
-- ============================================================
CREATE OR REPLACE PROCEDURE GOVERNANCE.UPSERT_CASE(
    P_SIGNAL_ID VARCHAR, P_SIGNAL_TYPE VARCHAR, P_CUSTOMER_ID INT,
    P_STATUS VARCHAR, P_PRIORITY VARCHAR, P_ASSIGNED_TO VARCHAR, P_ASSIGNED_ROLE VARCHAR
) RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER AS
BEGIN
    LET v_case_id VARCHAR := 'CASE-' || LPAD(ABS(HASH(:P_SIGNAL_ID))::VARCHAR, 8, '0');
    MERGE INTO GOVERNANCE.CASES tgt USING (SELECT :v_case_id AS case_id) src ON tgt.case_id = src.case_id
    WHEN MATCHED THEN UPDATE SET status = :P_STATUS, updated_at = CURRENT_TIMESTAMP(),
        closed_at = IFF(:P_STATUS LIKE 'CLOSED%', CURRENT_TIMESTAMP(), tgt.closed_at),
        resolution = IFF(:P_STATUS = 'CLOSED_CONFIRMED', 'STR_FILED', IFF(:P_STATUS = 'CLOSED_FALSE_POS', 'FALSE_POSITIVE', tgt.resolution))
    WHEN NOT MATCHED THEN INSERT (case_id, signal_id, signal_type, customer_id, status, priority, assigned_to, assigned_role, created_at, updated_at)
        VALUES (:v_case_id, :P_SIGNAL_ID, :P_SIGNAL_TYPE, :P_CUSTOMER_ID, :P_STATUS, :P_PRIORITY, :P_ASSIGNED_TO, :P_ASSIGNED_ROLE, CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
    RETURN 'Case ' || :v_case_id || ' upserted with status ' || :P_STATUS;
END;

CREATE OR REPLACE PROCEDURE GOVERNANCE.DRAFT_FINDING_REPORT(
    P_CASE_ID VARCHAR, P_REPORT_TYPE VARCHAR, P_TITLE VARCHAR,
    P_NARRATIVE VARCHAR, P_EVIDENCE_SUMMARY VARCHAR, P_POLICY_CITATIONS VARCHAR,
    P_CONFIDENCE FLOAT, P_TYPOLOGY VARCHAR, P_CUSTOMER_ID INT
) RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER AS
BEGIN
    LET v_report_id VARCHAR := 'RPT-' || LPAD(ABS(HASH(:P_CASE_ID || CURRENT_TIMESTAMP()::VARCHAR))::VARCHAR, 8, '0');
    INSERT INTO GOVERNANCE.FINDINGS_REPORTS (report_id, case_id, report_type, status, title, narrative, evidence_summary, policy_citations, confidence, typology, customer_id)
    VALUES (:v_report_id, :P_CASE_ID, :P_REPORT_TYPE, 'DRAFT', :P_TITLE, :P_NARRATIVE, :P_EVIDENCE_SUMMARY, :P_POLICY_CITATIONS, :P_CONFIDENCE, :P_TYPOLOGY, :P_CUSTOMER_ID);
    RETURN 'Draft report ' || :v_report_id || ' created for case ' || :P_CASE_ID || ' (status: DRAFT, awaiting human review)';
END;

CREATE OR REPLACE PROCEDURE GOVERNANCE.LOG_QUESTION(
    P_SESSION_ID VARCHAR, P_QUESTION VARCHAR, P_TOOL_USED VARCHAR,
    P_SQL_GENERATED VARCHAR, P_EVIDENCE_REFS VARCHAR, P_POLICY_CITATIONS VARCHAR,
    P_CONFIDENCE FLOAT, P_RESPONSE_SUMMARY VARCHAR, P_USER_ROLE VARCHAR
) RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER AS
BEGIN
    LET v_log_id VARCHAR := 'LOG-' || LPAD(ABS(HASH(:P_SESSION_ID || CURRENT_TIMESTAMP()::VARCHAR))::VARCHAR, 8, '0');
    INSERT INTO GOVERNANCE.QUESTION_LOG (log_id, session_id, question, tool_used, sql_generated, evidence_refs, policy_citations, confidence, response_summary, user_role)
    VALUES (:v_log_id, :P_SESSION_ID, :P_QUESTION, :P_TOOL_USED, :P_SQL_GENERATED, :P_EVIDENCE_REFS, :P_POLICY_CITATIONS, :P_CONFIDENCE, :P_RESPONSE_SUMMARY, :P_USER_ROLE);
    RETURN 'Logged question ' || :v_log_id;
END;

CREATE OR REPLACE PROCEDURE GOVERNANCE.NOTIFY_STATE_CHANGE(
    P_ENTITY_TYPE VARCHAR, P_ENTITY_ID VARCHAR, P_OLD_STATE VARCHAR,
    P_NEW_STATE VARCHAR, P_MESSAGE VARCHAR
) RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER AS
BEGIN
    LET v_log_id VARCHAR := 'NOTIF-' || LPAD(ABS(HASH(:P_ENTITY_ID || CURRENT_TIMESTAMP()::VARCHAR))::VARCHAR, 8, '0');
    INSERT INTO GOVERNANCE.QUESTION_LOG (log_id, session_id, question, tool_used, response_summary, user_role)
    VALUES (:v_log_id, 'SYSTEM', 'State change: ' || :P_ENTITY_TYPE || ' ' || :P_ENTITY_ID || ' ' || :P_OLD_STATE || ' -> ' || :P_NEW_STATE, 'NOTIFY_STATE_CHANGE', :P_MESSAGE, 'SYSTEM');
    RETURN 'Notification queued: ' || :P_ENTITY_TYPE || ' ' || :P_ENTITY_ID || ' changed to ' || :P_NEW_STATE;
END;

-- ============================================================
-- 3. Agent deployment
-- NOTE: Deploy the YAML spec from argus_agent.yaml using:
--   cortex agent-studio agent-deploy --file-path argus_agent.yaml --fqn ARGUS_RISK_COPILOT.GOVERNANCE.ARGUS_COPILOT
-- ============================================================

-- 4. Grants
GRANT USAGE ON AGENT GOVERNANCE.ARGUS_COPILOT TO ROLE PLATFORM_ADMIN;
GRANT USAGE ON AGENT GOVERNANCE.ARGUS_COPILOT TO ROLE COMPLIANCE_OFFICER;
GRANT USAGE ON AGENT GOVERNANCE.ARGUS_COPILOT TO ROLE FRAUD_ANALYST;
GRANT USAGE ON AGENT GOVERNANCE.ARGUS_COPILOT TO ROLE CREDIT_ANALYST;
GRANT USAGE ON AGENT GOVERNANCE.ARGUS_COPILOT TO ROLE AUDITOR;
GRANT MONITOR ON AGENT GOVERNANCE.ARGUS_COPILOT TO ROLE PLATFORM_ADMIN;

GRANT SELECT, INSERT, UPDATE ON TABLE GOVERNANCE.FINDINGS_REPORTS TO ROLE COMPLIANCE_OFFICER;
GRANT SELECT, INSERT, UPDATE ON TABLE GOVERNANCE.FINDINGS_REPORTS TO ROLE FRAUD_ANALYST;
GRANT SELECT ON TABLE GOVERNANCE.FINDINGS_REPORTS TO ROLE AUDITOR;
GRANT SELECT ON TABLE GOVERNANCE.QUESTION_LOG TO ROLE COMPLIANCE_OFFICER;
GRANT SELECT ON TABLE GOVERNANCE.QUESTION_LOG TO ROLE AUDITOR;
