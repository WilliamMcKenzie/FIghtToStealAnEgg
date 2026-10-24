# usage: imgup.py file.png[:WxH] ... : uploads each PNG as a Roblox image through Studio
# (EditableImage + AssetService:CreateAssetAsync in the Edit datamodel), printing its
# rbxassetid. Optional WxH resizes first (Roblox keeps images at most 1024 on a side).
# Pixels go over in base64 chunks staged in StringValues (ServerStorage.ImgUp), as
# execute_luau has no _G; the final call decodes them into a buffer.
import base64,json,os,subprocess,sys
from PIL import Image
S=os.path.dirname(os.path.abspath(__file__))
CHUNK=190000
OUT=os.environ.get('OUT','ids.json')
def run(code):
    tmp=os.path.join(S,"_img.luau"); open(tmp,"w").write(code)
    out=subprocess.run(["python3",os.path.join(S,"lu.py"),tmp,"Edit"],capture_output=True,text=True).stdout.strip().splitlines()
    return out[-1] if out else ""
for arg in sys.argv[1:]:
    path,_,size=arg.partition(":")
    im=Image.open(path).convert("RGBA")
    if size:
        w,h=map(int,size.split("x")); im=im.resize((w,h),Image.LANCZOS)
    elif max(im.size)>1024:
        im.thumbnail((1024,1024),Image.LANCZOS)
    w,h=im.size
    data=base64.b64encode(im.tobytes()).decode()
    chunks=[data[i:i+CHUNK] for i in range(0,len(data),CHUNK)]
    run('local f=game.ServerStorage:FindFirstChild("ImgUp") if f then f:Destroy() end f=Instance.new("Folder") f.Name="ImgUp" f.Parent=game.ServerStorage return "ok"')
    for i in range(0,len(chunks),5):
        parts=" ".join(f'do local v=Instance.new("StringValue") v.Name="{j:05d}" v.Value="{chunks[j]}" v.Parent=f end' for j in range(i,min(i+5,len(chunks))))
        run(f'local f=game.ServerStorage.ImgUp {parts} return "ok"')
    name=os.path.splitext(os.path.basename(path))[0]
    code=f'''
local f=game.ServerStorage.ImgUp
local kids=f:GetChildren() table.sort(kids,function(a,b) return a.Name<b.Name end)
local parts={{}} for _,v in kids do table.insert(parts,v.Value) end
local b64=table.concat(parts)
local map={{}} local A="ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i=1,64 do map[string.byte(A,i)]=i-1 end
local n=#b64 local out=buffer.create({w*h*4}) local o=0
for i=1,n,4 do
  local a,b,c,d=string.byte(b64,i,i+3)
  local x=map[a]*262144+map[b]*4096+(c~=61 and map[c] or 0)*64+(d~=61 and map[d] or 0)
  buffer.writeu8(out,o,bit32.rshift(x,16)) o+=1
  if c~=61 then buffer.writeu8(out,o,bit32.band(bit32.rshift(x,8),255)) o+=1 end
  if d~=61 then buffer.writeu8(out,o,bit32.band(x,255)) o+=1 end
end
f:Destroy()
local AS=game:GetService("AssetService")
local img=AS:CreateEditableImage({{Size=Vector2.new({w},{h})}})
img:WritePixelsBuffer(Vector2.zero,Vector2.new({w},{h}),out)
local result,id=AS:CreateAssetAsync(img,Enum.AssetType.Image,{{Name="{name}"}})
return tostring(result).." "..tostring(id)'''
    r=run(code); print(name,f"{w}x{h}",r)
    ids=json.load(open(OUT)) if os.path.exists(OUT) else {}
    p=r.split()
    if len(p)==2 and p[0].endswith("Success") and p[1].isdigit():
        ids[name]="rbxassetid://"+p[1]; json.dump(ids,open(OUT,"w"),indent=2)
