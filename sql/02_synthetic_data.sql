-- ============================================================
-- 02_synthetic_data.sql  —  Bulk synthetic data via GENERATOR()
-- Pure SQL, no LLM calls. Referentially consistent.
-- ============================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE ARGUS_RISK_COPILOT;
USE WAREHOUSE COMPUTE_WH;
USE SCHEMA RAW;

-- ============================================================
-- CUSTOMERS  (~2,000 rows)
-- ============================================================
TRUNCATE TABLE IF EXISTS CUSTOMERS;
INSERT INTO CUSTOMERS (customer_id, name, dob, kyc_risk_rating, address, phone, email, onboarding_date)
WITH
first_names AS (
    SELECT ARRAY_CONSTRUCT(
        'Aarav','Aditi','Aditya','Akshay','Amit','Ananya','Anjali','Arjun','Bhavna','Chandra',
        'Deepa','Deepak','Diya','Gaurav','Geeta','Hari','Isha','Kabir','Kavya','Krishna',
        'Lakshmi','Manish','Meera','Mohan','Nandini','Neha','Nikhil','Pallavi','Pooja','Pradeep',
        'Priya','Rahul','Rajesh','Ravi','Rekha','Rohan','Rohit','Sakshi','Sandeep','Sapna',
        'Shreya','Siddharth','Sneha','Sonia','Sunil','Sunita','Tanvi','Varun','Vijay','Zara'
    ) AS arr
),
last_names AS (
    SELECT ARRAY_CONSTRUCT(
        'Agarwal','Banerjee','Bhatt','Choudhary','Das','Deshmukh','Dubey','Ghosh','Gupta','Iyer',
        'Jain','Joshi','Kapoor','Khan','Kumar','Malhotra','Mehta','Mishra','Nair','Pandey',
        'Patel','Pillai','Rajput','Rao','Reddy','Roy','Shah','Sharma','Singh','Sinha',
        'Srinivasan','Thakur','Tiwari','Varma','Verma','Yadav','Bose','Menon','Hegde','Kulkarni'
    ) AS arr
),
cities AS (
    SELECT ARRAY_CONSTRUCT(
        'Mumbai','Delhi','Bangalore','Hyderabad','Chennai','Kolkata','Pune','Ahmedabad','Jaipur','Lucknow',
        'Chandigarh','Bhopal','Patna','Indore','Nagpur','Kochi','Coimbatore','Vadodara','Surat','Visakhapatnam'
    ) AS arr
),
kyc_ratings AS (
    SELECT ARRAY_CONSTRUCT('LOW','LOW','LOW','LOW','LOW','LOW','MEDIUM','MEDIUM','MEDIUM','HIGH') AS arr
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS customer_id,
    first_names.arr[UNIFORM(0, 49, RANDOM(1))]::VARCHAR || ' ' ||
        last_names.arr[UNIFORM(0, 39, RANDOM(2))]::VARCHAR AS name,
    DATEADD(day, UNIFORM(0, 14600, RANDOM(3)), '1960-01-01'::DATE) AS dob,
    kyc_ratings.arr[UNIFORM(0, 9, RANDOM(4))]::VARCHAR AS kyc_risk_rating,
    UNIFORM(1, 999, RANDOM(5))::VARCHAR || ' ' ||
        ARRAY_CONSTRUCT('MG Road','Station Road','Gandhi Nagar','Nehru Street','Park Avenue',
            'Lake View','Ring Road','Sector ' || UNIFORM(1,50,RANDOM(6))::VARCHAR,
            'Phase ' || UNIFORM(1,10,RANDOM(7))::VARCHAR, 'Colony')[UNIFORM(0,9,RANDOM(8))]::VARCHAR || ', ' ||
        cities.arr[UNIFORM(0, 19, RANDOM(9))]::VARCHAR AS address,
    '+91' || UNIFORM(7000000000, 9999999999, RANDOM(10))::VARCHAR AS phone,
    LOWER(REPLACE(
        first_names.arr[UNIFORM(0, 49, RANDOM(1))]::VARCHAR || '.' ||
        last_names.arr[UNIFORM(0, 39, RANDOM(2))]::VARCHAR, ' ', ''))
        || UNIFORM(1,999,RANDOM(11))::VARCHAR || '@'
        || ARRAY_CONSTRUCT('gmail.com','yahoo.co.in','outlook.com','hotmail.com','rediffmail.com')[UNIFORM(0,4,RANDOM(12))]::VARCHAR AS email,
    DATEADD(day, -UNIFORM(0, 1825, RANDOM(13)), CURRENT_DATE()) AS onboarding_date
FROM TABLE(GENERATOR(ROWCOUNT => 2000)) v
CROSS JOIN first_names
CROSS JOIN last_names
CROSS JOIN cities
CROSS JOIN kyc_ratings;


-- ============================================================
-- ACCOUNTS  (~3,000 rows)
-- 1-2 accounts per customer, some customers get 3
-- ============================================================
TRUNCATE TABLE IF EXISTS ACCOUNTS;
INSERT INTO ACCOUNTS (account_id, customer_id, account_type, status, open_date, currency, current_balance)
WITH acct_types AS (
    SELECT ARRAY_CONSTRUCT('SAVINGS','SAVINGS','SAVINGS','SAVINGS','SAVINGS',
        'CURRENT','CURRENT','CURRENT','LOAN','FD') AS arr
),
statuses AS (
    SELECT ARRAY_CONSTRUCT('ACTIVE','ACTIVE','ACTIVE','ACTIVE','ACTIVE',
        'ACTIVE','ACTIVE','DORMANT','DORMANT','CLOSED') AS arr
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS account_id,
    UNIFORM(1, 2000, RANDOM(20))::INT AS customer_id,
    acct_types.arr[UNIFORM(0, 9, RANDOM(21))]::VARCHAR AS account_type,
    statuses.arr[UNIFORM(0, 9, RANDOM(22))]::VARCHAR AS status,
    DATEADD(day, -UNIFORM(30, 1800, RANDOM(23)), CURRENT_DATE()) AS open_date,
    'INR' AS currency,
    ROUND(POWER(10, UNIFORM(3, 6, RANDOM(24)) + UNIFORM(0, 100, RANDOM(25))::FLOAT / 100), 2) AS current_balance
FROM TABLE(GENERATOR(ROWCOUNT => 3000)) v
CROSS JOIN acct_types
CROSS JOIN statuses;


-- ============================================================
-- COUNTERPARTIES  (~500 rows)
-- ============================================================
TRUNCATE TABLE IF EXISTS COUNTERPARTIES;
INSERT INTO COUNTERPARTIES (counterparty_id, name, type, country, is_pep, is_sanctioned)
WITH
cp_first AS (
    SELECT ARRAY_CONSTRUCT(
        'Alpha','Beta','Gamma','Delta','Omega','Phoenix','Neptune','Atlas','Zenith','Nova',
        'Prism','Apex','Vertex','Meridian','Horizon','Sterling','Summit','Quantum','Nexus','Global',
        'Rajan','Mohammad','Wei','Viktor','Ahmed','Fatima','Ivan','Olga','Chen','Dmitri'
    ) AS arr
),
cp_second AS (
    SELECT ARRAY_CONSTRUCT(
        'Trading','Exports','Industries','Finance','Holdings','Solutions','Enterprises','Corp','Ltd','Group',
        'Logistics','Capital','Ventures','Associates','Partners','International','Systems','Tech','Metals','Textiles'
    ) AS arr
),
cp_types AS (
    SELECT ARRAY_CONSTRUCT('INDIVIDUAL','INDIVIDUAL','INDIVIDUAL','CORPORATE','CORPORATE',
        'CORPORATE','CORPORATE','CORPORATE','GOVERNMENT','GOVERNMENT') AS arr
),
countries AS (
    SELECT ARRAY_CONSTRUCT('IN','IN','IN','IN','IN','IN','IN',
        'AE','US','GB','SG','HK','CH','DE','NG','PK','BD','LK','NP','MM') AS arr
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS counterparty_id,
    cp_first.arr[UNIFORM(0, 29, RANDOM(30))]::VARCHAR || ' ' ||
        cp_second.arr[UNIFORM(0, 19, RANDOM(31))]::VARCHAR AS name,
    cp_types.arr[UNIFORM(0, 9, RANDOM(32))]::VARCHAR AS type,
    countries.arr[UNIFORM(0, 19, RANDOM(33))]::VARCHAR AS country,
    IFF(UNIFORM(1, 100, RANDOM(34)) <= 5, TRUE, FALSE) AS is_pep,
    IFF(UNIFORM(1, 100, RANDOM(35)) <= 3, TRUE, FALSE) AS is_sanctioned
FROM TABLE(GENERATOR(ROWCOUNT => 500)) v
CROSS JOIN cp_first CROSS JOIN cp_second CROSS JOIN cp_types CROSS JOIN countries;


-- ============================================================
-- WATCHLIST_ENTRIES  (~60 rows)
-- Some deliberately match counterparty names for fuzzy-match testing
-- ============================================================
TRUNCATE TABLE IF EXISTS WATCHLIST_ENTRIES;
INSERT INTO WATCHLIST_ENTRIES (watchlist_id, entity_name, aliases, list_type, source, effective_date)
WITH
wl_names AS (
    SELECT ARRAY_CONSTRUCT(
        -- deliberate near-matches to counterparty name components
        'Alpha Trading LLC','Viktor Holdings','Ahmed Finance Group','Dmitri Enterprises',
        'Olga Capital Partners','Chen Metals International','Ivan Logistics SA',
        'Mohammad Exports FZE','Fatima Solutions Ltd','Wei Industries Corp',
        -- pure watchlist entries
        'Rajan Kumar Verma','Suresh Babu Nair','Abdul Rashid Khan','Priya Kumari Singh',
        'Rajendra Prasad Yadav','Naveen Chandra Bose','Syed Imran Ali','Kumari Devi Sharma',
        'Brijesh Patel','Harish Mehta','Gopal Krishna Iyer','Anita Banerjee','Suresh Reddy',
        'Ramesh Choudhary','Vijay Kulkarni','Sundar Pillai','Deepak Joshi','Manoj Tiwari',
        'Ashok Rajput','Kiran Deshmukh','Lalita Ghosh','Parveen Malhotra','Sanjeev Dubey',
        'Tarun Sinha','Uma Shankar Mishra','Vinod Kapoor','Wasim Akram','Xavier Fernandes',
        'Yogesh Bhatt','Zaheer Abbas','Arun Hegde','Balaji Srinivasan','Chetan Varma',
        'Dilip Das','Esha Roy','Farhan Sheikh','Gaurav Thakur','Hemant Agarwal',
        'Indira Pandey','Jagdish Shah','Kamla Devi','Lalit Gupta','Mukesh Verma',
        'Naresh Rao','Om Prakash','Pankaj Jain','Qureshi Ahmad','Rakesh Sharma',
        'Satish Kumar','Trilok Nath','Uday Bhan','Vikram Singh','Waqar Younis',
        'Xerxes Patel','Yusuf Siddiqui','Zeenat Aman','Ajay Devgan','Bhagwan Das'
    ) AS arr
),
list_types AS (
    SELECT ARRAY_CONSTRUCT('PEP','PEP','PEP','SANCTIONS','SANCTIONS','SANCTIONS','PEP','SANCTIONS','PEP','SANCTIONS') AS arr
),
sources AS (
    SELECT ARRAY_CONSTRUCT('UNSC','OFAC','EU_SANCTIONS','FIU-IND','RBI_CAUTION_LIST','INTERPOL','FATF','WORLD_CHECK','DOW_JONES','REFINITIV') AS arr
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS watchlist_id,
    wl_names.arr[MOD(ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, 60)]::VARCHAR AS entity_name,
    NULL AS aliases,
    list_types.arr[UNIFORM(0, 9, RANDOM(40))]::VARCHAR AS list_type,
    sources.arr[UNIFORM(0, 9, RANDOM(41))]::VARCHAR AS source,
    DATEADD(day, -UNIFORM(30, 1800, RANDOM(42)), CURRENT_DATE()) AS effective_date
FROM TABLE(GENERATOR(ROWCOUNT => 60)) v
CROSS JOIN wl_names CROSS JOIN list_types CROSS JOIN sources;


-- ============================================================
-- TRANSACTIONS  (~100,000 rows over trailing 12 months)
-- ============================================================
TRUNCATE TABLE IF EXISTS TRANSACTIONS;
INSERT INTO TRANSACTIONS (transaction_id, account_id, counterparty_id, amount, currency, channel,
    transaction_type, timestamp, device_id, geo_location, declared_purpose)
WITH
channels AS (
    SELECT ARRAY_CONSTRUCT('UPI','UPI','UPI','UPI','NEFT','NEFT','MOBILE','MOBILE','BRANCH','BRANCH',
        'ATM','NETBANKING','RTGS','IMPS','IMPS') AS arr
),
txn_types AS (
    SELECT ARRAY_CONSTRUCT('CREDIT','CREDIT','CREDIT','DEBIT','DEBIT','DEBIT','DEBIT') AS arr
),
purposes AS (
    SELECT ARRAY_CONSTRUCT('Salary','Rent','Utilities','Groceries','Transfer','Investment',
        'Loan Repayment','Business Payment','Insurance','Education','Medical','Travel',
        'E-Commerce','Subscription','Gift','Tax Payment','FD Deposit','Withdrawal','Cash Deposit','Misc') AS arr
),
geos AS (
    SELECT ARRAY_CONSTRUCT(
        'Mumbai-Andheri','Mumbai-BKC','Mumbai-Fort','Delhi-CP','Delhi-Dwarka','Bangalore-Koramangala',
        'Bangalore-Whitefield','Chennai-T-Nagar','Kolkata-Salt-Lake','Pune-Hinjewadi',
        'Hyderabad-Hitec-City','Ahmedabad-SG-Highway','Jaipur-MI-Road','Lucknow-Gomti-Nagar',
        'Chandigarh-Sec-17','Kochi-MG-Road','Indore-Vijay-Nagar','Surat-Ring-Road',
        'Nagpur-Dharampeth','Bhopal-MP-Nagar') AS arr
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS transaction_id,
    UNIFORM(1, 3000, RANDOM(50))::INT AS account_id,
    UNIFORM(1, 500, RANDOM(51))::INT AS counterparty_id,
    ROUND(POWER(10, 2 + UNIFORM(0, 400, RANDOM(52))::FLOAT / 100), 2) AS amount,
    'INR' AS currency,
    channels.arr[UNIFORM(0, 14, RANDOM(53))]::VARCHAR AS channel,
    txn_types.arr[UNIFORM(0, 6, RANDOM(54))]::VARCHAR AS transaction_type,
    DATEADD(second,
        UNIFORM(0, 365 * 86400, RANDOM(55)),
        DATEADD(day, -365, CURRENT_TIMESTAMP())) AS timestamp,
    'DEV-' || LPAD(UNIFORM(1, 4000, RANDOM(56))::VARCHAR, 6, '0') AS device_id,
    geos.arr[UNIFORM(0, 19, RANDOM(57))]::VARCHAR AS geo_location,
    purposes.arr[UNIFORM(0, 19, RANDOM(58))]::VARCHAR AS declared_purpose
FROM TABLE(GENERATOR(ROWCOUNT => 100000)) v
CROSS JOIN channels CROSS JOIN txn_types CROSS JOIN purposes CROSS JOIN geos;


-- ============================================================
-- LOANS  (~600 rows)
-- ============================================================
TRUNCATE TABLE IF EXISTS LOANS;
INSERT INTO LOANS (loan_id, customer_id, principal, outstanding, disbursement_date,
    tenure_months, interest_rate, dpd, restructuring_flag, bureau_score_at_origination, latest_bureau_score)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS loan_id,
    UNIFORM(1, 2000, RANDOM(60))::INT AS customer_id,
    ROUND(POWER(10, UNIFORM(4, 7, RANDOM(61)) + UNIFORM(0,100,RANDOM(62))::FLOAT/100), -3) AS principal,
    ROUND(POWER(10, UNIFORM(4, 7, RANDOM(63)) + UNIFORM(0,100,RANDOM(64))::FLOAT/100), -3) * UNIFORM(20, 100, RANDOM(65))::FLOAT / 100 AS outstanding,
    DATEADD(day, -UNIFORM(30, 1095, RANDOM(66)), CURRENT_DATE()) AS disbursement_date,
    ARRAY_CONSTRUCT(12, 24, 36, 48, 60, 84, 120, 180, 240)[UNIFORM(0, 8, RANDOM(67))]::INT AS tenure_months,
    ROUND(UNIFORM(700, 1800, RANDOM(68))::FLOAT / 100, 2) AS interest_rate,
    IFF(UNIFORM(1, 100, RANDOM(69)) <= 85, 0,
        UNIFORM(1, 180, RANDOM(70))) AS dpd,
    IFF(UNIFORM(1, 100, RANDOM(71)) <= 5, TRUE, FALSE) AS restructuring_flag,
    UNIFORM(550, 850, RANDOM(72)) AS bureau_score_at_origination,
    UNIFORM(500, 870, RANDOM(73)) AS latest_bureau_score
FROM TABLE(GENERATOR(ROWCOUNT => 600)) v;


-- ============================================================
-- GENERAL_LEDGER  (~2,400 rows — 200 per month × 12)
-- GL codes support LCR/NSFR proxy calculation
-- ============================================================
TRUNCATE TABLE IF EXISTS GENERAL_LEDGER;
INSERT INTO GENERAL_LEDGER (entry_id, posting_date, gl_code, gl_description, debit_amount, credit_amount, balance, department)
WITH
gl_items AS (
    SELECT ARRAY_CONSTRUCT(
        'GL1001','GL1002','GL1003','GL1004','GL1005','GL1006','GL1007','GL1008','GL1009','GL1010',
        'GL2001','GL2002','GL2003','GL2004','GL2005','GL3001','GL3002','GL3003','GL3004','GL3005'
    ) AS codes,
    ARRAY_CONSTRUCT(
        'CASA Deposits','Term Deposits','Savings Deposits','Current Account Deposits','Inter-Bank Borrowings',
        'Retail Advances','Corporate Advances','Priority Sector Advances','Investment - Govt Securities','Investment - SLR',
        'CRR Balance','Cash in Hand','NPA Provisions','Interest Income Accrued','Fee Income',
        'Operating Expenses','Staff Costs','Depreciation','Other Liabilities','Capital Reserves'
    ) AS descs
),
depts AS (
    SELECT ARRAY_CONSTRUCT('Treasury','Retail Banking','Corporate Banking','Risk Management','Operations',
        'Finance','Compliance','IT','HR','Admin') AS arr
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS entry_id,
    DATEADD(day,
        MOD(ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, 365),
        DATEADD(day, -365, CURRENT_DATE())) AS posting_date,
    gl_items.codes[MOD(ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, 20)]::VARCHAR AS gl_code,
    gl_items.descs[MOD(ROW_NUMBER() OVER (ORDER BY SEQ4()) - 1, 20)]::VARCHAR AS gl_description,
    ROUND(UNIFORM(100000, 50000000, RANDOM(80))::FLOAT, 2) AS debit_amount,
    ROUND(UNIFORM(100000, 50000000, RANDOM(81))::FLOAT, 2) AS credit_amount,
    ROUND(UNIFORM(1000000, 500000000, RANDOM(82))::FLOAT, 2) AS balance,
    depts.arr[UNIFORM(0, 9, RANDOM(83))]::VARCHAR AS department
FROM TABLE(GENERATOR(ROWCOUNT => 2400)) v
CROSS JOIN gl_items CROSS JOIN depts;


-- ============================================================
-- DEVICE_SESSION_LOGS  (~8,000 rows)
-- ============================================================
TRUNCATE TABLE IF EXISTS DEVICE_SESSION_LOGS;
INSERT INTO DEVICE_SESSION_LOGS (session_id, customer_id, device_id, ip_geo, login_timestamp, event_type)
WITH
event_types AS (
    SELECT ARRAY_CONSTRUCT('LOGIN','LOGIN','LOGIN','LOGIN','LOGIN','LOGIN','LOGIN','LOGIN',
        'CONTACT_CHANGE','PASSWORD_RESET') AS arr
),
ip_geos AS (
    SELECT ARRAY_CONSTRUCT(
        'IN-MH-Mumbai','IN-DL-Delhi','IN-KA-Bangalore','IN-TN-Chennai','IN-WB-Kolkata',
        'IN-MH-Pune','IN-GJ-Ahmedabad','IN-RJ-Jaipur','IN-UP-Lucknow','IN-PB-Chandigarh',
        'AE-DU-Dubai','US-NY-NewYork','GB-LDN-London','SG-SG-Singapore','UNKNOWN') AS arr
)
SELECT
    ROW_NUMBER() OVER (ORDER BY SEQ4()) AS session_id,
    UNIFORM(1, 2000, RANDOM(90))::INT AS customer_id,
    'DEV-' || LPAD(UNIFORM(1, 4000, RANDOM(91))::VARCHAR, 6, '0') AS device_id,
    ip_geos.arr[UNIFORM(0, 14, RANDOM(92))]::VARCHAR AS ip_geo,
    DATEADD(second,
        UNIFORM(0, 365 * 86400, RANDOM(93)),
        DATEADD(day, -365, CURRENT_TIMESTAMP())) AS login_timestamp,
    event_types.arr[UNIFORM(0, 9, RANDOM(94))]::VARCHAR AS event_type
FROM TABLE(GENERATOR(ROWCOUNT => 8000)) v
CROSS JOIN event_types CROSS JOIN ip_geos;
