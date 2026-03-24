import urllib.request
import json
import os

token = os.getenv('GITHUB_TOKEN')
if not token:
    print("GITHUB_TOKEN not set")
    exit(1)

# Get run status
req = urllib.request.Request(
    'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/actions/runs/23508417117',
    headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github.v3+json'}
)
resp = urllib.request.urlopen(req)
data = json.loads(resp.read())
print(f"Run Status: {data['status']}, Conclusion: {data.get('conclusion', 'N/A')}")

# Get jobs
req = urllib.request.Request(
    'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/actions/runs/23508417117/jobs',
    headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github.v3+json'}
)
resp = urllib.request.urlopen(req)
jobs_data = json.loads(resp.read())
for job in jobs_data['jobs']:
    print(f"Job: {job['name']}, Status: {job['status']}, Conclusion: {job['conclusion']}, ID: {job['id']}")
    if job['conclusion'] == 'failure':
        # Download logs
        req = urllib.request.Request(
            f'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/actions/jobs/{job["id"]}/logs',
            headers={'Authorization': f'Bearer {token}', 'Accept': 'application/vnd.github.v3+json'}
        )
        try:
            resp = urllib.request.urlopen(req)
            # Follow redirect
            if resp.status == 302:
                log_url = resp.headers['Location']
                print(f"Log URL: {log_url}")
                # Download the zip
                req2 = urllib.request.Request(log_url)
                with urllib.request.urlopen(req2) as log_resp:
                    with open(f'logs_{job["id"]}.zip', 'wb') as f:
                        f.write(log_resp.read())
                print(f"Logs downloaded to logs_{job['id']}.zip")
        except Exception as e:
            print(f"Error downloading logs: {e}")