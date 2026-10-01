# Argus Risk Copilot

**A governed, explainable AI copilot for banking fraud detection, AML compliance, credit risk monitoring, and regulatory reporting -- built entirely on Snowflake.**

Argus turns raw banking data into actionable signals in minutes through four detection typologies, role-based governance, natural-language investigation, and a governed dashboard, with CLI-based Snowflake deployment.

> All data in this project is 100% synthetic. No proprietary, confidential, or production data from any organization is included anywhere in this repository.

---

## Architecture

Argus implements the **SIGNAL -> EVIDENCE -> FINDING -> REPORT** governance loop:

```
RAW Tables (synthetic) -> Dynamic Tables (CONFORMED) -> SIGNALS_ALERTS (auto-detection)
                                                           |
Policy Documents -> Cortex Search Service -+               v
                                           +-> Cortex Agent -> Cases -> Findings -> Reports
Semantic View -> Cortex Analyst -----------+               |
                                                           v
                                              Notification Dispatcher (Email/Slack/Teams/SMS/Jira)
                                                           |
                                              Streamlit Dashboard (7 pages, RBAC-gated)
```

### Core Components

| Layer | Snowflake Feature | Purpose |
|-------|------------------|---------|
| Data Ingestion | RAW tables + GENERATOR() | 100K+ synthetic banking transactions, 2K customers, 642 loans |
| Data Pipeline | 7 Dynamic Tables (incremental) | Deduplicated, normalized CONFORMED layer |
| Signal Detection | 1 Dynamic Table (15-min lag) | 4 fraud typologies: Structuring, Money Mule, ATO, Loan Stacking |
| Semantic Layer | Semantic View (11 tables, 8 metrics) | Governed data access via Cortex Analyst |
| Policy Retrieval | Cortex Search Service | Hybrid semantic+keyword search over 6 policy documents |
| AI Agent | Cortex Agent (6 tools) | Evidence-first reasoning with human-in-the-loop |
| Governance | 5 Masking Policies, 7 RBAC Roles | Column-level PII protection using CURRENT_ROLE() |
| Notifications | SYSTEM\$SEND_EMAIL + 5 channel stubs | Multi-channel dispatch with audit logging |
| UI | Streamlit-in-Snowflake (7 pages) | Alert queue, case management, regulatory reporting, audit log |
| Scheduling | Snowflake Task (CRON) | Daily 8 AM IST signal digest email |

---

## Data Model

### RAW Schema (source of truth)
- **CUSTOMERS** (2,000 rows) -- Bank customers with KYC risk rating
- **ACCOUNTS** (3,000 rows) -- Savings, current, loan, FD accounts
- **TRANSACTIONS** (100,199 rows) -- Banking transactions across UPI, NEFT, RTGS, etc.
- **LOANS** (642 rows) -- Loan portfolio with DPD, bureau scores
- **COUNTERPARTIES** (500 rows) -- Transaction counterparties with PEP/sanctions flags
- **WATCHLIST_ENTRIES** (60 rows) -- PEP and sanctions watchlist
- **GENERAL_LEDGER** (2,400 rows) -- GL entries for LCR/NSFR calculation
- **DEVICE_SESSION_LOGS** (8,060 rows) -- Device login sessions with IP geolocation

### CONFORMED Schema (dynamic tables)
- 7 dynamic tables with `QUALIFY ROW_NUMBER()` dedup, `TARGET_LAG = DOWNSTREAM`
- Ground-truth columns (`_gt_*`) excluded from CONFORMED layer

### GOVERNANCE Schema
- **SIGNALS_ALERTS** (47 rows) -- Auto-detected signals across 4 typologies
- **CASES** (47 rows) -- Investigation cases linked to signals
- **FINDINGS** (29 rows) -- Investigation findings with evidence
- **REVIEWER_ACTIONS** -- Human review audit trail
- **FINDINGS_REPORTS** -- Draft regulatory filings (STR, escalation memos)
- **QUESTION_LOG** -- Full agent interaction audit trail
- **NOTIFICATION_CONFIG** (9 rows) -- Per-channel routing config
- **NOTIFICATION_LOG** -- Dispatch history with error detail
- **NOTIFICATION_RECIPIENTS** -- Dynamic email recipient management

### UNSTRUCTURED Schema
- **REFERENCE_DOCUMENTS** (6 docs) -- AML Policy, Liquidity Policy, RBI Circular, STR Template, Credit Risk Policy, ATO Procedure
- **POLICY_DOCUMENTS** (136 chunks) -- Section-level chunks for Cortex Search

### SEMANTIC Schema
- **ARGUS_COPILOT_SV** -- Semantic view with 11 tables, 9 relationships, 8 facts, 34 dimensions, 8 metrics, 5 verified queries

---

## Signal Detection Rules

| Typology | Rule | Expected Count |
|----------|------|---------------|
| **Structuring** | 3+ cash deposits within 48 hours, each INR 2.5-3.5L, total near 10L threshold | 19 signals |
| **Money Mule** | Rapid in/out pattern: credit followed by debit within 3 hours, 80%+ of credited amount | 14 signals |
| **Account Takeover** | Device/IP change followed by high-value transaction within 24 hours | 2 signals |
| **Loan Stacking** | 3+ active loans per customer with total outstanding > INR 50L | 12 signals |

---

## RBAC Model

| Role | Pages | PII Access | Write Access |
|------|-------|-----------|-------------|
| PLATFORM_ADMIN | All 7 | Full | Full |
| COMPLIANCE_OFFICER | 6 (no Integrations) | Full | Cases, findings, reports |
| FRAUD_ANALYST | 4 | Masked (except device_id) | Cases |
| CREDIT_ANALYST | 3 | Masked | Read-only |
| TREASURY_ANALYST | 1 (Liquidity) | Masked | Read-only |
| AUDITOR | 5 | Full | Read-only |
| BRANCH_USER | 1 (Ask Argus) | Masked | Read-only |

---

## How to Deploy (New Account)

### Prerequisites
- Snowflake account (Enterprise edition recommended for masking policies)
- ACCOUNTADMIN role access
- Cortex AI features enabled (Cortex Agent, Cortex Search, Cortex Analyst)

### Step-by-step

Run the SQL scripts in order from the `sql/` directory:

```
00_setup.sql           -- Database, schemas, warehouse
01_raw_tables.sql      -- 8 RAW table DDLs
02_synthetic_data.sql  -- Bulk synthetic data via GENERATOR()
03_ground_truth.sql    -- Targeted fraud pattern injection
04_unstructured.sql    -- 6 reference policy documents
05_conformed_dts.sql   -- 7 CONFORMED dynamic tables
06_signals.sql         -- SIGNALS_ALERTS detection pipeline
07_rbac_masking.sql    -- 7 roles + 5 masking policies + grants
08_semantic_view.sql   -- Semantic view + CASES/FINDINGS/REVIEWER_ACTIONS tables
09_policy_search.sql   -- POLICY_DOCUMENTS chunking + Cortex Search service
10_agent.sql           -- Agent procedures + deploy via cortex agent-studio
11_streamlit.sql       -- Stage + PUT + CREATE STREAMLIT
12_notifications.sql   -- Notification stack (update email in script)
```

**Important**: In `12_notifications.sql`, replace `YOUR_EMAIL@example.com` with your Snowflake account user's email address.

### Regenerating Synthetic Data

All synthetic data is generated via Snowflake `GENERATOR()` with deterministic seeds. To regenerate:

```sql
-- Re-run in order (scripts are idempotent via TRUNCATE):
-- 02_synthetic_data.sql   (TRUNCATEs before INSERT)
-- 03_ground_truth.sql     (DELETEs ground-truth rows before re-insert)
-- Then refresh dynamic tables:
ALTER DYNAMIC TABLE ARGUS_RISK_COPILOT.CONFORMED.CUSTOMERS_CLEAN REFRESH;
ALTER DYNAMIC TABLE ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN REFRESH;
ALTER DYNAMIC TABLE ARGUS_RISK_COPILOT.GOVERNANCE.SIGNALS_ALERTS REFRESH;
```

---

## Project Structure (GitHub Submission)

```
argus/
  sql/                        -- All SQL DDL and DML scripts (numbered 00-12)
    argus_agent.yaml           -- Cortex Agent YAML specification
  streamlit_app/              -- Streamlit application
    streamlit_app.py           -- Single-file Streamlit app (679 lines)
    environment.yml            -- Snowflake Streamlit environment
  python/                     -- Python utilities (procedures embedded in SQL)
  docs/                       -- Additional documentation
  README.md                   -- This file
  requirements.txt            -- Python dependencies
```

---

## Datasets Used

All datasets are **100% synthetic**, generated via Snowflake SQL `GENERATOR()` with deterministic random seeds. No external datasets, APIs, or third-party data sources are used.

| Dataset | Rows | Generation Method |
|---------|------|-------------------|
| Customers | 2,000 | GENERATOR() with Indian name arrays |
| Accounts | 3,000 | GENERATOR() with account type distributions |
| Transactions | 100,199 | GENERATOR() + ground-truth injection |
| Loans | 642 | GENERATOR() with DPD/bureau score distributions |
| Counterparties | 500 | GENERATOR() with PEP/sanctions flags |
| Watchlist | 60 | GENERATOR() with deliberately fuzzy names |
| General Ledger | 2,400 | GENERATOR() with GL codes for LCR/NSFR |
| Device Sessions | 8,060 | GENERATOR() with IP geo distributions |
| Policy Documents | 6 | Hand-written synthetic policy text |

---

## Regulatory Context

Argus is designed for the Indian banking/NBFC regulatory landscape:
- **RBI Master Direction** on KYC and AML (2016, amended 2024)
- **PMLA (Prevention of Money Laundering Act)** -- CTR/STR filing thresholds
- **FIU-IND** -- Suspicious Transaction Report (STR) filing
- **NPA Classification** -- SMA-0/1/2, Sub-Standard, Doubtful per RBI norms
- **LCR/NSFR** -- Basel III liquidity ratios adapted for Indian banks

---

## Security & Governance

- **PII Masking**: 5 column-level masking policies using `CURRENT_ROLE()`, applied to CONFORMED dynamic tables
- **RBAC**: 7 roles with least-privilege grants; page-level gating in Streamlit
- **SQL Injection Prevention**: All user inputs escaped via `esc()` helper in Streamlit; Python procedures use proper quote escaping
- **Governed Agent Access**: Agent routes all data queries through Cortex Analyst (semantic view) -- never raw table SQL
- **Audit Trail**: QUESTION_LOG captures every agent interaction with CURRENT_USER(); REVIEWER_ACTIONS logs all case/report state changes; NOTIFICATION_LOG records every dispatch attempt with error detail
- **No Secrets in Code**: Email addresses parameterized; no API keys, tokens, or credentials committed

---

## Technology Stack

- **Languages**: Python (stored procedures, Streamlit app), SQL (DDL, DML, dynamic tables)
- **Snowflake Features**: Dynamic Tables, Cortex Agent, Cortex Analyst, Cortex Search, Semantic Views, Masking Policies, RBAC, Notification Integration, Snowflake Tasks, Streamlit-in-Snowflake
- **Built with**: Snowflake Cortex Code (CoCo) across the full lifecycle -- planning, development, execution, testing, and hardening
