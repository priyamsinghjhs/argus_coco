import subprocess, sys, shutil

yaml_path = r'C:\Users\91895\argus\scripts\argus_risk_copilot.sv.yaml'
yaml_content = open(yaml_path, 'r', encoding='utf-8').read()

cortex = shutil.which('cortex') or 'cortex.cmd'
print(f'Using cortex at: {cortex}')

# Try sv-write first
r = subprocess.run(
    f'{cortex} agent-studio sv-write --yaml-content - --file-path ARGUS_RISK_COPILOT.sv.yaml',
    input=yaml_content, capture_output=True, text=True, timeout=60, shell=True
)
print('WRITE stdout:', r.stdout[:1000])
if r.stderr:
    print('WRITE stderr:', r.stderr[:1000])

# If sv-write doesn't support stdin, try direct deploy
r2 = subprocess.run(
    f'{cortex} agent-studio sv-deploy --yaml-content - --fqn ARGUS_RISK_COPILOT.SEMANTIC.ARGUS_RISK_COPILOT',
    input=yaml_content, capture_output=True, text=True, timeout=120, shell=True
)
print('DEPLOY stdout:', r2.stdout[:1000])
if r2.stderr:
    print('DEPLOY stderr:', r2.stderr[:1000])
