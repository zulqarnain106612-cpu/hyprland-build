import urllib.request, json, time, sys

token = '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'
repo = 'zulqarnain106612-cpu/hyprland-build'
headers = {'Authorization': 'token ' + token}

def get(url):
    r = urllib.request.urlopen(urllib.request.Request(url, headers=headers))
    return json.loads(r.read())

# Find latest active or most recent build run
runs = get('https://api.github.com/repos/%s/actions/runs?per_page=5' % repo)['workflow_runs']
build_runs = [x for x in runs if 'Build Hyprland' in x['name']]
active = [x for x in build_runs if x['status'] in ('in_progress', 'queued')]
run = active[0] if active else build_runs[0]
run_id = run['id']
print('Monitoring run %d | status: %s | started: %s' % (run_id, run['status'], run['created_at']))
sys.stdout.flush()

prev_step = 0
for i in range(80):
    time.sleep(20)
    try:
        data = get('https://api.github.com/repos/%s/actions/runs/%d/jobs' % (repo, run_id))
        jobs = data.get('jobs', [])
        if not jobs:
            print('[%ds] waiting for jobs...' % ((i+1)*20))
            sys.stdout.flush()
            continue
        job = jobs[0]
        steps = [s for s in job.get('steps', []) if s['status'] != 'pending']
        # Print new steps only
        for s in steps:
            if s['number'] > prev_step:
                status = s.get('conclusion') or s['status']
                print('[%3ds] Step %2d: %-45s %s' % ((i+1)*20, s['number'], s['name'], status))
                sys.stdout.flush()
                prev_step = s['number']
        # Check if done
        if job.get('conclusion') in ('success', 'failure', 'cancelled'):
            print('\n=== FINAL: %s ===' % job['conclusion'].upper())
            sys.stdout.flush()
            break
        # Re-check run status
        run_data = get('https://api.github.com/repos/%s/actions/runs/%d' % (repo, run_id))
        if run_data['status'] == 'completed':
            print('\n=== RUN COMPLETED: %s ===' % run_data['conclusion'].upper())
            sys.stdout.flush()
            break
    except Exception as e:
        print('[%ds] error: %s' % ((i+1)*20, e))
        sys.stdout.flush()
