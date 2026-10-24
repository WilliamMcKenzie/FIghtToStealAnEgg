# usage: meshup.py out.json file.obj ... : uploads each OBJ as a mesh through Studio (Edit),
# writes { name: "rbxassetid://..." } to out.json (merging).
import json,os,subprocess,sys
S=os.path.dirname(os.path.abspath(__file__))
out=sys.argv[1]; ids=json.load(open(out)) if os.path.exists(out) else {}
for path in sys.argv[2:]:
    name=os.path.splitext(os.path.basename(path))[0]
    if name in ids: print(name,"already",ids[name]); continue
    v,vt,vn,f=[],[],[],[]
    for l in open(path):
        p=l.split()
        if not p: continue
        if p[0]=="v": v.append([round(float(x),4) for x in p[1:4]])
        elif p[0]=="vt": vt.append([round(float(x),4) for x in p[1:3]])
        elif p[0]=="vn": vn.append([round(float(x),4) for x in p[1:4]])
        elif p[0]=="f": f.append([[int(i) if i else 0 for i in c.split("/")] for c in p[1:]])
    data=json.dumps({"v":v,"vt":vt,"vn":vn,"f":f})
    code=f'''
local AS=game:GetService("AssetService")
local d=game:GetService("HttpService"):JSONDecode({json.dumps(data)})
local m=AS:CreateEditableMesh()
local V,T,N={{}},{{}},{{}}
for i,p in d.v do V[i]=m:AddVertex(Vector3.new(p[1],p[2],p[3])) end
for i,p in d.vt do T[i]=m:AddUV(Vector2.new(p[1],1-p[2])) end
for i,p in d.vn do N[i]=m:AddNormal(Vector3.new(p[1],p[2],p[3])) end
for _,face in d.f do
  for k=2,#face-1 do
    local a,b,c=face[1],face[k],face[k+1]
    local t=m:AddTriangle(V[a[1]],V[b[1]],V[c[1]])
    if a[2]~=0 then m:SetFaceUVs(t,{{T[a[2]],T[b[2]],T[c[2]]}}) end
    if a[3]~=0 then m:SetFaceNormals(t,{{N[a[3]],N[b[3]],N[c[3]]}}) end
  end
end
local ok,res,id=pcall(function() return AS:CreateAssetAsync(m,Enum.AssetType.Mesh,{{Name="{name}"}}) end)
return tostring(ok).." "..tostring(res).." "..tostring(id)
'''
    tmp=os.path.join(S,"_up.luau"); open(tmp,"w").write(code)
    r=subprocess.run(["python3",os.path.join(S,"lu.py"),tmp,"Edit"],capture_output=True,text=True).stdout.strip().splitlines()
    r=r[-1] if r else ""
    print(name,r)
    parts=r.split()
    if len(parts)>=3 and parts[0]=="true" and parts[2]!="nil":
        ids[name]="rbxassetid://"+parts[2]; json.dump(ids,open(out,"w"),indent=2)
