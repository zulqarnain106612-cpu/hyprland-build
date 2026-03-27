import urllib.request, json, zipfile, io, sys

token = 'GH_TOKEN_PLACEHOLDER'
repo = 'zulqarnain106612-cpu/hyprland-build'
run_id = 23602662287
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
    print('Files:', [n for n in z.namelist() if 'aquamarine' in n.lower() or n == '0_build.txt'])
    
    # Try step-specific log
    for name in z.namelist():
        if 'aquamarine' in name.lower():
            content = z.read(name).decode('utf-8', errors='replace')
            print('\n=== %s (last 3000) ===' % name)
            print(content[-3000:])
            break
    else:
        # Fall back to combined log
        content = z.read('0_build.txt').decode('utf-8', errors='replace')
        idx = content.rfind('Build aquamarine')
        print(content[idx:idx+4000] if idx >= 0 else content[-4000:])
except Exception as e:
    import traceback; traceback.print_exc()
