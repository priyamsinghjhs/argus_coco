-- =============================================================================
-- ARGUS -- Integrations & Notifications DDL
-- =============================================================================
-- Tables, seed data, and stored procedures for the Integrations tab.
-- Run once to set up. All statements use IF NOT EXISTS / MERGE so the
-- script is safe to re-run.
-- =============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE SCHEMA GOVERNANCE;

-- ─── 1. Tables ──────────────────────────────────────────────────────────────

-- 1a. FINDINGS_REPORTS -- STR/SAR draft reports with approve/reject workflow
CREATE TABLE IF NOT EXISTS FINDINGS_REPORTS (
    REPORT_ID        VARCHAR NOT NULL PRIMARY KEY,
    CASE_ID          VARCHAR,
    REPORT_TYPE      VARCHAR,          -- STR, ATO_INCIDENT, CREDIT_REVIEW, ESCALATION_MEMO, GENERAL
    TITLE            VARCHAR,
    NARRATIVE        VARCHAR,          -- Agent-generated or manually drafted narrative
    EVIDENCE_SUMMARY VARCHAR,          -- Condensed evidence from signals
    POLICY_CITATIONS VARCHAR,          -- Relevant policy section references
    TYPOLOGY         VARCHAR,          -- STRUCTURING, MONEY_MULE, ACCOUNT_TAKEOVER, LOAN_STACKING
    CUSTOMER_ID      NUMBER(38,0),
    CONFIDENCE       FLOAT,
    STATUS           VARCHAR DEFAULT 'DRAFT',  -- DRAFT -> APPROVED / RETURNED / REJECTED
    VERSION          NUMBER(38,0) DEFAULT 1,
    CREATED_BY       VARCHAR,
    CREATED_AT       TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    APPROVED_BY      VARCHAR,
    APPROVED_AT      TIMESTAMP_LTZ
);

-- 1b. NOTIFICATION_RECIPIENTS -- email recipients with per-user alert preferences
CREATE TABLE IF NOT EXISTS NOTIFICATION_RECIPIENTS (
    RECIPIENT_ID   NUMBER(38,0) NOT NULL AUTOINCREMENT PRIMARY KEY,
    EMAIL          VARCHAR NOT NULL,
    DISPLAY_NAME   VARCHAR,
    ROLE_FILTER    VARCHAR,            -- NULL or 'ALL' = all roles; else specific role name
    ALERT_SIGNALS  BOOLEAN DEFAULT TRUE,
    ALERT_FINDINGS BOOLEAN DEFAULT TRUE,
    ALERT_REPORTS  BOOLEAN DEFAULT TRUE,
    ALERT_DIGEST   BOOLEAN DEFAULT TRUE,
    MIN_SEVERITY   VARCHAR DEFAULT 'HIGH',   -- LOW, MEDIUM, HIGH, CRITICAL
    ACTIVE         BOOLEAN DEFAULT TRUE,
    ADDED_AT       TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 1c. NOTIFICATION_CONFIG -- per-channel, per-loop-stage enable/disable
CREATE TABLE IF NOT EXISTS NOTIFICATION_CONFIG (
    CHANNEL      VARCHAR NOT NULL,     -- EMAIL, SLACK, SMS, TEAMS, JIRA
    LOOP_STAGE   VARCHAR NOT NULL,     -- SIGNAL_DETECTED, FINDING_CREATED, REPORT_DRAFTED, etc.
    ENABLED      BOOLEAN DEFAULT FALSE,
    DESTINATION  VARCHAR,              -- webhook URL, phone number, Jira base URL, etc.
    MIN_SEVERITY VARCHAR DEFAULT 'HIGH',
    UPDATED_AT   TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
    PRIMARY KEY (CHANNEL, LOOP_STAGE)
);

-- 1d. NOTIFICATION_LOG -- dispatch audit log
CREATE TABLE IF NOT EXISTS NOTIFICATION_LOG (
    NOTIF_ID      NUMBER(38,0) NOT NULL AUTOINCREMENT PRIMARY KEY,
    EVENT_TYPE    VARCHAR,             -- STATE_CHANGE, SIGNAL_ALERT, FINDING_ALERT, etc.
    ENTITY_TYPE   VARCHAR,             -- CASE, SIGNAL, FINDING, REPORT
    ENTITY_ID     VARCHAR,
    CHANNEL       VARCHAR,
    LOOP_STAGE    VARCHAR,
    DESTINATION   VARCHAR,
    STATUS        VARCHAR,             -- SENT, FAILED, PENDING, NOT_CONFIGURED
    ERROR_MESSAGE VARCHAR,
    SENT_AT       TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);

-- 1e. QUESTION_LOG -- audit trail for Argus agent questions and answers
CREATE TABLE IF NOT EXISTS QUESTION_LOG (
    LOG_ID           NUMBER(38,0) NOT NULL AUTOINCREMENT PRIMARY KEY,
    SESSION_ID       VARCHAR,
    QUESTION         VARCHAR,
    TOOL_USED        VARCHAR,          -- SEMANTIC_VIEW, POLICY_SEARCH, CORTEX_COMPLETE, etc.
    CONFIDENCE       FLOAT,
    RESPONSE_SUMMARY VARCHAR,
    USER_ROLE        VARCHAR,
    QUERIED_BY       VARCHAR,
    TIMESTAMP        TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);


-- ─── 2. Seed Data -- Default Notification Channel Config (13 rows) ──────────

MERGE INTO NOTIFICATION_CONFIG AS t
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


-- ─── 3. Stored Procedures ───────────────────────────────────────────────────

-- 3a. DRAFT_FINDING_REPORT -- creates a report row from a case finding
CREATE OR REPLACE PROCEDURE DRAFT_FINDING_REPORT(
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
    INSERT INTO FINDINGS_REPORTS
        (REPORT_ID, CASE_ID, REPORT_TYPE, TITLE, NARRATIVE, EVIDENCE_SUMMARY,
         POLICY_CITATIONS, TYPOLOGY, CUSTOMER_ID, CONFIDENCE, STATUS, CREATED_BY, CREATED_AT)
    VALUES (:v_report_id, :P_CASE_ID, :P_REPORT_TYPE, :P_TITLE, :P_NARRATIVE, :P_EVIDENCE,
            :P_POLICY, :P_TYPOLOGY, :P_CUSTOMER_ID, :P_CONFIDENCE, 'DRAFT', CURRENT_USER(), CURRENT_TIMESTAMP());
    RETURN 'Report ' || :v_report_id || ' drafted successfully.';
END;

-- 3b. APPROVE_REPORT -- approve, return, or reject a draft report
CREATE OR REPLACE PROCEDURE APPROVE_REPORT(
    P_REPORT_ID VARCHAR, P_ACTION VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    IF (:P_ACTION = 'APPROVE') THEN
        UPDATE FINDINGS_REPORTS
        SET STATUS = 'APPROVED', APPROVED_BY = CURRENT_USER(), APPROVED_AT = CURRENT_TIMESTAMP()
        WHERE REPORT_ID = :P_REPORT_ID;
        RETURN 'Report ' || :P_REPORT_ID || ' approved by ' || CURRENT_USER();
    ELSEIF (:P_ACTION = 'RETURN') THEN
        UPDATE FINDINGS_REPORTS SET STATUS = 'RETURNED' WHERE REPORT_ID = :P_REPORT_ID;
        RETURN 'Report ' || :P_REPORT_ID || ' returned for edits.';
    ELSEIF (:P_ACTION = 'REJECT') THEN
        UPDATE FINDINGS_REPORTS SET STATUS = 'REJECTED' WHERE REPORT_ID = :P_REPORT_ID;
        RETURN 'Report ' || :P_REPORT_ID || ' rejected.';
    ELSE
        RETURN 'Unknown action: ' || :P_ACTION;
    END IF;
END;

-- 3c. NOTIFY_STATE_CHANGE -- log a notification on case status changes
CREATE OR REPLACE PROCEDURE NOTIFY_STATE_CHANGE(
    P_ENTITY_TYPE VARCHAR, P_ENTITY_ID VARCHAR,
    P_OLD_STATUS VARCHAR, P_NEW_STATUS VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    INSERT INTO NOTIFICATION_LOG
        (EVENT_TYPE, ENTITY_TYPE, ENTITY_ID, CHANNEL, LOOP_STAGE, STATUS, SENT_AT)
    VALUES ('STATE_CHANGE', :P_ENTITY_TYPE, :P_ENTITY_ID, 'EMAIL', 'CASE_STATUS_CHANGE',
            'SENT', CURRENT_TIMESTAMP());
    RETURN :P_ENTITY_TYPE || ' ' || :P_ENTITY_ID || ' notification logged: ' || :P_OLD_STATUS || ' -> ' || :P_NEW_STATUS;
END;

-- 3d. REBUILD_EMAIL_INTEGRATION -- recreates notification integration from active recipients
CREATE OR REPLACE PROCEDURE REBUILD_EMAIL_INTEGRATION()
RETURNS VARCHAR
LANGUAGE SQL
EXECUTE AS OWNER
AS
BEGIN
    LET v_emails VARCHAR;
    SELECT LISTAGG('''' || EMAIL || '''', ', ') INTO :v_emails
    FROM NOTIFICATION_RECIPIENTS WHERE ACTIVE = TRUE;

    IF (:v_emails IS NULL OR :v_emails = '') THEN
        RETURN 'No active recipients found. Add recipients first.';
    END IF;

    EXECUTE IMMEDIATE
        'CREATE OR REPLACE NOTIFICATION INTEGRATION ARGUS_EMAIL_INTEGRATION ' ||
        'TYPE = EMAIL ENABLED = TRUE ALLOWED_RECIPIENTS = (' || :v_emails || ')';
    RETURN 'Email integration rebuilt with active recipients.';
END;

-- 3e. SEND_TEST_EMAIL -- sends a test email to verify recipient setup
CREATE OR REPLACE PROCEDURE SEND_TEST_EMAIL(P_EMAIL VARCHAR)
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

-- =============================================================================
-- Done. All Integrations & Notifications objects are in place.
-- =============================================================================
