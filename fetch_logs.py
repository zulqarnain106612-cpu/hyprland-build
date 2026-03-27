import urllib.request, urllib.error, zipfile, io, os, sys

token = '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'
run_id = 23581328233

class NoRedirectHandler(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Follow redirect without auth header to avoid Azure 403
        new_req = urllib.request.Request(newurl)
        return new_req

opener = urllib.request.build_opener(NoRedirectHandler())

req = urllib.request.Request(
    'https://api.github.com/repos/zulqarnain1066-hub/hyprland-build/actions/runs/%d/logs' % run_id,
    headers={'Authorization': 'token ' + token})

try:
    r = opener.open(req)
    data = r.read()
    z = zipfile.ZipFile(io.BytesIO(data))
    print('Files in zip:', z.namelist())
    for name in z.namelist():
        if 'build' in name.lower():
            content = z.read(name).decode('utf-8', errors='replace')
            # Find error section
            for keyword in ['error:', 'Error', 'FAILED', 'fatal']:
                idx = content.rfind(keyword)
                if idx > 0:
                    print(f'\n=== {name} (around last {keyword}) ===')
                    print(content[max(0,idx-500):idx+1000])
                    break
except Exception as e:
    print('ERROR:', type(e).__name__, e)
