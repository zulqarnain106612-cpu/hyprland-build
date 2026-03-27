import urllib.request, json, zipfile, io, sys

token = 'GH_TOKEN_PLACEHOLDER'
repo = 'zulqarnain106612-cpu/hyprland-build'
run_id = 23601281830
headers = {'Authorization': 'token ' + token}

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, hdrs, newurl):
        return urllib.request.Request(newurl)

opener = urllib.request.build_opener(NoRedirect())
req = urllib.request.Request(
    'https://api.github.com/repos/%s/actions/runs/%d/logs' % (repo, run_id),
    headers=headers)

try:
    r = opener.open(req)
    data = r.read()
    z = zipfile.ZipFile(io.BytesIO(data))
    print('Files:', z.namelist())
    content = z.read('0_build.txt').decode('utf-8', errors='replace')
    with open('latest_build_log.txt', 'w', encoding='utf-8') as f:
        f.write(content)
    print('Saved %d chars to latest_build_log.txt' % len(content))
    # Print last 6000 chars
    print(content[-6000:])
except Exception as e:
    print('ERROR:', type(e).__name__, e)
    import traceback; traceback.print_exc()
