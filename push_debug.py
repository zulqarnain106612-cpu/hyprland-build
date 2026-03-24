import base64, json, urllib.request, sys, os

token = 'TOKEN_REMOVED'
base = os.path.dirname(os.path.abspath(__file__))

with open(os.path.join(base, 'debug_aquamarine.yml'), 'rb') as f:
    content = base64.b64encode(f.read()).decode()

body = json.dumps({'message': 'Add debug workflow', 'content': content}).encode()
req = urllib.request.Request(
    'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/contents/.github/workflows/debug.yml',
    data=body, method='PUT',
    headers={'Authorization': 'token ' + token, 'Content-Type': 'application/json'})

try:
    r = urllib.request.urlopen(req)
    d = json.loads(r.read())
    sys.stderr.write('PUSHED: ' + d.get('content', {}).get('name', 'ok') + '\n')
except urllib.error.HTTPError as e:
    sys.stderr.write('ERROR: ' + str(e.code) + ' ' + e.read().decode()[:300] + '\n')
