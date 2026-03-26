import base64, json, urllib.request, sys, os

token = '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'
base = os.path.dirname(os.path.abspath(__file__))

# Get current SHA
req = urllib.request.Request(
    'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/contents/.github/workflows/build.yml',
    headers={'Authorization': 'token ' + token})
try:
    r = urllib.request.urlopen(req)
    sha = json.loads(r.read())['sha']
except:
    sha = None

with open(os.path.join(base, 'build.yml'), 'rb') as f:
    content = base64.b64encode(f.read()).decode()

body_data = {'message': 'Fix aquamarine PATH - add explicit step + CMAKE_PREFIX_PATH', 'content': content}
if sha:
    body_data['sha'] = sha

body = json.dumps(body_data).encode()
req = urllib.request.Request(
    'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/contents/.github/workflows/build.yml',
    data=body, method='PUT',
    headers={'Authorization': 'token ' + token, 'Content-Type': 'application/json'})

try:
    r = urllib.request.urlopen(req)
    d = json.loads(r.read())
    print('PUSHED:', d.get('content', {}).get('name', 'ok'))
    
    # Trigger workflow
    trigger = urllib.request.Request(
        'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/actions/workflows/build.yml/dispatches',
        data=json.dumps({'ref': 'main'}).encode(),
        method='POST',
        headers={'Authorization': 'token ' + token, 'Content-Type': 'application/json'})
    urllib.request.urlopen(trigger)
    print('TRIGGERED')
except urllib.error.HTTPError as e:
    print('ERROR:', e.code, e.read().decode()[:500])
