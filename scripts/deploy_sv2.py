import subprocess, sys

# Read the YAML
yaml_path = r'C:\Users\91895\argus\scripts\argus_risk_copilot.sv.yaml'
yaml_content = open(yaml_path, 'r', encoding='utf-8').read()

# Use cortex agent-studio sv-deploy with --yaml-content by writing to temp file 
# and using shell command substitution
import tempfile, os

# Save yaml to temp
tmp = os.path.join(tempfile.gettempdir(), 'sv_deploy.yaml')
with open(tmp, 'w', encoding='utf-8') as f:
    f.write(yaml_content)

# Use PowerShell to call cortex with file content
ps_cmd = f'''
$content = Get-Content -Raw '{tmp}'
cortex agent-studio sv-deploy --yaml-content $content --fqn ARGUS_RISK_COPILOT.SEMANTIC.ARGUS_RISK_COPILOT
'''

result = subprocess.run(
    ['powershell', '-NoProfile', '-Command', ps_cmd],
    capture_output=True, text=True, timeout=120
)
print('STDOUT:', result.stdout[:2000] if result.stdout else 'empty')
if result.stderr:
    print('STDERR:', result.stderr[:2000])
print('Return code:', result.returncode)

os.unlink(tmp)
