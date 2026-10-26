# Saves the open place's StarterGui UI (QM's Studio edits) into the repo: ui/<ScreenGui>.json,
# one file per ScreenGui (tools/studio/uicodec.luau). Run on the Mac with Studio open in Edit,
# then commit ui/. uiload.py puts them back into a place.
# (The JSON comes back in chunks, staged in StringValues in ServerStorage.UiSave, as
# execute_luau has no _G and its answers are best kept short.)
import json,os,subprocess,sys
D=os.path.dirname(os.path.abspath(__file__)); P=os.path.normpath(os.path.join(D,'..','..'))
CHUNK=60000
def run(code):
    tmp=os.path.join(D,'_uisave.luau'); open(tmp,'w').write(code)
    out=subprocess.run([sys.executable,os.path.join(D,'lu.py'),tmp,'Edit'],capture_output=True,text=True).stdout.strip().splitlines()
    os.remove(tmp)
    return out[-1] if out else ''
n=run(open(os.path.join(D,'uicodec.luau')).read()+f'''
local s=UiCodec.save()
local f=game.ServerStorage:FindFirstChild("UiSave") if f then f:Destroy() end
f=Instance.new("Folder") f.Name="UiSave" f.Parent=game.ServerStorage
local n=0
for i=1,#s,{CHUNK} do n+=1 local v=Instance.new("StringValue") v.Name=string.format("%05d",n) v.Value=string.sub(s,i,i+{CHUNK}-1) v.Parent=f end
return "chunks "..n
''')
if not n.startswith('chunks '): sys.exit('Studio said: '+n)
parts=[]
for i in range(1,int(n.split()[1])+1):
    parts.append(run(f'return "<<"..game.ServerStorage.UiSave["{i:05d}"].Value..">>"').strip()[2:-2])
run('local f=game.ServerStorage:FindFirstChild("UiSave") if f then f:Destroy() end return "ok"')
guis=json.loads(''.join(parts))
os.makedirs(os.path.join(P,'ui'),exist_ok=True)
for name,node in guis.items():
    with open(os.path.join(P,'ui',name+'.json'),'w') as f: json.dump(node,f,indent=1,sort_keys=True)
    print('saved ui/%s.json'%name)
