import urllib.request, json, time, sys, os

token = os.environ['GH_TOKEN']  # set via: set GH_TOKEN=<your_token>
headers = {'Authorization': 'token ' + token}

def get(url):
    r = urllib.request.urlopen(urllib.request.Request(url, headers=headers))
    return json.loads(r.read())

# Find latest run
runs = get('https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/actions/runs?per_page=5')['workflow_runs']
for x in runs:
    print(x['id'], x['status'], x['conclusion'], x['created_at'])

# Monitor the most recent in_progress or queued
active = [x for x in runs if x['status'] in ('in_progress', 'queued')]
if not active:
    print('No active runs')
    sys.exit(0)

run_id = active[0]['id']
print(f'\nMonitoring run {run_id}...\n')

for i in range(40):
    time.sleep(30)
    try:
        jobs = get(f'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/actions/runs/{run_id}/jobs').get('jobs', [])
        if not jobs:
            print(f'[{(i+1)*30}s] no jobs yet')
            sys.stdout.flush()
            continue
        job = jobs[0]
        steps = [s for s in job.get('steps', []) if s['status'] != 'pending']
        for s in steps[-5:]:
            print(f'[{(i+1)*30}s] {s["number"]:2}. {s["name"]}: {s["status"]}/{s.get("conclusion","")}')
        sys.stdout.flush()
        if job.get('conclusion') in ('success', 'failure', 'cancelled'):
            print('FINAL:', job['conclusion'])
            # Print all steps summary
            for s in job.get('steps', []):
                print(f'  {s["number"]:2}. {s["name"]}: {s.get("conclusion","pending")}')
            break
    except Exception as e:
        print(f'[{(i+1)*30}s] error: {e}')
        sys.stdout.flush()
