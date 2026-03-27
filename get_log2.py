import urllib.request, zipfile, io, sys

token = 'GH_TOKEN_PLACEHOLDER'
repo = 'zulqarnain106612-cpu/hyprland-build'
run_id = 23602662287
headers = {'Authorization': 'token ' + token}

class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, hdrs, newurl):
        return urllib.request.Request(newurl)

opener = urllib.request.build_opener(NoRedirect())
try:
    r = opener.open(urllib.request.Request(
        'https://api.github.com/repos/%s/actions/runs/%d/logs' % (repo, run_id),
        headers=headers))
    z = zipfile.ZipFile(io.BytesIO(r.read()))
    print('Files:', z.namelist())
    for name in z.namelist():
        if 'hyprwire' in name.lower() or '15_' in name:
            content = z.read(name).decode('utf-8', errors='replace')
            print('\n=== %s ===' % name)
            print(content[-3000:])
except Exception as e:
    import traceback; traceback.print_exc()
