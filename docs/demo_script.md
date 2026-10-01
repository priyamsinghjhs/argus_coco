# Argus Risk Copilot — CoCo CLI Demo Script (~3 min)

## Skills/Capabilities Demonstrated
1. **Snowflake SQL execution** — Dynamic table pipeline inspection + direct queries
2. **Cortex Analyst** — Natural language → SQL via semantic view
3. **Investigative drill-down** — Evidence-based transaction forensics

---

## Pre-Recording Checklist
- CoCo CLI open, connected to Snowflake (`IF58924`)
- Terminal font large enough to read on video
- Clear screen before starting

---

## SCENE 1 — Set the Stage (~30s)

**[Narration]** "This is Argus Risk Copilot — an AML and fraud detection pipeline built entirely on Snowflake, operated end-to-end through CoCo CLI."

### Command 1: Show the pipeline
```
SHOW DYNAMIC TABLES IN DATABASE ARGUS_RISK_COPILOT;
```

**[Narration]** "Seven conformed dynamic tables clean raw data incrementally — customers, accounts, transactions, counterparties, device sessions, loans, and general ledger. A governance-layer dynamic table called SIGNALS_ALERTS runs four detection rules every 15 minutes."

---

## SCENE 2 — Signal Overview via Direct SQL (~40s)

**[Narration]** "Let's see what the signals pipeline has detected."

### Command 2: Signal summary
```
SELECT signal_type, severity, COUNT(*) AS alerts FROM ARGUS_RISK_COPILOT.GOVERNANCE.SIGNALS_ALERTS GROUP BY 1,2 ORDER BY 1,2;
```

**[Narration]** "85 signals across four typologies — structuring, money mule, account takeover, and loan stacking. 18 are critical severity."

---

## SCENE 3 — Cortex Analyst Natural Language Query (~50s)

**[Narration]** "Now instead of writing SQL, let's ask Cortex Analyst in plain English via the semantic view."

### Command 3: Natural language query
```
cortex analyst query "How-many-critical-severity-signals-are-open-and-which-typologies?" --view ARGUS_RISK_COPILOT.SEMANTIC.ARGUS_COPILOT_SV
```

**[Narration]** "Cortex Analyst translates the question into a SEMANTIC_VIEW query — 4 account takeover and 14 money mule signals at critical severity. Same answer, zero SQL written."

### Command 4: Execute the generated SQL
Copy-paste the generated SQL from the Analyst response and run it.

**[Narration]** "We execute the Analyst-generated SQL and confirm — 18 critical alerts, money mule is the dominant typology."

---

## SCENE 4 — Forensic Deep Dive (~60s)

**[Narration]** "Let's investigate the top money mule signal."

### Command 5: Pull top signal with evidence
```
SELECT signal_id, entity_id, detected_at, confidence, evidence_json FROM ARGUS_RISK_COPILOT.GOVERNANCE.SIGNALS_ALERTS WHERE signal_type = 'MONEY_MULE' AND severity = 'CRITICAL' ORDER BY confidence DESC LIMIT 1;
```

**[Narration]** "Customer 318, account 2511 — 0.90 confidence. The evidence shows 12 distinct senders funneled 1.9 million rupees into a dormant account within 48 hours, then 62 percent was drained via two RTGS transfers."

### Command 6: Show all 14 evidence transactions
```
SELECT transaction_id, counterparty_id, amount, transaction_type, channel, timestamp, declared_purpose FROM ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN WHERE transaction_id IN (200216,200217,200218,200219,200220,200221,200222,200223,200224,200225,200226,200227,200228,200229) ORDER BY timestamp;
```

**[Narration]** "All 14 transactions — 12 inbound NEFT credits arriving at exact 2-hour intervals from 12 unique counterparties, amounts incrementing by 3,571 each time. Then two identical RTGS debits of 596,371 labeled urgent transfer. This is textbook mule account behavior — mechanical inflows, rapid consolidation, fast drain."

---

## CLOSING (~10s)

**[Narration]** "That's Argus Risk Copilot — from pipeline to signal detection to forensic evidence, all through CoCo CLI with Cortex Analyst and Snowflake dynamic tables."

---

## Quick-Paste Command Block (copy these in order)

```sql
-- 1. Pipeline overview
SHOW DYNAMIC TABLES IN DATABASE ARGUS_RISK_COPILOT;

-- 2. Signal summary
SELECT signal_type, severity, COUNT(*) AS alerts FROM ARGUS_RISK_COPILOT.GOVERNANCE.SIGNALS_ALERTS GROUP BY 1,2 ORDER BY 1,2;
```

```bash
# 3. Cortex Analyst
cortex analyst query "How-many-critical-severity-signals-are-open-and-which-typologies?" --view ARGUS_RISK_COPILOT.SEMANTIC.ARGUS_COPILOT_SV
```

```sql
-- 4. Execute Analyst-generated SQL (paste from output above)

-- 5. Top money mule signal
SELECT signal_id, entity_id, detected_at, confidence, evidence_json FROM ARGUS_RISK_COPILOT.GOVERNANCE.SIGNALS_ALERTS WHERE signal_type = 'MONEY_MULE' AND severity = 'CRITICAL' ORDER BY confidence DESC LIMIT 1;

-- 6. Evidence transactions
SELECT transaction_id, counterparty_id, amount, transaction_type, channel, timestamp, declared_purpose FROM ARGUS_RISK_COPILOT.CONFORMED.TRANSACTIONS_CLEAN WHERE transaction_id IN (200216,200217,200218,200219,200220,200221,200222,200223,200224,200225,200226,200227,200228,200229) ORDER BY timestamp;
```
