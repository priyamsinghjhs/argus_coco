-- ============================================================
-- 06_signals_pipeline.sql
-- GOVERNANCE.SIGNALS_ALERTS — Dynamic Table that evaluates
-- four typology rules against CONFORMED data every 15 minutes
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE WAREHOUSE COMPUTE_WH;

CREATE OR REPLACE DYNAMIC TABLE GOVERNANCE.SIGNALS_ALERTS
    TARGET_LAG = '15 minutes'
    WAREHOUSE = COMPUTE_WH
AS
WITH
-- ================================================================
-- TYPOLOGY 1: STRUCTURING — 48-hour sliding window via self-join
-- 3+ cash deposits of INR 2.5L-3.5L within 48 hrs, across 2+ geos,
-- summing just under INR 10L
-- ================================================================
structuring_pairs AS (
    SELECT
        t1.account_id, a.customer_id,
        t1.transaction_id AS anchor_txn, t1.timestamp AS anchor_ts,
        t2.transaction_id AS paired_txn, t2.timestamp AS paired_ts,
        t2.amount, t2.geo_location
    FROM CONFORMED.TRANSACTIONS_CLEAN t1
    JOIN CONFORMED.TRANSACTIONS_CLEAN t2
        ON t2.account_id = t1.account_id
        AND t2.transaction_type = 'CREDIT'
        AND t2.channel IN ('BRANCH', 'ATM')
        AND t2.amount BETWEEN 250000 AND 350000
        AND t2.timestamp BETWEEN t1.timestamp AND DATEADD(hour, 48, t1.timestamp)
    JOIN CONFORMED.ACCOUNTS_CLEAN a ON a.account_id = t1.account_id
    WHERE t1.transaction_type = 'CREDIT'
      AND t1.channel IN ('BRANCH', 'ATM')
      AND t1.amount BETWEEN 250000 AND 350000
),
structuring_signals AS (
    SELECT
        account_id, customer_id, anchor_txn,
        MIN(paired_ts) AS window_start, MAX(paired_ts) AS window_end,
        COUNT(DISTINCT paired_txn) AS deposit_count,
        SUM(DISTINCT amount) AS total_amount,
        COUNT(DISTINCT geo_location) AS distinct_geos,
        ARRAY_AGG(DISTINCT paired_txn) AS evidence_txn_ids,
        ARRAY_AGG(DISTINCT geo_location) AS evidence_geos
    FROM structuring_pairs
    GROUP BY account_id, customer_id, anchor_txn
    HAVING deposit_count >= 3
       AND total_amount BETWEEN 700000 AND 1100000
       AND distinct_geos >= 2
),
structuring_out AS (
    SELECT
        MD5(customer_id::VARCHAR || '|STRUCTURING|' || window_start::VARCHAR) AS signal_id,
        'STRUCTURING'   AS signal_type,
        customer_id::VARCHAR AS entity_id,
        'CUSTOMER'      AS entity_type,
        window_end      AS detected_at,
        'HIGH'          AS severity,
        CASE
            WHEN total_amount >= 900000 THEN 0.95
            WHEN total_amount >= 800000 THEN 0.85
            ELSE 0.75
        END             AS confidence,
        OBJECT_CONSTRUCT(
            'account_id', account_id,
            'deposit_count', deposit_count,
            'total_amount', total_amount,
            'distinct_geos', distinct_geos,
            'transaction_ids', evidence_txn_ids,
            'geolocations', evidence_geos,
            'policy_ref', 'AML Policy Manual, Section 4.2'
        )::VARIANT      AS evidence_json,
        'v1.0'          AS rule_version
    FROM structuring_signals
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_amount DESC) = 1
),

-- ================================================================
-- TYPOLOGY 2: MONEY MULE
-- Dormant 60+ days, then burst 10+ inbound from unrelated
-- counterparties, outbound within 24 hrs
-- ================================================================
account_activity_gaps AS (
    SELECT
        account_id,
        timestamp,
        LAG(timestamp) OVER (PARTITION BY account_id ORDER BY timestamp) AS prev_ts,
        DATEDIFF(day, LAG(timestamp) OVER (PARTITION BY account_id ORDER BY timestamp), timestamp) AS gap_days
    FROM CONFORMED.TRANSACTIONS_CLEAN
),
dormant_reactivations AS (
    SELECT DISTINCT account_id,
           timestamp AS reactivation_ts
    FROM account_activity_gaps
    WHERE gap_days >= 60
),
mule_inbound AS (
    SELECT
        t.account_id,
        dr.reactivation_ts,
        COUNT(DISTINCT t.counterparty_id) AS distinct_senders,
        COUNT(*)                          AS inbound_count,
        SUM(t.amount)                     AS inbound_total,
        ARRAY_AGG(DISTINCT t.transaction_id) AS inbound_txn_ids
    FROM CONFORMED.TRANSACTIONS_CLEAN t
    JOIN dormant_reactivations dr ON dr.account_id = t.account_id
    WHERE t.transaction_type = 'CREDIT'
      AND t.timestamp BETWEEN dr.reactivation_ts AND DATEADD(hour, 48, dr.reactivation_ts)
    GROUP BY t.account_id, dr.reactivation_ts
    HAVING distinct_senders >= 10
),
mule_outbound AS (
    SELECT
        t.account_id,
        mi.reactivation_ts,
        COUNT(*)      AS outbound_count,
        SUM(t.amount) AS outbound_total,
        ARRAY_AGG(DISTINCT t.transaction_id) AS outbound_txn_ids
    FROM CONFORMED.TRANSACTIONS_CLEAN t
    JOIN mule_inbound mi ON mi.account_id = t.account_id
    WHERE t.transaction_type = 'DEBIT'
      AND t.timestamp BETWEEN mi.reactivation_ts AND DATEADD(hour, 72, mi.reactivation_ts)
    GROUP BY t.account_id, mi.reactivation_ts
),
mule_out AS (
    SELECT
        MD5(mi.account_id::VARCHAR || '|MONEY_MULE|' || mi.reactivation_ts::VARCHAR) AS signal_id,
        'MONEY_MULE'     AS signal_type,
        a.customer_id::VARCHAR AS entity_id,
        'CUSTOMER'       AS entity_type,
        mi.reactivation_ts AS detected_at,
        'CRITICAL'       AS severity,
        0.90             AS confidence,
        OBJECT_CONSTRUCT(
            'account_id', mi.account_id,
            'dormancy_reactivation', mi.reactivation_ts,
            'distinct_senders', mi.distinct_senders,
            'inbound_count', mi.inbound_count,
            'inbound_total', mi.inbound_total,
            'outbound_count', COALESCE(mo.outbound_count, 0),
            'outbound_total', COALESCE(mo.outbound_total, 0),
            'inbound_txn_ids', mi.inbound_txn_ids,
            'outbound_txn_ids', mo.outbound_txn_ids,
            'policy_ref', 'AML Policy Manual, Section 4.3'
        )::VARIANT       AS evidence_json,
        'v1.0'           AS rule_version
    FROM mule_inbound mi
    JOIN CONFORMED.ACCOUNTS_CLEAN a ON a.account_id = mi.account_id
    LEFT JOIN mule_outbound mo ON mo.account_id = mi.account_id
        AND mo.reactivation_ts = mi.reactivation_ts
),

-- ================================================================
-- TYPOLOGY 3: ACCOUNT TAKEOVER
-- New-device login -> contact change within 60 min ->
-- large transfer to new payee within 120 min
-- ================================================================
new_device_logins AS (
    SELECT
        s.customer_id,
        s.device_id,
        s.login_timestamp,
        s.session_id
    FROM CONFORMED.DEVICE_SESSIONS_CLEAN s
    WHERE s.event_type = 'LOGIN'
      AND NOT EXISTS (
          SELECT 1 FROM CONFORMED.DEVICE_SESSIONS_CLEAN older
          WHERE older.customer_id = s.customer_id
            AND older.device_id = s.device_id
            AND older.login_timestamp < s.login_timestamp
      )
),
ato_contact_changes AS (
    SELECT
        ndl.customer_id,
        ndl.device_id,
        ndl.login_timestamp,
        ndl.session_id AS login_session_id,
        cc.session_id  AS change_session_id,
        cc.login_timestamp AS change_timestamp
    FROM new_device_logins ndl
    JOIN CONFORMED.DEVICE_SESSIONS_CLEAN cc
        ON cc.customer_id = ndl.customer_id
        AND cc.event_type IN ('CONTACT_CHANGE', 'PASSWORD_RESET')
        AND cc.login_timestamp BETWEEN ndl.login_timestamp AND DATEADD(minute, 60, ndl.login_timestamp)
),
ato_transfers AS (
    SELECT
        acc.customer_id,
        acc.device_id,
        acc.login_timestamp,
        acc.change_timestamp,
        t.transaction_id,
        t.amount,
        t.counterparty_id,
        t.timestamp AS transfer_timestamp
    FROM ato_contact_changes acc
    JOIN CONFORMED.ACCOUNTS_CLEAN a ON a.customer_id = acc.customer_id
    JOIN CONFORMED.TRANSACTIONS_CLEAN t ON t.account_id = a.account_id
        AND t.transaction_type = 'DEBIT'
        AND t.amount >= 200000
        AND t.timestamp BETWEEN acc.change_timestamp AND DATEADD(minute, 120, acc.change_timestamp)
),
ato_out AS (
    -- Strict rule: new device + contact change + high-value transfer = CRITICAL
    SELECT
        MD5(customer_id::VARCHAR || '|ACCOUNT_TAKEOVER|' || login_timestamp::VARCHAR) AS signal_id,
        'ACCOUNT_TAKEOVER' AS signal_type,
        customer_id::VARCHAR AS entity_id,
        'CUSTOMER'         AS entity_type,
        transfer_timestamp AS detected_at,
        'CRITICAL'         AS severity,
        0.92               AS confidence,
        OBJECT_CONSTRUCT(
            'customer_id', customer_id,
            'new_device_id', device_id,
            'login_timestamp', login_timestamp,
            'contact_change_timestamp', change_timestamp,
            'transfer_timestamp', transfer_timestamp,
            'transfer_amount', amount,
            'counterparty_id', counterparty_id,
            'transaction_id', transaction_id,
            'policy_ref', 'ATO Response Procedure, Section 2.1'
        )::VARIANT         AS evidence_json,
        'v1.0'             AS rule_version
    FROM ato_transfers

    UNION ALL

    -- Relaxed rule: new device + contact change or password reset (no transfer required) = HIGH
    SELECT
        MD5(acc.customer_id::VARCHAR || '|ATO_SUSPICIOUS|' || acc.login_timestamp::VARCHAR) AS signal_id,
        'ACCOUNT_TAKEOVER' AS signal_type,
        acc.customer_id::VARCHAR AS entity_id,
        'CUSTOMER'         AS entity_type,
        acc.change_timestamp AS detected_at,
        'HIGH'             AS severity,
        0.78               AS confidence,
        OBJECT_CONSTRUCT(
            'customer_id', acc.customer_id,
            'new_device_id', acc.device_id,
            'login_timestamp', acc.login_timestamp,
            'suspicious_event_timestamp', acc.change_timestamp,
            'policy_ref', 'ATO Response Procedure, Section 1.3 — Device anomaly with profile change'
        )::VARIANT         AS evidence_json,
        'v1.1'             AS rule_version
    FROM ato_contact_changes acc
    WHERE NOT EXISTS (
        SELECT 1 FROM ato_transfers at2
        WHERE at2.customer_id = acc.customer_id
          AND at2.login_timestamp = acc.login_timestamp
    )
),

-- ================================================================
-- TYPOLOGY 4: LOAN STACKING
-- 3+ loans within 14-day window, aggregate principal > 25L
-- ================================================================
loan_windows AS (
    SELECT
        l1.customer_id,
        l1.loan_id AS anchor_loan_id,
        l1.disbursement_date AS window_start,
        DATEADD(day, 14, l1.disbursement_date) AS window_end,
        COUNT(l2.loan_id) AS loans_in_window,
        SUM(l2.principal) AS total_principal,
        ARRAY_AGG(DISTINCT l2.loan_id) AS loan_ids,
        MIN(l2.latest_bureau_score) AS min_bureau_score
    FROM CONFORMED.LOANS_CLEAN l1
    JOIN CONFORMED.LOANS_CLEAN l2
        ON l2.customer_id = l1.customer_id
        AND l2.disbursement_date BETWEEN l1.disbursement_date AND DATEADD(day, 14, l1.disbursement_date)
    GROUP BY l1.customer_id, l1.loan_id, l1.disbursement_date
    HAVING loans_in_window >= 3
       AND total_principal > 2500000
),
loan_stacking_out AS (
    SELECT
        MD5(customer_id::VARCHAR || '|LOAN_STACKING|' || window_start::VARCHAR) AS signal_id,
        'LOAN_STACKING'  AS signal_type,
        customer_id::VARCHAR AS entity_id,
        'CUSTOMER'       AS entity_type,
        window_end       AS detected_at,
        'HIGH'           AS severity,
        CASE
            WHEN total_principal > 5000000 THEN 0.95
            WHEN total_principal > 3500000 THEN 0.85
            ELSE 0.75
        END              AS confidence,
        OBJECT_CONSTRUCT(
            'customer_id', customer_id,
            'window_start', window_start,
            'window_end', window_end,
            'loans_in_window', loans_in_window,
            'total_principal', total_principal,
            'loan_ids', loan_ids,
            'min_bureau_score', min_bureau_score,
            'policy_ref', 'Credit Risk Policy, Section 2.1-2.3'
        )::VARIANT       AS evidence_json,
        'v1.0'           AS rule_version
    FROM loan_windows
    QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY total_principal DESC) = 1
)

-- ================================================================
-- UNION ALL typologies into single alerts table
-- ================================================================
SELECT * FROM structuring_out
UNION ALL
SELECT * FROM mule_out
UNION ALL
SELECT * FROM ato_out
UNION ALL
SELECT * FROM loan_stacking_out;
