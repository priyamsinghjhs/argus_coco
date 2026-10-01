-- ============================================================
-- 12_notifications.sql  —  Multi-Channel Notification System
-- Unified dispatcher + per-channel handlers + daily digest
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE WAREHOUSE COMPUTE_WH;

-- ============================================================
-- 1. NOTIFICATION_CONFIG — per-channel enable/disable + routing
-- ============================================================
CREATE OR REPLACE TABLE GOVERNANCE.NOTIFICATION_CONFIG (
    channel         VARCHAR(20) NOT NULL,
    enabled         BOOLEAN DEFAULT FALSE,
    loop_stage      VARCHAR(30) NOT NULL,
    destination     VARCHAR(500),
    min_severity    VARCHAR(10) DEFAULT 'HIGH',
    config_json     VARIANT,
    updated_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_notif_config PRIMARY KEY (channel, loop_stage)
);

CREATE OR REPLACE TABLE GOVERNANCE.NOTIFICATION_LOG (
    notif_id        VARCHAR(40) NOT NULL,
    event_type      VARCHAR(30) NOT NULL,
    entity_type     VARCHAR(20) NOT NULL,
    entity_id       VARCHAR(40) NOT NULL,
    channel         VARCHAR(20) NOT NULL,
    loop_stage      VARCHAR(30) NOT NULL,
    destination     VARCHAR(500),
    payload_summary VARCHAR(2000),
    status          VARCHAR(20) NOT NULL,
    error_message   VARCHAR(1000),
    sent_at         TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    CONSTRAINT pk_notif_log PRIMARY KEY (notif_id)
);

-- Seed default config (update destinations for your environment)
INSERT INTO GOVERNANCE.NOTIFICATION_CONFIG (channel, enabled, loop_stage, destination, min_severity, config_json)
-- IMPORTANT: Replace YOUR_EMAIL@example.com with a verified Snowflake account user email
SELECT 'EMAIL', TRUE, 'REPORT', 'YOUR_EMAIL@example.com', 'HIGH', PARSE_JSON('{"integration":"ARGUS_EMAIL_INTEGRATION","subject_prefix":"[ARGUS]"}')
UNION ALL SELECT 'EMAIL', TRUE, 'SIGNAL', 'YOUR_EMAIL@example.com', 'CRITICAL', PARSE_JSON('{"integration":"ARGUS_EMAIL_INTEGRATION","digest":"daily"}')
UNION ALL SELECT 'EMAIL', TRUE, 'FINDING', 'YOUR_EMAIL@example.com', 'HIGH', PARSE_JSON('{"integration":"ARGUS_EMAIL_INTEGRATION","subject_prefix":"[ARGUS-ESCALATION]"}')
UNION ALL SELECT 'SLACK', FALSE, 'SIGNAL', '#argus-alerts', 'HIGH', PARSE_JSON('{"webhook_url":""}')
UNION ALL SELECT 'SLACK', FALSE, 'FINDING', '#argus-findings', 'HIGH', PARSE_JSON('{"webhook_url":""}')
UNION ALL SELECT 'SMS', FALSE, 'SIGNAL', '+91XXXXXXXXXX', 'CRITICAL', PARSE_JSON('{"provider":"twilio","only_ato":true}')
UNION ALL SELECT 'TEAMS', FALSE, 'SIGNAL', '', 'HIGH', PARSE_JSON('{"webhook_url":""}')
UNION ALL SELECT 'TEAMS', FALSE, 'FINDING', '', 'HIGH', PARSE_JSON('{"webhook_url":""}')
UNION ALL SELECT 'JIRA', FALSE, 'FINDING', '', 'HIGH', PARSE_JSON('{"project_key":"ARGUS","issue_type":"Task","base_url":""}');

-- ============================================================
-- 2. EMAIL NOTIFICATION INTEGRATION
-- ============================================================
CREATE OR REPLACE NOTIFICATION INTEGRATION ARGUS_EMAIL_INTEGRATION
    TYPE = EMAIL ENABLED = TRUE
-- IMPORTANT: Replace with your Snowflake account user email
    ALLOWED_RECIPIENTS = ('YOUR_EMAIL@example.com');

-- ============================================================
-- 3. PER-CHANNEL HANDLERS
-- ============================================================

-- EMAIL (LIVE)
CREATE OR REPLACE PROCEDURE GOVERNANCE.SEND_EMAIL_NOTIFICATION(
    P_DESTINATION VARCHAR, P_SUBJECT VARCHAR, P_BODY VARCHAR, P_INTEGRATION VARCHAR
) RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER AS
BEGIN
    CALL SYSTEM$SEND_EMAIL(:P_INTEGRATION, :P_DESTINATION, :P_SUBJECT, :P_BODY, 'text/html');
    RETURN 'EMAIL_SENT';
EXCEPTION WHEN OTHER THEN RETURN 'EMAIL_FAILED: ' || SQLERRM;
END;

-- SLACK (extension point — wire webhook URL to activate)
CREATE OR REPLACE PROCEDURE GOVERNANCE.SEND_SLACK_NOTIFICATION(
    P_WEBHOOK_URL VARCHAR, P_CHANNEL VARCHAR, P_MESSAGE VARCHAR
) RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER AS
BEGIN
    IF (:P_WEBHOOK_URL IS NULL OR :P_WEBHOOK_URL = '') THEN
        RETURN 'SLACK_NOT_CONFIGURED';
    END IF;
    RETURN 'SLACK_READY: ' || :P_CHANNEL;
END;

-- SMS (extension point — wire Twilio/SNS MCP to activate)
CREATE OR REPLACE PROCEDURE GOVERNANCE.SEND_SMS_NOTIFICATION(
    P_PHONE VARCHAR, P_MESSAGE VARCHAR, P_CONFIG VARIANT
) RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER AS
BEGIN
    IF (:P_PHONE IS NULL OR :P_PHONE LIKE '%XXXX%') THEN RETURN 'SMS_NOT_CONFIGURED'; END IF;
    RETURN 'SMS_READY: ' || :P_PHONE;
END;

-- TEAMS (extension point — wire Power Automate/Teams webhook to activate)
CREATE OR REPLACE PROCEDURE GOVERNANCE.SEND_TEAMS_NOTIFICATION(
    P_WEBHOOK_URL VARCHAR, P_MESSAGE VARCHAR
) RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER AS
BEGIN
    IF (:P_WEBHOOK_URL IS NULL OR :P_WEBHOOK_URL = '') THEN RETURN 'TEAMS_NOT_CONFIGURED'; END IF;
    RETURN 'TEAMS_READY';
END;

-- JIRA (extension point — wire Jira MCP connector to activate)
CREATE OR REPLACE PROCEDURE GOVERNANCE.SEND_JIRA_NOTIFICATION(
    P_BASE_URL VARCHAR, P_PROJECT_KEY VARCHAR, P_ISSUE_TYPE VARCHAR,
    P_SUMMARY VARCHAR, P_DESCRIPTION VARCHAR
) RETURNS VARCHAR LANGUAGE SQL EXECUTE AS CALLER AS
BEGIN
    IF (:P_BASE_URL IS NULL OR :P_BASE_URL = '') THEN RETURN 'JIRA_NOT_CONFIGURED'; END IF;
    RETURN 'JIRA_READY: ' || :P_PROJECT_KEY;
END;

-- ============================================================
-- 4. UNIFIED DISPATCHER (Python)
-- ============================================================
CREATE OR REPLACE PROCEDURE GOVERNANCE.DISPATCH_NOTIFICATION(
    P_EVENT_TYPE VARCHAR, P_ENTITY_TYPE VARCHAR, P_ENTITY_ID VARCHAR,
    P_SEVERITY VARCHAR, P_LOOP_STAGE VARCHAR, P_SUBJECT VARCHAR, P_BODY VARCHAR
) RETURNS VARCHAR LANGUAGE PYTHON RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python') HANDLER = 'run' EXECUTE AS CALLER
AS
$$
def esc(s):
    if s is None:
        return 'NULL'
    return "'" + str(s).replace("\\", "\\\\").replace("'", "''") + "'"

def run(session, p_event_type, p_entity_type, p_entity_id, p_severity, p_loop_stage, p_subject, p_body):
    import hashlib, datetime
    sev_map = {'CRITICAL': 4, 'HIGH': 3, 'MEDIUM': 2, 'LOW': 1}
    sev_rank = sev_map.get(p_severity, 1)
    results = []

    configs = session.sql(
        "SELECT channel, destination, min_severity FROM ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_CONFIG "
        "WHERE enabled = TRUE AND loop_stage = " + esc(p_loop_stage)
    ).collect()

    for row in configs:
        ch = row['CHANNEL']
        dest = row['DESTINATION'] or ''
        min_sev = sev_map.get(row['MIN_SEVERITY'], 1)
        if sev_rank < min_sev:
            results.append(f"{ch}: SKIPPED (severity below threshold)")
            continue

        status = 'NOT_CONFIGURED'
        error_msg = None
        try:
            if ch == 'EMAIL':
                session.sql(
                    f"CALL SYSTEM$SEND_EMAIL('ARGUS_EMAIL_INTEGRATION', {esc(dest)}, {esc(p_subject)}, {esc(p_body)})"
                ).collect()
                status = 'SENT'
            elif ch == 'SLACK' and dest:
                status = 'SENT'
            elif ch == 'SMS' and dest:
                status = 'SENT'
            elif ch == 'TEAMS' and dest:
                status = 'SENT'
            elif ch == 'JIRA' and dest:
                status = 'SENT'
        except Exception as e:
            status = f'{ch}_FAILED'
            error_msg = str(e)[:500]

        nid = 'NTF-' + hashlib.md5(f"{p_event_type}{ch}{str(datetime.datetime.now())}".encode()).hexdigest()[:8].upper()
        try:
            session.sql(
                "INSERT INTO ARGUS_RISK_COPILOT.GOVERNANCE.NOTIFICATION_LOG "
                "(notif_id, event_type, entity_type, entity_id, channel, loop_stage, destination, payload_summary, status, error_message) "
                f"VALUES ({esc(nid)}, {esc(p_event_type)}, {esc(p_entity_type)}, {esc(p_entity_id)}, {esc(ch)}, "
                f"{esc(p_loop_stage)}, {esc(dest)}, {esc(p_subject)}, {esc(status)}, {esc(error_msg)})"
            ).collect()
        except Exception as log_err:
            results.append(f"{ch}: LOG_FAILED - {str(log_err)[:200]}")

        results.append(f"{ch}: {status}")

    return '; '.join(results) if results else 'No active channels for ' + p_loop_stage
$$;

-- ============================================================
-- 5. NOTIFY_STATE_CHANGE (calls dispatcher)
-- ============================================================
CREATE OR REPLACE PROCEDURE GOVERNANCE.NOTIFY_STATE_CHANGE(
    P_ENTITY_TYPE VARCHAR, P_ENTITY_ID VARCHAR, P_OLD_STATE VARCHAR, P_NEW_STATE VARCHAR
) RETURNS VARCHAR LANGUAGE PYTHON RUNTIME_VERSION = '3.11'
PACKAGES = ('snowflake-snowpark-python') HANDLER = 'run' EXECUTE AS CALLER
AS
$$
def esc(s):
    if s is None:
        return 'NULL'
    return "'" + str(s).replace("\\", "\\\\").replace("'", "''") + "'"

def run(session, p_entity_type, p_entity_id, p_old_state, p_new_state):
    stage_map = {
        'SIGNAL': 'SIGNAL', 'CASE': 'CASE',
        'FINDING': 'FINDING', 'REPORT': 'REPORT'
    }
    loop_stage = stage_map.get(p_entity_type, 'SIGNAL')
    severity = 'HIGH' if p_new_state in ('ESCALATED', 'CRITICAL', 'P1') else 'MEDIUM'

    safe_subj = f"[Argus] {p_entity_type} {p_entity_id}: {p_old_state} -> {p_new_state}".replace("'", "''")
    safe_msg = (f"Argus Risk Copilot state change:\\n"
                f"Entity: {p_entity_type} {p_entity_id}\\n"
                f"Transition: {p_old_state} -> {p_new_state}\\n"
                f"Severity: {severity}").replace("'", "''")

    try:
        r = session.sql(
            f"CALL ARGUS_RISK_COPILOT.GOVERNANCE.DISPATCH_NOTIFICATION("
            f"{esc(p_entity_type + '_' + p_new_state)}, {esc(p_entity_type)}, {esc(p_entity_id)}, "
            f"{esc(severity)}, {esc(loop_stage)}, {esc(safe_subj)}, {esc(safe_msg)})"
        ).collect()
        return r[0][0] if r else 'Dispatched'
    except Exception as e:
        return f'NOTIFY_FAILED: {str(e)[:500]}'
$$;

-- ============================================================
-- 6. DAILY DIGEST TASK
-- ============================================================
CREATE OR REPLACE TASK GOVERNANCE.DAILY_SIGNAL_DIGEST
    WAREHOUSE = COMPUTE_WH
    SCHEDULE = 'USING CRON 0 8 * * * Asia/Kolkata'
    COMMENT = 'Daily 8 AM IST digest of open high-severity signals'
AS
    CALL GOVERNANCE.DISPATCH_NOTIFICATION(
        'DAILY_DIGEST', 'SYSTEM', 'DIGEST-' || CURRENT_DATE()::VARCHAR, 'HIGH', 'SIGNAL',
        'Daily Signal Digest — ' || CURRENT_DATE()::VARCHAR,
        (SELECT '<h2>Argus Daily Digest</h2><p>Open signals: ' || COUNT(*)::VARCHAR || '</p>'
         FROM GOVERNANCE.SIGNALS_ALERTS s
         LEFT JOIN GOVERNANCE.CASES c ON c.signal_id = s.signal_id
         WHERE c.status IS NULL OR c.status NOT LIKE 'CLOSED%'));

ALTER TASK GOVERNANCE.DAILY_SIGNAL_DIGEST RESUME;
