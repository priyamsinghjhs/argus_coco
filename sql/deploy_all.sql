-- ============================================================
-- deploy_all.sql  —  Master deployment script
-- Run this single file to deploy everything on a clean account.
-- Each sub-script is idempotent (CREATE OR REPLACE / IF NOT EXISTS).
-- ============================================================
-- USAGE:
--   In Snowsight worksheet: paste each script in order
--   Via CoCo CLI: execute each .sql file sequentially
--   Via SnowSQL: !source 00_setup.sql  (etc.)
-- ============================================================

-- NOTE: Snowflake worksheets don't support !source.
-- This file documents the execution order.
-- Execute each file in sequence:

-- Step 1: Database & schemas
-- >> 00_setup.sql

-- Step 2: RAW table DDL
-- >> 01_raw_tables.sql

-- Step 3: Bulk synthetic data
-- >> 02_synthetic_data.sql

-- Step 4: Ground-truth typology injection
-- >> 03_ground_truth_injection.sql

-- Step 5: Unstructured policy documents
-- >> 04_unstructured_docs.sql

-- Step 6: CONFORMED dynamic tables
-- >> 05_conformed_dynamic_tables.sql

-- Step 7: Signals/alerts detection pipeline
-- >> 06_signals_pipeline.sql

-- Step 8: RBAC roles & masking policies
-- >> 07_rbac_masking.sql

-- ============================================================
-- VALIDATION QUERIES (run after deployment)
-- ============================================================

-- Row counts
SELECT 'CUSTOMERS'           AS tbl, COUNT(*) AS cnt FROM ARGUS_RISK_COPILOT.RAW.CUSTOMERS
UNION ALL SELECT 'ACCOUNTS',           COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.ACCOUNTS
UNION ALL SELECT 'COUNTERPARTIES',     COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.COUNTERPARTIES
UNION ALL SELECT 'WATCHLIST_ENTRIES',   COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.WATCHLIST_ENTRIES
UNION ALL SELECT 'TRANSACTIONS',       COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.TRANSACTIONS
UNION ALL SELECT 'LOANS',              COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.LOANS
UNION ALL SELECT 'GENERAL_LEDGER',     COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.GENERAL_LEDGER
UNION ALL SELECT 'DEVICE_SESSION_LOGS',COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.DEVICE_SESSION_LOGS
UNION ALL SELECT 'REFERENCE_DOCUMENTS',COUNT(*) FROM ARGUS_RISK_COPILOT.UNSTRUCTURED.REFERENCE_DOCUMENTS;

-- Ground-truth counts
SELECT 'GT_STRUCTURING'  AS typology, COUNT(*) AS customers FROM ARGUS_RISK_COPILOT.RAW.CUSTOMERS WHERE _gt_structuring = TRUE
UNION ALL SELECT 'GT_MULE',        COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.CUSTOMERS WHERE _gt_mule = TRUE
UNION ALL SELECT 'GT_ATO',         COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.CUSTOMERS WHERE _gt_ato = TRUE
UNION ALL SELECT 'GT_LOAN_STACK',  COUNT(*) FROM ARGUS_RISK_COPILOT.RAW.CUSTOMERS WHERE _gt_loan_stacking = TRUE;

-- Dynamic table status
SHOW DYNAMIC TABLES IN SCHEMA ARGUS_RISK_COPILOT.CONFORMED;
SHOW DYNAMIC TABLES IN SCHEMA ARGUS_RISK_COPILOT.GOVERNANCE;

-- Signals generated
SELECT signal_type, COUNT(*) AS signal_count, AVG(confidence) AS avg_confidence
FROM ARGUS_RISK_COPILOT.GOVERNANCE.SIGNALS_ALERTS
GROUP BY signal_type
ORDER BY signal_type;

-- Masking policies
SHOW MASKING POLICIES IN SCHEMA ARGUS_RISK_COPILOT.GOVERNANCE;

-- Roles
SHOW ROLES LIKE '%ANALYST%';
SHOW ROLES LIKE '%OFFICER%';
SHOW ROLES LIKE '%ADMIN%';
SHOW ROLES LIKE '%AUDITOR%';
SHOW ROLES LIKE '%BRANCH%';
