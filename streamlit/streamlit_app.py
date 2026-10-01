import streamlit as st
import json
import base64
from snowflake.snowpark.context import get_active_session
import _snowflake

# -- Session & RBAC --------------------------------------------------------
session = get_active_session()
_role_row = session.sql("SELECT CURRENT_ROLE() AS R, CURRENT_USER() AS U").collect()[0]
CURRENT_ROLE = _role_row["R"]
CURRENT_USER = _role_row["U"]

DB = "ARGUS_RISK_COPILOT"

# -- Pramanakavach Logo (inline SVG, base64-encoded) ------------------------
_LOGO_SVG_B64 = (
    "PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCA0ODAg"
    "MTIwIiB3aWR0aD0iNDgwIiBoZWlnaHQ9IjEyMCI+CiAgPGRlZnM+CiAgICA8c3R5bGU+CiAgICAg"
    "IC50aXRsZSB7IGZvbnQtZmFtaWx5OiAnR2VvcmdpYScsICdUaW1lcyBOZXcgUm9tYW4nLCBzZXJp"
    "ZjsgZm9udC1zaXplOiAyOHB4OyBmaWxsOiAjMWEzYTVjOyBsZXR0ZXItc3BhY2luZzogMXB4OyB9"
    "CiAgICAgIC5oaW5kaSB7IGZvbnQtZmFtaWx5OiAnTm90byBTYW5zIERldmFuYWdhcmknLCAnQXJp"
    "YWwgVW5pY29kZSBNUycsIHNhbnMtc2VyaWY7IGZvbnQtc2l6ZTogMTRweDsgZmlsbDogIzFhM2E1"
    "YzsgfQogICAgICAudGFnbGluZSB7IGZvbnQtZmFtaWx5OiAnR2VvcmdpYScsICdUaW1lcyBOZXcg"
    "Um9tYW4nLCBzZXJpZjsgZm9udC1zaXplOiAxMXB4OyBmaWxsOiAjNGE3YTljOyBmb250LXN0eWxl"
    "OiBpdGFsaWM7IH0KICAgICAgLnNoaWVsZCB7IGZpbGw6IG5vbmU7IHN0cm9rZTogIzFhM2E1Yzsg"
    "c3Ryb2tlLXdpZHRoOiAyOyB9CiAgICAgIC5ydXBlZSB7IGZvbnQtZmFtaWx5OiAnQXJpYWwnLCBz"
    "YW5zLXNlcmlmOyBmb250LXNpemU6IDMycHg7IGZpbGw6ICMxYTNhNWM7IGZvbnQtd2VpZ2h0OiBi"
    "b2xkOyB9CiAgICAgIC5jaXJjbGUgeyBmaWxsOiBub25lOyBzdHJva2U6ICMxYTNhNWM7IHN0cm9r"
    "ZS13aWR0aDogMS41OyB9CiAgICAgIC5jaGVjay1jaXJjbGUgeyBmaWxsOiAjMWEzYTVjOyB9CiAg"
    "ICAgIC5jaGVjayB7IGZpbGw6IHdoaXRlOyB9CiAgICAgIC5saW5lIHsgc3Ryb2tlOiAjMWEzYTVj"
    "OyBzdHJva2Utd2lkdGg6IDEuNTsgfQogICAgPC9zdHlsZT4KICA8L2RlZnM+CiAgCiAgPCEtLSBT"
    "aGllbGQgc2hhcGUgLS0+CiAgPHBhdGggZD0iTSA2MCAxMCBMIDExMCAzMCBMIDExMCA2NSBRIDEx"
    "MCA5NSA2MCAxMTUgUSAxMCA5NSAxMCA2NSBMIDEwIDMwIFoiIGNsYXNzPSJzaGllbGQiLz4KICAK"
    "ICA8IS0tIFJ1cGVlIHN5bWJvbCBpbnNpZGUgc2hpZWxkIC0tPgogIDx0ZXh0IHg9IjQ4IiB5PSI3"
    "MiIgY2xhc3M9InJ1cGVlIj7igrk8L3RleHQ+CiAgCiAgPCEtLSBDaXJjbGUvZ2xvYmUgbGluZXMg"
    "aW5zaWRlIHNoaWVsZCAtLT4KICA8ZWxsaXBzZSBjeD0iNjAiIGN5PSI2OCIgcng9IjI4IiByeT0i"
    "MjgiIGNsYXNzPSJjaXJjbGUiIG9wYWNpdHk9IjAuMyIvPgogIDxsaW5lIHgxPSIzMiIgeTE9IjU4"
    "IiB4Mj0iODgiIHkyPSI1OCIgY2xhc3M9ImxpbmUiIG9wYWNpdHk9IjAuMyIvPgogIDxsaW5lIHgx"
    "PSIzMiIgeTE9Ijc4IiB4Mj0iODgiIHkyPSI3OCIgY2xhc3M9ImxpbmUiIG9wYWNpdHk9IjAuMyIv"
    "PgogIAogIDwhLS0gQ2hlY2sgbWFyayBjaXJjbGUgYXQgdG9wIC0tPgogIDxjaXJjbGUgY3g9Ijg1"
    "IiBjeT0iMTUiIHI9IjEwIiBjbGFzcz0iY2hlY2stY2lyY2xlIi8+CiAgPHBvbHlsaW5lIHBvaW50"
    "cz0iNzksMTUgODMsMTkgOTEsMTEiIGZpbGw9Im5vbmUiIHN0cm9rZT0id2hpdGUiIHN0cm9rZS13"
    "aWR0aD0iMiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIi8+"
    "CiAgCiAgPCEtLSBIb3Jpem9udGFsIGxpbmVzIChyZXByZXNlbnRpbmcgZG9jdW1lbnQvZGF0YSkg"
    "LS0+CiAgPGxpbmUgeDE9IjE1IiB5MT0iNDIiIHgyPSI0NSIgeTI9IjQyIiBjbGFzcz0ibGluZSIg"
    "b3BhY2l0eT0iMC40Ii8+CiAgPGxpbmUgeDE9IjE1IiB5MT0iNDgiIHgyPSI0MCIgeTI9IjQ4IiBj"
    "bGFzcz0ibGluZSIgb3BhY2l0eT0iMC40Ii8+CiAgPGxpbmUgeDE9IjE1IiB5MT0iNTQiIHgyPSIz"
    "NSIgeTI9IjU0IiBjbGFzcz0ibGluZSIgb3BhY2l0eT0iMC40Ii8+CiAgCiAgPCEtLSBUZXh0OiBQ"
    "cmFtYW5ha2F2YWNoIC0tPgogIDx0ZXh0IHg9IjEzMCIgeT0iNTIiIGNsYXNzPSJ0aXRsZSI+UHJh"
    "bcSBbmFrYXZhY2g8L3RleHQ+CiAgCiAgPCEtLSBIaW5kaSB0ZXh0IC0tPgogIDx0ZXh0IHg9IjEz"
    "MCIgeT0iNzUiIGNsYXNzPSJoaW5kaSI+4KSq4KWN4KSw4KSu4KS+4KSj4KSV4KS14KSaPC90ZXh0"
    "PgogIAogIDwhLS0gVGFnbGluZSAtLT4KICA8dGV4dCB4PSIxMzAiIHk9Ijk4IiBjbGFzcz0idGFn"
    "bGluZSI+RnJhdWQgQmxvY2tlZCDCtyBldmlkZW5jZSBoZWxkPC90ZXh0Pgo8L3N2Zz4K"
)

def _render_logo_html():
    return f'<img src="data:image/svg+xml;base64,{_LOGO_SVG_B64}" style="width:100%;max-width:280px;" />'

def esc(s):
    """Escape a value for safe SQL interpolation."""
    if s is None:
        return "NULL"
    return "'" + str(s).replace("\\", "\\\\").replace("'", "''") + "'"

def safe_rerun():
    if hasattr(st, 'rerun'):
        st.rerun()
    elif hasattr(st, 'experimental_rerun'):
        st.experimental_rerun()

ROLE_PAGES = {
    "ACCOUNTADMIN":       ["Ask Argus","Alert Queue","Case Detail","Liquidity & Credit","Regulatory Reporting","Audit Log","Integrations"],
    "PLATFORM_ADMIN":     ["Ask Argus","Alert Queue","Case Detail","Liquidity & Credit","Regulatory Reporting","Audit Log","Integrations"],
    "COMPLIANCE_OFFICER": ["Ask Argus","Alert Queue","Case Detail","Liquidity & Credit","Regulatory Reporting","Audit Log"],
    "FRAUD_ANALYST":      ["Ask Argus","Alert Queue","Case Detail","Audit Log"],
    "CREDIT_ANALYST":     ["Ask Argus","Liquidity & Credit","Audit Log"],
    "TREASURY_ANALYST":   ["Liquidity & Credit"],
    "AUDITOR":            ["Alert Queue","Case Detail","Liquidity & Credit","Regulatory Reporting","Audit Log"],
    "BRANCH_USER":        ["Ask Argus"],
}
allowed = ROLE_PAGES.get(CURRENT_ROLE, ["Ask Argus"])

# -- Sidebar ----------------------------------------------------------------
st.sidebar.markdown(_render_logo_html(), unsafe_allow_html=True)
st.sidebar.markdown("---")
st.sidebar.caption(f"Role: **{CURRENT_ROLE}**")
page = st.sidebar.radio("Navigation", allowed, label_visibility="collapsed")
st.sidebar.divider()
st.sidebar.markdown("SIGNAL ➜ EVIDENCE ➜ FINDING ➜ REPORT")

# -- Agent helper -----------------------------------------------------------
def call_argus_agent(question, chat_history=None):
    """Call the Argus Cortex Agent via the REST API."""
    messages = []
    if chat_history:
        for msg in chat_history[-6:]:
            if msg["role"] == "user":
                messages.append({"role": "user", "content": [{"type": "text", "text": msg["content"]}]})
            else:
                messages.append({"role": "assistant", "content": [{"type": "text", "text": msg["content"]}]})
    messages.append({"role": "user", "content": [{"type": "text", "text": question}]})

    req_body = json.dumps({"messages": messages, "stream": False})

    try:
        resp = _snowflake.send_snow_api_request(
            "POST",
            f"/api/v2/databases/{DB}/schemas/GOVERNANCE/agents/ARGUS_COPILOT:run",
            {},
            {},
            req_body,
            {},
            30000
        )

        if resp and resp.get("status", 0) == 200:
            body = json.loads(resp.get("content", "{}"))
            text_parts = []
            for block in body.get("content", []):
                if block.get("type") == "text":
                    text_parts.append(block["text"])
            if text_parts:
                return "\n\n".join(text_parts)
            return json.dumps(body, indent=2)[:3000]
        else:
            status = resp.get("status", "unknown") if resp else "no response"
            content = resp.get("content", "") if resp else ""
            raise Exception(f"Agent API returned status {status}: {content[:500]}")
    except Exception:
        raise

def call_fallback_llm(question):
    """Fallback to CORTEX.COMPLETE when the agent is unavailable."""
    result = session.sql(f"""
        SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b',
            'You are Pramanakavach, a governed banking risk copilot for an Indian bank. '
            || 'Follow these rules: evidence-first, cite data IDs, state confidence. '
            || 'Question: ' || {esc(question)}
        ) AS response
    """).collect()
    answer = result[0]["RESPONSE"] if result else "No response."
    return "[Fallback mode - agent unavailable]\n\n" + answer

# =====================================================================
# PAGE 1 -- Ask Argus (Cortex Agent Chat)
# =====================================================================
if page == "Ask Argus":
    st.header("Ask Argus")
    st.caption("Chat with the governed Argus agent. Every answer is routed through the semantic view and policy search -- never raw SQL.")

    if "chat_history" not in st.session_state:
        st.session_state.chat_history = []

    for msg in st.session_state.chat_history:
        if msg["role"] == "user":
            st.markdown(f"**You:** {msg['content']}")
        else:
            st.markdown(f"**Argus:** {msg['content']}")
        st.divider()

    with st.form("ask_form", clear_on_submit=True):
        prompt = st.text_input("Ask about fraud signals, AML, credit risk, or liquidity...", key="ask_input")
        col_submit, col_txn, col_draft, col_esc = st.columns(4)
        submitted = col_submit.form_submit_button("Ask Argus", type="primary")
        btn_txn = col_txn.form_submit_button("View Transactions")
        btn_draft = col_draft.form_submit_button("Draft Finding")
        btn_escalate = col_esc.form_submit_button("Escalate")

    question = None
    if submitted and prompt:
        question = prompt
    elif btn_txn:
        question = "Show me the underlying transactions for the most recent signal."
    elif btn_draft:
        question = "Draft a finding report with evidence and policy citations for the most recent case."
    elif btn_escalate:
        question = "Escalate the most recent case to a senior compliance officer."

    if question:
        st.session_state.chat_history.append({"role": "user", "content": question})
        st.markdown(f"**You:** {question}")

        with st.spinner("Argus is reasoning..."):
            try:
                answer = call_argus_agent(question, st.session_state.chat_history)
            except Exception:
                try:
                    answer = call_fallback_llm(question)
                except Exception as e2:
                    answer = f"Error: {str(e2)[:500]}"

        st.markdown(f"**Argus:** {answer}")
        st.session_state.chat_history.append({"role": "assistant", "content": answer})

# =====================================================================
# PAGE 2 -- Alert Queue
# =====================================================================
elif page == "Alert Queue":
    st.header("Alert Queue")

    VALID_TYPES = ["STRUCTURING","MONEY_MULE","ACCOUNT_TAKEOVER","LOAN_STACKING"]
    VALID_SEV = ["CRITICAL","HIGH","MEDIUM","LOW"]
    VALID_SORT = {
        "Severity then Confidence": "severity_rank ASC, confidence DESC",
        "Confidence Desc": "confidence DESC",
        "Newest First": "detected_at DESC",
    }

    col1, col2, col3 = st.columns(3)
    with col1:
        typology_filter = st.multiselect("Typology", VALID_TYPES, default=["STRUCTURING","MONEY_MULE","ACCOUNT_TAKEOVER","LOAN_STACKING"])
    with col2:
        severity_filter = st.multiselect("Severity", VALID_SEV, default=["CRITICAL","HIGH"])
    with col3:
        sort_label = st.selectbox("Sort by", list(VALID_SORT.keys()))

    safe_types = [t for t in typology_filter if t in VALID_TYPES]
    safe_sevs = [s for s in severity_filter if s in VALID_SEV]
    sort_clause = VALID_SORT[sort_label]

    if not safe_types:
        safe_types = VALID_TYPES
    if not safe_sevs:
        safe_sevs = VALID_SEV

    type_list = ",".join([esc(t) for t in safe_types])
    sev_list = ",".join([esc(s) for s in safe_sevs])

    df = session.sql(f"""
        SELECT s.signal_id, s.signal_type, s.entity_id AS customer_id, s.severity, s.confidence,
               s.detected_at, c.status AS case_status, c.assigned_to,
               CASE s.severity WHEN 'CRITICAL' THEN 1 ELSE 2 END AS severity_rank
        FROM {DB}.GOVERNANCE.SIGNALS_ALERTS s
        LEFT JOIN {DB}.GOVERNANCE.CASES c ON c.signal_id = s.signal_id
        WHERE s.signal_type IN ({type_list}) AND s.severity IN ({sev_list})
        ORDER BY {sort_clause}
    """).to_pandas()

    mc1, mc2, mc3, mc4 = st.columns(4)
    mc1.metric("Total Alerts", len(df))
    mc2.metric("Critical", len(df[df["SEVERITY"]=="CRITICAL"]))
    mc3.metric("High", len(df[df["SEVERITY"]=="HIGH"]))
    mc4.metric("Open Cases", len(df[df["CASE_STATUS"].notna() & (df["CASE_STATUS"]!="CLOSED")]) if "CASE_STATUS" in df.columns else 0)

    st.dataframe(df.drop(columns=["SEVERITY_RANK"], errors="ignore"), use_container_width=True, height=400)

    st.divider()
    st.subheader("Promote Signal to Case")
    signal_ids = df["SIGNAL_ID"].tolist() if len(df) > 0 else []
    if signal_ids:
        sel_signal = st.selectbox("Signal to promote", signal_ids)
        if st.button("Create Case", type="primary"):
            try:
                session.sql(f"""
                    INSERT INTO {DB}.GOVERNANCE.CASES
                        (case_id, signal_id, signal_type, customer_id, status, priority,
                         assigned_to, created_at, updated_at)
                    SELECT
                        'CASE-' || SUBSTR(s.signal_id, 1, 12) || '-' || TO_CHAR(CURRENT_TIMESTAMP(), 'YYYYMMDDHH24MISS'),
                        s.signal_id,
                        s.signal_type,
                        s.entity_id,
                        'OPEN',
                        s.severity,
                        NULL,
                        CURRENT_TIMESTAMP(),
                        CURRENT_TIMESTAMP()
                    FROM {DB}.GOVERNANCE.SIGNALS_ALERTS s
                    WHERE s.signal_id = {esc(sel_signal)}
                      AND NOT EXISTS (SELECT 1 FROM {DB}.GOVERNANCE.CASES c WHERE c.signal_id = s.signal_id)
                """).collect()
                st.success(f"Case created for signal {sel_signal}")
                safe_rerun()
            except Exception as e:
                st.error(f"Error creating case: {str(e)[:300]}")
    else:
        st.info("No signals match the current filters.")

# =====================================================================
# PAGE 3 -- Case Detail
# =====================================================================
elif page == "Case Detail":
    st.header("Case Detail")

    cases_df = session.sql(f"""
        SELECT case_id, signal_type, customer_id, status, priority, assigned_to, created_at
        FROM {DB}.GOVERNANCE.CASES
        ORDER BY created_at DESC
    """).to_pandas()

    case_id = st.selectbox("Select Case", cases_df["CASE_ID"].tolist() if len(cases_df) > 0 else ["No cases"])

    if case_id != "No cases" and len(cases_df) > 0:
        if case_id not in cases_df["CASE_ID"].values:
            st.error("Invalid case selected.")
        else:
            case_row = cases_df[cases_df["CASE_ID"] == case_id].iloc[0]

            col1, col2, col3, col4 = st.columns(4)
            col1.metric("Status", case_row["STATUS"])
            col2.metric("Priority", case_row["PRIORITY"])
            col3.metric("Typology", case_row["SIGNAL_TYPE"])
            col4.metric("Customer", str(case_row["CUSTOMER_ID"]))

            tab1, tab2, tab3 = st.tabs(["Evidence Timeline", "Finding", "Actions"])

            with tab1:
                st.subheader("Signal Evidence")
                evidence = session.sql(f"""
                    SELECT s.signal_id, s.detected_at, s.confidence, s.evidence_json
                    FROM {DB}.GOVERNANCE.SIGNALS_ALERTS s
                    JOIN {DB}.GOVERNANCE.CASES c ON c.signal_id = s.signal_id
                    WHERE c.case_id = {esc(case_id)}
                """).to_pandas()

                if len(evidence) > 0:
                    st.json(json.loads(evidence.iloc[0]["EVIDENCE_JSON"]) if evidence.iloc[0]["EVIDENCE_JSON"] else {})
                else:
                    st.info("No signal evidence found.")

            with tab2:
                st.subheader("Finding / Draft Report")
                signal_type = case_row["SIGNAL_TYPE"]
                customer_id = case_row["CUSTOMER_ID"]

                findings = session.sql(f"""
                    SELECT finding_id, finding_type, confidence, narrative, policy_reference, created_by, created_at
                    FROM {DB}.GOVERNANCE.FINDINGS
                    WHERE case_id = {esc(case_id)}
                    ORDER BY created_at DESC
                """).to_pandas()

                if len(findings) > 0:
                    for _, f in findings.iterrows():
                        with st.expander(f"Finding {f['FINDING_ID']} -- {f['FINDING_TYPE']} (conf: {f['CONFIDENCE']})"):
                            st.markdown(f"**Narrative:** {f['NARRATIVE']}")
                            st.markdown(f"**Policy Ref:** {f['POLICY_REFERENCE']}")
                            st.caption(f"By {f['CREATED_BY']} at {f['CREATED_AT']}")

                can_draft = CURRENT_ROLE in ("ACCOUNTADMIN", "PLATFORM_ADMIN", "COMPLIANCE_OFFICER", "FRAUD_ANALYST")
                draft_key = f"draft_{case_id}"

                if len(findings) == 0 and can_draft and draft_key not in st.session_state:
                    st.warning("No findings yet for this case.")
                    st.markdown("Use **Ask Argus** to automatically gather evidence, retrieve policy citations, and draft a finding report.")

                    if st.button("Ask Argus to Draft Finding", type="primary", key="ask_argus_draft"):
                        with st.spinner("Argus is gathering evidence and drafting the finding..."):
                            try:
                                sig_ev = session.sql(f"""
                                    SELECT s.signal_id, s.confidence, s.evidence_json
                                    FROM {DB}.GOVERNANCE.SIGNALS_ALERTS s
                                    JOIN {DB}.GOVERNANCE.CASES c ON c.signal_id = s.signal_id
                                    WHERE c.case_id = {esc(case_id)}
                                """).collect()
                                ev_json = sig_ev[0]["EVIDENCE_JSON"] if sig_ev else "{}"
                                sig_conf = float(sig_ev[0]["CONFIDENCE"]) if sig_ev else 0.75

                                agent_question = (
                                    f"Draft a finding report for case {case_id}. "
                                    f"Signal type: {signal_type}, customer: {customer_id}. "
                                    f"Signal evidence: {ev_json}. "
                                    f"Include: (1) a detailed narrative with specific transaction IDs and amounts, "
                                    f"(2) policy citations from the relevant sections, "
                                    f"(3) confidence score. Use both the data analyst and policy search tools."
                                )
                                safe_q = agent_question.replace("\\", "\\\\").replace('"', '\\"')
                                req_body = '{"messages":[{"role":"user","content":[{"type":"text","text":"' + safe_q + '"}]}]}'
                                result = session.sql(f"""
                                    SELECT SNOWFLAKE.CORTEX.DATA_AGENT_RUN(
                                        '{DB}.GOVERNANCE.ARGUS_COPILOT',
                                        $${req_body}$$
                                    ) AS response
                                """).collect()
                                raw = result[0]["RESPONSE"] if result else "{}"
                                try:
                                    resp_obj = json.loads(raw)
                                    text_parts = []
                                    for block in resp_obj.get("content", []):
                                        if block.get("type") == "text":
                                            text_parts.append(block["text"])
                                    narrative = "\n\n".join(text_parts) if text_parts else str(raw)[:4000]
                                except (json.JSONDecodeError, TypeError, KeyError):
                                    narrative = str(raw)[:4000]
                                source = "ARGUS_AGENT"
                            except Exception:
                                try:
                                    sig_ev = session.sql(f"""
                                        SELECT s.confidence, s.evidence_json
                                        FROM {DB}.GOVERNANCE.SIGNALS_ALERTS s
                                        JOIN {DB}.GOVERNANCE.CASES c ON c.signal_id = s.signal_id
                                        WHERE c.case_id = {esc(case_id)}
                                    """).collect()
                                    ev_json = sig_ev[0]["EVIDENCE_JSON"] if sig_ev else "{}"
                                    sig_conf = float(sig_ev[0]["CONFIDENCE"]) if sig_ev else 0.75
                                    llm_result = session.sql(f"""
                                        SELECT SNOWFLAKE.CORTEX.COMPLETE('llama3.1-70b',
                                            'You are Argus, a governed banking risk copilot. '
                                            || 'Draft a concise finding report for signal type: {signal_type}, '
                                            || 'customer: {customer_id}. Evidence: ' || {esc(str(ev_json)[:2000])}
                                            || '. Include: narrative with transaction IDs and amounts, '
                                            || 'policy citations, and confidence score.'
                                        ) AS response
                                    """).collect()
                                    narrative = llm_result[0]["RESPONSE"] if llm_result else "See signal evidence for details."
                                    narrative = "[Fallback - agent unavailable]\n\n" + narrative
                                    source = "ARGUS_FALLBACK"
                                except Exception as e2:
                                    st.error(f"Failed to generate finding: {str(e2)[:500]}")
                                    narrative = None

                            if narrative:
                                policy_ref = ""
                                try:
                                    pr = session.sql(f"""
                                        SELECT PARSE_JSON(SNOWFLAKE.CORTEX.SEARCH_PREVIEW(
                                            '{DB}.UNSTRUCTURED.POLICY_SEARCH_SVC',
                                            '{{"query": "{signal_type} indicators policy section", "columns": ["SECTION_REF"], "limit": 3}}'
                                        ))['results'] AS r
                                    """).collect()
                                    if pr:
                                        refs = json.loads(pr[0]["R"])
                                        policy_ref = "; ".join([r.get("SECTION_REF", "") for r in refs if r.get("SECTION_REF")])
                                except Exception:
                                    policy_ref = f"See {signal_type} policy section"

                                try:
                                    ev_obj = json.loads(ev_json) if isinstance(ev_json, str) else ev_json
                                    ev_summary = "; ".join([f"{k}: {v}" for k, v in (ev_obj if isinstance(ev_obj, dict) else {}).items()])[:2000]
                                except Exception:
                                    ev_summary = str(ev_json)[:2000]

                                rtype_map = {"STRUCTURING": "STR", "MONEY_MULE": "STR", "ACCOUNT_TAKEOVER": "ATO_INCIDENT", "LOAN_STACKING": "CREDIT_REVIEW"}
                                default_rtype = rtype_map.get(signal_type, "GENERAL")
                                default_title = f"{signal_type.replace('_', ' ').title()} -- Customer {customer_id}, Case {case_id}"

                                st.session_state[draft_key] = {
                                    "narrative": narrative[:4000],
                                    "policy_ref": policy_ref,
                                    "evidence_summary": ev_summary,
                                    "confidence": sig_conf,
                                    "report_type": default_rtype,
                                    "title": default_title,
                                    "source": source,
                                }
                                safe_rerun()

                if draft_key in st.session_state:
                    draft = st.session_state[draft_key]
                    st.divider()
                    st.subheader("Review Draft Finding")
                    if draft["source"] == "ARGUS_FALLBACK":
                        st.caption("Generated via LLM fallback (agent unavailable). Review carefully before submitting.")
                    else:
                        st.caption("Generated by Argus agent. Review, edit if needed, then submit.")

                    dc1, dc2 = st.columns(2)
                    with dc1:
                        edit_rtype = st.selectbox("Report Type",
                            ["STR", "ATO_INCIDENT", "CREDIT_REVIEW", "ESCALATION_MEMO", "GENERAL"],
                            index=["STR", "ATO_INCIDENT", "CREDIT_REVIEW", "ESCALATION_MEMO", "GENERAL"].index(draft["report_type"]),
                            key="edit_rtype")
                    with dc2:
                        edit_title = st.text_input("Title", value=draft["title"], key="edit_title")

                    edit_narrative = st.text_area("Narrative", value=draft["narrative"], height=250, key="edit_narrative")
                    edit_policy = st.text_input("Policy Citations", value=draft["policy_ref"], key="edit_policy")
                    edit_evidence = st.text_area("Evidence Summary", value=draft["evidence_summary"], height=100, key="edit_evidence")
                    edit_confidence = st.slider("Confidence", 0.0, 1.0, float(draft["confidence"]), 0.05, key="edit_conf")

                    sc1, sc2 = st.columns(2)
                    with sc1:
                        if st.button("Submit Finding & Draft Report", type="primary", key="submit_finding"):
                            with st.spinner("Submitting..."):
                                try:
                                    fnd_id = f"FND-{case_id.replace('CASE-', '')}-{'A' if draft['source'] == 'ARGUS_AGENT' else 'F'}"
                                    session.sql(f"""
                                        INSERT INTO {DB}.GOVERNANCE.FINDINGS
                                            (finding_id, case_id, finding_type, confidence, narrative, evidence_summary,
                                             policy_reference, created_by, created_at)
                                        VALUES ({esc(fnd_id)}, {esc(case_id)}, {esc(signal_type)}, {edit_confidence},
                                                {esc(edit_narrative[:4000])}, {esc(edit_evidence[:2000])},
                                                {esc(edit_policy)}, {esc(draft['source'])}, CURRENT_TIMESTAMP())
                                    """).collect()

                                    rpt_result = session.sql(f"""
                                        CALL {DB}.GOVERNANCE.DRAFT_FINDING_REPORT(
                                            {esc(case_id)}, {esc(edit_rtype)}, {esc(edit_title)},
                                            {esc(edit_narrative[:4000])}, {esc(edit_evidence[:2000])},
                                            {esc(edit_policy)}, {edit_confidence}, {esc(signal_type)}, {customer_id}
                                        )
                                    """).collect()
                                    rpt_msg = rpt_result[0][0] if rpt_result else "Report drafted"
                                    del st.session_state[draft_key]
                                    st.success(f"Finding {fnd_id} submitted. {rpt_msg}")
                                    safe_rerun()
                                except Exception as e:
                                    st.error(f"Submit failed: {str(e)[:500]}")
                    with sc2:
                        if st.button("Discard Draft", key="discard_finding"):
                            del st.session_state[draft_key]
                            st.info("Draft discarded.")
                            safe_rerun()

                elif len(findings) == 0 and not can_draft:
                    st.info("No findings yet. A Compliance Officer or Fraud Analyst can draft one.")

                st.divider()
                reports = session.sql(f"""
                    SELECT report_id, report_type, status, title, confidence, typology, created_at, approved_by
                    FROM {DB}.GOVERNANCE.FINDINGS_REPORTS
                    WHERE case_id = {esc(case_id)}
                    ORDER BY created_at DESC
                """).to_pandas()
                if len(reports) > 0:
                    st.subheader("Draft Reports")
                    st.dataframe(reports, use_container_width=True)

            with tab3:
                st.subheader("Reviewer Actions")
                if CURRENT_ROLE in ("ACCOUNTADMIN", "PLATFORM_ADMIN", "COMPLIANCE_OFFICER", "FRAUD_ANALYST"):
                    VALID_STATUSES = ["OPEN", "UNDER_REVIEW", "ESCALATED", "CLOSED_CONFIRMED", "CLOSED_FALSE_POS"]
                    new_status = st.selectbox("Update Status", VALID_STATUSES)
                    if st.button("Update Case Status"):
                        if new_status not in VALID_STATUSES:
                            st.error("Invalid status.")
                        else:
                            old_status = case_row["STATUS"]
                            session.sql(f"""
                                UPDATE {DB}.GOVERNANCE.CASES
                                SET status = {esc(new_status)},
                                    updated_at = CURRENT_TIMESTAMP(),
                                    closed_at = IFF({esc(new_status)} LIKE 'CLOSED%', CURRENT_TIMESTAMP(), closed_at),
                                    resolution = IFF({esc(new_status)} = 'CLOSED_CONFIRMED', 'STR_FILED',
                                                 IFF({esc(new_status)} = 'CLOSED_FALSE_POS', 'FALSE_POSITIVE', resolution))
                                WHERE case_id = {esc(case_id)}
                            """).collect()

                            session.sql(f"""
                                INSERT INTO {DB}.GOVERNANCE.REVIEWER_ACTIONS
                                    (action_id, finding_id, case_id, reviewer_name, reviewer_role,
                                     action_type, comment, action_timestamp)
                                VALUES (
                                    {esc('ACT-' + case_id[-12:] + '-' + new_status[:8])}, 'N/A', {esc(case_id)},
                                    CURRENT_USER(), {esc(CURRENT_ROLE)},
                                    'STATUS_CHANGE', {esc(f'{old_status} -> {new_status}')}, CURRENT_TIMESTAMP()
                                )
                            """).collect()

                            try:
                                session.sql(f"""
                                    CALL {DB}.GOVERNANCE.NOTIFY_STATE_CHANGE(
                                        'CASE', {esc(case_id)}, {esc(old_status)}, {esc(new_status)}
                                    )
                                """).collect()
                            except Exception:
                                pass
                            st.success(f"Case {case_id} updated to {new_status}")
                            safe_rerun()

                actions_df = session.sql(f"""
                    SELECT action_id, reviewer_name, reviewer_role, action_type, comment, action_timestamp
                    FROM {DB}.GOVERNANCE.REVIEWER_ACTIONS
                    WHERE case_id = {esc(case_id)}
                    ORDER BY action_timestamp DESC
                """).to_pandas()
                if len(actions_df) > 0:
                    st.dataframe(actions_df, use_container_width=True)
                else:
                    st.info("No reviewer actions yet.")

# =====================================================================
# PAGE 4 -- Liquidity & Credit Dashboard
# =====================================================================
elif page == "Liquidity & Credit":
    st.header("Liquidity & Credit Dashboard")

    tab1, tab2, tab3 = st.tabs(["Liquidity Ratio", "NPA / DPD Buckets", "Early Warning Borrowers"])

    with tab1:
        st.subheader("LCR Proxy Trend (Monthly)")
        lcr_df = session.sql(f"""
            WITH monthly AS (
                SELECT DATE_TRUNC('month', posting_date) AS month,
                       SUM(CASE WHEN gl_code IN ('GL1009','GL1010','GL2001','GL2002') THEN balance ELSE 0 END) AS hqla,
                       SUM(CASE WHEN gl_code IN ('GL1001','GL1002','GL1003','GL1004','GL1005') THEN balance ELSE 0 END) * 0.10 AS outflows
                FROM {DB}.CONFORMED.GENERAL_LEDGER_CLEAN
                GROUP BY 1
            )
            SELECT month, ROUND(hqla / NULLIF(outflows, 0) * 100, 1) AS lcr_pct, hqla, outflows
            FROM monthly ORDER BY month
        """).to_pandas()

        if len(lcr_df) > 0:
            st.line_chart(lcr_df.set_index("MONTH")["LCR_PCT"])
            st.dataframe(lcr_df, use_container_width=True)
        st.info("Internal threshold: LCR >= 110% (normal), >= 100% (stress) -- Liquidity Policy Section 2.3")

    with tab2:
        st.subheader("Loan Portfolio by DPD Bucket")
        dpd_df = session.sql(f"""
            SELECT CASE WHEN dpd = 0 THEN 'CURRENT'
                        WHEN dpd <= 30 THEN 'SMA-0'
                        WHEN dpd <= 60 THEN 'SMA-1'
                        WHEN dpd <= 90 THEN 'SMA-2'
                        WHEN dpd <= 180 THEN 'SUB-STANDARD'
                        ELSE 'DOUBTFUL' END AS dpd_bucket,
                   COUNT(*) AS loan_count,
                   SUM(outstanding) AS total_outstanding,
                   AVG(latest_bureau_score) AS avg_bureau
            FROM {DB}.CONFORMED.LOANS_CLEAN
            GROUP BY 1
            ORDER BY CASE dpd_bucket WHEN 'CURRENT' THEN 1 WHEN 'SMA-0' THEN 2 WHEN 'SMA-1' THEN 3
                     WHEN 'SMA-2' THEN 4 WHEN 'SUB-STANDARD' THEN 5 ELSE 6 END
        """).to_pandas()

        if len(dpd_df) > 0:
            st.bar_chart(dpd_df.set_index("DPD_BUCKET")["LOAN_COUNT"])
            mc1, mc2, mc3 = st.columns(3)
            total_loans = dpd_df["LOAN_COUNT"].sum()
            npa_count = dpd_df[dpd_df["DPD_BUCKET"].isin(["SUB-STANDARD", "DOUBTFUL"])]["LOAN_COUNT"].sum()
            mc1.metric("Total Loans", int(total_loans))
            mc2.metric("NPA Count (DPD>90)", int(npa_count))
            mc3.metric("NPA Ratio", f"{npa_count / total_loans * 100:.1f}%")
            st.dataframe(dpd_df, use_container_width=True)

        st.subheader("Concentration by Outstanding")
        conc_df = session.sql(f"""
            SELECT CASE WHEN outstanding < 100000 THEN '<1L'
                        WHEN outstanding < 1000000 THEN '1-10L'
                        WHEN outstanding < 10000000 THEN '10L-1Cr'
                        ELSE '>1Cr' END AS exposure_band,
                   COUNT(*) AS loans, SUM(outstanding) AS total_exposure
            FROM {DB}.CONFORMED.LOANS_CLEAN
            GROUP BY 1 ORDER BY total_exposure DESC
        """).to_pandas()
        if len(conc_df) > 0:
            st.bar_chart(conc_df.set_index("EXPOSURE_BAND")["TOTAL_EXPOSURE"])

    with tab3:
        st.subheader("Early Warning Borrowers (Bureau Score Drop >= 50)")
        ew_df = session.sql(f"""
            SELECT l.loan_id, l.customer_id, c.name, l.bureau_score_at_origination, l.latest_bureau_score,
                   (l.bureau_score_at_origination - l.latest_bureau_score) AS score_drop,
                   l.principal, l.outstanding, l.dpd,
                   CASE WHEN l.dpd = 0 THEN 'CURRENT' WHEN l.dpd <= 30 THEN 'SMA-0'
                        WHEN l.dpd <= 60 THEN 'SMA-1' WHEN l.dpd <= 90 THEN 'SMA-2'
                        ELSE 'NPA' END AS status
            FROM {DB}.CONFORMED.LOANS_CLEAN l
            JOIN {DB}.CONFORMED.CUSTOMERS_CLEAN c ON c.customer_id = l.customer_id
            WHERE (l.bureau_score_at_origination - l.latest_bureau_score) >= 50
            ORDER BY score_drop DESC LIMIT 50
        """).to_pandas()
        st.dataframe(ew_df, use_container_width=True, height=400)

# =====================================================================
# PAGE 5 -- Regulatory Reporting
# =====================================================================
elif page == "Regulatory Reporting":
    st.header("Regulatory Reporting")

    tab1, tab2, tab3 = st.tabs(["Draft Filings Queue", "Filing History", "Examiner Audit View"])

    with tab1:
        st.subheader("Draft Reports Awaiting Review")
        drafts = session.sql(f"""
            SELECT r.report_id, r.report_type, r.title, r.typology, r.confidence,
                   r.customer_id, r.created_at, r.status, c.case_id
            FROM {DB}.GOVERNANCE.FINDINGS_REPORTS r
            LEFT JOIN {DB}.GOVERNANCE.CASES c ON c.case_id = r.case_id
            WHERE r.status = 'DRAFT'
            ORDER BY r.created_at DESC
        """).to_pandas()

        if len(drafts) > 0:
            st.dataframe(drafts, use_container_width=True)

            if CURRENT_ROLE in ("ACCOUNTADMIN", "PLATFORM_ADMIN", "COMPLIANCE_OFFICER"):
                selected_report = st.selectbox("Select report to review", drafts["REPORT_ID"].tolist())
                if selected_report not in drafts["REPORT_ID"].values:
                    st.error("Invalid report selected.")
                else:
                    detail = session.sql(f"""
                        SELECT * FROM {DB}.GOVERNANCE.FINDINGS_REPORTS
                        WHERE report_id = {esc(selected_report)}
                    """).to_pandas()
                    if len(detail) > 0:
                        r = detail.iloc[0]
                        st.markdown(f"**Title:** {r['TITLE']}")
                        st.markdown(f"**Narrative:** {r['NARRATIVE']}")
                        st.markdown(f"**Evidence:** {r['EVIDENCE_SUMMARY']}")
                        st.markdown(f"**Policy Citations:** {r['POLICY_CITATIONS']}")
                        st.metric("Confidence", r["CONFIDENCE"])

                        col1, col2, col3 = st.columns(3)
                        with col1:
                            if st.button("Approve Filing"):
                                try:
                                    res = session.sql(f"CALL {DB}.GOVERNANCE.APPROVE_REPORT({esc(selected_report)}, 'APPROVE')").collect()
                                    st.success(f"Report {selected_report} APPROVED: {res[0][0]}")
                                    safe_rerun()
                                except Exception as e:
                                    st.error(f"Approval failed: {str(e)[:300]}")
                        with col2:
                            if st.button("Send Back for Edit"):
                                try:
                                    res = session.sql(f"CALL {DB}.GOVERNANCE.APPROVE_REPORT({esc(selected_report)}, 'RETURN')").collect()
                                    st.warning(f"Report {selected_report} returned: {res[0][0]}")
                                    safe_rerun()
                                except Exception as e:
                                    st.error(f"Return failed: {str(e)[:300]}")
                        with col3:
                            if st.button("Reject"):
                                try:
                                    res = session.sql(f"CALL {DB}.GOVERNANCE.APPROVE_REPORT({esc(selected_report)}, 'REJECT')").collect()
                                    st.error(f"Report {selected_report} rejected: {res[0][0]}")
                                    safe_rerun()
                                except Exception as e:
                                    st.error(f"Rejection failed: {str(e)[:300]}")
        else:
            st.info("No draft reports in queue. Use Ask Argus to generate finding drafts.")

    with tab2:
        st.subheader("Filing History (All Versions)")
        history = session.sql(f"""
            SELECT report_id, report_type, title, status, typology, confidence,
                   created_by, created_at, approved_by, approved_at, version
            FROM {DB}.GOVERNANCE.FINDINGS_REPORTS
            ORDER BY created_at DESC
        """).to_pandas()
        st.dataframe(history, use_container_width=True, height=400)

    with tab3:
        st.subheader("Examiner Audit View (Read-Only)")
        st.caption("Comprehensive view for RBI/FIU-IND examination -- all reports with full evidence chain.")
        exam_df = session.sql(f"""
            SELECT r.report_id, r.report_type, r.status, r.title, r.typology, r.confidence,
                   r.narrative, r.evidence_summary, r.policy_citations,
                   c.case_id, c.signal_type, c.priority, c.assigned_to,
                   s.detected_at AS signal_detected_at, s.evidence_json AS signal_evidence
            FROM {DB}.GOVERNANCE.FINDINGS_REPORTS r
            LEFT JOIN {DB}.GOVERNANCE.CASES c ON c.case_id = r.case_id
            LEFT JOIN {DB}.GOVERNANCE.SIGNALS_ALERTS s ON s.signal_id = c.signal_id
            ORDER BY r.created_at DESC
        """).to_pandas()
        st.dataframe(exam_df, use_container_width=True, height=500)

# =====================================================================
# PAGE 6 -- Audit Log
# =====================================================================
elif page == "Audit Log":
    st.header("Audit Log")

    tab1, tab2 = st.tabs(["Question Log", "Reviewer Actions"])

    with tab1:
        st.subheader("Agent Question & Answer Log")
        search_q = st.text_input("Search questions", placeholder="e.g. structuring, LCR, customer 101...")
        if search_q:
            safe_search = search_q.replace("'", "''").replace("%", "\\%").replace("_", "\\_")
            where = f"WHERE LOWER(question) LIKE '%{safe_search.lower()}%' ESCAPE '\\\\'"
        else:
            where = ""

        qlog = session.sql(f"""
            SELECT log_id, session_id, question, tool_used, confidence, response_summary,
                   user_role, queried_by, timestamp
            FROM {DB}.GOVERNANCE.QUESTION_LOG
            {where}
            ORDER BY timestamp DESC LIMIT 200
        """).to_pandas()
        st.dataframe(qlog, use_container_width=True, height=400)
        st.caption(f"Showing {len(qlog)} of most recent entries.")

    with tab2:
        st.subheader("Reviewer Actions History")
        actions = session.sql(f"""
            SELECT a.action_id, a.case_id, a.finding_id, a.reviewer_name, a.reviewer_role,
                   a.action_type, a.comment, a.action_timestamp
            FROM {DB}.GOVERNANCE.REVIEWER_ACTIONS a
            ORDER BY a.action_timestamp DESC
        """).to_pandas()
        st.dataframe(actions, use_container_width=True, height=400)

# =====================================================================
# PAGE 7 -- Integrations (PLATFORM_ADMIN only)
# =====================================================================
elif page == "Integrations":
    st.header("Integrations & Notifications")
    st.caption("Manage email recipients, configure alert preferences per recipient, and control notification channels.")

    tab_email, tab_channels, tab_log = st.tabs(["Email Recipients", "Channel Configuration", "Notification Log"])

    with tab_email:
        st.subheader("Email Recipients")
        st.info("Add email addresses of **Snowflake account users** who should receive Argus alerts. "
                "After adding/removing, click **Apply Changes** to rebuild the email integration.")

        recipients_df = session.sql(f"""
            SELECT recipient_id, email, display_name, role_filter, alert_signals, alert_findings,
                   alert_reports, alert_digest, min_severity, active, added_at
            FROM {DB}.GOVERNANCE.NOTIFICATION_RECIPIENTS
            ORDER BY added_at
        """).to_pandas()

        if len(recipients_df) > 0:
            st.dataframe(recipients_df[["EMAIL", "DISPLAY_NAME", "ROLE_FILTER", "ALERT_SIGNALS",
                "ALERT_FINDINGS", "ALERT_REPORTS", "ALERT_DIGEST", "MIN_SEVERITY", "ACTIVE"]],
                use_container_width=True)

        st.divider()
        st.subheader("Add New Recipient")
        col1, col2 = st.columns(2)
        with col1:
            new_email = st.text_input("Email address", placeholder="user@example.com",
                help="Must be an email belonging to a user in this Snowflake account.")
            new_name = st.text_input("Display name", placeholder="e.g. Priya Sharma")
        with col2:
            new_role = st.selectbox("Role filter", ["ALL", "COMPLIANCE_OFFICER", "FRAUD_ANALYST",
                "CREDIT_ANALYST", "TREASURY_ANALYST", "AUDITOR", "PLATFORM_ADMIN"])
            new_severity = st.selectbox("Minimum severity", ["HIGH", "CRITICAL", "MEDIUM", "LOW"])

        st.markdown("**Alert types for this recipient:**")
        ac1, ac2, ac3, ac4 = st.columns(4)
        new_signals = ac1.checkbox("Signals", value=True, key="new_sig")
        new_findings = ac2.checkbox("Findings", value=True, key="new_find")
        new_reports = ac3.checkbox("Reports", value=True, key="new_rpt")
        new_digest = ac4.checkbox("Daily Digest", value=True, key="new_dig")

        if st.button("Add Recipient", type="primary"):
            if not new_email or "@" not in new_email:
                st.error("Please enter a valid email address.")
            else:
                role_val = "NULL" if new_role == "ALL" else esc(new_role)
                try:
                    session.sql(f"""
                        INSERT INTO {DB}.GOVERNANCE.NOTIFICATION_RECIPIENTS
                            (email, display_name, role_filter, alert_signals, alert_findings,
                             alert_reports, alert_digest, min_severity, active)
                        VALUES ({esc(new_email)}, {esc(new_name)}, {role_val},
                                {new_signals}, {new_findings}, {new_reports}, {new_digest},
                                {esc(new_severity)}, TRUE)
                    """).collect()
                    st.success(f"Added {new_email}. Click **Apply Changes** below to activate.")
                    safe_rerun()
                except Exception as e:
                    st.error(f"Failed to add: {str(e)[:300]}")

        st.divider()
        if len(recipients_df) > 0:
            st.subheader("Manage Existing Recipients")
            manage_email = st.selectbox("Select recipient to manage",
                recipients_df["EMAIL"].tolist(), key="manage_sel")

            mc1, mc2, mc3, mc4 = st.columns(4)
            with mc1:
                if st.button("Toggle Active/Inactive", key="toggle_active"):
                    session.sql(f"""
                        UPDATE {DB}.GOVERNANCE.NOTIFICATION_RECIPIENTS
                        SET active = NOT active WHERE email = {esc(manage_email)}
                    """).collect()
                    safe_rerun()
            with mc2:
                if st.button("Remove Recipient", key="remove_recip"):
                    session.sql(f"""
                        DELETE FROM {DB}.GOVERNANCE.NOTIFICATION_RECIPIENTS
                        WHERE email = {esc(manage_email)}
                    """).collect()
                    st.warning(f"Removed {manage_email}.")
                    safe_rerun()
            with mc3:
                if st.button("Send Test Email", key="test_email"):
                    try:
                        result = session.sql(f"""
                            CALL {DB}.GOVERNANCE.SEND_TEST_EMAIL({esc(manage_email)})
                        """).collect()
                        st.success(f"Test email result: {result[0][0]}")
                    except Exception as e:
                        st.error(f"Test failed: {str(e)[:300]}")

        st.divider()
        st.subheader("Apply Changes")
        st.warning("After adding or removing recipients, click below to rebuild the Snowflake email integration. "
                    "Only emails belonging to verified Snowflake account users will work.")
        if st.button("Apply Changes -- Rebuild Email Integration", type="primary", key="rebuild_btn"):
            try:
                result = session.sql(f"CALL {DB}.GOVERNANCE.REBUILD_EMAIL_INTEGRATION()").collect()
                st.success(f"Integration rebuilt: {result[0][0]}")
            except Exception as e:
                st.error(f"Rebuild failed: {str(e)[:500]}")

    with tab_channels:
        st.subheader("Notification Channels")
        st.caption("Enable/disable channels and configure destinations. Changes take effect immediately.")

        config_df = session.sql(f"""
            SELECT channel, enabled, loop_stage, destination, min_severity
            FROM {DB}.GOVERNANCE.NOTIFICATION_CONFIG
            ORDER BY channel, loop_stage
        """).to_pandas()

        for _, row in config_df.iterrows():
            ch = row["CHANNEL"]
            stage = row["LOOP_STAGE"]
            enabled = row["ENABLED"]
            dest = row["DESTINATION"] or ""
            with st.expander(f"{'[ON]' if enabled else '[OFF]'} {ch} -> {stage} (severity >= {row['MIN_SEVERITY']})"):
                new_enabled = st.checkbox(f"Enabled", value=enabled, key=f"en_{ch}_{stage}")
                new_dest = st.text_input(f"Destination", value=dest, key=f"dest_{ch}_{stage}")
                new_sev = st.selectbox(f"Min Severity", ["LOW", "MEDIUM", "HIGH", "CRITICAL"],
                    index=["LOW", "MEDIUM", "HIGH", "CRITICAL"].index(row["MIN_SEVERITY"]),
                    key=f"sev_{ch}_{stage}")
                if st.button(f"Save {ch}/{stage}", key=f"save_{ch}_{stage}"):
                    session.sql(f"""
                        UPDATE {DB}.GOVERNANCE.NOTIFICATION_CONFIG
                        SET enabled = {new_enabled}, destination = {esc(new_dest)},
                            min_severity = {esc(new_sev)}, updated_at = CURRENT_TIMESTAMP()
                        WHERE channel = {esc(ch)} AND loop_stage = {esc(stage)}
                    """).collect()
                    st.success(f"Saved {ch}/{stage}.")
                    safe_rerun()

        st.divider()
        st.subheader("Channel Wiring Guide")
        st.markdown("""
| Channel | How to Activate |
|---|---|
| **Email** | Add recipients above. Uses Snowflake SYSTEM$SEND_EMAIL -- no external setup needed. |
| **Slack** | Set the webhook_url in the SLACK channel config to your Slack Incoming Webhook URL. |
| **SMS** | Wire via MCP connector to Twilio or AWS SNS. Set phone number in destination. |
| **Teams** | Set the webhook_url to a Power Automate / Teams Incoming Webhook URL. |
| **Jira** | Set base_url to your Jira Cloud URL. Wire via MCP connector or external access integration. |
        """)

    with tab_log:
        st.subheader("Notification Dispatch Log")
        nlog = session.sql(f"""
            SELECT notif_id, event_type, entity_type, entity_id, channel, loop_stage,
                   destination, status, error_message, sent_at
            FROM {DB}.GOVERNANCE.NOTIFICATION_LOG
            ORDER BY sent_at DESC LIMIT 100
        """).to_pandas()

        if len(nlog) > 0:
            mc1, mc2, mc3 = st.columns(3)
            mc1.metric("Total Dispatches", len(nlog))
            mc2.metric("Sent", len(nlog[nlog["STATUS"] == "SENT"]))
            mc3.metric("Failed/Not Configured", len(nlog[nlog["STATUS"] != "SENT"]))
            st.dataframe(nlog, use_container_width=True, height=400)
        else:
            st.info("No notifications dispatched yet.")
