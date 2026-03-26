import subprocess, sys

TOKEN = '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'
REPLACEMENT = '<token_removed>'

# Use git filter-repo if available, otherwise use BFG approach via subprocess
result = subprocess.run(
    ['git', 'filter-repo', '--replace-text', '-'],
    input=f'literal:{TOKEN}==>{REPLACEMENT}\n',
    capture_output=True, text=True
)
print(result.stdout)
print(result.stderr, file=sys.stderr)
