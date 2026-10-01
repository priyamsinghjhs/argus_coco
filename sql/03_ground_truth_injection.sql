-- ============================================================
-- 03_ground_truth_injection.sql
-- Plants labelled cases for 4 flagship typologies into RAW data.
-- Each set: targeted INSERTs + UPDATEs with _gt_* flags = TRUE.
-- Tx IDs start at 200001+ to avoid collisions with bulk data.
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA RAW;

-- Idempotency: Remove prior ground-truth injections before re-inserting
DELETE FROM TRANSACTIONS WHERE transaction_id >= 200001;
DELETE FROM DEVICE_SESSION_LOGS WHERE session_id >= 200001;
DELETE FROM LOANS WHERE loan_id >= 2001;
UPDATE CUSTOMERS SET _gt_structuring = FALSE, _gt_mule = FALSE WHERE _gt_structuring = TRUE OR _gt_mule = TRUE;
UPDATE ACCOUNTS SET _gt_mule = FALSE WHERE _gt_mule = TRUE;

-- ============================================================
-- 1. STRUCTURING  (~25 cases)
--    3 deposits INR 2,80,000-3,20,000 within 24-48 hrs,
--    across 2 branches, summing just under INR 10,00,000
-- ============================================================

-- Flag 25 customers as structuring ground truth
UPDATE CUSTOMERS SET _gt_structuring = TRUE
WHERE customer_id BETWEEN 101 AND 125;

-- For each of the 25 customers, insert 3 structuring deposits (75 txns total)
-- Transactions IDs: 200001 - 200075
INSERT INTO TRANSACTIONS (transaction_id, account_id, counterparty_id, amount, currency,
    channel, transaction_type, timestamp, device_id, geo_location, declared_purpose,
    _gt_structuring)
WITH structuring_customers AS (
    SELECT a.account_id, a.customer_id,
           ROW_NUMBER() OVER (PARTITION BY a.customer_id ORDER BY a.account_id) AS rn
    FROM ACCOUNTS a
    WHERE a.customer_id BETWEEN 101 AND 125
    QUALIFY rn = 1
),
base AS (
    SELECT customer_id, account_id,
           ROW_NUMBER() OVER (ORDER BY customer_id) AS cust_seq
    FROM structuring_customers
),
deposit_legs AS (
    SELECT b.customer_id, b.account_id, b.cust_seq, leg.idx AS leg_num,
           200000 + (b.cust_seq - 1) * 3 + leg.idx AS txn_id,
           -- 3 amounts summing to 8.5L-9.5L range (under 10L threshold)
           CASE leg.idx
               WHEN 1 THEN 280000 + (b.cust_seq * 137) % 30000
               WHEN 2 THEN 290000 + (b.cust_seq * 251) % 25000
               WHEN 3 THEN 300000 + (b.cust_seq * 389) % 20000
           END AS deposit_amt,
           -- Spread across 24-48 hour window
           DATEADD(hour,
               CASE leg.idx WHEN 1 THEN 0 WHEN 2 THEN 8 + (b.cust_seq % 12) WHEN 3 THEN 24 + (b.cust_seq % 20) END,
               DATEADD(day, -(30 + b.cust_seq * 7 % 90), CURRENT_TIMESTAMP())) AS txn_ts,
           -- Alternate between 2 branches
           CASE WHEN leg.idx <= 2 THEN 'Mumbai-Andheri' ELSE 'Mumbai-Fort' END AS geo
    FROM base b,
         (SELECT 1 AS idx UNION ALL SELECT 2 UNION ALL SELECT 3) leg
)
SELECT
    txn_id,
    account_id,
    UNIFORM(1, 500, RANDOM(100 + txn_id))::INT AS counterparty_id,
    deposit_amt,
    'INR',
    CASE WHEN leg_num <= 2 THEN 'BRANCH' ELSE 'ATM' END,
    'CREDIT',
    txn_ts,
    'DEV-' || LPAD(UNIFORM(1, 100, RANDOM(200 + txn_id))::VARCHAR, 6, '0'),
    geo,
    'Cash Deposit',
    TRUE
FROM deposit_legs;


-- ============================================================
-- 2. MONEY-MULE  (~15 cases)
--    Dormant 60+ days, then burst of 10+ inbound from unrelated
--    counterparties, outbound within 24 hrs
-- ============================================================

-- Pick 15 accounts and mark as mule ground truth
UPDATE ACCOUNTS SET _gt_mule = TRUE, status = 'ACTIVE'
WHERE account_id IN (
    SELECT account_id FROM ACCOUNTS
    WHERE account_id BETWEEN 2501 AND 2600
    ORDER BY account_id
    LIMIT 15
);

UPDATE CUSTOMERS SET _gt_mule = TRUE
WHERE customer_id IN (
    SELECT customer_id FROM ACCOUNTS WHERE _gt_mule = TRUE
);

-- For each mule account: 12 inbound + 2 outbound = 14 txns × 15 = 210 txns
-- Transaction IDs: 200076 - 200285
INSERT INTO TRANSACTIONS (transaction_id, account_id, counterparty_id, amount, currency,
    channel, transaction_type, timestamp, device_id, geo_location, declared_purpose,
    _gt_mule)
WITH mule_accounts AS (
    SELECT account_id, ROW_NUMBER() OVER (ORDER BY account_id) AS acct_seq
    FROM ACCOUNTS WHERE _gt_mule = TRUE
),
-- 12 inbound transfers from 12 distinct counterparties
inbound AS (
    SELECT
        200075 + (m.acct_seq - 1) * 14 + leg.idx AS txn_id,
        m.account_id,
        (m.acct_seq * 31 + leg.idx * 17) % 500 + 1 AS counterparty_id,
        ROUND(UNIFORM(50000, 300000, RANDOM(300 + m.acct_seq * 100 + leg.idx))::FLOAT, 2) AS amount,
        'CREDIT' AS txn_type,
        DATEADD(hour, leg.idx * 2,
            DATEADD(day, -(10 + m.acct_seq * 3 % 20), CURRENT_TIMESTAMP())) AS txn_ts,
        leg.idx
    FROM mule_accounts m,
         (SELECT 1 AS idx UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
          UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8
          UNION ALL SELECT 9 UNION ALL SELECT 10 UNION ALL SELECT 11 UNION ALL SELECT 12) leg
),
-- 2 large outbound transfers within 24 hours of last inbound
outbound AS (
    SELECT
        200075 + (m.acct_seq - 1) * 14 + 12 + leg.idx AS txn_id,
        m.account_id,
        UNIFORM(1, 500, RANDOM(400 + m.acct_seq + leg.idx))::INT AS counterparty_id,
        ROUND(UNIFORM(500000, 1500000, RANDOM(500 + m.acct_seq + leg.idx))::FLOAT, 2) AS amount,
        'DEBIT' AS txn_type,
        DATEADD(hour, 26 + leg.idx * 4,
            DATEADD(day, -(10 + m.acct_seq * 3 % 20), CURRENT_TIMESTAMP())) AS txn_ts,
        12 + leg.idx AS idx
    FROM mule_accounts m,
         (SELECT 1 AS idx UNION ALL SELECT 2) leg
)
SELECT txn_id, account_id, counterparty_id, amount, 'INR',
       'NEFT', txn_type, txn_ts,
       'DEV-' || LPAD(UNIFORM(1,100,RANDOM(600+txn_id))::VARCHAR, 6, '0'),
       'Mumbai-BKC', 'Fund Transfer', TRUE
FROM inbound
UNION ALL
SELECT txn_id, account_id, counterparty_id, amount, 'INR',
       'RTGS', txn_type, txn_ts,
       'DEV-' || LPAD(UNIFORM(1,100,RANDOM(700+txn_id))::VARCHAR, 6, '0'),
       'Mumbai-BKC', 'Urgent Transfer', TRUE
FROM outbound;

-- Delete any random transactions for these accounts in the 60-day dormancy window
DELETE FROM TRANSACTIONS
WHERE account_id IN (SELECT account_id FROM ACCOUNTS WHERE _gt_mule = TRUE)
  AND _gt_mule = FALSE
  AND timestamp > DATEADD(day, -80, CURRENT_TIMESTAMP())
  AND timestamp < DATEADD(day, -15, CURRENT_TIMESTAMP());


-- ============================================================
-- 3. ACCOUNT TAKEOVER  (~20 cases)
--    New-device login → contact change within 60 min →
--    large transfer to new payee within next 60 min
-- ============================================================

UPDATE CUSTOMERS SET _gt_ato = TRUE
WHERE customer_id BETWEEN 201 AND 220;

-- Insert ATO session pattern: new device login + contact change + password reset
-- Session IDs: 100001 - 100060 (3 per customer × 20)
INSERT INTO DEVICE_SESSION_LOGS (session_id, customer_id, device_id, ip_geo, login_timestamp, event_type, _gt_ato)
WITH ato_customers AS (
    SELECT customer_id, ROW_NUMBER() OVER (ORDER BY customer_id) AS cust_seq
    FROM CUSTOMERS WHERE _gt_ato = TRUE
),
ato_events AS (
    SELECT
        100000 + (c.cust_seq - 1) * 3 + e.step AS session_id,
        c.customer_id,
        'DEV-NEW-' || LPAD(c.cust_seq::VARCHAR, 4, '0') AS device_id,
        'UNKNOWN' AS ip_geo,
        DATEADD(minute,
            CASE e.step WHEN 1 THEN 0 WHEN 2 THEN 15 + c.cust_seq % 30 WHEN 3 THEN 35 + c.cust_seq % 20 END,
            DATEADD(day, -(5 + c.cust_seq * 3 % 30), CURRENT_TIMESTAMP())) AS login_ts,
        CASE e.step WHEN 1 THEN 'LOGIN' WHEN 2 THEN 'CONTACT_CHANGE' WHEN 3 THEN 'PASSWORD_RESET' END AS evt
    FROM ato_customers c,
         (SELECT 1 AS step UNION ALL SELECT 2 UNION ALL SELECT 3) e
)
SELECT session_id, customer_id, device_id, ip_geo, login_ts, evt, TRUE
FROM ato_events;

-- Insert ATO transactions: large transfer to new payee after the session events
-- Transaction IDs: 200286 - 200305 (1 per customer × 20)
INSERT INTO TRANSACTIONS (transaction_id, account_id, counterparty_id, amount, currency,
    channel, transaction_type, timestamp, device_id, geo_location, declared_purpose, _gt_ato)
WITH ato_customers AS (
    SELECT c.customer_id, a.account_id,
           ROW_NUMBER() OVER (ORDER BY c.customer_id) AS cust_seq
    FROM CUSTOMERS c
    JOIN ACCOUNTS a ON a.customer_id = c.customer_id
    WHERE c._gt_ato = TRUE
    QUALIFY ROW_NUMBER() OVER (PARTITION BY c.customer_id ORDER BY a.account_id) = 1
)
SELECT
    200285 + cust_seq AS txn_id,
    account_id,
    UNIFORM(400, 500, RANDOM(800 + cust_seq))::INT AS counterparty_id,
    ROUND(UNIFORM(500000, 2500000, RANDOM(900 + cust_seq))::FLOAT, 2) AS amount,
    'INR',
    'NETBANKING',
    'DEBIT',
    DATEADD(minute, 60 + cust_seq % 30,
        DATEADD(day, -(5 + cust_seq * 3 % 30), CURRENT_TIMESTAMP())) AS ts,
    'DEV-NEW-' || LPAD(cust_seq::VARCHAR, 4, '0'),
    'UNKNOWN',
    'Urgent Transfer',
    TRUE
FROM ato_customers;


-- ============================================================
-- 4. LOAN STACKING  (~12 cases)
--    3+ loans within a 14-day window, aggregate principal > 25L
-- ============================================================

UPDATE CUSTOMERS SET _gt_loan_stacking = TRUE
WHERE customer_id BETWEEN 301 AND 312;

-- Insert 3-4 clustered loans per stacking customer
-- Loan IDs: 1001 - 1048 (up to 4 per customer × 12)
INSERT INTO LOANS (loan_id, customer_id, principal, outstanding, disbursement_date,
    tenure_months, interest_rate, dpd, restructuring_flag,
    bureau_score_at_origination, latest_bureau_score, _gt_loan_stacking)
WITH stacking_customers AS (
    SELECT customer_id, ROW_NUMBER() OVER (ORDER BY customer_id) AS cust_seq
    FROM CUSTOMERS WHERE _gt_loan_stacking = TRUE
),
loan_legs AS (
    SELECT
        1000 + (c.cust_seq - 1) * 4 + leg.idx AS loan_id,
        c.customer_id,
        c.cust_seq,
        leg.idx AS leg_num,
        -- Each loan 8-12L, so 3 loans = 24-36L (crosses 25L threshold)
        CASE leg.idx
            WHEN 1 THEN 800000 + (c.cust_seq * 50000) % 200000
            WHEN 2 THEN 900000 + (c.cust_seq * 70000) % 300000
            WHEN 3 THEN 1000000 + (c.cust_seq * 90000) % 200000
            WHEN 4 THEN IFF(c.cust_seq <= 6, 700000, NULL)
        END AS principal_amt,
        DATEADD(day,
            CASE leg.idx WHEN 1 THEN 0 WHEN 2 THEN 3 + c.cust_seq % 5 WHEN 3 THEN 8 + c.cust_seq % 5 WHEN 4 THEN 11 END,
            DATEADD(day, -(60 + c.cust_seq * 15 % 120), CURRENT_DATE())) AS disb_date
    FROM stacking_customers c,
         (SELECT 1 AS idx UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) leg
    WHERE NOT (leg.idx = 4 AND c.cust_seq > 6)
)
SELECT
    loan_id,
    customer_id,
    principal_amt,
    ROUND(principal_amt * UNIFORM(60, 95, RANDOM(1000 + loan_id))::FLOAT / 100, 2),
    disb_date,
    ARRAY_CONSTRUCT(24, 36, 48, 60)[UNIFORM(0, 3, RANDOM(1100 + loan_id))]::INT,
    ROUND(UNIFORM(900, 1600, RANDOM(1200 + loan_id))::FLOAT / 100, 2),
    0,
    FALSE,
    UNIFORM(600, 750, RANDOM(1300 + loan_id)),
    UNIFORM(580, 720, RANDOM(1400 + loan_id)),
    TRUE
FROM loan_legs
WHERE principal_amt IS NOT NULL;
