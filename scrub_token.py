import subprocess, sys

<<<<<<< HEAD
TOKEN = 'REDACTED_TOKEN'
=======
TOKEN = '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'
>>>>>>> fix/hyprland-build-green
REPLACEMENT = '<token_removed>'

# Use git filter-repo if available, otherwise use BFG approach via subprocess
result = subprocess.run(
    ['git', 'filter-repo', '--replace-text', '-'],
    input=f'literal:{TOKEN}==>{REPLACEMENT}\n',
    capture_output=True, text=True
)
print(result.stdout)
print(result.stderr, file=sys.stderr)
