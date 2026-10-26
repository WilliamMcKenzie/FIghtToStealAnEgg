# Puts ui/*.json (saved by uisave.py) back into the open place's StarterGui, replacing those
# ScreenGuis: for a fresh place, or to undo Studio edits back to the repo's. Edit mode.
#   python3 uiload.py            # every ui/*.json
#   python3 uiload.py Hud        # just ui/Hud.json
import json,os,subprocess,sys,glob
D=os.path.dirname(os.path.abspath(__file__)); P=os.path.normpath(os.path.join(D,'..','..'))
names=sys.argv[1:] or [os.path.basename(f)[:-5] for f in sorted(glob.glob(os.path.join(P,'ui','*.json')))]
guis={n:json.load(open(os.path.join(P,'ui',n+'.json'))) for n in names}
s=json.dumps(guis); k=0
while ']'+'='*k+']' in s: k+=1
code=open(os.path.join(D,'uicodec.luau')).read()+'\nreturn UiCodec.load([%s[%s]%s])\n'%('='*k,s,'='*k)
tmp=os.path.join(D,'_uiload.luau'); open(tmp,'w').write(code)
subprocess.run([sys.executable,os.path.join(D,'lu.py'),tmp,'Edit'])
os.remove(tmp)
