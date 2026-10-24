# usage: python3 lu.py file.luau [Edit|Client|Server]  (studio id from STUDIO env or first listed)
import json,subprocess,sys,os,time
p=subprocess.Popen(['/Applications/RobloxStudio.app/Contents/MacOS/StudioMCP','--stdio'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.DEVNULL,text=True)
def send(m): p.stdin.write(json.dumps(m)+'\n'); p.stdin.flush()
def recv(i):
  while True:
    m=json.loads(p.stdout.readline())
    if m.get('id')==i: return m
def call(i,name,args):
  send({"jsonrpc":"2.0","id":i,"method":"tools/call","params":{"name":name,"arguments":args}})
  r=recv(i); outs=[]
  for c in r.get('result',{}).get('content',[]):
    if c.get('type')=='image':
      import base64; fn=os.environ.get('OUT','shot.png'); open(fn,'wb').write(base64.b64decode(c['data'])); outs.append('image -> '+fn)
    else: outs.append(c.get('text',str(c)))
  return "\n".join(outs) + (str(r['error']) if 'error' in r else '')
send({"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"cc","version":"1"}}}); recv(1)
send({"jsonrpc":"2.0","method":"notifications/initialized"}); time.sleep(4)
sid=os.environ.get('STUDIO') or json.loads(call(2,'list_roblox_studios',{}))['studios'][0]['id']
if sys.argv[1]=='--tool':
  a=json.loads(sys.argv[3]) if len(sys.argv)>3 else {}; a['studio_id']=sid; print(call(3,sys.argv[2],a))
else:
  print(call(3,'execute_luau',{"code":open(sys.argv[1]).read(),"datamodel_type":sys.argv[2] if len(sys.argv)>2 else "Edit","studio_id":sid}))
p.kill()
