import urllib.request, zipfile, io, sys

token = 'GH_TOKEN_PLACEHOLDER'
repo = 'zulqarnain106612-cpu/hyprland-build'
run_id = 23654392425
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
    names = z.namelist()
    with open('step19_log.txt', 'w', encoding='utf-8') as out:
        out.write('Files: ' + str(names) + '\n\n')
        for name in names:
            if '19_' in name or 'Hyprland' in name:
                content = z.read(name).decode('utf-8', errors='replace')
                out.write('=== %s ===\n' % name)
                out.write(content[-5000:])
        # Also write combined log tail
        if '0_build.txt' in names:
            content = z.read('0_build.txt').decode('utf-8', errors='replace')
            out.write('\n=== 0_build.txt TAIL ===\n')
            out.write(content[-5000:])
    print('Written to step19_log.txt')
except Exception as e:
    import traceback
    with open('step19_log.txt', 'w') as out:
        traceback.print_exc(file=out)
    print('Error:', e)
