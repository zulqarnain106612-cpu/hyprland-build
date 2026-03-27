import urllib.request, json, zipfile, io

token = 'GH_TOKEN_PLACEHOLDER'
repo = 'zulqarnain106612-cpu/hyprland-build'
headers = {'Authorization': 'token ' + token}

def get(url):
    r = urllib.request.urlopen(urllib.request.Request(url, headers=headers))
    return json.loads(r.read())

# Latest runs
runs = get('https://api.github.com/repos/%s/actions/runs?per_page=5' % repo)['workflow_runs']
for x in runs:
    print(x['id'], x['name'], x['status'], x['conclusion'], x['created_at'])

# Latest build run
build_runs = [x for x in runs if 'Build Hyprland' in x['name']]
run = build_runs[0]
run_id = run['id']
print('\nLatest build run:', run_id, run['status'], run['conclusion'])

# Get steps
jobs = get('https://api.github.com/repos/%s/actions/runs/%d/jobs' % (repo, run_id)).get('jobs', [])
if jobs:
    for s in jobs[0].get('steps', []):
        mark = s.get('conclusion') or s['status']
        print('  %2d. %-45s %s' % (s['number'], s['name'], mark))

# If failed, get logs
if run['conclusion'] == 'failure' and jobs:
    failed = [s for s in jobs[0].get('steps', []) if s.get('conclusion') == 'failure']
    if failed:
        step_num = failed[0]['number']
        print('\nFailed at step %d: %s' % (step_num, failed[0]['name']))

        class NoRedirect(urllib.request.HTTPRedirectHandler):
            def redirect_request(self, req, fp, code, msg, hdrs, newurl):
                return urllib.request.Request(newurl)

        opener = urllib.request.build_opener(NoRedirect())
        r = opener.open(urllib.request.Request(
            'https://api.github.com/repos/%s/actions/runs/%d/logs' % (repo, run_id),
            headers=headers))
        z = zipfile.ZipFile(io.BytesIO(r.read()))
        target = '%d_' % step_num
        for name in z.namelist():
            if target in name:
                print(z.read(name).decode('utf-8', errors='replace')[-3000:])
                break
