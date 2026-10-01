import subprocess, sys

yaml_content = open(r'C:\Users\91895\argus\scripts\argus_risk_copilot.sv.yaml', 'r', encoding='utf-8').read()

# Escape single quotes for SQL
yaml_escaped = yaml_content.replace("'", "''")

sql = "CALL SYSTEM$CREATE_SEMANTIC_VIEW_FROM_YAML(\n  'ARGUS_RISK_COPILOT.SEMANTIC.ARGUS_RISK_COPILOT',\n  '" + yaml_escaped + "',\n  FALSE\n)"

open(r'C:\Users\91895\argus\scripts\deploy_sv.sql', 'w', encoding='utf-8').write(sql)
print(f'SQL written: {len(sql)} chars')
