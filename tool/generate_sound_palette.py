"""Generate the original short, mono PCM sound palette; no external samples."""
from pathlib import Path
import math,random,struct,wave
RATE=22050
root=Path(__file__).resolve().parents[1]/'assets/audio'
def write(name,duration,kind,seed):
 rng=random.Random(seed);samples=[]
 for i in range(int(duration*RATE)):
  t=i/RATE;u=t/duration
  attack=min(1,t/.012);envelope=attack*(1-u)**2
  noise=rng.uniform(-1,1)
  if kind=='paper': value=.2*noise*math.exp(-t*23)+.4*math.sin(2*math.pi*(580+200*u)*t)*envelope
  elif kind=='heartbeat':
   value=sum(.6*math.sin(2*math.pi*72*(t-d))*math.exp(-(t-d)*32) for d in [0,.14] if t>=d)
  elif kind=='cut': value=(.2*noise+.35*math.sin(2*math.pi*(1100-700*u)*t))*envelope
  elif kind=='ready': value=sum(.22*math.sin(2*math.pi*f*t) for f in [220,330,440])*envelope
  elif kind=='anchor': value=(.45*math.sin(2*math.pi*(260-80*u)*t)+.12*noise*math.exp(-t*30))*envelope
  else: value=.45*noise*math.sin(math.pi*u)**2*(1-u)
  samples.append(struct.pack('<h',int(max(-.85,min(.85,value))*32767)))
 with wave.open(str(root/f'{name}.wav'),'wb') as out:
  out.setparams((1,2,RATE,0,'NONE','not compressed'));out.writeframes(b''.join(samples))
for args in [('memory',.19,'paper',1),('risk',.32,'heartbeat',2),('reaction',.17,'cut',3),('pulse_ready',.38,'ready',4),('anchor',.28,'anchor',5),('exchange',.18,'exchange',6)]:write(*args)
