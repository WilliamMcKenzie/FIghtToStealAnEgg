# Rough solo progression sim for the Oct 27 balance pass (Config.luau numbers copied in by hand).
# python3 tools/balance_sim.py [eggs per boss cycle]. Lava pets are LassoAPet's Volcano ones (cash on this curve).
import math, random, sys
P = dict(Scale=10, Damage=0.65, Speed=0.054, Max=2)
def pdmg(S): return 1+P['Damage']*math.log(1+S/P['Scale'])
def pspd(S): return min(1+P['Speed']*math.log(1+S/P['Scale']), P['Max'])
# weapons in price order: (name, price, base dps at S=0)
W = [("Kendo",0)]+[(n,p) for n,p in [("Shortbow",500),("Shortsword",1500),("Staff",3500),("Axe",10000),("Lightning",25000),("Longbow",50000),("Longsword",100000),("Wind",250000),("Water",500000),("Waraxe",1000000),("Club",2000000),("Unholy",4000000),("Nature",8000000),("Blood",15000000),("Fire",30000000),("Flower",75000000)]]
WDPS=[20*1.3**i for i in range(len(W))]
biomes=["Meadow","Desert","Ice","Lava"]
REG = dict(Meadow=0,Desert=6000,Ice=120000,Lava=1500000)
GROUND = dict(Meadow=(300,2),Desert=(8000,5),Ice=(150000,15),Lava=(2000000,45))
BOSS = dict(Meadow=(200,2,40),Desert=(4000,6,400),Ice=(30000,20,3000),Lava=(200000,60,20000)) # hp, strength, cash bounty
EGGS = dict(
 Meadow={"Pinto":(.35,15,15),"Pig":(.25,9,15),"Bunny":(.25,12,15),"Fish":(.13,24,45),"Rhino":(.08,90,120),"Unicorn":(.05,450,3600)},
 Desert={"Cactus":(.3,18,15),"Scorpion":(.3,60,60),"Sandworm":(.2,180,75),"SpineLizard":(.2,240,90),"Snake":(.025,750,7200)},
 Ice={"Penguin":(.3,45,15),"Boar":(.25,91,15),"Snowman":(.22,180,60),"IceGolem":(.12,760,300),"Icebringer":(.02,2000,7200)},
 Lava={"Firebird":(.42,300,15),"RockHog":(.18,600,60),"FireLobster":(.17,650,60),"VolcanoTortoise":(.1,800,60),"Rockworm":(.13,1800,1200),"LavaWhale":(.03,4500,1200),"Phoenix":(.03,12000,43200)})
EGGS_PER_CYCLE=int(sys.argv[1]) if len(sys.argv)>1 else 3
def run(seed, verbose=False, REBIRTH=10_000_000):
  rnd=random.Random(seed)
  t=0; cash=0; S=0; wi=0; reg=1; grounds=set(); pets=[]; hatching=[]
  log=[]
  def dps(): return WDPS[wi]*pdmg(S)*pspd(S)
  def income(): return sum(sorted(pets,reverse=True)[:5])
  bought_log=[]
  while t<4*3600:
    b=biomes[reg-1]
    hp,bs,bounty=BOSS[b]
    ttk=hp/dps()
    if ttk>120: # too hard: fight previous boss
      b=biomes[reg-2]; hp,bs,bounty=BOSS[b]; ttk=hp/dps()
    # fight
    S+=hp*bs*0.1; cash+=bounty+income()*ttk; t+=ttk
    # eggs
    for _ in range(EGGS_PER_CYCLE):
      if len(hatching)<8:
        r=rnd.random(); acc=0
        for k,(w,c,h) in EGGS[b].items():
          acc+=w/sum(x[0] for x in EGGS[b].values())
          if r<=acc: hatching.append((t+h,c)); break
    # cooldown 60s: train
    g=max([x for x in grounds], key=lambda x:GROUND[x][1], default=None)
    gs=GROUND[g][1] if g else 1
    S+=dps()*gs*0.1*0.6*60  # 60% uptime
    cash+=income()*60; t+=60
    done=[x for x in hatching if x[0]<=t]; hatching=[x for x in hatching if x[0]>t]
    pets+= [c for _,c in done]
    # spend greedily: cheapest available
    while True:
      opts=[]
      if wi+1<len(W): opts.append((W[wi+1][1],'w'))
      if reg<4: opts.append((REG[biomes[reg]],'r'))
      for gname in biomes[:reg]:
        if gname not in grounds: opts.append((GROUND[gname][0],'g',gname))
      if not opts: break
      o=min(opts)
      if o[0]>cash: break
      cash-=o[0]
      if o[1]=='w': wi+=1; bought_log.append((t,W[wi][0]))
      elif o[1]=='r':
        reg+=1; nb=biomes[reg-1]; bought_log.append((t,"REGION "+nb)); log.append((nb,t/60,S,W[wi][0],dps(),BOSS[nb][0]/dps(),income()))
      else: grounds.add(o[2]); bought_log.append((t,"ground "+o[2]))
    if cash>=REBIRTH and reg==4:
      log.append(("Rebirth",t/60,S,W[wi][0],dps(),0,income())); break
  if verbose:
    for x in bought_log: print("  %6.1f min %s"%(x[0]/60,x[1]))
  return log
for seed in range(3):
  for nb,m,S,w,d,ttk,inc in run(seed, verbose=(seed==0)):
    print(f"{nb:8} at {m:6.1f} min  S={S:10.0f}  {w:10} dps={d:8.0f}  bossTTK={ttk:5.1f}s  income={inc:6.0f}/s")
  print()
