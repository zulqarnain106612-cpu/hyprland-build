import subprocess, sys

TOKEN = 'REDACTED_TOKEN'
REPLACEMENT = '<token_removed>'

# Use git filter-repo if available, otherwise use BFG approach via subprocess
result = subprocess.run(
    ['git', 'filter-repo', '--replace-text', '-'],
    input=f'literal:{TOKEN}==>{REPLACEMENT}\n',
    capture_output=True, text=True
)
print(result.stdout)
print(result.stderr, file=sys.stderr)
