-- ============================================================
-- 09_policy_search.sql  —  Policy Document Chunking + Cortex Search
-- Parses reference docs into citable section-level chunks
-- and creates a hybrid semantic+keyword search service
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE WAREHOUSE COMPUTE_WH;

-- 1. Create chunked policy documents table
CREATE OR REPLACE TABLE UNSTRUCTURED.POLICY_DOCUMENTS (
    chunk_id         INT NOT NULL,
    doc_id           INT NOT NULL,
    doc_type         VARCHAR(50) NOT NULL,
    title            VARCHAR(500) NOT NULL,
    version          VARCHAR(20),
    effective_date   DATE,
    section_ref      VARCHAR(200) NOT NULL,
    chunk_text       VARCHAR(8000) NOT NULL,
    CONSTRAINT pk_policy_chunks PRIMARY KEY (chunk_id)
);

-- 2. Parse and chunk all 6 reference documents at section/subsection level
INSERT INTO UNSTRUCTURED.POLICY_DOCUMENTS
WITH
lines AS (
    SELECT r.doc_id, r.doc_type, r.title, r.version, r.effective_date,
           f.index AS line_idx,
           TRIM(f.value) AS line_text
    FROM UNSTRUCTURED.REFERENCE_DOCUMENTS r,
         LATERAL SPLIT_TO_TABLE(r.content, CHR(10)) f
    WHERE TRIM(f.value) != ''
),
sections AS (
    SELECT *,
           CASE 
               WHEN REGEXP_LIKE(line_text, '^[0-9]+\\.\\s+[A-Z].*') THEN REGEXP_SUBSTR(line_text, '^[0-9]+')
               WHEN REGEXP_LIKE(line_text, '^[0-9]+\\.[0-9]+\\s.*') THEN REGEXP_SUBSTR(line_text, '^[0-9]+\\.[0-9]+')
               WHEN REGEXP_LIKE(line_text, '^SECTION [A-Z].*') THEN REGEXP_SUBSTR(line_text, '^SECTION [A-Z]')
               WHEN REGEXP_LIKE(line_text, '^[A-Z]\\.[0-9]+\\s.*') THEN REGEXP_SUBSTR(line_text, '^[A-Z]\\.[0-9]+')
               WHEN REGEXP_LIKE(line_text, '^CHAPTER [IVX]+.*') THEN REGEXP_SUBSTR(line_text, '^CHAPTER [IVX]+')
               ELSE NULL 
           END AS detected_section,
           CASE 
               WHEN REGEXP_LIKE(line_text, '^[0-9]+\\.\\s+[A-Z].*') THEN 1
               WHEN REGEXP_LIKE(line_text, '^[0-9]+\\.[0-9]+\\s.*') THEN 1
               WHEN REGEXP_LIKE(line_text, '^SECTION [A-Z].*') THEN 1
               WHEN REGEXP_LIKE(line_text, '^[A-Z]\\.[0-9]+\\s.*') THEN 1
               WHEN REGEXP_LIKE(line_text, '^CHAPTER [IVX]+.*') THEN 1
               ELSE 0
           END AS is_section_start
    FROM lines
),
grouped AS (
    SELECT *,
           SUM(is_section_start) OVER (PARTITION BY doc_id ORDER BY line_idx) AS section_group
    FROM sections
),
chunks AS (
    SELECT doc_id, doc_type, title, version, effective_date,
           section_group,
           COALESCE(MAX(detected_section), 'PREAMBLE') AS section_num,
           LISTAGG(line_text, ' ') WITHIN GROUP (ORDER BY line_idx) AS chunk_text
    FROM grouped
    GROUP BY doc_id, doc_type, title, version, effective_date, section_group
),
final AS (
    SELECT 
        doc_id, doc_type, title, version, effective_date, section_group,
        CASE doc_id
            WHEN 1 THEN IFF(section_num = 'PREAMBLE', 'AML Policy Manual, Preamble', 'AML Policy Manual, Section ' || section_num)
            WHEN 2 THEN IFF(section_num = 'PREAMBLE', 'Liquidity Policy, Preamble', 'Liquidity Policy, Section ' || section_num)
            WHEN 3 THEN IFF(section_num = 'PREAMBLE', 'RBI Master Direction, Preamble', 'RBI Master Direction, Section ' || section_num)
            WHEN 4 THEN IFF(section_num = 'PREAMBLE', 'STR Template, Header', 'STR Template, ' || section_num)
            WHEN 5 THEN IFF(section_num = 'PREAMBLE', 'Credit Risk Policy, Preamble', 'Credit Risk Policy, Section ' || section_num)
            WHEN 6 THEN IFF(section_num = 'PREAMBLE', 'ATO Procedure, Preamble', 'ATO Procedure, Section ' || section_num)
        END AS section_ref,
        chunk_text
    FROM chunks
)
SELECT 
    ROW_NUMBER() OVER (ORDER BY doc_id, section_group) AS chunk_id,
    doc_id, doc_type, title, version, effective_date,
    section_ref, chunk_text
FROM final
ORDER BY doc_id, section_group;

-- 3. Create Cortex Search service for hybrid semantic + keyword retrieval
CREATE OR REPLACE CORTEX SEARCH SERVICE UNSTRUCTURED.POLICY_SEARCH_SVC
  ON chunk_text
  ATTRIBUTES doc_type, title, section_ref, effective_date
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 day'
  AS (
    SELECT chunk_id, doc_id, doc_type, title, version, effective_date,
           section_ref, chunk_text
    FROM UNSTRUCTURED.POLICY_DOCUMENTS
  );

-- 4. Grant access
GRANT USAGE ON CORTEX SEARCH SERVICE UNSTRUCTURED.POLICY_SEARCH_SVC TO ROLE PLATFORM_ADMIN;
GRANT USAGE ON CORTEX SEARCH SERVICE UNSTRUCTURED.POLICY_SEARCH_SVC TO ROLE COMPLIANCE_OFFICER;
GRANT USAGE ON CORTEX SEARCH SERVICE UNSTRUCTURED.POLICY_SEARCH_SVC TO ROLE FRAUD_ANALYST;
GRANT USAGE ON CORTEX SEARCH SERVICE UNSTRUCTURED.POLICY_SEARCH_SVC TO ROLE CREDIT_ANALYST;
GRANT USAGE ON CORTEX SEARCH SERVICE UNSTRUCTURED.POLICY_SEARCH_SVC TO ROLE AUDITOR;
