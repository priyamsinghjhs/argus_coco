-- ============================================================
-- 04_unstructured_docs.sql  —  Policy & Reference Documents
-- Stored in UNSTRUCTURED.REFERENCE_DOCUMENTS for Cortex Search
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA UNSTRUCTURED;

CREATE OR REPLACE TABLE REFERENCE_DOCUMENTS (
    doc_id          INT NOT NULL,
    doc_type        VARCHAR(50) NOT NULL,
    title           VARCHAR(500) NOT NULL,
    content         VARCHAR(16777216) NOT NULL,
    version         VARCHAR(20) DEFAULT '1.0',
    effective_date  DATE NOT NULL,
    CONSTRAINT pk_ref_docs PRIMARY KEY (doc_id)
);

-- ============================================================
-- DOC 1: AML Policy Manual
-- ============================================================
INSERT INTO REFERENCE_DOCUMENTS (doc_id, doc_type, title, content, version, effective_date)
SELECT 1, 'POLICY', 'Anti-Money Laundering (AML) Policy Manual',
$$ANTI-MONEY LAUNDERING (AML) POLICY MANUAL
Version 1.0 | Effective Date: 01-Jan-2024
Classification: INTERNAL – RESTRICTED

1. PURPOSE AND SCOPE
1.1 This policy establishes the framework for preventing, detecting, and reporting money laundering and terrorist financing activities in compliance with the Prevention of Money Laundering Act 2002 (PMLA), RBI Master Direction on KYC dated 25-Feb-2016 (updated), and FIU-IND guidelines.
1.2 This policy applies to all employees, officers, and agents of the Bank across all branches, digital channels, and subsidiaries.

2. CUSTOMER DUE DILIGENCE (CDD)
2.1 Standard CDD must be completed before account opening. Required documents: PAN, Aadhaar, address proof, photograph.
2.2 Enhanced Due Diligence (EDD) is mandatory for: (a) Politically Exposed Persons (PEPs), (b) customers from high-risk jurisdictions (FATF grey/black list), (c) customers with KYC risk rating HIGH, (d) non-face-to-face onboarding, (e) transactions above INR 50,00,000 in a calendar month.
2.3 Ongoing monitoring shall re-assess CDD at least annually for HIGH risk customers, every 3 years for MEDIUM, and every 5 years for LOW.

3. TRANSACTION MONITORING
3.1 All transactions must be screened in real time against internal rules and external watchlists.
3.2 Cash Transaction Reporting (CTR): All cash transactions (deposit or withdrawal) of INR 10,00,000 (Ten Lakh) or above in a single transaction, or cash transactions aggregating INR 10,00,000 or above in a calendar month, must be reported to FIU-IND within 15 days of the close of the month.
3.3 Suspicious Transaction Reporting (STR): Any transaction that gives rise to a reasonable ground of suspicion must be reported to FIU-IND within 7 days of the suspicion being formed, regardless of amount.

4. TYPOLOGY-SPECIFIC INDICATORS
4.1 General Red Flags: (a) Transactions inconsistent with customer profile, (b) reluctance to provide KYC documents, (c) frequent large cash transactions just below reporting thresholds, (d) rapid movement of funds with no apparent economic purpose.
4.2 Structuring Indicators: The deliberate breaking of transactions to avoid reporting thresholds is a criminal offence under PMLA Section 3. Indicators include: (i) Three or more cash deposits within a 24-to-48-hour window, each between INR 2,50,000 and INR 3,50,000, summing to just below INR 10,00,000; (ii) deposits made at two or more different branches or ATMs; (iii) use of different channels (branch, ATM, CDM) for the same underlying activity; (iv) customer has no business justification for multiple small cash deposits. Confidence: Any combination of indicators (i) and (ii) should generate a HIGH severity alert.
4.3 Money Mule Indicators: (i) Account dormant for 60 or more days followed by a sudden burst of activity; (ii) 10 or more inbound transfers from unrelated counterparties within 48 hours; (iii) rapid outbound transfer of accumulated funds within 24 hours of the inbound burst; (iv) account holder is a young individual with no significant prior transaction history. Confidence: Combination of (i), (ii), and (iii) should generate CRITICAL severity.
4.4 Account Takeover Indicators: (i) Login from a previously unseen device; (ii) contact detail change (email, phone, address) within 60 minutes of the new-device login; (iii) large outbound transfer to a new beneficiary within 120 minutes of the contact change; (iv) IP geolocation inconsistent with customer's registered location. Confidence: (i) + (ii) + (iii) within the prescribed time windows should generate CRITICAL severity.

5. RECORD RETENTION
5.1 All transaction records, CTRs, STRs, and related correspondence must be maintained for a minimum of 5 years from the date of transaction or closure of account, whichever is later.
5.2 Records must be sufficient to reconstruct individual transactions and must be available for inspection by competent authorities.

6. REPORTING OBLIGATIONS
6.1 The Principal Officer is responsible for filing CTRs and STRs with FIU-IND through the FINnet 2.0 portal.
6.2 Tipping off: No employee shall disclose to any customer or third party that an STR has been or is being filed. Violation constitutes an offence under PMLA Section 66.

7. GOVERNANCE
7.1 The AML Compliance Committee, chaired by the Chief Compliance Officer, shall meet quarterly to review the effectiveness of the AML program.
7.2 Independent audit of the AML program shall be conducted annually.
$$, '1.0', '2024-01-01';


-- ============================================================
-- DOC 2: Basel Liquidity Policy (LCR / NSFR)
-- ============================================================
INSERT INTO REFERENCE_DOCUMENTS (doc_id, doc_type, title, content, version, effective_date)
SELECT 2, 'POLICY', 'Liquidity Risk Management Policy – LCR and NSFR Framework',
$$LIQUIDITY RISK MANAGEMENT POLICY
LCR AND NSFR FRAMEWORK
Version 1.0 | Effective Date: 01-Apr-2024
Classification: INTERNAL – RESTRICTED

1. OBJECTIVE
1.1 This policy defines the Bank's approach to measuring and managing liquidity risk in accordance with Basel III norms as adopted by the Reserve Bank of India (RBI) vide circular DBOD.BP.BC.No.120/21.04.098/2013-14.

2. LIQUIDITY COVERAGE RATIO (LCR)
2.1 Definition: LCR = Stock of High Quality Liquid Assets (HQLA) / Total Net Cash Outflows over 30 calendar days.
2.2 Regulatory Minimum: LCR must be maintained at or above 100% at all times.
2.3 Internal Threshold: The Bank targets an LCR of at least 110% under normal conditions and at least 100% under stress.
2.4 HQLA Classification:
    - Level 1 (0% haircut): Cash, CRR balance, Government securities (G-Secs), State Development Loans (SDLs).
    - Level 2A (15% haircut): Corporate bonds rated AA- or above, covered bonds.
    - Level 2B (25-50% haircut): Corporate bonds rated A+ to BBB-, RMBS, equity shares in major indices.
    - Level 2 assets cannot exceed 40% of total HQLA; Level 2B cannot exceed 15%.
2.5 Net Cash Outflows: Calculated as total expected outflows minus MIN(expected inflows, 75% of outflows).

3. NET STABLE FUNDING RATIO (NSFR)
3.1 Definition: NSFR = Available Stable Funding (ASF) / Required Stable Funding (RSF).
3.2 Regulatory Minimum: NSFR must be maintained at or above 100%.
3.3 Internal Threshold: The Bank targets an NSFR of at least 105%.
3.4 ASF factors: Regulatory capital and liabilities with remaining maturity > 1 year = 100%; stable retail deposits = 95%; less stable retail deposits = 90%; wholesale funding 6-12 months = 50%; all other = 0%.
3.5 RSF factors: Cash and CRR = 0%; unencumbered G-Secs = 5%; performing loans to corporates < 1 year = 50%; retail loans = 65%; residential mortgages = 65%; all other assets = 100%.

4. STRESS TESTING
4.1 The Treasury function shall conduct liquidity stress tests monthly under three scenarios: (a) Institution-specific, (b) Market-wide, (c) Combined.
4.2 Survival horizon must exceed 30 days under all three scenarios.
4.3 Results shall be reported to ALCO within 5 business days.

5. EARLY WARNING INDICATORS
5.1 LCR dropping below 115% triggers AMBER alert.
5.2 LCR dropping below 105% triggers RED alert and activates the Contingency Funding Plan (CFP).
5.3 NSFR below 108% triggers AMBER; below 102% triggers RED.

6. CONTINGENCY FUNDING PLAN
6.1 Activated automatically when any RED alert is triggered.
6.2 Actions include: (a) halt new term lending, (b) activate repo lines, (c) notify ALCO, (d) report to RBI within 24 hours if LCR < 100%.
$$, '1.0', '2024-04-01';


-- ============================================================
-- DOC 3: RBI Circular on Cash Transaction Reporting
-- ============================================================
INSERT INTO REFERENCE_DOCUMENTS (doc_id, doc_type, title, content, version, effective_date)
SELECT 3, 'CIRCULAR', 'RBI Master Direction – Reporting of Cash Transactions and Suspicious Transactions',
$$RESERVE BANK OF INDIA
MASTER DIRECTION – KYC / AML / CFT
RBI/2015-16/272 (Updated as on 10-Jan-2024)

CHAPTER VI – REPORTING OBLIGATIONS

12. CASH TRANSACTION REPORTS (CTR)
12.1 Every banking company shall furnish to the Director, FIU-IND, a Cash Transaction Report (CTR) for each month within fifteen days from the close of the month.
12.2 CTR shall cover: (a) All cash deposits and withdrawals aggregating INR 10,00,000 (Rupees Ten Lakh) or above in a month in any single account; (b) All cash deposits and withdrawals aggregating INR 10,00,000 or above in a month by a single person across accounts; (c) All series of cash transactions integrally connected to each other which have been valued below INR 10,00,000 individually, but the aggregate value exceeds INR 10,00,000, occurring within a month.
12.3 Cross-border wire transfers: All cross-border wire transfers of value exceeding INR 5,00,000 or its equivalent in foreign currency shall also be reported.

13. SUSPICIOUS TRANSACTION REPORTS (STR)
13.1 A suspicious transaction includes transactions whether or not made in cash which, to a person acting in good faith: (a) gives rise to a reasonable ground of suspicion that it may involve proceeds of an offence specified in the Schedule to the PMLA; (b) appears to be made in circumstances of unusual or unjustified complexity; (c) appears to have no economic rationale or bona fide purpose; (d) gives rise to a reasonable ground of suspicion that it may involve financing of the activities relating to terrorism.
13.2 STRs shall be filed with FIU-IND within 7 working days of forming the suspicion.
13.3 Principal Officer shall be the single point of contact with FIU-IND.

14. NON-PROFIT ORGANISATION (NPO) TRANSACTIONS
14.1 All NPO accounts shall be subject to enhanced monitoring. Transactions exceeding INR 5,00,000 shall be flagged for review.

15. PENALTIES
15.1 Non-compliance with reporting obligations may attract penalties under PMLA Section 13 and RBI directions under Section 35A of the Banking Regulation Act.

REFERENCE: PMLA Section 12, 12AA; PML (Maintenance of Records) Rules 2005; FIU-IND Operating Guidelines v3.2.
$$, '1.0', '2024-01-10';


-- ============================================================
-- DOC 4: STR Narrative Template
-- ============================================================
INSERT INTO REFERENCE_DOCUMENTS (doc_id, doc_type, title, content, version, effective_date)
SELECT 4, 'TEMPLATE', 'Suspicious Transaction Report (STR) Narrative Template',
$$SUSPICIOUS TRANSACTION REPORT – NARRATIVE TEMPLATE
Version 1.0 | For Internal Use Only

SECTION A – SUBJECT IDENTIFICATION
A.1 Subject Name: [Full legal name of the customer]
A.2 Customer ID: [Internal customer identifier]
A.3 Account Number(s): [All accounts involved]
A.4 KYC Risk Rating: [LOW / MEDIUM / HIGH]
A.5 PEP Status: [Yes / No]
A.6 Relationship Start Date: [Date of account opening]

SECTION B – SUSPICIOUS ACTIVITY SUMMARY
B.1 Reporting Period: [Start Date] to [End Date]
B.2 Typology: [Structuring / Money Mule / Account Takeover / Layering / Trade-Based ML / Other]
B.3 Total Value of Suspicious Activity: INR [Amount]
B.4 Number of Transactions: [Count]
B.5 Channels Used: [Branch / ATM / Mobile / Internet Banking / UPI / RTGS / NEFT]

SECTION C – DETAILED NARRATIVE
[Provide a chronological, factual description of the suspicious activity. Include:
- What triggered the initial alert
- Specific transactions with dates, amounts, and channels
- Counterparties involved and their known risk indicators
- How the activity deviates from the customer's normal profile
- Any links to watchlist entities or adverse media
- Actions taken by the Bank (account freeze, EDD, etc.)
Reference specific policy sections that define the red flags observed.]

SECTION D – EVIDENCE SUMMARY
D.1 Transaction Records: [List of transaction IDs]
D.2 Session Logs: [Relevant device/login session IDs]
D.3 Watchlist Matches: [Entity names and match scores]
D.4 Policy References: [Section numbers from AML Policy Manual]
D.5 Supporting Documents: [KYC records, correspondence, screenshots]

SECTION E – RECOMMENDATION
E.1 Confidence Level: [HIGH / MEDIUM / LOW]
E.2 Recommended Action: [File STR with FIU-IND / Escalate to AML Committee / Continue Monitoring / Close with No Action]
E.3 Recommended Timeframe: [Immediate / Within 7 days / Next review cycle]
E.4 Prepared By: [Officer Name, Designation]
E.5 Reviewed By: [Reviewer Name, Designation]
E.6 Date Prepared: [DD-MMM-YYYY]
$$, '1.0', '2024-01-01';


-- ============================================================
-- DOC 5: Credit Risk Policy Excerpt
-- ============================================================
INSERT INTO REFERENCE_DOCUMENTS (doc_id, doc_type, title, content, version, effective_date)
SELECT 5, 'POLICY', 'Credit Risk Policy – Loan Origination and NPA Classification',
$$CREDIT RISK POLICY – LOAN ORIGINATION AND NPA CLASSIFICATION
Version 1.0 | Effective Date: 01-Jul-2024

1. LOAN ORIGINATION STANDARDS
1.1 Bureau Score Thresholds: (a) Prime: CIBIL score >= 750; (b) Near-Prime: 650-749; (c) Sub-Prime: below 650. Sub-Prime applications require additional collateral or guarantor.
1.2 Debt-to-Income Ratio: Total EMI obligations must not exceed 50% of verified monthly income (FOIR – Fixed Obligation to Income Ratio).
1.3 Loan Concentration Limits: No single borrower's aggregate exposure shall exceed INR 50,00,000 without approval from the Credit Committee.

2. LOAN STACKING DETECTION
2.1 Definition: Loan stacking refers to a borrower obtaining three or more loans within a 14-day window from one or more lenders.
2.2 Indicators: (i) Three or more loan disbursements to the same customer within 14 calendar days; (ii) aggregate principal of stacked loans exceeds INR 25,00,000; (iii) recent bureau score decline of 50+ points; (iv) multiple hard inquiries from different lenders within 30 days.
2.3 Action: Any loan stacking pattern detected post-disbursement shall be escalated to the Credit Risk team within 24 hours. New disbursement requests from flagged customers shall be placed on hold pending review.

3. NPA CLASSIFICATION (as per RBI norms)
3.1 Special Mention Accounts:
    - SMA-0: Principal or interest payment overdue between 1-30 days.
    - SMA-1: Principal or interest payment overdue between 31-60 days.
    - SMA-2: Principal or interest payment overdue between 61-90 days.
3.2 Non-Performing Asset: An account is classified as NPA when principal or interest payment remains overdue for more than 90 days (DPD > 90).
3.3 Sub-categories:
    - Sub-Standard: NPA for up to 12 months.
    - Doubtful: NPA for more than 12 months.
    - Loss: Identified as loss by the Bank or auditor but not yet written off.

4. RESTRUCTURING
4.1 Restructuring is permitted only for viable accounts facing temporary cash flow difficulties.
4.2 Restructured accounts shall be downgraded to the immediately lower asset classification category.
4.3 A restructured standard account shall be classified as SMA-0 at minimum.

5. PROVISIONING REQUIREMENTS
5.1 Standard assets: 0.40% (secured), 0.40% (unsecured).
5.2 Sub-Standard: 15% (secured), 25% (unsecured).
5.3 Doubtful (up to 1 year): 25%; Doubtful (1-3 years): 40%; Doubtful (> 3 years): 100%.
5.4 Loss assets: 100%.
$$, '1.0', '2024-07-01';


-- ============================================================
-- DOC 6: Account Takeover Response Procedure
-- ============================================================
INSERT INTO REFERENCE_DOCUMENTS (doc_id, doc_type, title, content, version, effective_date)
SELECT 6, 'PROCEDURE', 'Account Takeover (ATO) Detection and Response Procedure',
$$ACCOUNT TAKEOVER (ATO) DETECTION AND RESPONSE PROCEDURE
Version 1.0 | Effective Date: 01-Mar-2024

1. PURPOSE
1.1 This procedure defines the detection triggers, containment actions, and reporting requirements for suspected account takeover events.

2. DETECTION TRIGGERS
2.1 Primary Indicators (automated):
    (a) Login from a device not previously associated with the customer (new device fingerprint).
    (b) Contact detail change (email, phone number, or registered address) within 60 minutes of a new-device login.
    (c) Large outbound transfer (exceeding INR 2,00,000) to a beneficiary not previously transacted with, within 120 minutes of the contact change.
    (d) IP geolocation mismatch: login IP resolves to a country or state different from the customer's registered address.
2.2 Secondary Indicators (manual review):
    (a) Multiple failed authentication attempts preceding the successful login.
    (b) SIM swap detected on the registered mobile number (via telecom API).
    (c) Customer complaint of not initiating the transaction.

3. IMMEDIATE CONTAINMENT (within 15 minutes of detection)
3.1 Freeze all debit transactions on the affected account(s).
3.2 Disable digital banking access for the customer.
3.3 Notify the customer via registered alternate channel (email if phone compromised, SMS if email compromised).
3.4 Place a hold on the beneficiary account if it is within the Bank.

4. INVESTIGATION
4.1 The Fraud Investigation team shall gather: (a) complete session logs for the 72-hour window, (b) device fingerprint comparison, (c) IP geolocation data, (d) transaction trail, (e) CCTV footage if branch visit occurred.
4.2 Timeline: preliminary findings within 24 hours; full report within 5 business days.

5. RECOVERY
5.1 Initiate chargeback or reversal request with the beneficiary bank within 4 hours of detection (as per NPCI / RBI circular on limiting liability – RBI/2017-18/15).
5.2 File a cyber crime report on the National Cyber Crime Reporting Portal (cybercrime.gov.in) and obtain acknowledgement number.

6. REPORTING
6.1 Internal: Incident report to CISO and Head of Operations within 24 hours.
6.2 Regulatory: If the fraud amount exceeds INR 1,00,000, report to RBI via the Fraud Monitoring Return within the prescribed timeframe.
6.3 If money laundering is suspected, file an STR with FIU-IND within 7 days.

7. EVIDENCE PRESERVATION
7.1 All session logs, IP data, device fingerprints, and communication records must be preserved for a minimum of 8 years.
7.2 Evidence must be stored in tamper-evident format suitable for forensic analysis and court proceedings.
$$, '1.0', '2024-03-01';
